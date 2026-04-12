# Startskærm UX-sprint (B1-B3)

**Dato:** 2026-04-12
**Status:** Godkendt — klar til implementation
**Mockup:** `.superpowers/brainstorm/58994-1776003963/content/home-states-v2.html`

---

## Problemet

Startskærmen har tre UX-fejl:

- **B1: Dobbelt velkomst** — "Hej, [navn]" som stor heading + KvanteHeaderBar = redundant
- **B2: Afsluttet ugesæt vises som aktivt** — `currentWeekly` falder tilbage til `sessionHistory.first` når alt er løst, så kortet viser "Fortsæt" selvom der intet er at fortsætte
- **B3: Tom tilstand** — Når der ingen aktiv uge er, vises et generisk "Start ugens opgaver" med tomt kort. Det er intetsigende og ligner en fejl.

---

## Løsningen

Én kontekstuel startskærm med tre tilstande. Kortet spejler elevens præcise situation — det *er* velkomsten. "Hej [navn]"-headingen fjernes.

---

## Farvepalette

Alle farver er afledt direkte fra Rob-pixelartens farver. Ingen system-farver undtagen hvid/sort.

| Token                               | Kilde i pixelart                 | Hex       |
| ----------------------------------- | -------------------------------- | --------- |
| `KvanteTheme.Colors.primary`        | Gear-krave, orange               | `#C94B1A` |
| `KvanteTheme.Colors.accentRed`      | Antenna-top, coral-rød           | `#C0392B` |
| `KvanteTheme.Colors.robBlue`        | Robs hoved                       | `#5B9EB5` |
| `KvanteTheme.Colors.blush`          | Kinder-pink                      | `#E8547A` |
| `KvanteTheme.Colors.backgroundWarm` | Afledt af gear-orange, meget lys | `#FFF7ED` |
| `KvanteTheme.Colors.textPrimary`    | Øje-outline, mørk navy           | `#1A2D3D` |

**`Color.green` bruges ikke.** Korrekte chips bruger `robBlue` baggrund med hvid ✓ — tydeligt "korrekt" men inden for Robs univers.

---

## Tilstand 1: Midt i ugen (normal)

**Betingelse:** `activeWeekly != nil`

**Rob:** `rob2.png` (neutral) i hovedkortet, neutral i header

**Hovedkort:**

- Rob neutral pixelart (64×64, `.interpolation(.none)`)
- Titel: "Opgave {current} af {total}"
- Undertitel: "{sessionName} — {topic}"
- Progress-chips: horisontale bokse per opgave
  - Færdige: `robBlue` baggrund, hvid ✓, **tappable → åbner FeedbackSheet for den opgave**
  - Aktuel: `primary` (orange) border + nummer
  - Ventende: grå, nummer
- CTA-knap: "Fortsæt opgave {current}" (`primary` orange, fuld bredde)

**Under kortet:**

- Ekstra øvelser-kort (sekundært)
- Matematikbog-kort (sekundært)

---

## Tilstand 2: Alt er løst (triumf)

**Betingelse:** `activeWeekly == nil && completedWeekly != nil`

**Rob:** `rob2_happy.png` (glad) i hovedkortet — større (80×80). Glad i header.

**Hovedkort:**

- Varm gradient-baggrund (`#FFFFFF → #FFE8D6`), `primary`-tinted border (afledt af gear-kragen)
  - **Note:** Gradient-endpoint er `#FFE8D6` (ikke `#FFF0E6`) for at sikre tilstrækkelig kontrast mod `backgroundWarm` (`#FFF7ED`). Test visuelt — hvis det stadig forsvinder, gå varmere.
- Rob glad pixelart centreret, 80×80 — **Rob ejer øjeblikket**
- Lyn-zigzag under Rob (orange `primary`, statisk i denne sprint)
- Titel: "Uge {N} er i hus!"
- Undertitel: "{total} af {total} opgaver — flot arbejde"
- Progress-chips: alle `robBlue` ✓, alle tappable → FeedbackSheet
- **Ingen primær CTA-knap** — eleven skal lande i triumfen

**Under kortet:**

- "Se hvad du har lavet →" som rolig tekst-link i `robBlue`, centreret — navigerer til matematikbogen for denne session (v1-destination; direkte ark-navigation tilføjes senere)
- Matematikbog-kort (sekundært, passivt arkiv-link)
- **Øvelseskortet er skjult** — forhindrer "godt klaret, og forresten..."-effekten

---

## Tilstand 3: Ingen aktiv uge (venter)

**Betingelse:** `activeWeekly == nil && completedWeekly == nil`

**Rob:** `rob2.png` (neutral) i hovedkortet, neutral i header

**Hovedkort:**

- Dashed border (`robBlue` 25% opacity: `rgba(91, 158, 181, 0.25)`) — visuelt markerer "der er intet her endnu"
- Rob neutral pixelart (64×64)
- Titel: "Ingen nye opgaver endnu" (dæmpet, `textPrimary` 50% opacity)
- Tekst: "Der er ingen nye opgaver til dig endnu. Tjek igen snart!"
- **Ingen knap** — der er intet at starte

