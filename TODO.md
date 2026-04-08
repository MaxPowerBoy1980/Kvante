# Kvante TODO

## Gennemført

### 2026-04-08
- [x] **Single-digit multiplikation (areal-model)** — Ny `SingleDigitMultiplicationService` + `ArrayGridCleanView` med fyldte teal-kvadrater i a×b grid, række-for-række reveal animation, skip-counting som running total under grid'et, hybrid "+ n = total" boble-narration, celebration ved reveal. Scope 2-9 × 2-9. Operand-rækkefølge bevares (7×9 ≠ 9×7 visuelt — kommutativitet bliver synlig). Try-yours er ren tekst (kardinalreglen — ingen celler at tælle). Schema-migration: `AnimationStep.visual` er nu Optional på både backend og iOS. Routing dispatcher: single-digit foran long_mult i kæden. Branch: `feature/single-digit-multiplication`.

### 2026-04-07
- [x] **Phase 1: UI Overhaul** — Komplet redesign: cream/ink palette, Google AI Studio design, asymmetriske chat-bobler, teal student-bobler, kort-layout home screen, chat header, tactile 3D knapper
- [x] **Phase 1: Onboarding** — Konversationsbaseret chat-onboarding erstatter 3-skærms flow
- [x] **Phase 2: Continuous Chat** — Én samtale per assignment set (ikke per opgave), progress pill med drawer, + context menu, tiered celebrations
- [x] **Phase 2: Backend** — ChatMessage model, chat persistence endpoints, assignment position
- [x] **Phase 3: Ugematematik** — Backend genererer blandede ugentlige sæt, iOS ugematematik-knap aktiv, session historik på home screen, session dashboard view
- [x] **Sticky opgave-bar** — Aktuel opgavetekst altid synlig under progress pill
- [x] **Kort Division Visual (slikkepindsmetoden)** — Ny `ShortDivisionView` med cirkel + lodret streg + progressive rækker. Understøtter rest → brøk → decimal. Deterministisk backend service. Merget til main.
- [x] **Decimal-support i stacked arithmetic** — `3,4 + 2,8` viser nu tiendedele/hundrededele kolonner og komma-separator i gitteret
- [x] **Lang Multiplikation Visual** — Ny `LongMultiplicationView` med mente-række, forskudte delprodukter (som faktiske nuller), expression-chain reveal animation, sum-række, dobbelt-streg. Deterministisk `LongMultiplicationService` (ingen LLM). Scope: max 3×2 cifre. Kolonne-for-kolonne dansk narration der navngiver ener/tier/hundreder og forklarer mente. Multiplikations-submissions routes nu til Vision OCR (ikke Apple OCR).

---

## Næste features (prioriteret)

### 1. Lang Multiplikation — sekventiel narration-animation
Den nuværende narration i partial_product-trin er korrekt men tekst-tæt: hele kolonne-for-kolonne forklaringen står som én lang blok over grid'et. Eleven får kognitiv overload. Brainstorm retning: sekventiel reveal af narration synkroniseret med expression-chain animationen, eller compact/expanded toggle på udtryks-boblen, eller fjernet tekst-blok til fordel for rent visuel + TTS. Kræver sin egen brainstorming + spec — se `docs/superpowers/specs/2026-04-07-long-multiplication-visual.md` for det nuværende design der skal udvides.

### 2. Tabel-bevidsthed i single-digit multiplikation
Live-test af single-digit multiplikation (2026-04-08) afslørede at række-for-række skip-counting visualiserer multiplikation som gentaget addition, men ikke eksplicit forbinder til gangetabellerne. Brugerens ord: "disse stykker er nemmest hvis man kan tabellen for det pågældende tal". Retninger: A) efter reveal vises "Det her er 8-tabellen: 8, 16, 24, 32, 40, 48, 56 ✨" med målrækken highlighted, B) valgfri "Vis tabellen"-knap på setup-bobblen, C) helt ny `times_table` visual-type der erstatter array-grid når begge tal ≥ 5. Kræver brainstorm — option A er mindst invasiv.

