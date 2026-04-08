# Kvante TODO

## Gennemført

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

UX-review 2026-04-08 identificerede fem oplevelseshuller: progres føles ikke som progres, der er ingen "se hele mit arbejde"-visning, home-skærmen er flad, ingen streaks, og der mangler et papir-agtigt opgave-overblik. Aftalt retning: A-A-A (tæt opgradering af eksisterende UI + bog-metafor + "i dag"-helt på home) + opgaveark-overlay som første-skærm i en session. Fuld kontekst med begrundelser og Kvante-visuelle beslutninger i `~/.claude/projects/-Users-olsen-code-Kvante/memory/project_next_features.md`.

**Pakke 1 (Session persistence) er gennemført 2026-04-08** — se "Gennemført"-sektionen øverst. Det fjerner blocker'en for pakke 2, 4 og 5. Næste op er pakke 2.

### Pakke 2 — Opgaveark-overlay + cirkel-progres + streak-backend
Ny navigations-struktur: **Home → Ark-overlay → Chat**. Efter "Start opgaver" lander eleven på et slide-down ark-overlay (ikke direkte i chat) der viser alle ugens opgaver med hele regnestykket + status (orange=ikke løst, grøn=løst, lille pil=aktuel). Tap på en opgave → den bliver aktiv i chatten. "< Tilbage"-knappen i chatten går tilbage til arket, ikke hele vejen til home. Eleven kan frit vælge hvilken opgave hun starter med — ingen påtvungen rækkefølge.

Progres-visualisering: cirkel-rad baseret på Kvantes bryst-panel, placeret i "i dag"-helten på home-skærmen (pakke 3). Prikker går fra blå outline til orange fyldt som opgaverne løses. Ved korrekt svar fylder én prik op med animation (scale pulse), haptik, kort "ding", og et koral lyn-zigzag flashe hen over panelet. Lyn bliver Kvantes celebration-signatur — ikke grønt flueben. Flueben forbliver kun i teknisk scan-feedback ("Læste: 735 ✓").

Streak-backend: ny tabel eller felt der tracker "sidste dag med mindst 1 løst opgave". Streak = antal på hinanden følgende dage med aktivitet. Pr. opgave, ikke pr. tid. Én løst opgave = en streak-dag. Visualiseres som lille flamme-badge øverst til højre på home-skærmen.

### Pakke 3 — Home-skærm redesign + "i dag"-helten + bonus-mode
Ny home med stor dynamisk "i dag"-boks øverst der viser Kvante i tre tilstande afhængig af ugens status:
- **Intet løst i dag:** "Hej, Lyng! Uge 15 venter — 6 opgaver klar" + Kvante med tomt bryst-panel + "Start i dag"-knap
- **I gang:** "Godt i gang, Lyng! Du er halvvejs — 3 opgaver tilbage" + Kvante med 3/6 fyldte prikker + "Fortsæt"-knap
- **Færdig med ugen:** "Du gjorde det, Lyng! Uge 15 er i hus" + Kvante med alle prikker fyldt + lyn zigzag + bonus-tilbud: "Ekstra øvelser" eller "Hvil" (to knapper, ingen "næste uge"-knap — næste uge åbner automatisk mandag)

Streak-flamme som lille badge øverst til højre. De to eksisterende kort (Ugematematik / Øvelser) skubbes ned og bliver mindre — de er adgangspunkter, ikke heroes. Bog-knap ("Din matematikbog, 12 sider →") får sin egen plads nederst. Seneste-listen forsvinder som liste (erstattes af bog-arkivet i pakke 5).

Kvantes udtryk skifter mellem neutral / lidt smil / store øjne baseret på status. Minimum-sættet — kan udvides senere.

### Pakke 4 — Bulk-scan hele arket (separat fra pakke 2)
Nyt endpoint `POST /sessions/{id}/bulk-submit` med billede af hele A4-arket. Gemini Vision udtrækker alle regnestykker + elevens svar, matcher mod sessionens opgaver baseret på tallene (ikke position), validerer hvert svar. Returnerer batch-status: `{ matches: [{opgave_id, elev_svar, korrekt, feedback}], unmatched: [...] }`.

iOS: "📷 Scan hele arket"-knap i bunden af ark-overlay. Loading-state med bobende Kvante-antenne ("Kvante kigger på dit ark..."). Ark-overlayet opdateres batch-wise — hver opgave får enten ✓ grøn, ✗ rød eller ? gul. Samlet feedback-kort i chatten ("Jeg fandt 5 svar på dit ark — 4 rigtige, 1 der skal kigges på igen"). Tap på en rød opgave → den bliver aktiv i chatten → Kvante giver detaljeret feedback (bruger AI-fejlanalyse fra backlog når den er bygget).