**Under kortet:**

- Matematikbog-kort (sekundært)
- **Øvelseskortet er skjult**

**Headerbar:** Ingen progress-dots. Streak-badge vises stadig.

---

## Pixelart-integration

| Tilstand       | Billede          | Størrelse |
| -------------- | ---------------- | --------- |
| 1 (midt i uge) | `rob2.png`       | 64×64     |
| 2 (triumf)     | `rob2_happy.png` | 80×80     |
| 3 (ingen uge)  | `rob2.png`       | 64×64     |

Alle renderes med `.interpolation(.none)` for pixelart-skarphed.

**OBS:** `rob2_happy .png` har et mellemrum i filnavnet — omdøb til `rob2_happy.png` ved import til asset catalog. **Gør dette som allerførste commit** så alle efterfølgende asset-referencer er korrekte.

---

## Tilstandsmaskine

```swift
// sessionHistory antages sorteret nyeste-først
let weeklySessions = sessionHistory.filter { $0.mode == "weekly" }
let activeWeekly = weeklySessions.first { !$0.isCompleted }
let completedWeekly = weeklySessions.first { $0.isCompleted } // nyeste completed

if let active = activeWeekly {
    // Tilstand 1: Midt i ugen
} else if let completed = completedWeekly {
    // Tilstand 2: Alt er løst (triumf)
} else {
    // Tilstand 3: Ingen aktiv uge
}
```

**Note:** `completedWeekly` bruger `.first` på en liste sorteret nyeste-først — returnerer altså den *nyeste* completed session. Verificer at `sessionHistory` er sorteret korrekt inden brug. Triumf-tilstanden forbliver synlig indtil læreren opretter en ny ugentlig session.

**V2-overvejelse (ikke i denne sprint):** Triumf kan føles "stale" hvis eleven åbner appen 5+ dage efter completion uden at en ny uge er oprettet. Overvej evt. en tidsgrænse i v2 — vis triumf kun inden for 7 dage, derefter tilstand 3.

---

## Progress-chip navigation

1. Elev tapper en færdig chip (index 0–N)
2. `SessionViewModel` slår assignment op på det index
3. `FeedbackSheet` præsenteres for den assignment (samme sheet som fra arket)
4. Eleven lukker sheeten → tilbage på startskærmen

Genbruger eksisterende `FeedbackSheet` — ingen ny view nødvendig.

**Affordance-note:** Færdige chips (`robBlue` + ✓) ser statiske ud. Tilføj en subtil visuelt hint om at de er tappable — fx en minimal skygge, eller et kort onboarding-tooltip ved første tap.

---

## Ændringer i KvanteHeaderBar

- **Rob-udtryk matcher tilstand:** neutral (1/3), glad (2)
- **Dots:** vises kun i tilstand 1 og 2. Ingen dots i tilstand 3.
- **Streak:** vises altid

**Dobbelt-Rob:** Headerbaren viser Rob, og hovedkortet viser Rob. Det giver to Rob-instanser på skærmen. Hvis det visuelt føles for meget, kan Rob fjernes fra headerbaren og udelukkende leve i hovedkortet. Headerbar viser så kun progress-dots + streak. **Vurder dette visuelt under implementation** — det er en judgment call, ikke en hard regel.

---

## Hvad fjernes

- `"Hej, \(profile.name)!"` heading + undertitel-blokken
- `currentWeekly` computed property erstattes med `activeWeekly` + `completedWeekly`
- Logikken `currentWeekly != nil ? "Fortsæt" : "Start ugens opgaver"` erstattes af tilstandsmaskinen ovenfor

---

## Scope-afgrænsning

- Ingen animation på triumf-kortet i denne sprint — lyn-zigzag er statisk
- "Se hvad du har lavet →" peger på matematikbogen i v1
- Øvelseskortet skjules i tilstand 2 og 3, vises i tilstand 1

---

## Berørte filer

| Fil                     | Ændring                                                      |
| ----------------------- | ------------------------------------------------------------ |
| `NewHomeView.swift`     | Hovedændring: fjern velkomst-heading, tre-tilstands hovedkort, betinget visning af øvelser/bog |
| `KvanteHeaderBar.swift` | Rob-udtryk matcher tilstand; evt. fjern Rob hvis dobbelt-op føles forkert |
| `ContentView.swift`     | Evt. eksponere `completedWeekly` til home view               |
| `FeedbackSheet.swift`   | Ingen — genbruges som-den-er                                 |
| Asset catalog           | Omdøb `rob2_happy .png` → `rob2_happy.png` (FØRSTE commit)   |
| `KvanteTheme.swift`     | Tilføj `robBlue`, `accentRed`, `blush`, `textPrimary` tokens |
