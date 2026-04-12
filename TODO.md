# Kvante TODO

## Gennemført

### 2026-04-12
- [x] **Ensartet feedback-oplevelse** — Enkelt-scan (`POST /submissions/`) returnerer nu gear_score + improvement_tip via WorkAnalyzerService (med fallback ved AI-fejl). iOS: ChatViewModel viser gear-rating inline i chatten (fjerner broken `POST /feedback/` kald), FeedbackSheet sammensætter feedback fra gear_score-data ("Perfekt!"/"Godt arbejde!"/"Tæt på!"/"Lad os prøve igen" + tip). Tap i arket åbner FeedbackSheet med fuld data uanset scan-type. `POST /feedback/` deprecated. 3 nye pytest tests. Branch: `feature/ensartet-feedback`. Spec: `docs/superpowers/specs/2026-04-12-ensartet-feedback-design.md`. Plan: `docs/superpowers/plans/2026-04-12-ensartet-feedback.md`.
- [x] **FeedbackSheet (pakke 4 opfølgning)** — Én samlet `FeedbackSheet` erstatter tre gamle sheets (FeedbackPreviewSheet, ErrorAnalysisSheet, AssignmentDetailSheet). Kvante pixelart (5 states) øverst, tandhjul-rating (6 stjerner, midlertidigt SF Symbols — venter på pixelart fra Max), "Kvante siger" feedback-sektion med lazy loading, "Tip fra Kvante" forbedringsforslag, samtale-knapper ("Jeg prøver igen" / "Ja, vis mig!") ved fejl. GearScore Pydantic-model med validering + clamping. Backend: gear_score udtrukket fra analyze_work prompt, wired gennem bulk-submit. iOS: GearShape, GearRatingView, FeedbackSheet, croppet scan-billede. Historisk mode i matematikbogen (ingen knapper). 3 gamle sheets slettet (446 linjer). Branch: `feature/feedback-sheet`. Spec: `docs/superpowers/specs/2026-04-12-feedback-sheet-design.md`. Plan: `docs/superpowers/plans/2026-04-12-feedback-sheet.md`.
- [x] **Auto-crop ved bulk-scan** — Claude Vision returnerer normaliserede bounding boxes [x, y, w, h] per opgave. Backend validerer (min 3%, max 50% areal) + nyt `GET /scans/{id}/crop` endpoint med Pillow. iOS: `CropRegion` model, cropped thumbnails i ArkCell via `ScanImageCache.croppedImage()`, `BoundingBoxOverlay` (dimming + orange cutout) i ErrorAnalysisSheet/FeedbackPreviewSheet/AssignmentDetailSheet. Shimmer skeleton loading. Fallback: ingen bbox → fuld side. 26 pytest tests. Bugfixes: `isCurrent`-border skjult på done-opgaver, ark→chat scroller nu til valgt opgave. Branch: `feature/auto-crop`. Spec: `docs/superpowers/specs/2026-04-12-auto-crop-design.md`. Plan: `docs/superpowers/plans/2026-04-12-auto-crop.md`.
- [x] **Pakke 4: Bulk-scan hele arket + AI fejlanalyse** — `POST /sessions/{id}/bulk-submit` med multi-page VisionKit scanner. Claude Vision matcher håndskrevne svar til opgaver, validerer deterministisk med `compare_answer()`, analyserer fejltyper (procedural/understanding/careless). Tre-status ark (✓/✗/❓). ErrorAnalysisSheet (tap forkert → scan + fejltype + "Få hjælp" + "Ret mit svar"). ConfirmAnswerSheet (erstatter re-scan — "Kvante læste X, stemmer det?"). Multi-image `send_vision_multi()` på AIClient. 15 pytest tests. Ark UX fixes: fjernet dobbelt Hjem-knap, tap done → FeedbackPreviewSheet, større opgavekort, DEV-knap bag long-press på KvanteFace, scan-thumbnails for alle løste opgaver (Scan fallback fra Submission). Branch: `feature/pakke-4-bulk-scan`. Spec: `docs/superpowers/specs/2026-04-11-pakke-4-bulk-scan-design.md`. Plan: `docs/superpowers/plans/2026-04-11-pakke-4-bulk-scan.md`.

