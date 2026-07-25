import Foundation
import SwiftData

/// 'n Geskandeerde visitekaartjie.
///
/// CloudKit-vormig van die begin af (Stap 9):
///   1. Elke veld het 'n verstekwaarde
///   2. Geen @Attribute(.unique) nie — duplikate word met eie logika opgespoor (Stap 6)
///   3. Geen verpligte verwantskappe nie
@Model
class BusinessCard {

    // MARK: Persoon
    var firstName: String = ""
    var lastName: String = ""
    var jobTitle: String = ""

    // MARK: Maatskappy
    var company: String = ""

    // MARK: Kontak
    var email: String = ""
    var phone: String = ""
    var mobile: String = ""
    var website: String = ""

    // MARK: Adres
    var street: String = ""
    var city: String = ""
    var postalCode: String = ""

    // MARK: Metadata
    var notes: String = ""
    var dateScanned: Date = Date()

    /// Die volledige OCR-teks, net soos dit gelees is.
    /// Laat ons ou kaartjies herontleed wanneer die ontleding verbeter,
    /// sonder om weer te moet skandeer.
    var rawText: String = ""

    var cardImageData: Data?
    var savedToContacts: Bool = false

    init(
        firstName: String = "",
        lastName: String = "",
        jobTitle: String = "",
        company: String = "",
        email: String = "",
        phone: String = "",
        mobile: String = "",
        website: String = "",
        street: String = "",
        city: String = "",
        postalCode: String = "",
        notes: String = "",
        dateScanned: Date = Date(),
        rawText: String = "",
        cardImageData: Data? = nil,
        savedToContacts: Bool = false
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.jobTitle = jobTitle
        self.company = company
        self.email = email
        self.phone = phone
        self.mobile = mobile
        self.website = website
        self.street = street
        self.city = city
        self.postalCode = postalCode
        self.notes = notes
        self.dateScanned = dateScanned
        self.rawText = rawText
        self.cardImageData = cardImageData
        self.savedToContacts = savedToContacts
    }
}

// MARK: - Afgeleide waardes

extension BusinessCard {

    var fullName: String {
        [firstName, lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Wat in die lys gewys word. Val terug op die maatskappy of e-pos
    /// wanneer die naam nie gelees kon word nie.
    var displayName: String {
        if !fullName.isEmpty { return fullName }
        if !company.isEmpty { return company }
        if !email.isEmpty { return email }
        return "Naamlose kaartjie"
    }

    /// Die reël onder die naam in die lys.
    var subtitle: String {
        [jobTitle, company]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// Waar, wanneer OCR niks bruikbaars opgelewer het nie.
    var hasNoDetails: Bool {
        fullName.isEmpty && company.isEmpty && email.isEmpty && phone.isEmpty && mobile.isEmpty
    }
}