Udfordringer at løse i spec: long multiplication der fylder flere linjer, Vision der læser tal forkert (samme reparations-flow som nuværende single-scan), delvise ark hvor kun nogle opgaver er løst, bulk-scan to gange (anden gang overskriver tidligere resultater for matches).

### Pakke 5 — Bog-arkivet ("Din matematikbog")
Seneste-sektionen erstattes af et side-for-side hæfte. Hver session = én side med opgavetekst, kondenseret AI-gennemgang (ikke hele chat-historikken — for meget tekst), elevens scannede papir-foto som hovedelement, dato, flueben. Grupperet pr. uge med små uge-skille-sider ("Uge 14 — du løste 5 opgaver"). Kvante på omslaget holdende en blyant. Swipe venstre/højre for at bladre. Tilgængelig via dedikeret "Din matematikbog"-knap på home. Sideantal vises på knappen ("18 sider") fordi det føles stoltheds-agtigt hvor "8 sessions" føles teknisk.

Krav: session persistence (pakke 1) skal være i mål før der er noget at vise.

---

## Backlog (efter pakke 1-5)

### Lang Multiplikation — sekventiel narration-animation
Den nuværende narration i partial_product-trin er korrekt men tekst-tæt: hele kolonne-for-kolonne forklaringen står som én lang blok over grid'et. Eleven får kognitiv overload. Brainstorm retning: sekventiel reveal af narration synkroniseret med expression-chain animationen, eller compact/expanded toggle på udtryks-boblen, eller fjernet tekst-blok til fordel for rent visuel + TTS. Kræver sin egen brainstorming + spec — se `docs/superpowers/specs/2026-04-07-long-multiplication-visual.md` for det nuværende design der skal udvides.

### Tabel-bevidsthed i single-digit multiplikation
Live-test af single-digit multiplikation (2026-04-08) afslørede at række-for-række skip-counting visualiserer multiplikation som gentaget addition, men ikke eksplicit forbinder til gangetabellerne. Brugerens ord: "disse stykker er nemmest hvis man kan tabellen for det pågældende tal". Retninger: A) efter reveal vises "Det her er 8-tabellen: 8, 16, 24, 32, 40, 48, 56 ✨" med målrækken highlighted, B) valgfri "Vis tabellen"-knap på setup-bobblen, C) helt ny `times_table` visual-type der erstatter array-grid når begge tal ≥ 5. Kræver brainstorm — option A er mindst invasiv.

### Tabel-øvelser (dedikeret feature)
En egen mode hvor eleven øver gangetabellerne systematisk — ikke som del af opgave-løsning, men som selvstændig drill. Kunne være quick-fire (se et stykke, skriv svar), audio ping-pong (hør stykket, sig svar), eller visuel genkendelse af array-mønstre. Overlapper med "Daglig Øvelses-Mode" sektionen længere nede men fortjener sin egen plads fordi tabellerne er det pædagogiske fundament under al multiplikation. Kræver brainstorm af mode, scoring, spaced repetition.

### AI Fejlanalyse ved Forkert Svar
Kvante analyserer elevens fejl og guider: "Du har lagt sammen i stedet for at trække fra" eller "Du glemte at låne fra tierne". Nuværende feedback siger bare "prøv igen". Kobler stærkt til bulk-scan-feedback (pakke 4) og reparations-flowet.

### Lang Division Visual
Bracket-layout med divide/subtract/bring-down cyklus (sektion 2a i math-methods-reference).

### Completed LongMultiplicationState visual efter submission
Når eleven har scannet et korrekt multiplikations-svar, vises kun tekst-ros. Stacked addition/subtraction bygger en completed GridState der renderes. Tilsvarende `LongMultiplicationState.completed(a:b:)` for at vise elevens fulde opstilling med delprodukter ville være mere tilfredsstillende.

### SF Symbols som muligt ikon-system (brainstorm)
Brainstorm om nye UI-ikoner (cirkel-progres, streak-flamme, sheet-triggers, utility-ikoner) skal bygges med SF Symbols eller som custom illustration. SF Symbols er hurtigere, gratis, Dynamic Type-venligt og animerbart fra iOS 17+, men generisk. Custom giver karakter men kræver illustrator-arbejde. Sandsynligvis en blanding — tag stilling per ikon, ikke en fælles regel. Skal brainstormes inden pakke 2 begynder at bygge visuelle komponenter.