### 2026-04-11
- [x] **Pakke 5 perf: Inline assignments i session-historik** — Elimineret N+1 API-kald i bog-arkivet. Nyt `?include=assignments` query-parameter på `GET /students/{id}/sessions` returnerer fulde `ArkAssignment`-objekter inline med 4 batch SQL queries i stedet for 1+N individuelle requests. Backend N+1 i default-path også fikset. iOS `NotebookViewModel` simplificeret: `sessionGroups(for:)` er nu synkron, `loadDetail()`/`detailCache` slettet. `SerializeAsAny` for Pydantic v2 subclass-serialisering. Branch: `feature/pakke-5-perf`. Spec: `docs/superpowers/specs/2026-04-11-pakke-5-perf-design.md`. Plan: `docs/superpowers/plans/2026-04-11-pakke-5-perf.md`.

### 2026-04-10
- [x] **Pakke 5: Bog-arkivet ("Din matematikbog")** — Samarbejdsbog mellem elev og Kvante. Omslag med KvanteFace + blyant, "Matematikbogen", "[navn] & Kvante", bryst-panel-prikker, stats-badge. TabView(.page) swipe mellem omslag og uge-sider. Uge-sider med sammenklapppelige session-kort grupperet under "Ugematematik" og "Ekstra øvelser". Facit-kort med opgavetekst + svar-badge (grøn ✓/orange ✗/grå —) + feedback-linje. AssignmentDetailSheet med scan-billede, svar-sammenligning, Kvante-feedback. Home-kort med mini-bogomslag. Backend: `correct_answer` + `student_answer` på ArkAssignment, konfigurerbar `?limit=` på session-historik. 5 pytest tests. Auto-register student ved manglende backendStudentId. **Kendte mangler:** performance (N+1 API-kald), completion-dato i detail sheet. Branch: `feature/pakke-5-notebook`. Spec: `docs/superpowers/specs/2026-04-09-pakke-5-notebook-design.md`. Plan: `docs/superpowers/plans/2026-04-09-pakke-5-notebook.md`.

