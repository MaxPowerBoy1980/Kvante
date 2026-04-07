# Kvante TODO

## Gennemført (2026-04-06)

- [x] **Phase 1: UI Overhaul** — Komplet redesign: cream/ink palette, Google AI Studio design, asymmetriske chat-bobler, teal student-bobler, kort-layout home screen, chat header, tactile 3D knapper
- [x] **Phase 1: Onboarding** — Konversationsbaseret chat-onboarding erstatter 3-skærms flow
- [x] **Phase 2: Continuous Chat** — Én samtale per assignment set (ikke per opgave), progress pill med drawer, + context menu, tiered celebrations
- [x] **Phase 2: Backend** — ChatMessage model, chat persistence endpoints, assignment position
- [x] **Phase 3: Ugematematik** — Backend genererer blandede ugentlige sæt, iOS ugematematik-knap aktiv, session historik på home screen, session dashboard view
- [x] **Sticky opgave-bar** — Aktuel opgavetekst altid synlig under progress pill
- [x] **Kort Division Visual (slikkepindsmetoden)** — Ny `ShortDivisionView` med cirkel + lodret streg + progressive rækker. Understøtter rest → brøk → decimal. Deterministisk backend service. Merget til main.
- [x] **Decimal-support i stacked arithmetic** — `3,4 + 2,8` viser nu tiendedele/hundrededele kolonner og komma-separator i gitteret

---

## Næste features (prioriteret)

### 1. Multiplikation Visual (NÆSTE)
Multiplikation bruger stadig LLM-genererede prikker, som bryder kardinalreglen og er ulæselige ved store tal (9×7 = 63 prikker). Byg deterministisk service ligesom `ShortDivisionService`.

To mulige metoder fra `docs/design/2026-04-06-math-methods-reference.md`:
- **1a. Krydset** (kryds-multiplikation): Diagonale linjer der forbinder cifre
- **1b. Lang multiplikation**: Standard opstilling med delprodukter (206·14 → 824 + 2060 → 2884)

Start med 1b — mest brugt i 4.-6. klasse og kan udvide `stacked_arithmetic` med nye actions.

### 2. AI Fejlanalyse ved Forkert Svar
Kvante analyserer elevens fejl og guider: "Du har lagt sammen i stedet for at trække fra" eller "Du glemte at låne fra tierne". Nuværende feedback siger bare "prøv igen".

### 3. Claude Vision til submissions (erstat Apple OCR)
Apple OCR kan ikke læse columnar matematik eller slikkepindsnotation. For at AI'en kan vurdere *metode* (ikke bare facit) skal billeder sendes til Claude Vision. Opdater `work_analyzer.py`.

### 4. Session Persistence
iOS kalder ikke backend's ChatMessage save/load endpoints endnu. Elevens arbejde forsvinder ved app-lukning. Scannede billeder linkes ikke til assignments.

### 5. Lang Division Visual
Bracket-layout med divide/subtract/bring-down cyklus (sektion 2a i math-methods-reference).

---

## Kendte bugs

- [ ] **OCR-præcision** — Claude Haiku læser nogle gange forkert (856 i stedet for 850). Undersøg prompt eller model-valg.
- [ ] **Swift 6 concurrency warnings** — `append` kaldt fra baggrundstråd på @MainActor property. Warnings nu, fejl i fremtiden.
- [ ] **Visuel/tekst-konsistens** — AI skriver "æbler" men appen tegner cirkler. Prompt instruerer nu "prikker" men kan stadig ske.
- [ ] **Opgaveforklaring på engelsk** — Explain-endpoint returnerer nogle gange engelsk tekst.

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
