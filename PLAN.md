# VisiteScan — Herbouplan

**Datum:** 2026-07-25, hersien 2026-07-26
**Doel:** Herbou die verlore Visitescan iOS-app: skandeer 'n visitekaartjie, lees die besonderhede met OCR, en stoor dit in Contacts.app.
**Sjabloon:** FuelScan (`/Volumes/PRO-G40/ACTIVE/08 AI/Projects/01 Apps/FuelScan`) — selfde argitektuur, selfde gevoel.

> ## 📍 Status — 26 Julie 2026
>
> **Stappe 0–4 klaar, en die push is gedoen** — alles staan op
> `github.com/Erichzar/VisiteScan`. Onbepland bygekom: die makro-kamera
> (`MacroCameraView`) en die uitsny-skerm (`CardCropView`) — sien Stap 2½.
>
> **Stappe 5 en 6 klaar. Volgende: Stap 7 (stoor) — die app kan nog nie klaarmaak nie.**
> Dit is die herontwerp wat Erich op 26 Julie gevra het, in sy woorde:
> die kaartjie word geskandeer; dan 'n lys velde soos in die Contacts-app;
> die gelese teks word so goed moontlik daarteen gepas; en wat verkeerd
> geplaas is, skuif jy met die driestrepie-handvatsels na die regte veld.
>
> Toetsbevindings op werklike kaartjies (Erich, 26 Julie):
> - Die **makro-foto is duidelik skerper as die dokumentskandeerder** s'n.
> - Die **grootste teks is altyd die naam óf die firma** — nooit iets anders
>   nie. Daarom gebruik `CardParser` die e-pos as skeidsregter tussen die twee.

---

## 1. Agtergrond

Die oorspronklike Visitescan is deur 'n **SSD-korrupsie** vernietig. Bevestig onherstelbaar:

- Die enigste git-commit bevat net `.gitignore` — die bronkode het nooit 'n commit gehaal nie.
- Alle bronlêers is weg; net leë gidse oor. Die `build/`-uitset is ook leeg.
- Time Machine ("G40 TM") gaan net tot 29 Junie terug — ná die verlies.

**Wat wel oorleef het** (uit `.planning/phases/`-gidsname) — die oorspronklike ontwerp se twee fokusareas:

| Fase | Wat dit was | Waar dit nou is |
|------|-------------|-----------------|
| `01-parsing-quality` | Die kwaliteit waarmee teks gelees word | Stap 4 ✅, verfyn verder in Stap 6 |
| `02-history-deduplication` | Geskiedenis met duplikaat-uitskakeling | Stap 8 |

---

## 2. Besluite vooraf

### 2.1 CSV → vCard

Die oorspronklike spesifikasie vra "contacts .csv formaat". **Apple se Contacts.app kan egter nie CSV invoer nie** — dit voer **vCard (`.vcf`)** in.

```
Geparste kaartjie → CNContact ─┬─→ Contacts.app direk        (eerste prys)
                               └─→ CNContactVCardSerialization → .vcf  (rugsteun)
```

### 2.2 Xcode — ja, maar net as houer

| Wie | Doen wat |
|-----|----------|
| **Erich, in Xcode** | ⌘R om te loop, Signing-oortjie, toets op die iPhone |
| **Claude, in die lêers** | Skryf al die `.swift`-kode direk |

Contacts-toegang werk swak in die simulator (leë adresboek). **Toets op die regte iPhone** — Erich s'n is 'n iPhone 16 Pro, met die drieling-kamera wat die makro-modus moontlik maak.

### 2.3 CloudKit — ja, maar laaste ⚠️

Die sjabloon se regte (`CloudKit` + `aps-environment` + `remote-notification`) bly staan — dit is 'n samehangende opstelling. Maar sinkronisering word laaste aangeskakel (Stap 11), sodat ons nie sinkroniseringsfoute ontfout terwyl die OCR nog verbeter word nie. Die datamodel is van dag een af CloudKit-vormig (§3), dus is Stap 11 hoofsaaklik konfigurasie.

