//
//  CardOCRService.swift
//  VisiteScan
//
//  Lees die teks van 'n visitekaartjie af.
//
//  Anders as FuelScan se OCRService gee hierdie een nie net 'n string terug
//  nie, maar elke reël saam met sy posisie en hoogte op die kaartjie. Op 'n
//  visitekaartjie is die grootste teks byna altyd die naam — daardie hoogte
//  is die belangrikste leidraad wat ons by Stap 4 het.
//

import Vision
import UIKit

// MARK: - Een herkende reël

struct RecognizedLine: Identifiable {
    let id = UUID()
    let text: String

    /// Genormaliseerde blokkie (0–1), oorsprong links-onder soos Vision dit gee.
    let boundingBox: CGRect

    /// Tekshoogte as breukdeel van die kaartjie se hoogte.
    /// Groter = prominenter gedruk.
    var height: CGFloat { boundingBox.height }

    /// Hoe hoog op die kaartjie die reël sit (1 = heel bo).
    var verticalPosition: CGFloat { boundingBox.midY }
}

// MARK: - Diens

enum CardOCRService {

    /// Lees al die reëls van die kaartjie af, met posisie en hoogte.
    static func recognizeLines(from image: UIImage) async -> [RecognizedLine] {
        guard let cgImage = image.cgImage else { return [] }

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [
            Locale.Language(identifier: "af"),
            Locale.Language(identifier: "en")
        ]

        guard let observations = try? await request.perform(on: cgImage) else { return [] }

        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return RecognizedLine(text: text, boundingBox: observation.boundingBox.cgRect)
        }
    }

    /// Die rou teks, van bo na onder gelees.
    static func recognizeText(from image: UIImage) async -> String {
        let lines = await recognizeLines(from: image)
        return sortedTopToBottom(lines)
            .map(\.text)
            .joined(separator: "\n")
    }

    /// Vision gee die reëls in sy eie herkenningsvolgorde terug, nie noodwendig
    /// van bo na onder nie. Vir 'n kaartjie wil ons die visuele volgorde hê.
    static func sortedTopToBottom(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        lines.sorted { $0.verticalPosition > $1.verticalPosition }
    }
}
