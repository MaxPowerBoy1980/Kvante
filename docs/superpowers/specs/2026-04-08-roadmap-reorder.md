# Roadmap reorder — efter pakke 1 (2026-04-08)

Dette dokument låser den nye prioriterede rækkefølge for alt arbejde efter at pakke 1 (session persistence) blev merget til main 2026-04-08. Det erstatter "Næste features"-sektionen i TODO.md og skal afspejles i `~/.claude/projects/-Users-olsen-code-Kvante/memory/project_next_features.md`.

## Baggrund

Pakke 1 er gennemført og merget. Den eksisterende køreplan havde pakke 2→3→4→5 som lineær sekvens, dev-tooling i backlog, og en række mindre items (AI fejlanalyse, SF Symbols brainstorm, difficulty-ikoner, long mult polish, single-digit bugs + tabel-bevidsthed) spredt mellem backlog, bugs-sektion og åbne brainstorms. En dependency-brainstorm 2026-04-08 identificerede skjulte koblinger og muligheder for bundling. Brugerens kontekst: ingen aktive brugere endnu (Lyng tester ikke appen regelmæssigt), så bugs er ikke urgent. Dev-tooling prioriteres hurtigt for at multiplicere brugerens eget optimerings-loop. Pakke 2 splittes for at reducere risiko og accelerere feedback-loop.

## Succeskriterier

- Dev-tooling shipper før pakke 2 starter, så PencilKit-annoterede screenshots er tilgængelige gennem hele UI-arbejdet
- Pakke 2 er delt i en navigations-refactor (2a) og en data+animation-pakke (2b) så hver del kan leveres uafhængigt
- SF Symbols-beslutninger er truffet før pakke 2b bygger visuelle komponenter
- Pakke 5 (bog-arkivet) shipper før pakke 4 (bulk-scan) fordi den er helt dependency-fri og lavere-risiko
- AI fejlanalyse er foldet ind i pakke 4's spec (ikke en separat pakke) så bulk-scan leveres som hel feature
- Single-digit bugs og tabel-bevidsthed bundles til ét pass gennem single-digit-koden
- Long mult sequential narration og completed state bundles til ét pass gennem long mult-koden

## Prioriteret køreplan

### 1. Dev-tooling — Global Kvante-capture-knap

Erstatter den nuværende kamera-ikon + shake-to-submit-flow med en globalt tilgængelig Kvante-avatar-knap der åbner en capture-menu: tag screenshot, annotér med Apple Pencil (PencilKit), skriv tekst-note, "marker som TODO"-toggle. Ikke-TODO gemmes i eksisterende `~/Library/Application Support/Kvante/dev-screenshots/`. TODO-tagged gemmes i ny `~/Library/Application Support/Kvante/dev-todos/` med metadata-felt til tekst-note. Nye endpoints: modificer `POST /dev/screenshots` til at acceptere `is_todo` og `note`, tilføj `GET /dev/todos` og `DELETE /dev/todos/{id}` så brugeren manuelt kan dræne inbox'en efter overførsel til TODO.md.

**Why:** Den nuværende shake-to-submit er funktionel men begrænset — ingen annotation (stort tab når brugeren vil pege på præcis det område der er problemet), og den blander observation med faktiske TODO-items. PencilKit-annotation fjerner friktion ved bug-rapportering. TODO-toggle holder TODO.md ren. Dev-tooling multiplier på alle pakke 2-5 fordi QA-flow bliver markant bedre.

**How to apply:** Kræver sin egen brainstorm før spec. Åbne spørgsmål der skal besluttes: knappens placering (FAB i hjørnet? floating over alle skærme? i nav-bar?), forhold til chat-header-Kvante-avataren (samme knap eller to tilstedeværelser?), PencilKit-data-model (flat JPEG vs. `PKDrawing` + base image — ikke-redigerbart eller re-redigerbart?), om observations også skal kunne annoteres, om "skriv note uden screenshot" skal være muligt, kategorier på TODOs (bug/feature/spørgsmål) eller flad inbox.

### 2. Pakke 2a — Ark-overlay (navigations-refactor)