### 2026-04-09
- [x] **Kvante 2.0 (Pakke 2b + 3 kombineret)** — Persistent KvanteHeaderBar på alle skærme med tegnet KvanteFace (3 udtryk: neutral/glad/store øjne), ProgressDotsView (bryst-panel-prikker), StreakBadge. Celebration redesignet: orange lyn-zigzag erstatter grøn checkmark, haptik-feedback, timing-sekvens (0ms chat → 600ms header-pulse). Home redesignet: velkomst, ugens matematik-kort med mini-ark-preview, kompakt øvelser-kort. "Seneste"-listen fjernet. Sværhedsgrader reduceret 4→3 med farvede prik-ikoner (teal/orange/lilla). Streak-backend: `UserStreak`-tabel med UTC timestamps + `Europe/Copenhagen` timezone, `GET /students/{id}/streak` endpoint, auto-update ved korrekt submission, wired end-to-end til header. VStack-layout (header over NavigationStack) i stedet for safeAreaInset. Branch: `feature/kvante-2.0-header-home-celebration`. Spec: `docs/superpowers/specs/2026-04-09-kvante-2.0-header-home-celebration-design.md`. Plan: `docs/superpowers/plans/2026-04-09-kvante-2.0-header-home-celebration.md`.
- [x] **SF Symbols brainstorm** — Afsluttet hurtigt: SF Symbols beholdes for utility-ikoner. Kvante-specifikke elementer (cirkel-progres-prikker, lyn-zigzag) bliver SwiftUI `Path`/`Shape`, ikke symboler. Ingen custom illustration nødvendig.
- [x] **Pakke 2a: Ark-overlay (navigations-refactor)** — Ny ark-skærm mellem Home og Chat. Alle session-entries (weekly, practice, fortsæt) lander på arket først med 2-kolonne grid over opgaver, scan-thumbnails af løsninger, status-farvekodning (done/inProgress/notStarted), feedback-teaser + "i"-ikon feedback-preview-sheet. Ny `@Observable SessionViewModel` delt mellem ark og chat — ChatViewModel tyndet, delegerer assignment-state. `NavigationStack(path:)` med `SessionRoute`-enum (.ark, .chat). "Mit ark"-knap i chat-header. Backend: `GET /sessions/{id}` udvidet med `ark_status`, `latest_scan_id`, `latest_ai_feedback_summary`, `teacher_comment` (null i 2a), `session_name`, `current_assignment_index` — 15 pytest tests. Bug fixes bundlet: "complete/completed" status-mismatch + practice session tomme names. iOS nye filer: `SessionViewModel`, `ScanImageCache` (NSCache + ImageIO downsampling), `AssignmentSheetView` (papir-tekstur Canvas), `ArkCell`, `FeedbackPreviewSheet`. Slettet: `ProgressPillView`, `SessionDashboardView`, `PracticeSessionView`. Branch: `feature/pakke-2a-ark-overlay`. Spec: `docs/superpowers/specs/2026-04-09-pakke-2a-ark-overlay-design.md`. Plan: `docs/superpowers/plans/2026-04-09-pakke-2a-ark-overlay.md`.
- [x] **Dev-tooling: Global Kvante-capture-knap** — Erstatter shake-to-submit med note-first capture-sheet. Global Kvante-styled FAB (bottom-right, DEV-badge), PencilKit full-screen annotation, to separate storage-paths (`dev-todos/` uden retention, `dev-screenshots/` uændret). Backend Phase A (merget direkte til main 2026-04-08/09): nye `/dev/todos`-endpoints (POST/GET list/latest/{id}/{id}/image/DELETE 204) med pytest-TDD per endpoint + no-retention verification-test. iOS Phase B (`feature/dev-tooling-capture` → main): `APIClient.submitDevTodo`, `DevCaptureButton` (Kvante FAB + DEV-badge), `DevCaptureSheet` (auto-focused TextField, TODO-toggle router mellem `/dev/todos` og `/dev/screenshots`, opt-in "Tag billede"), `DevAnnotationEditor` (PencilKit med `CanvasRepresentable`, flatten med `originalImage.size` koordinat-konsistens) — alt `#if DEBUG`-gated, verificeret via Release build. Phase B udnyttede at Xcode-projektet bruger `PBXFileSystemSynchronizedRootGroup` så fil-renames og nye filer ikke kræver pbxproj-ændringer. Spec: `docs/superpowers/specs/2026-04-08-dev-tooling-global-kvante-capture-design.md`. Plan: `docs/superpowers/plans/2026-04-08-dev-tooling-capture.md`.

### 2026-04-08
- [x] **Pakke 1: Session persistence** — iOS persisterer chat-historikken så elevens arbejde overlever app-lukning og session-gen-åbning. Komponenter: ny generisk `Scan`-tabel + `POST /scans/upload` + `GET /scans/{id}/image` på backend. iOS får `ContentValue`-typed JSON-wrapper, `ChatMessagePersistence`-mapping per content_type (text, assignment_intro, scanned_image, feedback, answer_result, tip, celebration), `syncedMessageIds: Set<UUID>` sync-semantik med stabile UUIDs på tværs af mutation, `isLoadingHistory`-gate i ChatView, parallel scan-upload i `scanAnswer` så Apple- og Vision-OCR begge persisterer. Eksempel-flow markeres med 💡-ankerbesked; selve animationerne er ephemerale. Re-entry til eksisterende session via ny "Fortsæt session"-knap på SessionDashboardView (kræver nyt `GET /sessions/{id}`-endpoint). Bugfix undervejs: `.task(id: serverDiscovery.serverURL)` på home-screen så session-historikken loades efter Bonjour-discovery færdig. Branch: `feature/session-persistence`. End-to-end manuel QA 2026-04-08: bekræftet at scanne svar, force-quit, gen-åbne sessionen og se hele chatten med billeder, intro, feedback og 💡-ankermarkering. Foundation for pakke 2, 4 og 5.
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

Roadmap-reorder 2026-04-08 — se `docs/superpowers/specs/2026-04-08-roadmap-reorder.md` for fuld kontekst med **Why:** og **How to apply:** pr. item. Dependency-analyse identificerede splitninger (pakke 2 → 2a + 2b), bundlinger (single-digit polish, long mult polish) og foldinger (difficulty-ikoner → pakke 3, AI fejlanalyse → pakke 4, SF Symbols-beslutning som step mellem 2a og 2b). Brugerens kontekst: ingen aktive brugere endnu, dev-tooling prioriteres hurtigt for at multiplicere eget optimerings-loop. Kvante-visuelle beslutninger i `~/.claude/projects/-Users-olsen-code-Kvante/memory/project_next_features.md`.

