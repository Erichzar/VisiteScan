# CLAUDE.md — VisiteScan

Oriëntasie vir 'n nuwe Claude Code-sessie in hierdie projek.
**Lees eers `PLAN.md`** — dit is die stap-vir-stap plan wat ons volg.

---

## Wat dit is

iOS-app wat 'n visitekaartjie skandeer, die besonderhede met OCR lees, en
dit in **Contacts.app** stoor (eerste prys) of as **vCard `.vcf`** uitvoer.

SwiftUI + SwiftData + Vision. Erich is 'n amateur-programmeerder — verduidelik
stap vir stap, en skryf in Afrikaans.

## Waar ons is (25 Julie 2026)

Stappe 0–3 klaar. **Volgende: Stap 4 — die veldontleding.**

```
b99a255  Stap 3: rou OCR wat reëlposisies en -hoogtes bewaar
2c31d52  Herstel AppLogo-beeldstel sodat die logo binne die app wys
e5d90ee  Stap 2: kaartjie inlees uit kamera, skandeerder, galery of lêers
652ebba  Stap 1: geraamte met BusinessCard-model en drie oortjies
5a08033  Voeg herbouplan by, met CloudKit as Stap 9
b8b1d6e  Initial commit: leë VisiteScan-projek uit Xcode-sjabloon
```

Erich sou 'n paar werklike kaartjies skandeer en kyk of die reël met die
**grootste tekshoogte** die persoon se naam is, en of dit soms die maatskappy
se logo-teks is. **Vra hom wat hy gesien het voor jy Stap 4 bou** — daardie
antwoord bepaal of die naamherkenning 'n uitsluitingsreël vir logo's nodig het.

## Uitstaande

1. **Niks is nog gepush nie.** `gh` kan nie by die macOS-sleutelhanger uitkom
   nie (`Timeout … (keyring)`; die netwerk is reg, dit is die token wat weg is).
   Erich moet in Terminal `gh auth logout --hostname github.com` en dan
   `gh auth login` doen — of `gh auth login --insecure-storage` as dit weer
   vashaak. Daarna:
   `gh repo create VisiteScan --private --source=. --remote=origin --push`
   *Dit is die belangrikste uitstaande item — die vorige weergawe van hierdie
   app is verloor juis omdat die kode nooit gepush is nie.*
2. Los `visitescan-iOS-Default-1024@1x.png` in die projekwortel is oorbodig
   (dieselfde beeld is in AppIcon en AppLogo). Erich moet nog sê of dit uit kan.
3. Die ou leë dop by `02 Herstel nodig/Visitescan` moet weg — **na die asblik,
   nooit hard-delete nie** — sodra die push geslaag het.

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
