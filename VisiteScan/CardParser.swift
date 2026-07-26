//
//  CardParser.swift
//  VisiteScan
//
//  Stap 4: van rou OCR-reëls na velde. Stap 6: as toewysings, nie stringe nie.
//
//  Die oorspronklike Visitescan se `01-parsing-quality`-fase was hieroor.
//
//  Die kernprobleem: die grootste teks op 'n kaartjie is die naam *of* die
//  firma, en grootte alleen kan nie tussen die twee kies nie. Op Erich se eie
//  kaartjie is "Erich Lutz" groot én die logo se "architects" groot.
//
//  Die skeidsregter is die e-posadres. In erich@aiaza.art pas die deel voor die
//  @ by die persoon en die deel daarna by die firma. Dit staan op byna elke
//  kaartjie, en dit is 'n aansienlik betroubaarder merker as woordelyste.
//
//  Die volgorde hieronder is doelbewus: die velde met 'n harde vorm (e-pos,
//  telefoon, webwerf, poskode) word eerste toegewys. Wat oorbly, is die sagte
//  velde — naam, firma, pos — en teen daardie tyd is daar heelwat minder reëls
//  om tussen te kies.
//
//  Die uitset is `[LineAssignment]`: elke reël met sy veld. Raai die ontleder
//  verkeerd, skuif die mens die reël — sien `CardFieldsView`.
//

import Foundation
import CoreGraphics

enum CardParser {

    /// Reëls wat sterk op 'n firma dui. Nie 'n volledige lys nie en kan ook nie
    /// wees nie — dit is die tweede keuse, ná die e-pos.
    private static let companyMarkers = [
        "(pty)", "pty ltd", "ltd", "(edms)", "bpk", "cc", "inc", "llp",
        "group", "groep", "holdings", "trust", "consulting", "konsult",
        "architects", "argitekte", "attorneys", "prokureurs", "properties",
        "eiendomme", "studio", "agency", "agentskap", "solutions", "services",
        "dienste", "motors", "engineering", "ingenieurs", "filters", "&"
    ]

    /// Beroepsaanduidings. Kort reëls wat nêrens anders pas nie en hierby
    /// aansluit, word die postitel.
    private static let titleMarkers = [
        "pr.", "director", "direkteur", "manager", "bestuurder", "ceo", "cfo",
        "partner", "vennoot", "owner", "eienaar", "consultant", "konsultant",
        "attorney", "prokureur", "architect", "argitek", "agent", "broker",
        "makelaar", "specialist", "spesialis", "engineer", "ingenieur",
        "designer", "ontwerper", "accountant", "rekenmeester", "founder",
        "sales", "verkope", "marketing", "bemarking", "assistant", "assistent"
    ]

    private static let addressMarkers = [
        "po box", "p.o. box", "posbus", "private bag", "privaatsak", "postnet",
        "street", "straat", " str.", " str ", "road", " rd", "weg", "avenue",
        " ave", "laan", "drive", "rylaan", "suite", "unit", "eenheid",
        "floor", "vloer", "building", "gebou"
    ]

    // MARK: Ingang

    /// Elke reël, van bo na onder, met die veld waarheen die ontleder dink hy gaan.
    static func assign(_ lines: [RecognizedLine]) -> [LineAssignment] {
        let ordered = CardOCRService.sortedTopToBottom(lines)
        var fields = [CardField?](repeating: nil, count: ordered.count)

        // 1. Harde vorms eerste — hulle is die betroubaarste
        assignEmail(ordered, &fields)
        assignPhones(ordered, &fields)
        assignWebsite(ordered, &fields)
        assignAddress(ordered, &fields)

        // 2. Dan die sagte keuse, uit wat oorbly
        assignNameAndCompany(ordered, &fields)
        assignJobTitle(ordered, &fields)

        return zip(ordered, fields).map { line, field in
            LineAssignment(line: line, field: field ?? .unused)
        }
    }

    // MARK: E-pos

    private static func assignEmail(_ lines: [RecognizedLine], _ fields: inout [CardField?]) {
        let pattern = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/

        for (index, line) in lines.enumerated() where fields[index] == nil {
            if squashedEmail(line.text).firstMatch(of: pattern) != nil {
                fields[index] = .email
                return
            }
        }
    }