### Difficulty-ikoner (Let/Mellem/Svær/Ekspert) skal udskiftes
De nuværende plante-ikoner (frø → spire → træ → trofæ) på Øvelser-sværhedsskærmen skal ændres. Retninger at overveje i brainstorm: SF Symbols (stjerne-gradueringer, nummer-cirkler), custom Kvante-udtryks-ikoner (neutral → smil → koncentreret → "jeg kan det her"), eller noget fjerde. Ikke kritisk sti — lille separat pakke eller som del af pakke 3's home-redesign.

### Dev-tooling: Global Kvante-knap som rich capture-mekanisme (erstatter shake-to-screenshot)
Den nuværende dev-screenshot-feature (kamera-ikon nederst til højre, shake-to-submit) erstattes af en mere brugbar capture-flow centreret omkring Kvante-avataren. Kvante-ikonet bliver en globalt tilgængelig knap (på alle skærme) der åbner en menu med tre handlinger: tag screenshot, annotér med Apple Pencil oven på, og skriv tekst-note. Eleven/brugeren kan valgfrit markere fanget materiale som en TODO-item.

**Hvorfor:** Den nuværende shake-to-submit er funktionel men begrænset. Den fanger kun rå screenshots med en valgfri tekst, ingen annotation, og blander observation/troubleshooting med faktiske TODO-items. Når brugeren tester appen og vil flagge en konkret bug eller feature-idé, er det værdifuldt at kunne tegne på billedet med Apple Pencil for at pege på præcis det område der er problemet — det fjerner enormt meget tekst-besvær. Og en eksplicit "is this a TODO?"-toggle holder TODO-listen ren.

**Sub-features at bygge:**

- **Global Kvante-knap.** Erstatter det nuværende kamera-ikon på home-skærmen, og findes også på alle andre skærme. Skal tænkes ind i navigation-strukturen — f.eks. som en floating overlay-knap eller i et fast hjørne. Skal koeksistere med den eksisterende Kvante-avatar i chat-headeren (er det samme knap eller to forskellige Kvante-tilstedeværelser? Brainstorm).
- **Capture-menu.** Bottom-sheet eller popover ved tap. Indeholder: "Tag screenshot", "Tilføj note", toggle "Marker som TODO".
- **Apple Pencil annotation.** PencilKit (`PKCanvasView`) er den oplagte løsning — Apple's framework, gratis, integrerer direkte med pencil. Tegning lægges som et lag oven på det fangne screenshot, fladtrykkes ind i den endelige JPEG ved gem. Alternativ: gem `PKDrawing`-data separat og rendrer ovenpå ved visning, så brugeren kan re-redigere. Beslutning udsat til implementation.
- **Backend-routing baseret på TODO-flag:**
  - **Ikke-TODO** (default — observation/troubleshooting): gemmes i den eksisterende `~/Library/Application Support/Kvante/dev-screenshots/`-mappe præcis som i dag. Bevarer min nuværende workflow til debug-sessioner.
  - **TODO-tagged**: gemmes i ny `~/Library/Application Support/Kvante/dev-todos/`-mappe med billede + tekst-note som metadata. Jeg læser dem manuelt når jeg sidder med projektet, overfører relevante items til TODO.md, og **sletter dem fra dev-todos/ i takt med de bliver overført**. Det giver en "todos-inbox" der drænes løbende.
- **Backend endpoints:**
  - Modificér eller erstat eksisterende `POST /dev/screenshots` så den accepterer et `is_todo: bool`-felt og en `note`-felt. Routing baseres på flag.
  - Ny `GET /dev/todos` der lister TODO-items (jeg bruger den til at læse inbox).
  - Ny `DELETE /dev/todos/{id}` så jeg kan rydde op efter overførsel.
  - Den eksisterende `GET /dev/screenshots`-endpoint bevares som den er.

**Åbne spørgsmål til brainstorm når featuren tages op:**