Slide-down ark-overlay (60-70% af skærmen fra toppen) mellem Home og Chat. Efter "Start opgaver" lander eleven på arket, ikke direkte i chat. Arket viser alle ugens opgaver med fuldt regnestykke + status-markør (orange=ikke løst, grøn=løst, aktuel-pil). Tap på en opgave → sheet lukker og chat skifter til den opgave. "< Tilbage" i chat går til ark, ikke home. Session-headerens "0 løst ˅"-dropdown erstattes med "Mit ark"-knap der gen-åbner overlayet. Fri rækkefølge — eleven kan starte med vilkårlig opgave.

**Why:** UX-review afslørede at den nuværende progres-dropdown er for minimal. Eleven kan kun se hvilken opgave der er aktuel — ikke hvad der er løst vs. ikke startet. Og intet overblik over hele ugen. Brugerens ord: "det skal føles som papiret eller siden i matematikbogen". Split fra den oprindelige pakke 2 isolerer navigations-refactor fra animation+data-lag, så hver del kan leveres uafhængigt og feedback-loopet er hurtigere.

**How to apply:** Ny `AssignmentSheetView` der slider ned fra toppen. Papir-tekstur baggrund (varm off-white, let kornet). Home-skærmens "Start opgaver"-knap lander på ark-overlay i stedet for direkte i chat. Chat-headerens "< Tilbage" går nu til arket. Ingen nye animationer, ingen nye backend-lag — ren navigations-refactor. 2a kan introducere en shared `@Observable` session-model til at holde navigations-state mellem ark og chat (hvilken opgave er aktuel, status pr. opgave fra eksisterende API) — pakke 2b udvider så denne model med cirkel-progres og streak-data.

### 3. SF Symbols brainstorm

Lille standalone brainstorm der træffer visuel-DNA-beslutningen for pakke 2b og pakke 3: skal cirkel-progres-prikker, lyn-zigzag, streak-flamme og utility-ikoner bygges med SF Symbols (Apples systembibliotek) eller custom illustration. Output: én-sides beslutningsdokument per ikon-type.

**Why:** SF Symbols er hurtigere at bygge, konsekvente, Dynamic Type-venlige og animerbare fra iOS 17+, men kan føles generiske og miste Kvante-plushens specifikke personlighed. Custom giver maksimal karakter men kræver illustrator-arbejde. Beslutningen skal træffes før pakke 2b bygger komponenter — ikke midt i implementationen.

**How to apply:** Kan køre parallelt med 2a hvis der er energi. Sandsynligt resultat: en blanding — SF Symbols for streak-flammen og utility-ikoner, custom for lyn-zigzaggen og Kvante-brystpanelet. Beslut per ikon, ikke en fælles regel.

### 4. Pakke 2b — Cirkel-progres + streak-backend + celebration

Cirkel-progres-komponenten baseret på Kvantes plush-bryst-panel (6 blå prikker + 1 orange midt). Prikker går fra blå outline til orange fyldt som opgaverne løses. Ved korrekt svar: én prik fyldes op med scale pulse (1.0 → 1.3 → 1.0 over 400ms), haptik (soft-medium impact), kort lyd-cue, og koral lyn-zigzag flashes hen over panelet. Lyn bliver Kvantes celebration-signatur — flueben forbliver kun i teknisk scan-feedback ("Læste: 735 ✓"). Streak-backend: ny tabel eller felt der tracker "sidste dag med mindst 1 løst opgave". Streak = antal på hinanden følgende dage med mindst én løst opgave. Pr. opgave, ikke pr. tid. Returnér streak i submission-response.

**Why:** Progres-følelse kræver konkret visualisering, ikke bare tal. Streak-model pr. opgave er verificerbar, paper-first-venlig og tilgivende (eleven taber ikke streak fordi hun er langsom). Komponenten bygges her men monteres først i pakke 3's home — split fra 2a betyder at denne del kan iterere selvstændigt uden at låse navigations-refactor'en.

**How to apply:** Udvid 2a's `@Observable` session-model med cirkel-progres-state og streak-data. Streak-tabel: `UserStreak { last_active_date, current_streak }`. Ved hver korrekt submission: hvis `last_active_date == yesterday` → inkrementer. Hvis `== today` → ingen ændring. Ellers → reset til 1. Komponenten skal være klar til at blive monteret i pakke 3's home uden yderligere arbejde.