    /// OCR lees gereeld 'n spasie om die @ in.
    private static func squashedEmail(_ text: String) -> String {
        text.replacingOccurrences(of: " @ ", with: "@")
            .replacingOccurrences(of: " @", with: "@")
            .replacingOccurrences(of: "@ ", with: "@")
    }

    /// Die e-pos soos hy op die kaartjie staan — nodig vir die naam/firma-keuse.
    private static func email(in lines: [RecognizedLine], _ fields: [CardField?]) -> String {
        let pattern = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/
        for (index, line) in lines.enumerated() where fields[index] == .email {
            if let match = squashedEmail(line.text).firstMatch(of: pattern) {
                return String(match.output).lowercased()
            }
        }
        return ""
    }

    // MARK: Telefoon

    /// Suid-Afrikaanse nommers: selfoon begin met 06, 07 of 08; 'n landlyn met
    /// 01 tot 05. Internasionaal word +27 na 0 herlei sodat een reël albei dek.
    private static func assignPhones(_ lines: [RecognizedLine], _ fields: inout [CardField?]) {
        var haveMobile = false
        var havePhone = false

        for (index, line) in lines.enumerated() where fields[index] == nil {
            let lower = line.text.lowercased()
            guard let digits = phoneDigits(in: line.text) else { continue }

            if lower.contains("fax") || lower.contains("faks") {
                fields[index] = .notes
                continue
            }

            let isMobile = lower.contains("cell") || lower.contains("sel")
                || lower.contains("mobile") || digits.hasPrefix("06")
                || digits.hasPrefix("07") || digits.hasPrefix("08")

            if isMobile, !haveMobile {
                fields[index] = .mobile
                haveMobile = true
            } else if !isMobile, !havePhone {
                fields[index] = .phone
                havePhone = true
            } else {
                // 'n Derde nommer: laat die mens besluit waar hy hoort.
                fields[index] = .notes
            }
        }
    }

    /// Gee die nommer terug as die reël soos 'n telefoonnommer lyk, anders nil.
    static func phoneDigits(in text: String) -> String? {
        // 'n Reël met te veel letters is eerder 'n adres met 'n straatnommer.
        guard text.filter({ $0.isLetter }).count <= 6 else { return nil }

        var digits = text.filter { $0.isNumber || $0 == "+" }
        if digits.hasPrefix("+27") {
            digits = "0" + digits.dropFirst(3)
        } else if digits.hasPrefix("27"), digits.count == 11 {
            digits = "0" + digits.dropFirst(2)
        }
        digits = digits.filter { $0.isNumber }

        guard digits.count >= 9, digits.count <= 12, digits.hasPrefix("0") else { return nil }
        return digits
    }

    // MARK: Webwerf

    private static func assignWebsite(_ lines: [RecognizedLine], _ fields: inout [CardField?]) {
        let pattern = /(?:https?:\/\/)?(?:www\.)[A-Za-z0-9.-]+\.[A-Za-z]{2,}/

        for (index, line) in lines.enumerated() where fields[index] == nil {
            if line.text.firstMatch(of: pattern) != nil {
                fields[index] = .website
                return
            }
        }
    }

    // MARK: Adres

    private static func assignAddress(_ lines: [RecognizedLine], _ fields: inout [CardField?]) {
        var block: [Int] = []

        for (index, line) in lines.enumerated() where fields[index] == nil {
            let lower = line.text.lowercased()
            let isMarker = addressMarkers.contains { lower.contains($0) }

            // Sodra die blok begin het, hoort die volgende reëls tot by die
            // poskode daarby — 'n adres loop oor verskeie reëls.
            if isMarker || isPostalCode(line.text) || !block.isEmpty {
                block.append(index)
                if isPostalCode(line.text) { break }
            }
        }

        guard !block.isEmpty else { return }

        // Die poskode is die laaste reël as dit vier syfers alleen is.
        if let last = block.last, isPostalCode(lines[last].text) {
            fields[last] = .postalCode
            block.removeLast()
        }

        // Die reël net voor die poskode is die dorp; die res is straat/posbus.
        if let city = block.popLast() {
            fields[city] = .city
        }
        for index in block { fields[index] = .street }
    }

