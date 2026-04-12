# Startskærm UX-sprint (B1-B3)

**Dato:** 2026-04-12
**Mockup:** `.superpowers/brainstorm/58994-1776003963/content/home-states-v2.html`

## Problemet

Startskærmen har tre UX-fejl:

- **B1: Dobbelt velkomst** — "Hej, [navn]" som stor heading + KvanteHeaderBar = redundant
- **B2: Afsluttet ugesæt vises som aktivt** — `currentWeekly` falder tilbage til `sessionHistory.first` når alt er løst, så kortet viser "Fortsæt" selvom der intet er at fortsætte
- **B3: Tom tilstand** — Når der ingen aktiv uge er, vises et generisk "Start ugens opgaver" med tomt kort. Det er intetsigende og ligner en fejl.

## Løsningen

Én kontekstuel startskærm med tre tilstande. Kortet spejler elevens præcise situation — det *er* velkomsten. "Hej [navn]"-headingen fjernes.

## Tilstand 1: Midt i ugen (normal)

**Betingelse:** `activeWeekly != nil`

**Rob:** `rob2.png` (neutral) i hovedkortet, neutral i header

**Hovedkort:**
- Rob neutral pixelart (64×64, `image-rendering: pixelated`)
- Titel: "Opgave {current} af {total}"
- Undertitel: "{sessionName} — {topic}"
- Progress-chips: horisontale bokse per opgave
  - Færdige: grøn baggrund, ✓, **tappable → åbner FeedbackSheet for den opgave**
  - Aktuel: orange border + nummer
  - Ventende: grå, nummer
- CTA-knap: "Fortsæt opgave {current}" (orange, fuld bredde)

**Under kortet:**
- Ekstra øvelser-kort (sekundært)
- Matematikbog-kort (sekundært)

## Tilstand 2: Alt er løst (triumf)

**Betingelse:** `activeWeekly == nil && completedWeekly != nil`

**Rob:** `rob2_happy.png` (glad) i hovedkortet — større (80×80). Glad i header.

**Hovedkort:**
- Varm gradient-baggrund (`#fff → #FFF8F0`), orange-tint border
- Rob glad pixelart centreret — **Rob ejer øjeblikket**
- Lyn-zigzag under Rob (orange, `⚡⚡⚡` eller custom SwiftUI shape)
- Titel: "Uge {N} er i hus!"
- Undertitel: "{total} af {total} opgaver — flot arbejde"
- Progress-chips: alle grønne ✓, alle tappable → FeedbackSheet
- **Ingen primær CTA-knap** — eleven skal lande i triumfen

**Under kortet:**
- "Se dit arbejde denne uge →" som rolig tekst-link (teal, centreret) — navigerer til arket/matematikbogen for denne session
- Matematikbog-kort (sekundært, passivt arkiv-link)
- **Øvelseskortet er skjult** — forhindrer "godt klaret, og forresten..." effekten

## Tilstand 3: Ingen aktiv uge (venter)

**Betingelse:** `activeWeekly == nil && completedWeekly == nil` (ingen weekly sessions overhovedet, eller ingen nylig completed)

**Rob:** `rob2.png` (neutral) i hovedkortet, neutral i header

**Hovedkort:**
- Dashed border (`rgba(61,44,30,0.15)`) — visuelt markerer "der er intet her endnu"
- Rob neutral pixelart (64×64)
- Titel: "Ingen nye opgaver endnu" (dæmpet farve)
- Tekst: "Kvante venter på at din lærer lægger ugens opgaver ind. Tjek igen senere."
- **Ingen knap** — der er intet at starte

**Under kortet:**
- Matematikbog-kort (sekundært)
- **Øvelseskortet er skjult** — intet at øve sig på uden kontekst

**Headerbar:** Ingen progress-dots (ingen session). Streak-badge vises stadig.

## Pixelart-integration

Rob-billederne fra `icons/Kvante/Pixelart/` bruges direkte som assets:

