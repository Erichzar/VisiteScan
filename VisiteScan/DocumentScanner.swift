//
//  DocumentScanner.swift
//  VisiteScan
//
//  VisionKit se dokumentskandeerder. Sny die kaartjie outomaties uit,
//  regideer die perspektief en skoon die beeld op — presies wat OCR nodig het.
//
//  Reguit uit FuelScan oorgeneem.
//

import SwiftUI
import VisionKit

struct DocumentScanner: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        init(_ parent: DocumentScanner) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            DispatchQueue.main.async {
                if scan.pageCount > 0 {
                    self.parent.image = scan.imageOfPage(at: 0)
                }
                self.parent.dismiss()
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            DispatchQueue.main.async { self.parent.dismiss() }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            DispatchQueue.main.async { self.parent.dismiss() }
        }
    }
}
