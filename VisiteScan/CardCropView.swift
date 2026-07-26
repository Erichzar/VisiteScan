//
//  CardCropView.swift
//  VisiteScan
//
//  Die makro-kamera gee 'n skerp foto, maar 'n rou foto: die kaartjie lê skeef
//  in die raam, met tafel rondom. Die dokumentskandeerder het daardie regstelling
//  ingebou gehad ("Adjust"); hier bou ons dit self.
//
//  Vision herken die kaartjie se vier hoeke, jy sleep hulle reg as dit mis is,
//  en Core Image se perspektiefregstelling trek die kaartjie plat en sny die
//  res weg. Vir OCR is dit die stap wat saak maak — Vision lees 'n plat,
//  uitgesnyde kaartjie merkbaar beter as een wat skeef in 'n groter foto lê.
//

import SwiftUI
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Beeldhulpies

extension UIImage {

    /// Teken die beeld oor sodat `imageOrientation` `.up` is.
    ///
    /// Nodig omdat `cgImage` en `CIImage(image:)` die oriëntasie *ignoreer*.
    /// 'n Foto uit die kamera kom as `.right`, en sou andersins sywaarts
    /// verwerk word — Vision sou die teks nie kon lees nie. Die skandeerder
    /// het regop beelde teruggegee, so dit het eers nou begin saak maak.
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Draai 'n kwartslag kloksgewys.
    func rotatedQuarterTurn() -> UIImage {
        let newSize = CGSize(width: size.height, height: size.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: newSize, format: format).image { context in
            context.cgContext.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            context.cgContext.rotate(by: .pi / 2)
            draw(in: CGRect(x: -size.width / 2, y: -size.height / 2,
                            width: size.width, height: size.height))
        }
    }
}

// MARK: - Hoekherkenning en regstelling

enum CardPerspective {

    /// Die vier hoeke, genormaliseer 0–1 met die oorsprong **links-bo**
    /// (dieselfde as die skerm), in die volgorde links-bo, regs-bo,
    /// regs-onder, links-onder.
    static func detectCorners(in image: UIImage) -> [CGPoint]? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNDetectDocumentSegmentationRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        guard let observation = request.results?.first else { return nil }

        // Vision se oorsprong is links-onder, die skerm s'n links-bo.
        func flip(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x, y: 1 - point.y) }

        return [flip(observation.topLeft), flip(observation.topRight),
                flip(observation.bottomRight), flip(observation.bottomLeft)]
    }

    /// Trek die vierhoek plat en sny alles buite hom weg.
    static func correct(_ image: UIImage, corners: [CGPoint]) -> UIImage? {
        guard corners.count == 4, let cgImage = image.cgImage else { return nil }

        let source = CIImage(cgImage: cgImage)
        let extent = source.extent

        // Terug na Core Image se oorsprong links-onder.
        func place(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * extent.width, y: (1 - point.y) * extent.height)
        }

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = source
        filter.topLeft = place(corners[0])
        filter.topRight = place(corners[1])
        filter.bottomRight = place(corners[2])
        filter.bottomLeft = place(corners[3])

        guard let output = filter.outputImage,
              let result = CIContext().createCGImage(output, from: output.extent) else { return nil }

        return UIImage(cgImage: result)
    }
}

// MARK: - Die skerm

struct CardCropView: View {

    var onDone: (UIImage) -> Void
    var onCancel: () -> Void

    @State private var working: UIImage
    @State private var corners: [CGPoint]
    @State private var didDetect = false

    /// Effens binne die rand, sodat die hoeke sigbaar is as die herkenning misluk.
    private static let defaultCorners = [
        CGPoint(x: 0.08, y: 0.08), CGPoint(x: 0.92, y: 0.08),
        CGPoint(x: 0.92, y: 0.92), CGPoint(x: 0.08, y: 0.92)
    ]