### 3. Tabel-øvelser (dedikeret feature)
En egen mode hvor eleven øver gangetabellerne systematisk — ikke som del af opgave-løsning, men som selvstændig drill. Kunne være quick-fire (se et stykke, skriv svar), audio ping-pong (hør stykket, sig svar), eller visuel genkendelse af array-mønstre. Overlapper med "Daglig Øvelses-Mode" sektionen længere nede men fortjener sin egen plads fordi tabellerne er det pædagogiske fundament under al multiplikation. Kræver brainstorm af mode, scoring, spaced repetition.

### 4. AI Fejlanalyse ved Forkert Svar
Kvante analyserer elevens fejl og guider: "Du har lagt sammen i stedet for at trække fra" eller "Du glemte at låne fra tierne". Nuværende feedback siger bare "prøv igen".

### 5. Session Persistence
iOS kalder ikke backend's ChatMessage save/load endpoints endnu. Elevens arbejde forsvinder ved app-lukning. Scannede billeder linkes ikke til assignments.

### 6. Lang Division Visual
Bracket-layout med divide/subtract/bring-down cyklus (sektion 2a i math-methods-reference).

### 7. Completed LongMultiplicationState visual efter submission
Når eleven har scannet et korrekt multiplikations-svar, vises kun tekst-ros. Stacked addition/subtraction bygger en completed GridState der renderes. Tilsvarende `LongMultiplicationState.completed(a:b:)` for at vise elevens fulde opstilling med delprodukter ville være mere tilfredsstillende.

---

## Kendte bugs

- [ ] **"via Vision" label på single-digit submissions** — OPHØJET PRIORITET efter live test 2026-04-08. Feature `16caa1f` routede *alle* multiplikations-submissions til backend Vision OCR, og `d2d1a98` hardcoded "via Vision"-label for samme. Men single-digit multiplikation skulle bruge Apple OCR (lokalt, gratis — et enkelt ciffer er trivielt). Routing skal baseres på operand-størrelse, ikke "er det multiplikation". Fix: tilføj `should_use_vision_ocr_for_submission(assignment_text)` der kun returnerer True når mindst én operand ≥ 10.
- [ ] **Feedback-tekst beskriver forkert metode for single-digit** — OPHØJET PRIORITET efter live test 2026-04-08. Feedback-generator siger "Du stillede 7 og 8 op og gangede dem ciffer for ciffer med delprodukter" for 7 × 8, hvilket er lang-multiplikations-metoden, ikke hvad eleven faktisk gjorde (huske fra tabellen eller tælle på fingre). Feedback-prompt skal kende forskel på single-digit og long multiplication.
- [ ] **OCR-præcision** — Claude Haiku læser nogle gange forkert (856 i stedet for 850). Undersøg prompt eller model-valg.
- [ ] **Swift 6 concurrency warnings** — `append` kaldt fra baggrundstråd på @MainActor property. Warnings nu, fejl i fremtiden.
- [ ] **Visuel/tekst-konsistens** — AI skriver "æbler" men appen tegner cirkler. Prompt instruerer nu "prikker" men kan stadig ske.
- [ ] **Opgaveforklaring på engelsk** — Explain-endpoint returnerer nogle gange engelsk tekst.
- [ ] **AnimationPlayer.recalculateCumulativeState glemmer cumulativeGridState** — Pre-existing bug opdaget under T9 code review 2026-04-08. `recalculateCumulativeState` nulstiller `cumulativeShortDivisionState`, `cumulativeLongMultiplicationState`, og (nu) `cumulativeArrayGridState`, men IKKE `cumulativeGridState`. Kan give stale stacked-arithmetic grid-state ved backward scroll. Ikke kritisk — genopretter sig ved næste `setup`-step.

---

## Fremtidige faser

### Classroom Mode & Lærer-Dashboard
- Web-baseret lærer-dashboard (separat projekt)
- Session creation med QR/pin
- On-the-fly opgavegenerering
- Elev-fremskridtsoversigt med farvekodning

### Daglig Øvelses-Mode (Duolingo-stil)
- Audio ping-pong (tabeller med tale)
- Spaced repetition engine
- Quick-fire visual mode
- Streak og gamification

### Teknisk gæld
- [ ] Slet overflødige Info.plist-hjælpefiler fra iOS-mappen
- [ ] Performanceoptimering — thinking tokens i Gemini
- [ ] TTS-service til oplæsning af forklaringer