    private static func isPostalCode(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).wholeMatch(of: /\d{4}/) != nil
    }

    // MARK: Naam en firma — die eintlike vraag

    private static func assignNameAndCompany(_ lines: [RecognizedLine], _ fields: inout [CardField?]) {
        let free = lines.indices.filter { fields[$0] == nil }
        guard !free.isEmpty else { return }

        let blocks = mergeIntoBlocks(lines, indices: free)
        guard !blocks.isEmpty else { return }

        // Die grootste blokke eerste. Die naam of die firma is byna altyd een
        // van hulle — dit is presies wat op werklike kaartjies bevestig is.
        let ranked = blocks.sorted { $0.height > $1.height }

        let address = email(in: lines, fields)
        let localPart = address.split(separator: "@").first.map(String.init) ?? ""
        let domain = address.split(separator: "@").last?
            .split(separator: ".").first.map(String.init) ?? ""

        var person: Block?
        var company: Block?

        // Eerste keuse: die e-pos wys aan.
        for block in ranked {
            let squashed = block.text.lowercased().filter { $0.isLetter }
            if person == nil, matchesEmailPart(squashed, localPart) {
                person = block
            } else if company == nil, matchesEmailPart(squashed, domain) {
                company = block
            }
        }

        // Tweede keuse: 'n firma-merker in die teks.
        if company == nil {
            company = ranked.first { $0.indices != person?.indices && looksLikeCompany($0.text) }
        }

        // Wat oorbly: die grootste blok wat nog nie opgeëis is nie word die
        // persoon, want 'n kaartjie wat 'n persoon se naam heeltemal weglaat is
        // seldsaam.
        if person == nil {
            person = ranked.first { $0.indices != company?.indices && looksLikePerson($0.text) }
        }
        if company == nil {
            company = ranked.first { $0.indices != person?.indices }
        }

        for index in person?.indices ?? [] { fields[index] = .name }
        for index in company?.indices ?? [] { fields[index] = .company }
    }

    /// Die e-pos se dele bevat selde spasies of punte wat by die gedrukte naam
    /// pas, so vergelyk op letters alleen en in albei rigtings.
    private static func matchesEmailPart(_ squashedText: String, _ part: String) -> Bool {
        let cleaned = part.filter { $0.isLetter }
        guard cleaned.count >= 3, !squashedText.isEmpty else { return false }
        return squashedText.contains(cleaned) || cleaned.contains(squashedText)
    }

    private static func looksLikeCompany(_ text: String) -> Bool {
        let lower = text.lowercased()
        return companyMarkers.contains { lower.contains($0) }
    }

    private static func looksLikePerson(_ text: String) -> Bool {
        let words = text.split(separator: " ")
        guard (1...4).contains(words.count) else { return false }
        guard !text.contains(where: \.isNumber) else { return false }
        return !looksLikeCompany(text)
    }

    // MARK: Postitel

    private static func assignJobTitle(_ lines: [RecognizedLine], _ fields: inout [CardField?]) {
        for (index, line) in lines.enumerated() where fields[index] == nil {
            let lower = line.text.lowercased()
            if titleMarkers.contains(where: { lower.contains($0) }) {
                fields[index] = .jobTitle
                return
            }
        }
    }

    // MARK: Blokke

    /// 'n Naam staan dikwels oor twee reëls — op Erich se kaartjie is "Erich" en
    /// "Lutz" twee aparte OCR-reëls. Reëls wat aangrensend is én omtrent
    /// ewe groot, hoort by mekaar.
    struct Block {
        let indices: [Int]
        let text: String
        let height: CGFloat
    }

    private static func mergeIntoBlocks(_ lines: [RecognizedLine], indices: [Int]) -> [Block] {
        guard let first = indices.first else { return [] }

        var blocks: [Block] = []
        var currentIndices = [first]
        var currentText = lines[first].text
        var currentHeight = lines[first].height
        var previous = lines[first]

        for index in indices.dropFirst() {
            let line = lines[index]
            let similarHeight = abs(line.height - previous.height) < previous.height * 0.3
            let gap = previous.boundingBox.minY - line.boundingBox.maxY
            let adjacent = gap < previous.height * 0.8

            if similarHeight && adjacent {
                currentIndices.append(index)
                currentText += " " + line.text
                currentHeight = Swift.max(currentHeight, line.height)
            } else {
                blocks.append(Block(indices: currentIndices, text: currentText, height: currentHeight))
                currentIndices = [index]
                currentText = line.text
                currentHeight = line.height
            }
            previous = line
        }
        blocks.append(Block(indices: currentIndices, text: currentText, height: currentHeight))

        return blocks
    }
}
