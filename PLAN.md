# VisiteScan — Herbouplan

**Datum:** 2026-07-25
**Doel:** Herbou die verlore Visitescan iOS-app: skandeer 'n visitekaartjie, lees die besonderhede met OCR, en stoor dit in Contacts.app.
**Sjabloon:** FuelScan (`/Volumes/PRO-G40/ACTIVE/08 AI/Projects/01 Apps/FuelScan`) — selfde argitektuur, selfde gevoel.

> ## 📍 Status — 25 Julie 2026
>
> **Stappe 0–3 klaar. Volgende: Stap 4 (veldontleding).**
>
> Die app skandeer 'n kaartjie en wys die gelese teks met elke reël se
> tekshoogte. Erich sou 'n paar werklike kaartjies toets en kyk of die
> **grootste teks** die naam is, en of dit soms die logo is.
> **Vra hom wat hy gesien het voor Stap 4 gebou word.**
>
> **Dringend uitstaande: niks is nog na GitHub gepush nie** — sien §7.

---

## 1. Agtergrond

Die oorspronklike Visitescan is deur 'n **SSD-korrupsie** vernietig. Bevestig onherstelbaar:

- Die enigste git-commit bevat net `.gitignore` — die bronkode het nooit 'n commit gehaal nie.
- Alle bronlêers is weg; net leë gidse oor. Die `build/`-uitset is ook leeg.
- Time Machine ("G40 TM") gaan net tot 29 Junie terug — ná die verlies.

**Wat wel oorleef het** (uit `.planning/phases/`-gidsname) — die oorspronklike ontwerp se twee fokusareas:

| Fase | Wat dit was |
|------|-------------|
| `01-parsing-quality` | Die kwaliteit waarmee teks van die kaartjie gelees word |
| `02-history-deduplication` | 'n Geskiedenis van kaartjies, met duplikaat-uitskakeling |

Albei is in hierdie plan ingebou (Stap 4 en Stap 6).

---

## 2. Besluite vooraf

### 2.1 CSV → vCard

Jou spesifikasie vra "contacts .csv formaat". **Apple se Contacts.app kan egter nie CSV invoer nie** — dit voer **vCard (`.vcf`)** in.

Die goeie nuus: Apple se `Contacts`-raamwerk gee ons albei uit dieselfde objek.

```
Geparste kaartjie → CNContact ─┬─→ Contacts.app direk        (eerste prys)
                               └─→ CNContactVCardSerialization → .vcf  (rugsteun)
```

### 2.2 Xcode — ja, maar net as houer

| Wie | Doen wat |
|-----|----------|
| **Erich, in Xcode** | Projek skep, ⌘R om te loop, Signing-oortjie, toets op die iPhone |
| **Claude, in die lêers** | Skryf al die `.swift`-kode direk |

Contacts-toegang werk swak in die simulator (leë adresboek). **Toets op die regte iPhone.**

### 2.3 CloudKit — ja, maar laaste ⚠️

CloudKit sinkroniseer die kaartjies tussen iPhone/iPad/Mac via Erich se eie iCloud. Die Xcode-sjabloon het die regte reeds ingesit (`CloudKit` + `aps-environment` + `remote-notification`) — **dit is 'n samehangende CloudKit-opstelling, nie gemors nie.** Die push-notifikasies is hoe 'n toestel verwittig word dat data elders verander het.

**Die regte bly. Maar sinkronisering word laaste aangeskakel (Stap 9).**
Rede: as ons dit vroeg aanskakel, sukkel ons met sinkroniseringsfoute terwyl ons nog die OCR-ontleding regmaak. Eers laat werk, dan laat sinkroniseer.

**Wat wél nou moet gebeur:** die datamodel moet van dag een af CloudKit-vormig wees, anders is Stap 9 'n migrasie. Sien §3.

Nog uitstaande: `icloud-container-identifiers` is 'n leë lys. By Stap 9 voeg ons `iCloud.za.co.lutz.VisiteScan` by — 'n regmerkie in Signing & Capabilities.

---

## 3. Argitektuur

### Projekinstellings (soos geskep)