**Pakke 1 (Session persistence) er gennemført 2026-04-08**, **Dev-tooling capture-knap er gennemført 2026-04-09**, og **Pakke 2a (Ark-overlay) er gennemført 2026-04-09** — se "Gennemført"-sektionen øverst.

### 1. Startskærm UX-sprint (B1-B3)
Tre sammenhængende issues på home-skærmen:
- **B1: Dobbelt velkomst** — "Hej, [navn]"-header og KvanteHeaderBar er redundante. Konsolidér al velkomst ind i KvanteHeaderBar.
- **B2: Afsluttet ugesæt vises som aktivt** — Når 0 opgaver tilbage, fjern "Fortsæt"-knap. Flyt til matematikbogen, vis næste uge eller øvelsesforslag.
- **B3: Tom tilstand** — Definer hvad der vises uden aktivt ugesæt. Aldrig tom skærm — vis øvelsesforslag og/eller ros.
Berørte filer: `NewHomeView.swift`, `ContentView.swift`, `KvanteHeaderBar.swift`. Kræver brainstorm for tom-tilstand.

### 4. Matematikbog redesign (C1-C5, kræver brainstorm)
Samlet UX-pass over bog-arkivet:
- **C1: Navngivning** — "Ugematematik — uge 15" er uinformativt. Brainstorm navne der afspejler emne/regneart/sværhedsgrad.
- **C2: SF Symbols + visuel progress** — Ikon per opgavetype, grafisk progressbar i stedet for tekst-tæller.
- **C3: Kvalitetsvurdering** — Vis Kvantes vurdering direkte i listen (stjerner, emoji, farvekode). Eleven ser kvalitet på ét blik.
- **C4: Gratifying oplevelse** — Animerede completion-states, badges, streak-visning, ugens samlede progressbar. Listen er flad og uinspirerende.
- **C5: Mockup-data** — Populer historiske uger med realistisk data: varierede navne, completion-states, kvalitetsvurderinger. Appen skal se brugt ud.
Berørte filer: `NotebookView.swift`, `NotebookWeekView.swift`, `NotebookViewModel.swift`, evt. backend seed data. Kræver brainstorm.

### 5. Single-digit polish-bundle (var #2)
Samlet pass gennem single-digit multiplikations-koden:
- **Fix Vision OCR routing:** `should_use_vision_ocr_for_submission(assignment_text)` returnerer kun True når mindst én operand ≥ 10. "via Vision"-label baseret på faktisk path, ikke hardcoded. (Ophøjet fra Kendte bugs)
- **Fix feedback-tekst:** prompt skal kende forskel på single-digit og long mult. "Du kendte 7 × 8 fra 8-tabellen — 56, helt rigtigt" i stedet for "du gangede ciffer for ciffer med delprodukter". (Ophøjet fra Kendte bugs)
- **Tabel-bevidsthed (retning A):** efter reveal-boblen vises ekstra boble med "Det her er 8-tabellen: 8, 16, 24, 32, 40, 48, 56 ✨" med målrækken highlighted. Brug `b`-operanden som tabel-base hvis `a < b`, ellers `a`.

Bundling undgår at røre single-digit-koden tre gange. Bør ordnes før pakke 4's bulk-scan rammer single-digit-submissions.

### 6. Long mult polish-bundle
Samlet pass gennem long mult-koden:
- **Sequential narration-animation:** brainstorm først (retning B: sætning-for-sætning animation i samme boble, eller retning D: fjern tekst, lad grid + audio bære). Start med brainstorm af hvad "ro og klarhed" betyder for 9-13-årig.
- **Completed LongMultiplicationState efter submission:** static factory `LongMultiplicationState.completed(a:b:)`, multiplikations-success branch bruger `exampleStep` med completed state i stedet for ren tekst. Bringer multiplication op på parity med addition/subtraction.

