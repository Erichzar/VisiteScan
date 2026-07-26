//
//  CardField.swift
//  VisiteScan
//
//  Stap 6 se kernmodel.
//
//  Die skerm is twee kolomme: 'n **vaste lys veldname links** wat nooit beweeg
//  nie, en die gelese **waardes regs** wat geskuif word. Een waarde per veld.
//
//  Daaruit volg die belangrikste reël: skuif jy 'n waarde in 'n veld wat klaar
//  besit is, word die vorige inwoner **verdring na Temp**. Dit gebeur in
//  dieselfde gebaar — 'n mens sleep een keer, en die verdringing volg vanself.
//  Temp is 'n parkeerplek, nie 'n asblik nie: die waarde wag daar om later
//  geplaas te word.
//
//  'n Waarde is nie noodwendig een OCR-reël nie. "Erich" bo "Lutz" is twee
//  reëls maar één naam, so die ontleder voeg aangrensende reëls van dieselfde
//  veld saam voor hulle hier beland.
//

import Foundation

// MARK: - Die velde

/// Die vaste kolom links, in Contacts se volgorde. `temp` staan heel onder.
enum CardField: String, CaseIterable, Identifiable, Codable {
    case name, jobTitle, company
    case mobile, phone, email, website
    case street, suburb, city, postalCode
    case notes
    case temp, combo

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name:       "Naam"
        case .jobTitle:   "Pos"
        case .company:    "Firma"
        case .mobile:     "Selfoon"
        case .phone:      "Telefoon"
        case .email:      "E-pos"
        case .website:    "Webwerf"
        case .street:     "Straat"
        case .suburb:     "Voorstad"
        case .city:       "Dorp"
        case .postalCode: "Poskode"
        case .notes:      "Nota"
        case .temp:       "Temp"
        case .combo:      "Kombo"
        }
    }

    var icon: String {
        switch self {
        case .name:       "person"
        case .jobTitle:   "briefcase"
        case .company:    "building.2"
        case .mobile:     "iphone"
        case .phone:      "phone"
        case .email:      "envelope"
        case .website:    "globe"
        case .street:     "mappin.and.ellipse"
        case .suburb:     "house"
        case .city:       "building.columns"
        case .postalCode: "number"
        case .notes:      "note.text"
        case .temp:       "tray"
        case .combo:      "arrow.triangle.merge"
        }
    }

    /// Die vaste velde links. Temp en Kombo is werkbanke, nie velde nie.
    static var fixed: [CardField] { allCases.filter { $0 != .temp && $0 != .combo } }

    /// Werkbanke hou meer as een waarde en verdring niks.
    var isWorkbench: Bool { self == .temp || self == .combo }

    /// Die groepe waarin die skerm die vaste velde wys.
    static let groups: [(title: String, fields: [CardField])] = [
        ("Wie",    [.name, .jobTitle, .company]),
        ("Kontak", [.mobile, .phone, .email, .website]),
        ("Adres",  [.street, .suburb, .city, .postalCode]),
        ("Ekstra", [.notes])
    ]

    /// Wanneer die ontleder verskeie reëls aan dieselfde veld gee, hoe hulle
    /// saamgevoeg word. Temp en Nota bly aparte rye — daar tel elke reël apart.
    var joinSeparator: String { " " }

    var coalesces: Bool {
        switch self {
        case .temp, .combo, .notes: false
        default:                    true
        }
    }
}

// MARK: - Een waarde

/// Een waarde in een veld. Die teks is wysigbaar sodat 'n OCR-fout reggetik kan
/// word; `height` is die grootste bron-reël se tekshoogte, wat die ontleder se
/// naam-teenoor-firma-keuse dryf.
struct CardValue: Identifiable {
    let id = UUID()
    var text: String
    var field: CardField
    var height: CGFloat = 0
}

// MARK: - Skuif, met verdringing

extension Array where Element == CardValue {

    /// Die waarde in 'n veld, of nil. Elke vaste veld hou hoogstens een.
    func value(in field: CardField) -> CardValue? {
        first { $0.field == field }
    }

    func values(in field: CardField) -> [CardValue] {
        filter { $0.field == field }
    }

    func text(for field: CardField) -> String {
        values(in: field).map(\.text).joined(separator: field.joinSeparator)
    }

    /// Skuif 'n waarde na 'n veld.
    ///
    /// Drie gedrae, na gelang van die teiken:
    /// - **Kombo** smelt saam: die inkomende teks word agteraan die een wat
    ///   daar staan gevoeg, en die twee word een waarde. So kry 'n mens
    ///   "56 Tarentaal Str." en "Eenheid 3" in één straatveld.
    /// - **Temp** neem net op; dit verdring niks en hou soveel waardes as nodig.
    /// - **'n Gewone veld** hou hoogstens een waarde, so wat daar was, word
    ///   na Temp verdring. Dieselfde gebaar, twee bewegings.
    mutating func move(_ id: UUID, to field: CardField) {
        guard let source = firstIndex(where: { $0.id == id }),
              self[source].field != field else { return }

        if field == .combo,
           let existing = firstIndex(where: { $0.field == .combo && $0.id != id }) {
            self[existing].text += " " + self[source].text
            self[existing].height = Swift.max(self[existing].height, self[source].height)
            remove(at: source)
            return
        }

        if !field.isWorkbench,
           let occupant = firstIndex(where: { $0.field == field && $0.id != id }) {
            self[occupant].field = .temp
        }
        self[source].field = field
    }

    /// Die kaartjie se velde as stringe, afgelei uit die waardes.
    var card: ParsedCard {
        var card = ParsedCard()
        card.name = text(for: .name)
        card.jobTitle = text(for: .jobTitle)
        card.company = text(for: .company)
        card.mobile = text(for: .mobile)
        card.phone = text(for: .phone)
        card.email = text(for: .email)
        card.website = text(for: .website)
        card.street = text(for: .street)
        card.suburb = text(for: .suburb)
        card.city = text(for: .city)
        card.postalCode = text(for: .postalCode)
        card.notes = values(in: .notes).map(\.text).joined(separator: "\n")
        return card
    }

    /// Alles wat gelees is, in leesvolgorde — vir `BusinessCard.rawText`.
    var rawText: String {
        map(\.text).joined(separator: "\n")
    }
}

// MARK: - Die kaartjie se velde as stringe

struct ParsedCard {
    var name = ""
    var jobTitle = ""
    var company = ""
    var mobile = ""
    var phone = ""
    var email = ""
    var website = ""
    var street = ""
    var suburb = ""
    var city = ""
    var postalCode = ""
    var notes = ""

    /// Contacts hou voor- en van apart. Die kaartjie druk hulle saam, so die
    /// splitsing gebeur hier — die laaste woord is die van.
    var firstName: String {
        let words = name.split(separator: " ")
        return words.count > 1 ? words.dropLast().joined(separator: " ") : name
    }

    var lastName: String {
        let words = name.split(separator: " ")
        return words.count > 1 ? String(words[words.count - 1]) : ""
    }
}