| | |
|---|---|
| Naam | **VisiteScan** (hoofletter S — pas by FuelScan se styl) |
| Bundel-ID | `za.co.lutz.VisiteScan` |
| iOS-teiken | **27.0** (Erich se iPhone loop iOS 27) |
| Swift | 5.0-taalmodus |
| Span | ANY9W928M5 |
| Berging | SwiftData, later CloudKit-gesinkroniseer |

### Lêers om te skryf

| Lêer | Eweknie in FuelScan | Doel |
|------|--------------------|------|
| `VisiteScanApp.swift` | `FuelScanApp.swift` | SwiftData-houer, skema-herstel |
| `ContentView.swift` | ident. | TabView: Nuut / Kaarte / Instellings |
| `BusinessCard.swift` | `FuelTransaction.swift` | `@Model` — die kaartjie-data |
| `DocumentScanner.swift` | ident. — **kopieer 1:1** | VisionKit-kamerawrapper |
| `ShareSheet.swift` | ident. — **kopieer 1:1** | Deel die `.vcf` |
| `CardOCRService.swift` | `OCRService.swift` | Vision-OCR + veldontleding |
| `ContactsService.swift` | *(nuut)* | `CNContact`-bou, stoor, vCard, duplikaatsoek |
| `NewCardView.swift` | `NewTransactionView.swift` | Skandeer → lees → wysig → stoor |
| `CardListView.swift` | `TransactionListView.swift` | Geskiedenis, soek, uitvoer |
| `SettingsView.swift` | ident. | Oor + voorkeure |
| `Localizable.strings` | ident. | af + en |

Die sjabloon se `Item.swift` word deur `BusinessCard.swift` vervang.

### Datamodel — CloudKit-vormig van die begin af

```swift
@Model class BusinessCard {
    // Elke veld het 'n verstekwaarde — CloudKit-vereiste
    var firstName: String = ""
    var lastName: String = ""
    var company: String = ""
    var jobTitle: String = ""
    var email: String = ""
    var phone: String = ""
    var mobile: String = ""
    var website: String = ""
    var street: String = ""
    var city: String = ""
    var postalCode: String = ""
    var notes: String = ""
    var dateScanned: Date = Date()
    var rawText: String = ""        // volle OCR-teks — vir herontleding
    var cardImageData: Data?
    var savedToContacts: Bool = false
}
```

**Drie CloudKit-reëls wat ons van die begin af nakom:**

1. Elke veld het 'n verstekwaarde, óf is opsioneel
2. **Geen `@Attribute(.unique)`** — duplikaatopsporing gebeur met eie logika (Stap 6), nie met 'n databasisbeperking nie
3. Verwantskappe moet opsioneel wees — `BusinessCard` het nie eens verwantskappe nie, dus geen probleem

Punt 2 was reeds die plan vir Stap 6, dus kos CloudKit-versoenbaarheid ons hier niks.

`rawText` is die belangrikste veld: as die ontleding later verbeter, kan ons ou kaartjies **herontleed sonder om weer te skandeer**.

---

## 4. Die stappe

Elke stap eindig met **'n git commit en 'n push**.

### Stap 0 — Git eerste ⚠️ *(grootliks klaar)*

- [x] Projek geskep by `01 Apps/VisiteScan`
- [x] FuelScan se `.gitignore` ingekopieer
- [x] `git init` + eerste commit (`b8b1d6e`) — voor enige kode
- [ ] Push na private GitHub-repo `Erichzar/VisiteScan`
- [ ] Ou leë dop by `02 Herstel nodig/Visitescan` na die asblik

> **Reël vir hierdie projek: ons push ná elke stap.** Die `backup_projects_to_github.sh`-skrip slaan projekte sonder `.swift`-lêers oor — daarom is die vorige Visitescan nooit gerugsteun nie.

**Bekend:** `gh` kan nie by die sleutelhanger uitkom nie (`Timeout trying to log in … (keyring)`). Moet in 'n interaktiewe Terminal opgelos word.

---