| Tilstand | Billede | Størrelse i kort |
|----------|---------|------------------|
| 1 (midt i uge) | `rob2.png` | 64×64 |
| 2 (triumf) | `rob2_happy.png` | 80×80 |
| 3 (ingen uge) | `rob2.png` | 64×64 |

Alle renderes med `Image(...)` og `.interpolation(.none)` for at bevare pixelart-skarpheden.

**Bemærk:** `rob2_happy .png` har et mellemrum i filnavnet — skal enten omdøbes ved import til asset catalog eller håndteres i koden.

## Progress-chip navigation

Tappable ✓-chips er ny navigation:

1. Elev tapper en færdig chip (index 0-2 i eksemplet)
2. `SessionViewModel` slår assignment op på det index
3. FeedbackSheet præsenteres for den assignment (samme sheet som fra arket)
4. Eleven kan lukke sheeten og er tilbage på startskærmen

Dette genbruger den eksisterende `FeedbackSheet` — ingen ny view nødvendig. Kræver kun at hovedkortet kender assignment-listen og kan præsentere sheeten.

## Ændringer i KvanteHeaderBar

Headerbaren ændres minimalt:

- **Rob-udtryk matcher tilstand:** neutral (1/3), glad (2)
- **Dots:** vises kun når session er aktiv (tilstand 1 og 2). Ingen dots i tilstand 3.
- **Streak:** vises altid

Ingen strukturelle ændringer i headerbaren.

## Hvad fjernes

- `"Hej, \(profile.name)!"` heading + undertitel-blokken (linje 45-59 i NewHomeView.swift)
- `currentWeekly` computed property erstattes med to:
  - `activeWeekly`: første incomplete weekly session (`sessionHistory.first { $0.mode == "weekly" && !$0.isCompleted }`)
  - `completedWeekly`: senest completed weekly session (`sessionHistory.first { $0.mode == "weekly" && $0.isCompleted }`)
- Logikken `currentWeekly != nil ? "Fortsæt" : "Start ugens opgaver"` erstattes af tilstandsmaskinen

## Tilstandsmaskine

```swift
let weeklySessions = sessionHistory.filter { $0.mode == "weekly" }
let activeWeekly = weeklySessions.first { !$0.isCompleted }
let completedWeekly = weeklySessions.first { $0.isCompleted }

if let active = activeWeekly {
    // Tilstand 1: Midt i ugen
} else if let completed = completedWeekly {
    // Tilstand 2: Alt er løst (triumf)
} else {
    // Tilstand 3: Ingen aktiv uge
}
```

**Note:** `completedWeekly` viser den senest completed weekly session. Triumf-kortet forbliver synligt indtil en ny ugentlig session oprettes (→ tilstand 1). I praksis opretter læreren nye sessioner ugentligt, så triumf-tilstanden varer typisk fra færdiggørelse til næste mandag.

## Hvad der IKKE ændres

- Øvelseskortets indhold og navigation
- Matematikbogskortets indhold og navigation
- Backend — rent iOS-ændring
- Onboarding-flow
- Arket (AssignmentSheetView)
- ChatView

## Berørte filer

| Fil | Ændring |
|-----|---------|
| `NewHomeView.swift` | Hovedændring: fjern velkomst-heading, tre-tilstands hovedkort, betinget visning af øvelser/bog |
| `KvanteHeaderBar.swift` | Rob-udtryk matcher tilstand (minimal) |
| `ContentView.swift` | Evt. eksponere `completedWeekly` til home view |
| `FeedbackSheet.swift` | Ingen — genbruges som-den-er |
| Asset catalog | Tilføj Rob pixelart-billeder som image assets |

## Scope-afgrænsning

- Ingen animation på triumf-kortet i denne sprint — lyn-zigzag er statisk. Animation kan tilføjes senere.
- "Se dit arbejde denne uge →" navigerer til arket for den completed session. Hvis navigation er besværlig, kan det starte som et link til matematikbogen.
- Øvelseskortet gemmes kun i tilstand 2 og 3. Det dukker op igen i tilstand 1.
