//
//  CardParser.swift
//  VisiteScan
//
//  Stap 4: van rou OCR-reëls na velde.
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
//  telefoon, webwerf, poskode) word eerste uitgehaal en uit die pot verwyder.
//  Wat oorbly, is die sagte velde — naam, firma, pos — en teen daardie tyd is
//  daar heelwat minder reëls om tussen te kies.
//

import Foundation
import CoreGraphics

// MARK: - Die uitslag

struct ParsedCard {
    var firstName = ""
    var lastName = ""
    var jobTitle = ""
    var company = ""
    var email = ""
    var phone = ""
    var mobile = ""
    var website = ""
    var street = ""
    var city = ""
    var postalCode = ""
    var notes = ""

    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

// MARK: - Die ontleder

enum CardParser {

    /// Reëls wat sterk op 'n firma dui. Nie 'n volledige lys nie en kan ook nie
    /// wees nie — dit is die tweede keuse, ná die e-pos.
    private static let companyMarkers = [
        "(pty)", "pty ltd", "ltd", "(edms)", "bpk", "cc", "inc", "llp",
        "group", "groep", "holdings", "trust", "consulting", "konsult",
        "architects", "argitekte", "attorneys", "prokureurs", "properties",
        "eiendomme", "studio", "agency", "agentskap", "solutions", "services",
        "dienste", "motors", "engineering", "ingenieurs", "&"
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
        "street", "straat", "road", "weg", "avenue", "laan", "drive", "rylaan",
        "suite", "unit", "eenheid", "floor", "vloer", "building", "gebou"
    ]

    // MARK: Ingang

    static func parse(_ lines: [RecognizedLine]) -> ParsedCard {
        let ordered = CardOCRService.sortedTopToBottom(lines)
        var card = ParsedCard()

        /// Reëls wat reeds 'n veld geword het. Wat oorbly, voed die naamkeuse.
        var claimed = Set<Int>()

        // 1. Harde vorms, van bo af
        extractEmail(ordered, into: &card, claimed: &claimed)
        extractPhones(ordered, into: &card, claimed: &claimed)
        extractWebsite(ordered, into: &card, claimed: &claimed)
        extractAddress(ordered, into: &card, claimed: &claimed)

        // 2. Sagte velde uit wat oorbly
        let remaining = ordered.enumerated()
            .filter { !claimed.contains($0.offset) }
            .map { $0.element }

        assignNameAndCompany(remaining, into: &card)
        assignJobTitle(remaining, into: &card)

        return card
    }

    // MARK: E-pos

    private static func extractEmail(_ lines: [RecognizedLine],
                                     into card: inout ParsedCard,
                                     claimed: inout Set<Int>) {
        let pattern = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/

        for (index, line) in lines.enumerated() {
            // OCR lees gereeld 'n spasie om die @ in; haal dit uit voor die toets.
            let candidate = line.text.replacingOccurrences(of: " @ ", with: "@")
                .replacingOccurrences(of: " @", with: "@")
                .replacingOccurrences(of: "@ ", with: "@")

            if let match = candidate.firstMatch(of: pattern) {
                card.email = String(match.output).lowercased()
                claimed.insert(index)
                return
            }
        }
    }

    // MARK: Telefoon

    /// Suid-Afrikaanse nommers: selfoon begin met 06, 07 of 08; 'n landlyn met
    /// 01 tot 05. Internasionaal word +27 na 0 herlei sodat een reël albei dek.
    private static func extractPhones(_ lines: [RecognizedLine],
                                      into card: inout ParsedCard,
                                      claimed: inout Set<Int>) {
        for (index, line) in lines.enumerated() {
            let lower = line.text.lowercased()
            guard let digits = phoneDigits(in: line.text) else { continue }

            claimed.insert(index)

            // 'n Etiket op die kaartjie oorheers die nommer se eie vorm.
            if lower.contains("fax") || lower.contains("faks") {
                card.notes = appending("Faks: \(digits)", to: card.notes)
                continue
            }

            let isMobile = lower.contains("cell") || lower.contains("sel")
                || lower.contains("mobile") || digits.hasPrefix("06")
                || digits.hasPrefix("07") || digits.hasPrefix("08")

            if isMobile {
                if card.mobile.isEmpty { card.mobile = digits }
            } else {
                if card.phone.isEmpty { card.phone = digits }
            }
        }
    }