Nog uitstaande: `icloud-container-identifiers` is 'n leë lys. By Stap 11 kom `iCloud.za.co.lutz.VisiteScan` by — 'n regmerkie in Signing & Capabilities.

---

## 3. Argitektuur

### Projekinstellings

| | |
|---|---|
| Naam | **VisiteScan** (hoofletter S — pas by FuelScan) |
| Bundel-ID | `za.co.lutz.VisiteScan` |
| iOS-teiken | **27.0** |
| Span | ANY9W928M5 |
| Berging | SwiftData, later CloudKit-gesinkroniseer |
| GitHub | `Erichzar/VisiteScan` (privaat) — **push ná elke stap** |

### Lêers soos hulle nou staan

| Lêer | Status | Doel |
|------|--------|------|
| `VisiteScanApp.swift` | ✅ | SwiftData-houer |
| `ContentView.swift` | ✅ | TabView: Nuut / Kaarte / Instellings |
| `BusinessCard.swift` | ✅ | `@Model` — CloudKit-vormig (elke veld verstek, geen `.unique`) |
| `MacroCameraView.swift` | ✅ | Eie AVCapture-kamera; virtuele toestel gee makro |
| `CardCropView.swift` | ✅ | Hoekherkenning, sleepbare hoeke, perspektiefregstelling |
| `DocumentScanner.swift` | ✅ | VisionKit-skandeerder (sekondêre pad) |
| `ImagePickers.swift` | ✅ | Lêers-kieser (die ou `CameraView` is nie meer in gebruik nie) |
| `CardOCRService.swift` | ✅ | OCR wat `[RecognizedLine]` met posisie en hoogte teruggee |
| `CardParser.swift` | ✅ | Stap 4 — reëls → velde, e-pos as skeidsregter |
| `NewCardView.swift` | ✅ | Die hoofskerm — word in Stap 5–6 herontwerp |
| `CardListView.swift` | ✅ | Geskiedenis (kry duplikaatlogika in Stap 8) |
| `SettingsView.swift` | ✅ | Instellings |
| `ContactsService.swift` | Stap 7 | `CNContact`-bou, stoor, vCard |
| `ShareSheet.swift` | Stap 9 | Deel die `.vcf` (kopieer 1:1 uit FuelScan) |

### Sleutelfeit vir enige verdere OCR-werk

`cgImage` en `CIImage(image:)` **ignoreer `imageOrientation`**. 'n Kamerafoto kom as `.right`; sonder `normalizedUp()` (in `CardCropView.swift`) sien Vision die teks sywaarts. Die vangs in `MacroCameraView` normaliseer reeds — moenie dit verwyder nie.

---

## 4. Die stappe

Elke stap eindig met **bou, commit, push**. Die bou-opdrag en werkwyse staan in `CLAUDE.md`.

### Stap 0 — Git eerste ✅
Projek by `01 Apps/VisiteScan`, `git init` voor enige kode, en op 26 Julie die push na `Erichzar/VisiteScan`. Die ou leë dop by `02 Herstel nodig/Visitescan` moet nog na die asblik (nooit hard-delete nie) — Erich moet die sein gee.

### Stap 1 — Geraamte ✅
Drie oortjies, `BusinessCard`-model, String Catalogs in plaas van `Localizable.strings`.

### Stap 2 — Inlees ✅
Vier bronne: kamera, dokumentskandeerder, galery, Lêers. `Info.plist`-toestemmings. App-ikoon as `AppIcon` en `AppLogo`.

### Stap 2½ — Makro en uitsny ✅ *(onbepland, uit toetsing gebore)*
Die skanderings was dof: albei stelselkameras gebruik die groothoeklens, wat nie naby kan fokus nie. `MacroCameraView` vra `.builtInTripleCamera` (val terug op `.builtInDualWideCamera`, dan `.builtInWideAngleCamera`) — die virtuele toestel skakel self na die ultragroothoek oor wanneer die kaartjie naby kom. `autoFocusRangeRestriction = .near`. Lens-etiket wys wanneer makro werklik aan is.
`CardCropView` gee die skandeerder se "Adjust" terug: `VNDetectDocumentSegmentationRequest` merk die hoeke, hulle is sleepbaar, `CIPerspectiveCorrection` trek plat. **Getoets: die makro-foto klop die skandeerder duidelik.**

