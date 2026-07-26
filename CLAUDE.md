# CLAUDE.md — VisiteScan

Oriëntasie vir 'n nuwe Claude Code-sessie in hierdie projek.
**Lees eers `PLAN.md`** — dit is die stap-vir-stap plan wat ons volg.

---

## Wat dit is

iOS-app wat 'n visitekaartjie skandeer, die besonderhede met OCR lees, en
dit in **Contacts.app** stoor (eerste prys) of as **vCard `.vcf`** uitvoer.

SwiftUI + SwiftData + Vision. Erich is 'n amateur-programmeerder — verduidelik
stap vir stap, en skryf in Afrikaans.

## Waar ons is (26 Julie 2026)

Stappe 0–4 klaar, plus die onbeplande Stap 2½ (makro-kamera en uitsny-skerm —
die makro-foto klop die dokumentskandeerder duidelik op werklike kaartjies).
**Die push is gedoen:** alles staan op `github.com/Erichzar/VisiteScan`.

**Volgende: Stap 5 (vloei) en dan Stap 6 (veldlys met skuiwers).** Dit is die
herontwerp wat Erich op 26 Julie gevra het: een groot skandeer-knoppie, OCR
wat vanself loop, en die uitslag as 'n Contacts-agtige veldlys waar 'n
verkeerd geplaaste reël met die driestrepie-handvatsel na die regte veld
gesleep word. PLAN.md §4 (Stap 5 en 6) het die volle spesifikasie —
veral die toewysing-per-reël-model in Stap 6 is nie onderhandelbaar nie.

Toetsing gebeur oor **Remote Control**: Erich dryf die sessie van sy iPhone
(16 Pro) af en stuur skermgrepe direk in. Hou antwoorde bondig.

## Uitstaande

1. Los `visitescan-iOS-Default-1024@1x.png` in die projekwortel is oorbodig
   (dieselfde beeld is in AppIcon en AppLogo). Erich moet nog sê of dit uit kan.
2. Die ou leë dop by `02 Herstel nodig/Visitescan` moet weg — **na die asblik,
   nooit hard-delete nie** — wag vir Erich se sein.

## Werkwyse

- **Bou voor elke commit:** dit het al vier foute gevang wat andersins deur
  sou geglip het.
  ```bash
  cd "/Volumes/PRO-G40/ACTIVE/08 AI/Projects/01 Apps/VisiteScan"
  xcodebuild -project VisiteScan.xcodeproj -scheme VisiteScan \
    -destination 'generic/platform=iOS' -configuration Debug \
    build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
  ```
- **Een commit per stap**, met 'n boodskap wat die *waarom* verduidelik.
- **Moenie die git-outeur oorskryf nie.** Erich se globale config is
  `Erichzar <167574906+Erichzar@users.noreply.github.com>` — laat `git commit`
  dit self gebruik. (Vroeër is `-c user.name="Erich Lutz"` afgedwing, uit sy ou
  rugsteun-skrip oorgeneem.) Commits b8b1d6e t/m 2c31d52 dra die verkeerde
  outeur, maar die geskiedenis is intussen gepush — regstel sou 'n force-push
  verg. **Los dit, tensy Erich uitdruklik anders sê.**
- Die projek gebruik Xcode 16+ se **gesinkroniseerde lêergroepe**, so enige
  `.swift` wat in `VisiteScan/` beland is outomaties deel van die teiken —
  moenie aan `project.pbxproj` karring nie.
- **Moenie die G40 met `find` deursoek nie.** Vra Erich vir die pad; hy gee dit
  sommer. Nuwe gidse: gebruik die `request_directory`-hulpmiddel.
- Toets op die **regte iPhone**, nie die simulator nie — die simulator het geen
  kamera nie en 'n leë adresboek.

## Sleutelbesluite (moenie omkeer sonder om te vra nie)

| Besluit | Waarom |
|---|---|
| **vCard, nie CSV nie** | Contacts.app kan nie CSV invoer nie. Dieselfde `CNContact` voed die direkte integrasie én die uitvoerlêer. |
| **CloudKit laaste (Stap 9)** | Die sjabloon se CloudKit- en push-regte bly — dit is 'n samehangende opstelling, nie gemors nie. Maar vroeg aanskakel beteken sinkroniseringsfoute ontfout terwyl die OCR nog nie werk nie. |
| **Model is CloudKit-vormig** | Elke veld het 'n verstekwaarde, **geen `@Attribute(.unique)`**, geen verpligte verwantskappe. Breek dit en Stap 9 word 'n migrasie. |
| **`rawText` word bewaar** | Die volledige OCR-teks word gestoor sodat ou kaartjies herontleed kan word wanneer die ontleding verbeter — sonder om weer te skandeer. |
| **Geen `Localizable.strings`** | Moderne Xcode gebruik String Catalogs, wat SwiftUI se letterlike teks outomaties uittrek. Gebeur by Stap 8. |

## Sjabloon

**FuelScan** — `/Volumes/PRO-G40/ACTIVE/08 AI/Projects/01 Apps/FuelScan`.
Erich se eie app; VisiteScan spieël sy argitektuur en gevoel doelbewus.
`DocumentScanner.swift` en die beeldkiesers is reguit daaruit oorgeneem.
Gaan kyk daar eerste wanneer jy wonder hoe iets gedoen moet word.

## Agtergrond

Die oorspronklike Visitescan is deur 'n **SSD-korrupsie** vernietig — alle
bronkode weg, want dit was nooit ge-commit nie. Time Machine gaan net tot
29 Junie terug, ná die verlies. Hierdie projek is 'n herbou van nuuts af.
Sien `PLAN.md` §1.