    /// Gee die nommer terug as die reël soos 'n telefoonnommer lyk, anders nil.
    private static func phoneDigits(in text: String) -> String? {
        var digits = text.filter { $0.isNumber || $0 == "+" }

        // 'n Reël met te veel letters is eerder 'n adres met 'n straatnommer.
        let letters = text.filter { $0.isLetter }.count
        guard letters <= 6 else { return nil }

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

    private static func extractWebsite(_ lines: [RecognizedLine],
                                       into card: inout ParsedCard,
                                       claimed: inout Set<Int>) {
        let pattern = /(?:https?:\/\/)?(?:www\.)[A-Za-z0-9.-]+\.[A-Za-z]{2,}/

        for (index, line) in lines.enumerated() where !claimed.contains(index) {
            if let match = line.text.firstMatch(of: pattern) {
                card.website = String(match.output).lowercased()
                claimed.insert(index)
                return
            }
        }
    }

    // MARK: Adres

    private static func extractAddress(_ lines: [RecognizedLine],
                                       into card: inout ParsedCard,
                                       claimed: inout Set<Int>) {
        var block: [(index: Int, text: String)] = []

        for (index, line) in lines.enumerated() where !claimed.contains(index) {
            let lower = line.text.lowercased()
            let isMarker = addressMarkers.contains { lower.contains($0) }
            let isPostal = line.text.trimmingCharacters(in: .whitespaces).wholeMatch(of: /\d{4}/) != nil

            // Sodra die blok begin het, hoort die volgende reëls tot by die
            // poskode daarby — 'n adres loop oor verskeie reëls.
            if isMarker || isPostal || !block.isEmpty {
                block.append((index, line.text))
                if isPostal { break }
            }
        }

        guard !block.isEmpty else { return }

        // Die poskode is die laaste reël as dit vier syfers alleen is.
        if let last = block.last,
           last.text.trimmingCharacters(in: .whitespaces).wholeMatch(of: /\d{4}/) != nil {
            card.postalCode = last.text.trimmingCharacters(in: .whitespaces)
            block.removeLast()
        }

        // Die reël net voor die poskode is die dorp; die res is straat/posbus.
        if let city = block.popLast() {
            card.city = city.text
        }
        card.street = block.map(\.text).joined(separator: ", ")

        // Merk alles wat werklik 'n adresveld geword het.
        for entry in block { claimed.insert(entry.index) }
        if !card.city.isEmpty || !card.postalCode.isEmpty {
            for (index, line) in lines.enumerated()
            where line.text == card.city || line.text.trimmingCharacters(in: .whitespaces) == card.postalCode {
                claimed.insert(index)
            }
        }
    }

    // MARK: Naam en firma — die eintlike vraag

    private static func assignNameAndCompany(_ lines: [RecognizedLine],
                                             into card: inout ParsedCard) {
        let blocks = mergeIntoBlocks(lines)
        guard !blocks.isEmpty else { return }

        // Die grootste blokke eerste. Die naam of die firma is byna altyd een
        // van hulle — dit is presies wat op werklike kaartjies bevestig is.
        let ranked = blocks.sorted { $0.height > $1.height }

        let localPart = card.email.split(separator: "@").first.map(String.init) ?? ""
        let domain = card.email.split(separator: "@").last?
            .split(separator: ".").first.map(String.init) ?? ""

        var personBlock: Block?
        var companyBlock: Block?

        // Eerste keuse: die e-pos wys aan.
        for block in ranked {
            let squashed = block.text.lowercased().filter { $0.isLetter }
            if personBlock == nil, !localPart.isEmpty,
               matchesEmailPart(squashed, localPart) {
                personBlock = block
            } else if companyBlock == nil, !domain.isEmpty,
                      matchesEmailPart(squashed, domain) {
                companyBlock = block
            }
        }

        // Tweede keuse: 'n firma-merker in die teks.
        if companyBlock == nil {
            companyBlock = ranked.first { block in
                block !== personBlock && looksLikeCompany(block.text)
            }
        }

        // Wat oorbly: die grootste blok wat nog nie opgeëis is nie word die
        // persoon, want 'n kaartjie wat 'n persoon se naam heeltemal weglaat is
        // seldsaam.
        if personBlock == nil {
            personBlock = ranked.first { block in
                block !== companyBlock && looksLikePerson(block.text)
            }
        }
        if companyBlock == nil {
            companyBlock = ranked.first { $0 !== personBlock }
        }

        if let person = personBlock { splitName(person.text, into: &card) }
        if let company = companyBlock { card.company = company.text }
    }

    /// Die e-pos se dele bevat selde spasies of punte wat by die gedrukte naam
    /// pas, so vergelyk op letters alleen en in albei rigtings.
    private static func matchesEmailPart(_ squashedText: String, _ part: String) -> Bool {
        let cleaned = part.filter { $0.isLetter }
        guard cleaned.count >= 3 else { return false }
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

    private static func splitName(_ text: String, into card: inout ParsedCard) {
        let words = text.split(separator: " ").map(String.init)
        guard let last = words.last else { return }
        card.firstName = words.dropLast().joined(separator: " ")
        card.lastName = last
        if card.firstName.isEmpty {
            card.firstName = last
            card.lastName = ""
        }
    }

    // MARK: Postitel

    private static func assignJobTitle(_ lines: [RecognizedLine],
                                       into card: inout ParsedCard) {
        for line in lines {
            let lower = line.text.lowercased()
            guard titleMarkers.contains(where: { lower.contains($0) }) else { continue }
            guard line.text != card.company, !card.fullName.contains(line.text) else { continue }
            card.jobTitle = line.text
            return
        }
    }

    // MARK: Blokke

    /// 'n Naam staan dikwels oor twee reëls — op Erich se kaartjie is "Erich" en
    /// "Lutz" twee aparte OCR-reëls. Reëls wat aangrensend is én omtrent
    /// ewe groot, hoort by mekaar.
    final class Block {
        let text: String
        let height: CGFloat
        init(text: String, height: CGFloat) {
            self.text = text
            self.height = height
        }
    }

    private static func mergeIntoBlocks(_ lines: [RecognizedLine]) -> [Block] {
        guard !lines.isEmpty else { return [] }

        var blocks: [Block] = []
        var currentText = lines[0].text
        var currentHeight = lines[0].height
        var previous = lines[0]

        for line in lines.dropFirst() {
            let similarHeight = abs(line.height - previous.height) < previous.height * 0.3
            let gap = previous.boundingBox.minY - line.boundingBox.maxY
            let adjacent = gap < previous.height * 0.8

            if similarHeight && adjacent {
                currentText += " " + line.text
                currentHeight = max(currentHeight, line.height)
            } else {
                blocks.append(Block(text: currentText, height: currentHeight))
                currentText = line.text
                currentHeight = line.height
            }
            previous = line
        }
        blocks.append(Block(text: currentText, height: currentHeight))

        return blocks
    }

    // MARK: Hulpies

    private static func appending(_ value: String, to existing: String) -> String {
        existing.isEmpty ? value : existing + "\n" + value
    }
}
