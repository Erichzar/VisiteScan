//
//  CardField.swift
//  VisiteScan
//
//  Stap 6 se kernmodel.
//
//  Tot en met Stap 5 het die ontleder stringe teruggegee. Dit werk om te wys,
//  maar nie om te skuif nie: sodra 'n mens 'n reël na 'n ander veld sleep, moet
//  jy weet *watter* reël uit die ou veld se string kom en waar hy in die nuwe
//  een inpas. Dit word string-gemors.
//
//  Daarom draai die model om. Elke herkende reël kry 'n veld toegewys, en die
//  veldwaardes word uit die toewysings *afgelei*. Sleep = een reël se veld
//  verander; alles anders herbereken homself.
//

import Foundation

// MARK: - Die velde

/// Die velde soos Contacts hulle wys, plus `unused` vir wat oorbly.
enum CardField: String, CaseIterable, Identifiable, Codable {
    case name, jobTitle, company
    case mobile, phone, email, website
    case street, city, postalCode
    case notes
    case unused

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
        case .street:     "Straat / Posbus"
        case .city:       "Dorp"
        case .postalCode: "Poskode"
        case .notes:      "Aantekeninge"
        case .unused:     "Nie gebruik nie"
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
        case .city:       "building.columns"
        case .postalCode: "number"
        case .notes:      "note.text"
        case .unused:     "tray"
        }
    }

    /// Meerreëlige velde word met 'n komma saamgevoeg; die res met 'n spasie.
    /// 'n Naam oor twee reëls is "Erich Lutz", 'n adres is "56 Tarentaal Str., Eenheid 3".
    var joinSeparator: String {
        switch self {
        case .street, .notes: ", "
        default: " "
        }
    }

    /// Die groepe waarin die skerm die velde wys — Contacts se volgorde.
    static let groups: [(title: String, fields: [CardField])] = [
        ("Wie",      [.name, .jobTitle, .company]),
        ("Kontak",   [.mobile, .phone, .email, .website]),
        ("Adres",    [.street, .city, .postalCode]),
        ("Ekstra",   [.notes])
    ]
}

// MARK: - Een reël, een veld

/// 'n Herkende reël saam met die veld waarheen dit gaan. Die teks is apart van
/// `line.text` sodat 'n mens 'n OCR-fout kan regtik sonder om die herkenning
/// se oorspronklike te verloor.
struct LineAssignment: Identifiable {
    let line: RecognizedLine
    var field: CardField
    var text: String

    var id: UUID { line.id }

    init(line: RecognizedLine, field: CardField) {
        self.line = line
        self.field = field
        self.text = line.text
    }
}

// MARK: - Afgeleide waardes

extension Array where Element == LineAssignment {

    /// Die veld se waarde: al sy reëls, in leesvolgorde, saamgevoeg.
    func value(for field: CardField) -> String {
        self.filter { $0.field == field }
            .map(\.text)
            .filter { !$0.isEmpty }
            .joined(separator: field.joinSeparator)
    }

    func lines(for field: CardField) -> [LineAssignment] {
        self.filter { $0.field == field }
    }

    /// Die volledige kaartjie, afgelei uit die toewysings.
    var card: ParsedCard {
        var card = ParsedCard()
        card.name = value(for: .name)
        card.jobTitle = value(for: .jobTitle)
        card.company = value(for: .company)
        card.mobile = value(for: .mobile)
        card.phone = value(for: .phone)
        card.email = value(for: .email)
        card.website = value(for: .website)
        card.street = value(for: .street)
        card.city = value(for: .city)
        card.postalCode = value(for: .postalCode)
        card.notes = value(for: .notes)
        return card
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
