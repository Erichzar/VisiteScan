//
//  MacroCameraView.swift
//  VisiteScan
//
//  'n Eie kamera, want die stelselkameras gee ons geen beheer oor die lens nie.
//
//  Die iPhone het nie 'n makro-lens nie. Wat dit doen, is om outomaties na die
//  ultragroothoeklens oor te skakel wanneer die onderwerp te naby raak vir die
//  hoofkamera om te fokus. Daardie oorskakeling gebeur net as die app 'n
//  *virtuele* toestel gebruik (.builtInTripleCamera of .builtInDualWideCamera).
//  Vra jy net .builtInWideAngleCamera, kry jy nooit makro nie — en 'n
//  UIImagePickerController laat jou nie eens kies nie. Vandaar hierdie lêer.
//
//  Die lens-etiket bo-aan die skerm wys watter lens op hierdie oomblik aktief
//  is, sodat 'n mens kan sien wanneer die makro-oorskakeling werklik gebeur.
//

import SwiftUI
import AVFoundation
import UIKit

// MARK: - SwiftUI-omhulsel

struct MacroCameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> MacroCameraController {
        let controller = MacroCameraController()
        controller.onCapture = { captured in
            image = captured
            dismiss()
        }
        controller.onCancel = { dismiss() }
        return controller
    }

    func updateUIViewController(_ uiViewController: MacroCameraController, context: Context) {}
}

// MARK: - Die kamera self

final class MacroCameraController: UIViewController {

    var onCapture: ((UIImage) -> Void)?
    var onCancel: (() -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "za.co.lutz.VisiteScan.kamera")

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var device: AVCaptureDevice?

    private let lensLabel = UILabel()
    private var lensTimer: Timer?

    // MARK: Lewensiklus

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        buildPreview()
        buildControls()

        sessionQueue.async { [weak self] in
            self?.configureSession()
            self?.session.startRunning()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Elke halwe sekonde: wys watter lens nou aktief is.
        lensTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateLensLabel()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        lensTimer?.invalidate()
        lensTimer = nil
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    // MARK: Toestelkeuse

    /// Van beste na swakste. Die eerste twee is virtuele toestelle wat die
    /// ultragroothoek insluit — hulle gee makro. Die laaste een is die terugval
    /// vir toestelle sonder ultragroothoek; dan is daar eenvoudig nie makro nie.
    private static func bestDevice() -> AVCaptureDevice? {
        let preferred: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInWideAngleCamera
        ]
        for type in preferred {
            if let device = AVCaptureDevice.default(type, for: .video, position: .back) {
                return device
            }
        }
        return nil
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = Self.bestDevice(),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        self.device = device

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }

        session.commitConfiguration()

        // Fokus op naby goed. 'n Visitekaartjie is altyd naby, en sonder hierdie
        // beperking soek die outofokus ook na die agtergrond en swaai heen en weer.
        if (try? device.lockForConfiguration()) != nil {
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            device.unlockForConfiguration()
        }
    }

    // MARK: Voorskou

    private func buildPreview() {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        // Die vel word altyd regop aangebied, so hou die voorskou regop.
        if let connection = layer.connection,
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)
    }

    // MARK: Knoppies

    private func buildControls() {
        // Lens-etiket
        lensLabel.text = "…"
        lensLabel.textColor = .white
        lensLabel.font = .systemFont(ofSize: 13, weight: .medium)
        lensLabel.textAlignment = .center
        lensLabel.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        lensLabel.layer.cornerRadius = 12
        lensLabel.clipsToBounds = true
        lensLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(lensLabel)

        // Sluiter
        let shutter = UIButton(type: .custom)
        shutter.backgroundColor = .white
        shutter.layer.cornerRadius = 36
        shutter.layer.borderWidth = 4
        shutter.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        shutter.translatesAutoresizingMaskIntoConstraints = false
        shutter.addTarget(self, action: #selector(capture), for: .touchUpInside)
        view.addSubview(shutter)

        // Kanselleer
        let cancel = UIButton(type: .system)
        cancel.setTitle("Kanselleer", for: .normal)
        cancel.setTitleColor(.white, for: .normal)
        cancel.translatesAutoresizingMaskIntoConstraints = false
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancel)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            lensLabel.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            lensLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            lensLabel.heightAnchor.constraint(equalToConstant: 24),
            lensLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),

            shutter.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            shutter.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -28),
            shutter.widthAnchor.constraint(equalToConstant: 72),
            shutter.heightAnchor.constraint(equalToConstant: 72),

            cancel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
            cancel.centerYAnchor.constraint(equalTo: shutter.centerYAnchor)
        ])
    }

    private func updateLensLabel() {
        guard let device else {
            lensLabel.text = " Geen kamera "
            return
        }
        // By 'n virtuele toestel sê activePrimaryConstituent watter werklike lens
        // op hierdie oomblik gebruik word. Skakel dit na die ultragroothoek oor,
        // is die makro-modus aan.
        let name = device.activePrimaryConstituent?.localizedName ?? device.localizedName
        let isMacro = name.localizedCaseInsensitiveContains("ultra")
        lensLabel.text = isMacro ? "  \(name) — makro aan  " : "  \(name)  "
    }

    // MARK: Aksies

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let device, let previewLayer else { return }
        let point = gesture.location(in: view)
        let focusPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)

        guard (try? device.lockForConfiguration()) != nil else { return }
        if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
            device.focusPointOfInterest = focusPoint
            device.focusMode = .autoFocus
        }
        if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
            device.exposurePointOfInterest = focusPoint
            device.exposureMode = .autoExpose
        }
        device.unlockForConfiguration()
    }

    @objc private func capture() {
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .quality
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    @objc private func cancelTapped() {
        onCancel?()
    }
}

// MARK: - Vangs

extension MacroCameraController: AVCapturePhotoCaptureDelegate {

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        // normalizedUp() want 'n kamerafoto kom as .right, en cgImage ignoreer
        // die oriëntasie — sonder dit sou Vision die teks sywaarts sien.
        DispatchQueue.main.async { [weak self] in
            self?.onCapture?(image.normalizedUp())
        }
    }
}