### Stap 1 — Geraamte ✅
`VisiteScanApp.swift`, `ContentView.swift`, `BusinessCard.swift`. `Item.swift` uit.
`Localizable.strings` weggelaat — moderne Xcode gebruik String Catalogs, wat SwiftUI se letterlike teks outomaties uittrek. Skuif na Stap 8.
**Getoets:** app loop, drie oortjies wissel.

### Stap 2 — Skandeer ✅
`DocumentScanner.swift` en `ImagePickers.swift` (1:1 uit FuelScan) + `NewCardView.swift` se fotogedeelte — vier knoppies: **Kamera / Skandeer / Galery / Lêers**.
Bo FuelScan: die Kamera- en Skandeer-knoppies word gedeaktiveer waar die toestel hulle nie het nie (`UIImagePickerController` crash met `.camera` in die simulator).
`Info.plist` kry `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription`.
Erich se app-ikoon bygevoeg as `AppIcon` en `AppLogo`.
**Getoets:** skandeerder werk op die iPhone. Fokus sukkel in kunslig — tik om te fokus en druk self die sluiter eerder as om vir outo-vasvang te wag.

### Stap 3 — Rou OCR ✅
`CardOCRService` — FuelScan se `RecognizeTextRequest`-patroon (af + en), **maar dit gee `[RecognizedLine]` terug in plaas van 'n plat string**, met elke reël se blokkie en tekshoogte. Sonder daardie hoogtes sou Stap 4 net op sleutelwoorde kon staatmaak.
`sortedTopToBottom` stel Vision se herkenningsvolgorde reg na die visuele volgorde.
`NewCardView` wys die reëls met hul hoogte as persentasie — 'n tydelike afdeling wat Stap 4 vervang.
**Toets uitstaande:** is die grootste reël die naam, of soms die logo?

### Stap 4 — Ontleding ⭐ *(oorspronklike fase `01-parsing-quality`)*

| Veld | Metode | Vertroue |
|------|--------|----------|
| E-pos | Regex | Hoog |
| Telefoon | `NSDataDetector` + SA-formate (`+27`, `0XX`) | Hoog |
| Webwerf | `NSDataDetector` | Hoog |
| Maatskappy | Agtervoegsels: Pty, Ltd, CC, BK, Edms, Inc | Medium |
| Pos, stad, poskode | SA-poskode = 4 syfers | Medium |
| Posbenaming | Sleutelwoordlys (Direkteur, Bestuurder, Manager…) | Medium |
| **Naam** | **Grootste teks + uitsluiting** | **Laag — die moeilikste** |

**Die slim truuk:** Vision gee vir elke reël 'n *bounding box*. Op 'n visitekaartjie is die **grootste teks** byna altyd die naam of die logo. Sorteer op teksgrootte, sluit dan reëls uit wat 'n maatskappy-agtervoegsel of e-pos bevat. FuelScan gebruik nie bounding boxes nie — hier gaan VisiteScan verder as die sjabloon.

**Toets:** 5–10 werklike kaartjies. Ons meet: hoeveel velde reg, hoeveel moet met die hand reggemaak word.

### Stap 5 — Contacts.app 🎯 *(eerste prys)*
`ContactsService.swift`. Twee stoormaniere:
1. **`CNContactViewController(forNewContact:)`** — Apple se eie skerm, vooraf ingevul, jy druk Klaar. *Verstek.*
2. **`CNSaveRequest`** — stoor direk. Skakelaar in Instellings.

Benodig `NSContactsUsageDescription` (Afrikaanse teks). iOS 18+ se "beperkte toegang" word netjies hanteer.
**Toets:** skandeer → stoor → die kontak verskyn régtig in Contacts.app.

### Stap 6 — Geskiedenis + duplikate *(oorspronklike fase `02-history-deduplication`)*
`CardListView.swift` — lys, soek, vee uit. Duplikate op twee vlakke:
- **Binne die app:** e-pos → telefoon → naam+maatskappy
- **Teen Contacts.app:** `CNContactStore.unifiedContacts(matching:)` waarsku *voordat* 'n dubbel geskep word

**Toets:** skandeer dieselfde kaartjie twee keer → waarskuwing.