### 5. Pakke 3 — Home redesign + "i dag"-helten + bonus-mode + difficulty-ikoner

Ny home med stor dynamisk "i dag"-boks øverst der viser Kvante i tre tilstande: `no_progress_today` / `in_progress` / `week_complete`. Streak-flamme øverst til højre. De to eksisterende kort (Ugematematik / Øvelser) skubbes ned og bliver mindre. Bog-knap nederst. Seneste-listen fjernes helt. Kvantes udtryk skifter mellem neutral / lidt smil / store øjne baseret på status. **Difficulty-ikoner-redesign foldet ind:** de nuværende plante-ikoner (frø → spire → træ → trofæ) på Øvelser-sværhedsskærmen udskiftes som del af pakke 3's visuelle sprog, ikke som separat item.

**Why:** Den nuværende home-skærm er den æstetisk svageste skærm i appen. Home er gatekeeper — hvis eleven ikke åbner appen, sker intet andet. Difficulty-ikonerne hører til home's visuelle sprog og skal besluttes sammen med resten af home's ikonografi, ikke isoleret.

**How to apply:** `HomeView` med tre-tilstands "i dag"-boks. Kvante-figur i venstre side, tekst + CTA i højre. Tilstand A (intet i dag): "Hej, [navn]! Uge [N] venter — [X] opgaver klar" + tomt bryst-panel + "Start i dag"-knap. Tilstand B (i gang): "Godt i gang, [navn]! Du er halvvejs — [N] opgaver tilbage" + delvist fyldt bryst-panel + "Fortsæt"-knap. Tilstand C (færdig): "Du gjorde det, [navn]! Uge [N] er i hus" + alle prikker fyldt + lyn-zigzag + to knapper: "Ekstra øvelser" + "Hvil". Streak-badge: lille flamme + antal dage øverst til højre. Difficulty-ikoner: SF Symbols (fx `1.circle` → `4.circle`, eller `star` → `sparkles`) eller Kvante-udtryks-baserede — beslut som del af pakke 3's visuelle design. **Bog-knappens plads reserveres i pakke 3's layout, men selve knappen tilføjes først som del af pakke 5** når bog-arkivet er bygget og har et reelt destination-view — undgår "død knap"-tilstand mellem pakke 3 og 5.

### 6. Pakke 5 — Bog-arkivet ("Din matematikbog")

**Flyttet op fra oprindelig plads 5 til plads 6** (efter pakke 3, før pakke 4). Helt fri af dependencies nu pakke 1 er done. Seneste-sektionen erstattes af et side-for-side hæfte. Hver session = én side med opgavetekst, kondenseret AI-gennemgang, elevens scannede papir-foto som hovedelement, dato-stempel, flueben. Grupperet pr. uge med små uge-skille-sider. Kvante på omslaget holdende en blyant. Swipe venstre/højre for at bladre. Tilgængelig via dedikeret "Din matematikbog"-knap fra pakke 3.

**Why:** Bog-arkivet er stoltheds-arkivet — det er der eleven vender tilbage for at huske hun KAN det her. Brugerens eksplicitte ønske: "det skal være muligt at komme videre og se hele sin opgave, som hvis man havde løst det i en bog". Flyttet op foran pakke 4 fordi den er lavere-risiko (read-only view, ingen nye backend-koncepter, ingen nye AI-flows) og giver en stor synlig feature efter to UI-tunge pakker — god "pause" før pakke 4's AI-kompleksitet.

**How to apply:** Ny `NotebookView`. Swipe venstre/højre. Hver side: opgavetekst (øverst), kondenseret AI-gennemgang (ikke hele chat-historikken — for meget tekst), scannet papir-foto (stort, centralt, croppet til kun-papir-region), dato-stempel, flueben. Uge-skille-sider med Kvante-vignet. Omslag med Kvante + blyant + elevens navn + bog-tekstur. Åbnes via "Din matematikbog"-knap på home. Lander på seneste side først. Kondensering af AI-gennemgang: beslut i pakken — måske opgavetekst + correct answer + scannet foto + én linje feedback. Backend: intet nyt arbejde (al data er der allerede fra pakke 1).