### 7. Tabel-øvelser (ny feature)
Separat øvelsesmode hvor eleven træner gangetabellerne systematisk som selvstændig aktivitet, ikke del af opgave-løsning. Kræver egen brainstorm: mode (quick-fire / audio / visuel), adaptivitet, scoring, UI-placering. Fundamentet under al multiplikation.

### 8. Lang division visual
Bracket-layout med divide/subtract/bring-down cyklus. Deterministisk service som long-mult (`compute_steps` + `pick_example_numbers` + `generate_text`). Kræver egen brainstorm + spec. Sidste core math method der mangler visual.

---

## Kendte bugs

- [ ] **OCR-præcision** — Claude (aktiv provider på Mac Mini via `.env`) forveksler lignende cifre i håndskrift: 5↔6, 3↔8, 1↔7. Eksempel: eleven skriver 533 men systemet læser 633 (som er det korrekte svar), markerer opgaven rigtigt. Brøker er også problematiske: "1/4" læses som "4". Mulige fixes: (1) prompt-instruktion om at foretrække aflæsning der IKKE matcher facit ved tvivl, (2) ConfirmAnswerSheet ved "correct" med confidence < 0.85, (3) specifik prompt-guidance om forvekslelige cifre.
- [ ] **Scan-billede i FeedbackSheet viser forkert udsnit** — Når en opgave scannes via chatten (enkelt-scan) og derefter vises i FeedbackSheet, viser billedet kun et mærkeligt udsnit (fx toppen af regnestykket uden svaret) i stedet for hele det samlede regnestykke. Sandsynligvis fordi enkelt-scan gemmer et scan-billede uden bounding box, og cropningen rammer forkert. Eleven SKAL kunne se hele sit regnestykke inkl. svar i FeedbackSheet. Opdaget 2026-04-12.
- [ ] **Feedback-generator timeout** — `POST /feedback/` hænger/timeout'er ved lazy feedback-generering fra FeedbackSheet. Log viser at feedback_generator starter men aldrig returnerer. Claude API-kaldet ser ud til at hænge. `feedback_text` er None på alle submissions i DB. Opdaget under FeedbackSheet-test 2026-04-12. Fallback-tekst ("Godt arbejde!") dækker, men reel AI-feedback når aldrig eleven.
- [ ] **Swift 6 concurrency warnings** — `append` kaldt fra baggrundstråd på @MainActor property. Warnings nu, fejl i fremtiden.
- [ ] **Visuel/tekst-konsistens** — AI skriver "æbler" men appen tegner cirkler. Prompt instruerer nu "prikker" men kan stadig ske.
- [ ] **Opgaveforklaring på engelsk** — Explain-endpoint returnerer nogle gange engelsk tekst.
- [ ] **AnimationPlayer.recalculateCumulativeState glemmer cumulativeGridState** — Pre-existing bug opdaget under T9 code review 2026-04-08. `recalculateCumulativeState` nulstiller `cumulativeShortDivisionState`, `cumulativeLongMultiplicationState`, og (nu) `cumulativeArrayGridState`, men IKKE `cumulativeGridState`. Kan give stale stacked-arithmetic grid-state ved backward scroll. Ikke kritisk — genopretter sig ved næste `setup`-step.
- [ ] **Chat-tråd per opgave, ikke per session** — Nuværende design: én lang chat-tråd for hele sessionen (alle opgaver). Bliver uoverskueligt at vende tilbage til. Bør være fokuseret på den individuelle opgave — hver assignment får sin egen chat-kontekst. Kræver refactor af ChatViewModel + backend chat persistence.
- [ ] **Brøk-forklaringer utydelige** — Trin 3 i brøk-eksempler er utydelig. Brøk-eksempler skal simplificeres. Trin 4 flasher 1/4 af cirklen rundt (animationsfejl). Opdaget via dev-capture 2026-04-09.
- [x] **Practice sessions har tom `name` på backend** — Fikset i Pakke 2a (2026-04-09). Genererer nu `"Øvelser — Topic (Difficulty)"`.
- [x] **`completed_count` altid 0 pga. status string-mismatch** — Fikset i Pakke 2a (2026-04-09). Counter accepterer nu begge `"complete"` og `"completed"`.

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
