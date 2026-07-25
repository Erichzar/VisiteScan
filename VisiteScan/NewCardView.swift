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

enum ActiveSheet: Identifiable {
    case camera, scanner, files
    var id: Self { self }
}

struct NewCardView: View {

    @State private var activeSheet: ActiveSheet?
    @State private var showPhotosPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    /// Die kamera bestaan nie in die simulator nie — moenie dit daar aanbied nie,
    /// want UIImagePickerController crash met sourceType .camera.
    private let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
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
                            icon: "camera.fill",
                            label: "Kamera",
                            enabled: cameraAvailable
                        ) { activeSheet = .camera }

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

                    if selectedImage != nil {
                        Button(role: .destructive) {
                            selectedImage = nil
                        } label: {
                            Label("Verwyder foto", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("Kaartjie")
                } footer: {
                    if selectedImage == nil {
                        Text("Skandeer werk die beste — dit sny die kaartjie uit en regideer die perspektief.")
                    }
                }
            }
            .navigationTitle("Nuwe kaartjie")
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .camera:
                    CameraView(image: $selectedImage)
                        .ignoresSafeArea()
                case .scanner:
                    DocumentScanner(image: $selectedImage)
                case .files:
                    DocumentPickerView(image: $selectedImage)
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