### 7. Pakke 4 — Bulk-scan hele arket + AI fejlanalyse

Nyt endpoint `POST /sessions/{id}/bulk-submit` med billede af hele A4-arket. Gemini Vision udtrækker alle regnestykker + elevens svar, matcher mod sessionens opgaver baseret på tallene (ikke position), validerer hvert svar. Returnerer batch-status. iOS: "Scan hele arket"-knap i bunden af ark-overlay. Loading-state med bobende Kvante-antenne. Ark-overlay opdateres batch-wise. Samlet feedback-kort i chatten. Tap på rød opgave → detaljeret fejlanalyse i chatten. **AI fejlanalyse foldet ind:** pakke 4's spec skal eksplicit dække fejlanalyse-flowet ved tap på rød opgave — ikke svag "prøv igen"-feedback.

**Why:** Eleven løser nogle gange hele sit opgaveark selvstændigt uden at have brug for step-by-step hjælp. At scanne opgave for opgave er friktion. Bulk-scan løser det. AI fejlanalyse er ikke en separat feature — det er pakke 4's feedback-del. Uden fejlanalyse er bulk-scan halvt leveret: eleven ser "rød opgave" men får ingen reel pædagogisk hjælp.

**How to apply:** Backend-prompt til Gemini Vision: "Dette er et ark med håndskrevne regnestykker. For hvert regnestykke, udtræk venstre side (opgaven) og højre side (elevens svar). Returnér JSON. Ignorér arbejds-linjer, kun færdige regnestykker med svar." For hver match: validér `right` mod korrekte løsning. Ved forkert svar: analysér fejltypen (deterministisk for aritmetik — sammenlign cifre — eller AI-drevet for mere komplekse fejl). iOS: batch-update af ark-overlay (✓ grøn / ✗ rød / ? gul). Samlet feedback-kort. Tap på rød → detaljeret fejlanalyse som chat-besked. Udfordringer der skal tages stilling til i spec: long multiplication over flere linjer, Vision der læser tal forkert (reparations-flow), delvise ark, bulk-scan to gange (anden gang overskriver matches), kruseduller på arket.

### 8. Single-digit polish-bundle

Samlet pass gennem single-digit multiplikations-koden:
- Fix Vision OCR routing: tilføj `should_use_vision_ocr_for_submission(assignment_text) -> bool` der kun returnerer True når mindst én operand ≥ 10 (samme regel som `should_use_long_multiplication`). Rutning i `ChatViewModel.scanAnswer` tjekker denne. "via Vision"-label vises baseret på hvilken path der faktisk blev brugt, ikke hardcoded.
- Fix feedback-tekst: feedback-prompt skal kende forskel på single-digit og long multiplication. "Du kendte 7 × 8 fra 8-tabellen — 56, helt rigtigt" i stedet for "du gangede ciffer for ciffer med delprodukter".
- Tabel-bevidsthed retning A: efter reveal-boblen vises én ekstra boble med "Det her er 8-tabellen: 8, 16, 24, 32, 40, 48, 56 ✨" med målrækken highlighted. Min-invasiv — ingen nye visual-types, bare en ekstra tekst-boble med formateret span. Brug `b`-operanden som tabel-base hvis `a < b` ellers `a`.

**Why:** Alle tre items rører single-digit-koden. Bundling undgår at røre koden tre gange. Bugs er ikke urgent (ingen aktive brugere) men de bør ordnes før pakke 4's bulk-scan-flow rammer single-digit-submissions.

**How to apply:** Fixer først bugs (små, isolerede), derefter tabel-bevidsthed (kræver mini-brainstorm om hvornår tabellen-boblen skal vises og hvordan formateret span ser ud).

### 9. Long mult polish-bundle