    /// Die volle foto, tot in die hoeke. "Hele foto" moet werklik alles beteken,
    /// anders sny dit stilweg 'n rand van die kaartjie af.
    private static let fullCorners = [
        CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
        CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 1)
    ]

    init(image: UIImage,
         onDone: @escaping (UIImage) -> Void,
         onCancel: @escaping () -> Void) {
        self.onDone = onDone
        self.onCancel = onCancel
        _working = State(initialValue: image.normalizedUp())
        _corners = State(initialValue: Self.defaultCorners)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                GeometryReader { geometry in
                    let frame = displayRect(in: geometry.size)

                    ZStack(alignment: .topLeading) {
                        Color.black

                        // Die foto word uitdruklik in `frame` geplaas in plaas
                        // van deur die ZStack se belyning. Die hoeke word teen
                        // dieselfde `frame` bereken, so die twee kan nie meer
                        // uitmekaar loop nie — presies wat vroeër gebeur het.
                        Image(uiImage: working)
                            .resizable()
                            .scaledToFit()
                            .frame(width: frame.width, height: frame.height)
                            .offset(x: frame.minX, y: frame.minY)

                        dimOutsideQuad(in: frame, canvas: geometry.size)
                        quadOutline(in: frame)

                        ForEach(0..<4, id: \.self) { index in
                            handle(index, in: frame)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                }

                controls
            }
            .navigationTitle("Sny kaartjie uit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kanselleer", role: .cancel) { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gebruik") { apply() }
                        .fontWeight(.semibold)
                }
            }
            .task {
                guard !didDetect else { return }
                didDetect = true
                detect()
            }
        }
    }

    // MARK: Onderdele

    private var controls: some View {
        HStack(spacing: 0) {
            controlButton("Draai", icon: "rotate.right") {
                working = working.rotatedQuarterTurn()
                detect()
            }
            controlButton("Herken weer", icon: "viewfinder") {
                detect()
            }
            controlButton("Hele foto", icon: "rectangle.dashed") {
                withAnimation(.easeOut(duration: 0.2)) { corners = Self.fullCorners }
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    /// Ikoon én woord. Net 'n ikoon laat 'n mens raai wat die knoppie doen,
    /// en "Herken weer" teenoor "Hele foto" is nie uit 'n prentjie duidelik nie.
    private func controlButton(_ title: String,
                               icon: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    /// Verdonker alles buite die vierhoek. Sonder dit moet 'n mens raai of die
    /// raampie die hele kaartjie dek; nou is dit met een oogopslag sigbaar.
    private func dimOutsideQuad(in frame: CGRect, canvas: CGSize) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: canvas))
            let points = corners.map { position($0, in: frame) }
            path.move(to: points[0])
            for point in points.dropFirst() { path.addLine(to: point) }
            path.closeSubpath()
        }
        .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }

    private func quadOutline(in frame: CGRect) -> some View {
        Path { path in
            let points = corners.map { position($0, in: frame) }
            path.move(to: points[0])
            for point in points.dropFirst() { path.addLine(to: point) }
            path.closeSubpath()
        }
        .stroke(Color.accentColor, lineWidth: 2)
    }

    private func handle(_ index: Int, in frame: CGRect) -> some View {
        Circle()
            .fill(.white)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 3))
            .frame(width: 26, height: 26)
            // 'n Hoek sit dikwels op die foto se rand, waar die helfte van die
            // kolletjie buite lê. Die groter raakvlak maak hom steeds vatbaar.
            .frame(width: 48, height: 48)
            .contentShape(Circle())
            // Die sleep-gebaar sit ná .position, sodat value.location in die
            // ZStack se ruimte val en nie in die kolletjie s'n nie.
            .position(position(corners[index], in: frame))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        corners[index] = normalize(value.location, in: frame)
                    }
            )
    }

    // MARK: Ruimtes

    /// Waar die beeld werklik lê nadat `scaledToFit` sy werk gedoen het.
    /// Die hoeke is relatief tot die *beeld*, nie tot die skerm nie.
    private func displayRect(in size: CGSize) -> CGRect {
        let imageAspect = working.size.width / max(working.size.height, 1)
        let viewAspect = size.width / max(size.height, 1)

        var width = size.width
        var height = size.height
        if imageAspect > viewAspect {
            height = width / imageAspect
        } else {
            width = height * imageAspect
        }

        return CGRect(x: (size.width - width) / 2,
                      y: (size.height - height) / 2,
                      width: width, height: height)
    }

    private func position(_ corner: CGPoint, in frame: CGRect) -> CGPoint {
        CGPoint(x: frame.minX + corner.x * frame.width,
                y: frame.minY + corner.y * frame.height)
    }

    private func normalize(_ location: CGPoint, in frame: CGRect) -> CGPoint {
        CGPoint(x: min(max((location.x - frame.minX) / frame.width, 0), 1),
                y: min(max((location.y - frame.minY) / frame.height, 0), 1))
    }

    // MARK: Aksies

    private func detect() {
        if let found = CardPerspective.detectCorners(in: working) {
            withAnimation(.easeOut(duration: 0.2)) { corners = found }
        }
    }

    private func apply() {
        onDone(CardPerspective.correct(working, corners: corners) ?? working)
    }
}
