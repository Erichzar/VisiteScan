//
//  ImagePickers.swift
//  VisiteScan
//
//  Die Lêers-blaaier, wat SwiftUI nie self het nie.
//  (Galery gebruik SwiftUI se eie .photosPicker.)
//
//  Uit FuelScan oorgeneem.
//
//  Hier was ook 'n `CameraView` — 'n UIImagePickerController op die gewone
//  kamera. Stap 2½ het hom vervang: die stelselkamera gebruik die groothoeklens
//  en kan nie naby genoeg fokus nie, so `MacroCameraView` het sy plek geneem en
//  hierdie een het sedertdien net stil saamgery. Uit, want dooie kode laat 'n
//  mens later wonder watter van die twee die regte pad is.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Lêers

struct DocumentPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        init(_ parent: DocumentPickerView) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first,
                  url.startAccessingSecurityScopedResource(),
                  let data = try? Data(contentsOf: url) else { return }
            url.stopAccessingSecurityScopedResource()
            DispatchQueue.main.async {
                self.parent.image = UIImage(data: data)
                self.parent.dismiss()
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}
