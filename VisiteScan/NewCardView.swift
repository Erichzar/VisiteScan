//
//  NewCardView.swift
//  VisiteScan
//
//  Skandeer → lees → wysig → stoor.
//
//  Stap 5 het hierdie skerm van 'n vorm na 'n vloei omgeskakel. Dit was vier
//  ewe groot bronknoppies, 'n logo wat plek mors, en 'n "Lees kaartjie"-tik
//  wat die gebruiker moes onthou. Nou is dit: een groot knoppie → kamera →
//  uitsny → die velde staan daar.
//
//  Elke bron loop deur dieselfde tregter: bron → cropCandidate → CardCropView
//  → readCard(). Ook die dokumentskandeerder, wat self al uitsny — die ekstra
//  skerm kos een tik en spaar 'n tweede kodepad.
//

import SwiftUI
import SwiftData
import PhotosUI
import VisionKit
import AVFoundation

enum ActiveSheet: Identifiable {
    case macro, scanner, files
    var id: Self { self }
}

/// 'n Vars foto wat nog uitgesny moet word. UIImage is nie Identifiable nie,
/// en `.fullScreenCover(item:)` verlang dit.
struct CropCandidate: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct NewCardView: View {

    @State private var activeSheet: ActiveSheet?
    @State private var showPhotosPicker = false
    @State private var selectedPhoto: PhotosPickerItem?

    /// Waar elke bron sy foto los. Die `onChange` hieronder stuur dit deur na
    /// die uitsny-skerm, sodat daar net een pad is.
    @State private var incomingImage: UIImage?

    @State private var cropCandidate: CropCandidate?
    @State private var selectedImage: UIImage?

    @State private var isProcessing = false

    /// Die gelese waardes, elkeen in 'n veld. Dit is die enigste bron van
    /// waarheid vir die uitslag — die kaartjie se velde word hieruit afgelei
    /// (`values.card`), en die rou teks ook (`values.rawText`).
    @State private var values: [CardValue] = []

    /// Die simulator het geen kamera nie — moenie die knoppie daar aanbied nie.
    private let cameraAvailable = AVCaptureDevice.default(for: .video) != nil
    private let scannerAvailable = VNDocumentCameraViewController.isSupported

    var body: some View {
        NavigationStack {
            Form {
                if let image = selectedImage {
                    cardSection(image)
                } else {
                    startSection
                }

                if isProcessing {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Besig om te lees…")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !values.isEmpty {
                    Section {
                        Button {
                            swapNameAndCompany()
                        } label: {
                            Label("Ruil naam ↔ firma", systemImage: "arrow.up.arrow.down")
                        }
                    }

                    CardFieldsView(values: $values)
                }
            }
            .navigationTitle("Nuwe kaartjie")
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .macro:
                    MacroCameraView(image: $incomingImage)
                        .ignoresSafeArea()
                case .scanner:
                    DocumentScanner(image: $incomingImage)
                case .files:
                    DocumentPickerView(image: $incomingImage)
                }
            }
            .fullScreenCover(item: $cropCandidate) { candidate in
                CardCropView(
                    image: candidate.image,
                    onDone: { cropped in
                        cropCandidate = nil
                        accept(cropped)
                    },
                    onCancel: {
                        cropCandidate = nil
                        // Die foto is geneem; net die uitsny is oorgeslaan.
                        // Lees hom eerder ongesnye as om niks te doen nie.
                        if selectedImage == nil { accept(candidate.image) }
                    }
                )
            }
            .photosPicker(isPresented: $showPhotosPicker,
                          selection: $selectedPhoto,
                          matching: .images)
            .onChange(of: incomingImage) {
                if let incomingImage {
                    cropCandidate = CropCandidate(image: incomingImage)
                    self.incomingImage = nil
                }
            }
            .onChange(of: selectedPhoto) {
                Task {
                    if let data = try? await selectedPhoto?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        incomingImage = image
                    }
                    selectedPhoto = nil
                }
            }
        }
    }

    // MARK: Begin — die leë toestand

    private var startSection: some View {
        Section {
            Button {
                activeSheet = .macro
            } label: {
                VStack(spacing: 10) {
                    Image(systemName: "camera.macro")
                        .font(.system(size: 42))
                    Text("Skandeer kaartjie")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!cameraAvailable)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            otherSourcesMenu
        } footer: {
            Text("Die kamera skakel self na makro oor wanneer jy naby genoeg kom — die etiket bo-aan wys wanneer dit gebeur. Kom só naby dat die kaartjie die raam vul.")
        }
    }

    /// Die ander bronne is die uitsondering, nie die reël nie — hulle hoort in
    /// 'n menu, nie langs die hoofknoppie waar hulle ewe belangrik lyk nie.
    private var otherSourcesMenu: some View {
        Menu {
            if scannerAvailable {
                Button {
                    activeSheet = .scanner
                } label: {
                    Label("Dokumentskandeerder", systemImage: "doc.viewfinder")
                }
            }
            Button {
                showPhotosPicker = true
            } label: {
                Label("Galery", systemImage: "photo")
            }
            Button {
                activeSheet = .files
            } label: {
                Label("Lêers", systemImage: "folder")
            }
        } label: {
            Label("Ander bronne", systemImage: "ellipsis.circle")
        }
    }

    // MARK: Die kaartjie self

    private func cardSection(_ image: UIImage) -> some View {
        Section {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 200)
                .cornerRadius(10)

            Button {
                cropCandidate = CropCandidate(image: image)
            } label: {
                Label("Sny uit / draai", systemImage: "crop.rotate")
            }

            Button {
                activeSheet = .macro
            } label: {
                Label("Skandeer 'n ander kaartjie", systemImage: "camera.macro")
            }
            .disabled(!cameraAvailable)

            otherSourcesMenu

            Button(role: .destructive) {
                clear()
            } label: {
                Label("Verwyder foto", systemImage: "trash")
            }
        } header: {
            Text("Kaartjie")
        }
    }

    // MARK: Vloei

    /// Neem die foto aan en lees hom dadelik. Die OCR loop vanself — die
    /// gebruiker het klaar gesê wat hy wil hê deur die foto te neem.
    private func accept(_ image: UIImage) {
        selectedImage = image
        values = []
        isProcessing = true

        Task {
            let lines = await CardOCRService.recognizeLines(from: image)
            await MainActor.run {
                values = CardParser.values(lines)
                isProcessing = false
            }
        }
    }

    private func clear() {
        selectedImage = nil
        values = []
    }

    /// Die persoon se naam en die firma is albei groot gedruk, so die ontleder
    /// kan hulle omruil. Een tik stel dit reg, in plaas van elke reël afsonderlik
    /// oor te sleep.
    private func swapNameAndCompany() {
        withAnimation(.snappy) {
            for index in values.indices {
                switch values[index].field {
                case .name:    values[index].field = .company
                case .company: values[index].field = .name
                default:       break
                }
            }
        }
    }
}

#Preview {
    NewCardView()
        .modelContainer(for: BusinessCard.self, inMemory: true)
}
