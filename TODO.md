# Kvante TODO

## Gennemført (2026-04-06)

- [x] **Phase 1: UI Overhaul** — Komplet redesign: cream/ink palette, Google AI Studio design, asymmetriske chat-bobler, teal student-bobler, kort-layout home screen, chat header, tactile 3D knapper
- [x] **Phase 1: Onboarding** — Konversationsbaseret chat-onboarding erstatter 3-skærms flow
- [x] **Phase 2: Continuous Chat** — Én samtale per assignment set (ikke per opgave), progress pill med drawer, + context menu, tiered celebrations
- [x] **Phase 2: Backend** — ChatMessage model, chat persistence endpoints, assignment position
- [x] **Phase 3: Ugematematik** — Backend genererer blandede ugentlige sæt, iOS ugematematik-knap aktiv, session historik på home screen, session dashboard view
- [x] **Sticky opgave-bar** — Aktuel opgavetekst altid synlig under progress pill

---

## Næste features (prioriteret)

### 1. Kort Division Visual (NÆSTE)
Ny `StackedDivisionView` — den danske kort division metode:
```
  8
7)56
  56
  --
   0
```
Kræver: backend service (deterministisk) + iOS visual component + dispatch-routing.
Ref: `docs/design/2026-04-06-math-methods-reference.md`

### 2. AI Fejlanalyse ved Forkert Svar
Kvante analyserer elevens fejl og guider: "Du har lagt sammen i stedet for at trække fra" eller "Du glemte at låne fra tierne". Nuværende feedback siger bare "prøv igen".

### 3. Session Persistence
iOS kalder ikke backend's ChatMessage save/load endpoints endnu. Elevens arbejde forsvinder ved app-lukning. Scannede billeder linkes ikke til assignments.

### 4. Lang Multiplikation Visual
Udvid stacked arithmetic med delprodukter: 206·14 → 824 + 2060 → 2884.

### 5. Lang Division Visual
Bracket-layout med divide/subtract/bring-down cyklus.

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