- **Knappens placering på alle skærme:** Floating button (FAB) i hjørnet? I navigation-bar? Som en del af tab-bar? Skal placeringen være konsistent eller adaptiv per skærm?
- **Forholdet til chat-header-Kvante-avataren:** Skal det være den samme knap (ét globalt UI-element der altid sidder samme sted), eller to forskellige Kvante-tilstedeværelser (en stationær i header + en floating capture-knap)?
- **Annotation-implementation:** PencilKit er default-valget, men beslut om vi gemmer flat JPEG (simpelt, ikke-redigerbart) eller PKDrawing + base image (kan re-redigeres, dobbelt så meget data).
- **Skal observations (ikke-TODOs) også kunne annoteres?** Argument for: konsistent UI, brugeren behøver ikke vælge "is this TODO" først for at få annotation. Argument imod: simpelhed, observations er typisk mere "her er hvad jeg ser" end "her er præcis hvor problemet er".
- **Skal "skriv tekst" og "annotér" kunne kombineres med "ikke tag screenshot"?** Dvs. en pure "skriv en hurtig note til Claude" uden billede? Måske ja — det giver et lavfriktion alternativ til at åbne chat-flowet.
- **Tagning af kategorier på TODOs?** F.eks. "bug" / "feature" / "spørgsmål" — eller bare en flad inbox?
- **Hvad sker der hvis brugeren sletter det taggede item på iPad'en før jeg har overført det?** Brugerens iPad bør IKKE kunne slette serverside; det er kun jeg der dræner inbox'en.

**Forhold til pakke 1-5:** Helt orthogonalt. Hører ikke til den eksisterende køreplan. Kan tages som sin egen lille pakke når der er energi til det — sandsynligvis efter pakke 1 men før pakke 2, fordi det vil gøre QA af pakke 2 og frem markant nemmere.

---

## Kendte bugs

- [ ] **"via Vision" label på single-digit submissions** — OPHØJET PRIORITET efter live test 2026-04-08. Feature `16caa1f` routede *alle* multiplikations-submissions til backend Vision OCR, og `d2d1a98` hardcoded "via Vision"-label for samme. Men single-digit multiplikation skulle bruge Apple OCR (lokalt, gratis — et enkelt ciffer er trivielt). Routing skal baseres på operand-størrelse, ikke "er det multiplikation". Fix: tilføj `should_use_vision_ocr_for_submission(assignment_text)` der kun returnerer True når mindst én operand ≥ 10.
- [ ] **Feedback-tekst beskriver forkert metode for single-digit** — OPHØJET PRIORITET efter live test 2026-04-08. Feedback-generator siger "Du stillede 7 og 8 op og gangede dem ciffer for ciffer med delprodukter" for 7 × 8, hvilket er lang-multiplikations-metoden, ikke hvad eleven faktisk gjorde (huske fra tabellen eller tælle på fingre). Feedback-prompt skal kende forskel på single-digit og long multiplication.
- [ ] **OCR-præcision** — Claude Haiku læser nogle gange forkert (856 i stedet for 850). Undersøg prompt eller model-valg.
- [ ] **Swift 6 concurrency warnings** — `append` kaldt fra baggrundstråd på @MainActor property. Warnings nu, fejl i fremtiden.
- [ ] **Visuel/tekst-konsistens** — AI skriver "æbler" men appen tegner cirkler. Prompt instruerer nu "prikker" men kan stadig ske.
- [ ] **Opgaveforklaring på engelsk** — Explain-endpoint returnerer nogle gange engelsk tekst.
- [ ] **AnimationPlayer.recalculateCumulativeState glemmer cumulativeGridState** — Pre-existing bug opdaget under T9 code review 2026-04-08. `recalculateCumulativeState` nulstiller `cumulativeShortDivisionState`, `cumulativeLongMultiplicationState`, og (nu) `cumulativeArrayGridState`, men IKKE `cumulativeGridState`. Kan give stale stacked-arithmetic grid-state ved backward scroll. Ikke kritisk — genopretter sig ved næste `setup`-step.
- [ ] **Practice sessions har tom `name` på backend** — Opdaget under pakke 1 manuel QA 2026-04-08. `practice.create_practice_session` opretter Session-rows uden at sætte `name`-feltet, så home-skærmens "Seneste"-liste viser tomme titler for practice-sessions. Weekly sessions har derimod et name ("Ugematematik — uge X"). Fix: generér en titel ved oprettelse, fx `f"Øvelser — {topic} ({difficulty_label})"`.
- [ ] **`completed_count` altid 0 pga. status string-mismatch** — Opdaget under pakke 1 manuel QA 2026-04-08. `submissions.submit_work` sætter `assignment.status = "complete"` (line ~123), men `practice.get_session_history` tæller med `a.status == "completed"` (line 211). Strings matcher aldrig → completed_count er altid 0 selv for løste opgaver. Fix: vælg én kanonisk værdi (`"complete"` matcher mest) og opdater den anden side. Tjek også andre steder i kodebasen der læser eller skriver assignment.status.

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
