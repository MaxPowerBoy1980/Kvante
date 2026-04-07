# Kvante TODO

## Gennemført (2026-04-07)

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

### 2. Single-digit multiplikation (array/areal-model)
9 × 7 og lignende single×single hører ikke til long multiplication og blev bevidst ekskluderet fra scope. Bygges som separat feature med array/rektangel-model (ren gitter, ikke spredte prikker). Scope dækker 1×1 op til 9×9 og skal fungere som visuel bro til lang multiplikation.

### 3. AI Fejlanalyse ved Forkert Svar
Kvante analyserer elevens fejl og guider: "Du har lagt sammen i stedet for at trække fra" eller "Du glemte at låne fra tierne". Nuværende feedback siger bare "prøv igen".

### 4. Session Persistence
iOS kalder ikke backend's ChatMessage save/load endpoints endnu. Elevens arbejde forsvinder ved app-lukning. Scannede billeder linkes ikke til assignments.

### 5. Lang Division Visual
Bracket-layout med divide/subtract/bring-down cyklus (sektion 2a i math-methods-reference).

### 6. Completed LongMultiplicationState visual efter submission
Når eleven har scannet et korrekt multiplikations-svar, vises kun tekst-ros. Stacked addition/subtraction bygger en completed GridState der renderes. Tilsvarende `LongMultiplicationState.completed(a:b:)` for at vise elevens fulde opstilling med delprodukter ville være mere tilfredsstillende.

---

## Kendte bugs

- [ ] **OCR-præcision** — Claude Haiku læser nogle gange forkert (856 i stedet for 850). Undersøg prompt eller model-valg.
- [ ] **Swift 6 concurrency warnings** — `append` kaldt fra baggrundstråd på @MainActor property. Warnings nu, fejl i fremtiden.
- [ ] **Visuel/tekst-konsistens** — AI skriver "æbler" men appen tegner cirkler. Prompt instruerer nu "prikker" men kan stadig ske.
- [ ] **Opgaveforklaring på engelsk** — Explain-endpoint returnerer nogle gange engelsk tekst.
- [ ] **Hardcoded "Gemini Vision" label** — `ChatViewModel.scanAnswer` sætter `source = "Gemini Vision"` i vision-grenen, men den deployede backend kører `KVANTE_AI_PROVIDER=claude`. Etiketten er forkert. Fix: hent provider fra API-responset eller brug generisk "Vision".

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