Samlet pass gennem long mult-koden:
- **Sequential narration-animation:** Den shipped narration er korrekt men står som én lang tekstblok over grid'et. For 3-cifret multiplicand er det 3 sætninger + sum — kognitiv overload. Brainstorm først (retning B: animér narrationen sætning for sætning i samme boble, eller retning D: fjern tekst-blok helt, lad grid + audio bære forklaringen). Start med brainstorm af hvad "ro og klarhed" betyder for en 9-13-årig.
- **Completed LongMultiplicationState efter submission:** static factory `LongMultiplicationState.completed(a:b:)` der bygger state med alle partials og sum fyldt ud. Opdater `ChatViewModel.scanAnswer`'s multiplikations-success branch til at bruge en `exampleStep` message med completed state i stedet for ren tekst.

**Why:** Begge er polish på long mult-featuren fra 2026-04-07. Bundling undgår at røre koden to gange. Completed state bringer multiplication-submissions op på parity med addition/subtraction.

**How to apply:** Brainstorm sequential narration først (egen brainstorm-session). Completed state er deterministisk og kan implementeres lige efter.

### 10. Tabel-øvelser (ny feature)

Separat øvelsesmode hvor eleven træner gangetabellerne systematisk som selvstændig aktivitet, ikke som del af opgave-løsning.

**Why:** Brugeren nævnte eksplicit tabel-øvelser som en ønsket feature. Den nuværende app er struktureret omkring opgave-løsning. Der er ingen mekanisme for ren drill. Tabel-memorisering er det pædagogiske fundament under al multiplikation.

**How to apply:** Kræver sin egen brainstorm. Åbne spørgsmål: mode (quick-fire / audio ping-pong / visuel array-genkendelse / kombination), adaptivitet (spaced repetition vs. fast rækkefølge), scoring (streaks / bedste tid / ingen), placering i UI (ny knap på home, del af session-flow, egen nav-destination).

### 11. Lang division visual

Bracket-layout med divide/subtract/bring-down cyklus. Deterministisk service som long-mult.

**Why:** Sidste "core math method" der mangler visual. Efter tabel-øvelser har appen hele det pædagogiske fundament.

**How to apply:** Kræver sin egen brainstorm + spec. Følg long-mult-patternet: `LongDivisionService` med `compute_steps` + `pick_example_numbers` + `generate_text`, ny `LongDivisionView` med bracket + subtraction-rækker + bring-down animation.

## Items der IKKE er med i denne køreplan

Forbliver i backlog som de er:
- Classroom Mode & Lærer-Dashboard (fremtidig fase)
- Daglig Øvelses-Mode Duolingo-stil (overlapper med tabel-øvelser — revurder når tabel-øvelser-brainstorm kører; måske fusioneres)
- Teknisk gæld (Info.plist-oprydning, Swift 6 concurrency warnings, TTS-service, thinking tokens i Gemini)
- Kendte bugs der ikke er ophøjede: OCR-præcision (Claude Haiku læser 856 som 850), opgaveforklaring på engelsk, visuel/tekst-konsistens (æbler vs. cirkler), `AnimationPlayer.recalculateCumulativeState` glemmer `cumulativeGridState`, tomme practice session-titler, `completed_count` altid 0 pga. status string-mismatch

## Ændringer fra nuværende TODO.md

| Item | Før | Efter |
|---|---|---|
| Dev-tooling | Backlog, "kan tages efter pakke 1" | #1 prioritet |
| Pakke 2 | Monolit | Split 2a + 2b med SF Symbols imellem |
| Pakke 5 | Plads 5 | Plads 6 (flyttet op foran pakke 4) |
| SF Symbols brainstorm | Åben backlog-note | Konkret step mellem 2a og 2b |
| AI fejlanalyse | Backlog | Foldet ind i pakke 4 |
| Difficulty-ikoner | Backlog | Foldet ind i pakke 3 |
| Bugs + tabel-bevidsthed | Bugs-sektion + backlog | Bundlet som single-digit polish (#8) |
| Long mult narration + completed state | Backlog | Bundlet som long mult polish (#9) |

## Næste skridt efter denne spec

Brugeren reviewer specen. Ved godkendelse:
1. Opdater `TODO.md` så "Næste features"-sektionen afspejler denne nye rækkefølge
2. Opdater `~/.claude/projects/-Users-olsen-code-Kvante/memory/project_next_features.md` så memory matcher
3. Start brainstorm på item #1 (Dev-tooling global Kvante-capture-knap) i en separat session