### Stap 7 — vCard-uitvoer
`CNContactVCardSerialization` + `ShareSheet`. Een kaartjie of almal → `.vcf` → AirDrop, e-pos, Files.
**Toets:** voer uit, dubbelklik die `.vcf` op die Mac, dit maak in Contacts oop.

### Stap 8 — Afwerking
App-ikoon, Afrikaanse vertalings deur, `SettingsView` se Oor-afdeling, weergawe 1.0.

### Stap 9 — CloudKit-sinkronisering ☁️ *(nuut)*
- iCloud-houer `iCloud.za.co.lutz.VisiteScan` byvoeg in Signing & Capabilities
- `ModelConfiguration` na CloudKit oorskakel
- Sinkroniseringsskakelaar in `SettingsView` (FuelScan het reeds so 'n uitgekommentarieerde afdeling as voorbeeld)

**Toets:** skandeer op die iPhone, die kaartjie verskyn op 'n tweede toestel.
**Waarom laaste:** die model is klaar reg (§3), dus is dit hoofsaaklik konfigurasie. Vroeër aanskakel beteken sinkroniseringsfoute ontfout terwyl die OCR nog nie werk nie.

---

## 5. Volgorde

```
0. Git + projek     ✅  (push nog uitstaande — sien §7)
1. Geraamte         ✅
2. Skandeer         ✅
3. Rou OCR          ✅
4. Ontleding        ← ONS IS HIER. Die moeilikste, waar die waarde lê
5. Contacts.app     ← eerste prys
6. Geskiedenis + duplikate
7. vCard-uitvoer
8. Afwerking
9. CloudKit         ← laaste, want die model is klaar reg
```

Stappe 0–3 is meganies (FuelScan-kode hergebruik). Stap 4 is die werk. Stappe 5–7 en 9 is nuwe terrein.

---

## 6. Waar Erich se insette nodig is

| Stap | Wat |
|------|-----|
| 0 | `gh`-sleutelhanger oplos vir die push |
| 4 | **Regte visitekaartjies** om teen te toets — hoe meer verskillend, hoe beter |
| 5 | Toets op die regte iPhone (die simulator se adresboek is leeg) |
| 5 | Besluit: bevestigingskerm (aanbeveel) of stil-stoor |
| 9 | iCloud-houer byvoeg in Xcode; tweede toestel om sinkronisering te toets |

---

## 7. Uitstaande

### ⚠️ Die push — doen dit eerste

Niks is nog na GitHub nie. Al ses commits sit net op die G40. **Dit is presies die situasie wat die vorige weergawe van hierdie app gekos het.**

`gh` kan nie sy token uit die macOS-sleutelhanger kry nie. Die netwerk is heeltemal reg (IPv4 en IPv6 gee albei HTTP 200 na `api.github.com`) — `gh` se "error connecting" is misleidend; die token is eenvoudig weg. `~/.config/gh/hosts.yml` het die gebruiker `Erichzar` maar geen `oauth_token` nie.

In Terminal:

```bash
gh auth logout --hostname github.com
gh auth login          # GitHub.com → HTTPS → Yes → Login with a web browser
gh auth status         # moet skoon lyk

cd "/Volumes/PRO-G40/ACTIVE/08 AI/Projects/01 Apps/VisiteScan"
gh repo create VisiteScan --private --source=. --remote=origin --push
```

As dit weer by die sleutelhanger vashaak: `gh auth login --insecure-storage` (token as gewone teks in `hosts.yml`, net vir jou leesbaar).

### Kleiner dinge

- Los `visitescan-iOS-Default-1024@1x.png` in die projekwortel is oorbodig — dieselfde beeld sit in `AppIcon` én `AppLogo`. Erich moet sê of dit uit kan.
- Die ou leë dop by `02 Herstel nodig/Visitescan` moet weg **na die asblik, nooit hard-delete nie** — eers nadat die push geslaag het.
- Erich se `visitescan.icon` (Icon Composer) is nie ingedraad nie; die app gebruik die PNG uit die asset-katalogus. FuelScan doen presies dieselfde. Wil hy die gelaagde ikoon hê, moet die `.icon` in Xcode ingesleep word.
