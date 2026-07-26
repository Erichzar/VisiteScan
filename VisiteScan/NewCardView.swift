//
//  NewCardView.swift
//  VisiteScan
//
//  Skandeer → lees → wysig → stoor.
//  Stap 2: die beeld word ingelees. Die OCR volg by Stap 3.
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
    @State private var selectedImage: UIImage?
    @State private var macroCapture: UIImage?
    @State private var cropCandidate: CropCandidate?

    @State private var isProcessing = false
    @State private var recognizedLines: [RecognizedLine] = []
    @State private var parsed = ParsedCard()
    @State private var showRawText = false

    /// Die simulator het geen kamera nie — moenie die knoppie daar aanbied nie.
    private let cameraAvailable = AVCaptureDevice.default(for: .video) != nil
    private let scannerAvailable = VNDocumentCameraViewController.isSupported

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Logo-kopskrif
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            if let logo = UIImage(named: "AppLogo") {
                                Image(uiImage: logo)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 72, height: 72)
                                    .cornerRadius(16)
                            } else {
                                Image(systemName: "person.crop.rectangle")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.blue)
                            }
                            Text("VisiteScan")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // MARK: Kaartjie-foto
                Section {

                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(10)
                    }

                    // VStack + onTapGesture omseil Form se tap-onderskepping
                    HStack(spacing: 0) {

                        sourceButton(
                            icon: "camera.macro",
                            label: "Makro",
                            enabled: cameraAvailable
                        ) { activeSheet = .macro }

                        Divider()

                        sourceButton(
                            icon: "doc.viewfinder.fill",
                            label: "Skandeer",
                            tint: .orange,
                            enabled: scannerAvailable
                        ) { activeSheet = .scanner }

                        Divider()

                        sourceButton(
                            icon: "photo.fill",
                            label: "Galery"
                        ) { showPhotosPicker = true }

                        Divider()

                        sourceButton(
                            icon: "folder.fill",
                            label: "Lêers"
                        ) { activeSheet = .files }
                    }
                    .listRowInsets(EdgeInsets())

                    if let image = selectedImage {
                        Button {
                            cropCandidate = CropCandidate(image: image)
                        } label: {
                            Label("Sny uit / draai", systemImage: "crop.rotate")
                        }

                        Button {
                            readCard()
                        } label: {
                            if isProcessing {
                                HStack {
                                    ProgressView()
                                    Text("Besig om te lees…")
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                Label("Lees kaartjie", systemImage: "text.viewfinder")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(isProcessing)

                        Button(role: .destructive) {
                            selectedImage = nil
                            recognizedLines = []
                        } label: {
                            Label("Verwyder foto", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("Kaartjie")
                } footer: {
                    if selectedImage == nil {
                        Text("Makro fokus tot naby aan die kaartjie; Skandeer sny dit uit en regideer die perspektief. Toets albei op dieselfde kaartjie en kyk watter een beter lees.")
                    }
                }

                // MARK: Velde
                // Die ontleder doen sy beste raai; hier stel jy dit reg.
                if !recognizedLines.isEmpty {

                    Section {
                        TextField("Naam", text: $parsed.firstName)
                            .textContentType(.givenName)
                        TextField("Van", text: $parsed.lastName)
                            .textContentType(.familyName)
                        TextField("Pos", text: $parsed.jobTitle)
                        TextField("Firma", text: $parsed.company)
                            .textContentType(.organizationName)

                        // Die ontleder se waarskynlikste fout: die grootste teks
                        // is die naam *of* die firma, en soms kies hy verkeerd.
                        Button {
                            swapNameAndCompany()
                        } label: {
                            Label("Ruil naam ↔ firma", systemImage: "arrow.up.arrow.down")
                        }
                    } header: {
                        Text("Wie")
                    }

                    Section {
                        TextField("Selfoon", text: $parsed.mobile)
                            .keyboardType(.phonePad)
                        TextField("Telefoon", text: $parsed.phone)
                            .keyboardType(.phonePad)
                        TextField("E-pos", text: $parsed.email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        TextField("Webwerf", text: $parsed.website)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                    } header: {
                        Text("Kontak")
                    }

                    Section {
                        TextField("Straat / Posbus", text: $parsed.street, axis: .vertical)
                        TextField("Dorp", text: $parsed.city)
                        TextField("Poskode", text: $parsed.postalCode)
                            .keyboardType(.numberPad)
                    } header: {
                        Text("Adres")
                    }

                    if !parsed.notes.isEmpty {
                        Section("Aantekeninge") {
                            TextField("Aantekeninge", text: $parsed.notes, axis: .vertical)
                        }
                    }

                    // MARK: Rou OCR-teks
                    // Bly beskikbaar: as 'n veld leeg is, wys dit of die OCR die
                    // reël gemis het of die ontleder hom net verkeerd geplaas het.
                    Section {
                        DisclosureGroup("Rou teks — \(recognizedLines.count) reëls",
                                        isExpanded: $showRawText) {
                            ForEach(CardOCRService.sortedTopToBottom(recognizedLines)) { line in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(line.text)
                                    Spacer()
                                    Text(String(format: "%.0f%%", line.height * 100))
                                        .font(.caption2)
                                        .monospacedDigit()
                                        .foregroundStyle(.tertiary)
                                }
                                .font(.callout)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nuwe kaartjie")
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .macro:
                    MacroCameraView(image: $macroCapture)
                        .ignoresSafeArea()
                case .scanner:
                    DocumentScanner(image: $selectedImage)
                case .files:
                    DocumentPickerView(image: $selectedImage)
                }
            }
            // 'n Vars makro-foto gaan reguit na die uitsny-skerm — dieselfde
            // vloei as die skandeerder, wat ook eers sy hersienskerm wys.
            .fullScreenCover(item: $cropCandidate) { candidate in
                CardCropView(
                    image: candidate.image,
                    onDone: { cropped in
                        selectedImage = cropped
                        recognizedLines = []
                        cropCandidate = nil
                    },
                    onCancel: {
                        if selectedImage == nil { selectedImage = candidate.image }
                        cropCandidate = nil
                    }
                )
            }
            .onChange(of: macroCapture) {
                if let macroCapture {
                    cropCandidate = CropCandidate(image: macroCapture)
                    self.macroCapture = nil
                }
            }
            .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhoto, matching: .images)
            .onChange(of: selectedPhoto) {
                Task {
                    if let data = try? await selectedPhoto?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                    selectedPhoto = nil
                }
            }
        }
    }

    // MARK: Lees

    private func readCard() {
        guard let image = selectedImage else { return }
        isProcessing = true
        Task {
            let lines = await CardOCRService.recognizeLines(from: image)
            await MainActor.run {
                recognizedLines = lines
                parsed = CardParser.parse(lines)
                isProcessing = false
            }
        }
    }

    /// Die persoon se naam en die firma is albei groot gedruk, so die ontleder
    /// kan hulle omruil. Dit is goedkoper om dit met een knoppie reg te stel as
    /// om drie velde oor te tik.
    private func swapNameAndCompany() {
        let person = parsed.fullName
        parsed.firstName = parsed.company
        parsed.lastName = ""
        parsed.company = person
    }

    // MARK: Bronknoppie

    @ViewBuilder
    private func sourceButton(
        icon: String,
        label: String,
        tint: Color = .accentColor,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
            Text(label)
                .font(.caption)
        }
        .foregroundStyle(enabled ? tint : Color.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { if enabled { action() } }
    }
}

#Preview {
    NewCardView()
        .modelContainer(for: BusinessCard.self, inMemory: true)
}