### Stap 3 — Rou OCR ✅
`CardOCRService` gee `[RecognizedLine]` met elke reël se blokkie en hoogte — die grondstof vir alles hierna.

### Stap 4 — Ontleding ✅ *(oorspronklike fase `01-parsing-quality`)*
`CardParser`: harde vorms eerste uit (e-pos, telefoon, webwerf, adres/poskode), dan die sagte keuse. **Naam teenoor firma word deur die e-pos beslis** (voor die `@` = persoon, ná die `@` = firma), dan firma-merkers, dan grootte. Aangrensende reëls van dieselfde hoogte smelt saam ("Erich" bo "Lutz"). SA-nommers: 06/07/08 sel, 01–05 landlyn, +27 → 0.

---

### Stap 5 — Vloei: van vorm na skandeervloei ✅

**maak oop → een groot knoppie → kamera → uitsny → velde staan daar.**

1. **Auto-lees** ✅ — `accept(_:)` loop die OCR en ontleding sodra 'n foto aankom. Die "Lees kaartjie"-knoppie is weg. Elke bron loop nou deur dieselfde tregter (`incomingImage` → `cropCandidate` → `CardCropView` → `accept`), ook die dokumentskandeerder: die ekstra skerm kos een tik en spaar 'n tweede kodepad. Word die uitsny gekanselleer, word die ongesnye foto steeds gelees.
2. **Een hoofknoppie** ✅ — groot "Skandeer kaartjie" na die makro-kamera; die res onder 'n `Menu` ("Ander bronne"). Die logo woon nou in Instellings se Oor-afdeling.
3. **Teks op die uitsny-knoppies** ✅ — Draai / Herken weer / Hele foto het ikoon-bo-teks.

**Toets uitstaande:** uit 'n koue app twee tikke tot by 'n gelese kaartjie (hoofknoppie + sluiter), plus die hoek-kontrole.
`CameraView` in `ImagePickers.swift` is nou ongebruik — kan by Stap 10 uit.

### Stap 6 — Veldlys met skuiwers ✅ *(die kern van die herontwerp)*

Erich se spesifikasie: die uitslag lyk soos die Contacts-app se veldlys, en 'n reël wat verkeerd geplaas is **skuif jy met die driestrepie-handvatsel na die regte veld**.

**Die argitektuur-verandering wat dit moontlik maak** (in `CardField.swift`): `CardParser` gee nie meer stringe terug nie maar `[LineAssignment]` — elke `RecognizedLine` gekoppel aan 'n `CardField` (of aan `.unused`). Die veldwaardes word uit die toewysings *afgelei* (`assignments.card`), nie andersom nie. Skuif = een reël se veld verander; alles herbereken homself. `ParsedCard` bestaan nog, maar as afgeleide waarde.

**Die skerm** (`CardFieldsView.swift`): 'n afdeling per groep in Contacts se volgorde (Wie / Kontak / Adres / Ekstra), plus **"Nie gebruik nie"** onderaan. Elke veld is een ry wat sy reëls hou — 'n veld kan meer as een hê (straat; 'n naam oor twee reëls). Elke reël se teks bly tikbaar om 'n OCR-fout reg te maak.

**Twee maniere om te skuif, albei doelbewus:**
1. **Sleep** aan die ≡-handvatsel (`.draggable` / `.dropDestination`) — wat Erich gevra het, en die vinnigste as die lys sigbaar is.
2. **Tik** die pyltjie regs vir 'n kieslys van al die velde — sleep tussen afdelings is fyn duimwerk, en dié een mis nooit, veral wanneer die teikenveld buite die skerm lê.

Die "Ruil naam ↔ firma"-knoppie bly: dit ruil al die `.name`- en `.company`-reëls gelyk om, in plaas van elkeen afsonderlik te sleep.

**Toets uitstaande:** sleep op die toestel — voel die ≡-gebaar reg, of is die kieslys in die praktyk die een wat gebruik word? Dit bepaal of die sleep bly.

### Stap 7 — Stoor 🎯 *(eerste prys)*

Die velde loop nou dood — daar is geen stoor nie. `ContactsService.swift`:

1. **SwiftData:** die `BusinessCard` word gestoor met alle velde, `rawText` én `cardImageData` — die geskiedenis-oortjie kry sy inhoud.
2. **Contacts.app:** `CNContactViewController(forNewContact:)` — Apple se eie skerm, vooraf ingevul, Erich druk Klaar. (Direkte `CNSaveRequest` as skakelaar in Instellings.)
3. `NSContactsUsageDescription` in Afrikaans; iOS 18+ se beperkte toegang netjies hanteer.

**Toets:** skandeer → stoor → die kontak staan régtig in Contacts.app, en die kaartjie in die Kaarte-oortjie.

### Stap 8 — Geskiedenis + duplikate *(oorspronklike fase `02-history-deduplication`)*
`CardListView`: soek, vee uit. Duplikate op twee vlakke — binne die app (e-pos → telefoon → naam+firma) en teen Contacts.app (`unifiedContacts(matching:)`) *voordat* 'n dubbel geskep word.
**Toets:** dieselfde kaartjie twee keer → waarskuwing.

### Stap 9 — vCard-uitvoer
`CNContactVCardSerialization` + `ShareSheet` (1:1 uit FuelScan). Een kaartjie of almal → `.vcf` → AirDrop, e-pos, Files.
**Toets:** die `.vcf` maak op die Mac in Contacts oop.

### Stap 10 — Afwerking
Afrikaanse vertalings deur (String Catalogs), Oor-afdeling, weergawe 1.0. Besluit oor die los `visitescan-iOS-Default-1024@1x.png` in die projekwortel en die `visitescan.icon` (Icon Composer) wat nie ingedraad is nie.

### Stap 11 — CloudKit ☁️
iCloud-houer byvoeg (Xcode, Signing & Capabilities), `ModelConfiguration` oorskakel, skakelaar in Instellings.
**Toets:** skandeer op die iPhone, die kaartjie verskyn op 'n tweede toestel.

---

## 5. Volgorde

```
0.  Git + push       ✅
1.  Geraamte         ✅
2.  Inlees           ✅
2½. Makro + uitsny   ✅  (onbepland — uit toetsing gebore)
3.  Rou OCR          ✅
4.  Ontleding        ✅
5.  Vloei            ✅
6.  Veldlys met skuiwers  ✅
7.  Stoor            ← ONS IS HIER — eerste prys
8.  Geskiedenis + duplikate
9.  vCard-uitvoer
10. Afwerking
11. CloudKit         ← laaste, die model is klaar reg
```

---

## 6. Waar Erich se insette nodig is

| Stap | Wat |
|------|-----|
| 6 | Werklike kaartjies om die sleep-ervaring op die toestel te toets |
| 7 | Toets op die regte iPhone; besluit bevestigingskerm (aanbeveel) of stil-stoor |
| 10 | Besluit oor die los PNG en die Icon Composer-ikoon |
| 11 | iCloud-houer in Xcode aanskakel; tweede toestel vir die toets |
| enige | Die ou dop by `02 Herstel nodig/Visitescan`: sein wanneer dit asblik toe kan |

---

## 7. Aantekeninge

- **Die push werk nou.** Commits `b8b1d6e`–`2c31d52` dra die verkeerde outeur ("Erich Lutz" i.p.v. `Erichzar`); noudat die geskiedenis gepush is, sou regstel 'n force-push verg — los dit, tensy Erich uitdruklik anders sê.
- Toetsing gebeur oor **Remote Control** — Erich dryf die sessie van sy iPhone af en stuur skermgrepe direk in.
- Filters is doelbewus uit die uitsny-skerm gelaat: Vision lees kleur-oorspronklikes goed, en 'n swartwit-filter gooi inligting weg.
