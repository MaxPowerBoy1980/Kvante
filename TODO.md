# Kvante TODO

## Aktive fejl

- [ ] **Timeout ved scan fra iPhone** — Bonjour finder server (gront ikon), men upload/scan request timer ud. Debug: tjek APIClient timeout, server-logs, og billedstorrelse
- [ ] **launchd plist paths** — `com.kvante.backend.plist` har hardcoded `/Users/oleserver/` — skal matche Mac Mini's faktiske bruger

## Oprydning

- [ ] Slet overfloedige Info.plist-hjaelpefiler fra `ios/Kvante/Kvante/`:
  - `add_infoplist.py`
  - `add_infoplist.sh`
  - `validate_infoplist.py`
  - `CHECKLIST_INFOPLIST.md`
  - `INFO_PLIST_SETUP.md`
  - `README_INFOPLIST.md`

## Konfiguration

- [ ] `.env` mangler paa serveren (kun `.env.example` findes) — opret med Gemini API key

## Grundlaeggende test (eksisterende kode)

- [ ] Test fuld workflow: scan side -> vaelg opgave -> vis eksempel -> scan svar -> feedback
- [ ] Billedpreprocessering: test med rigtige blyant-paa-papir fotos (CLAHE + sharpening)
- [ ] Prompt-iteration med rigtige tekstbogsider

---

## Phase 1: Core Chat UI & Tutor Personality

> Status: Brainstorm-doc eksisterer (`docs/design/2026-03-21-chat-first-redesign.md`), intet implementeret.
> Nuvaerende UI er tool-agtigt (scan -> pick -> work -> feedback). Skal laves om til chat-flow.

### Chat UI redesign (iOS)
- [ ] Redesign til ChatGPT/Claude-stil chat-view — renere bobler, bedre typografi, smoothere scroll
- [ ] Chat som grundstruktur: alt praesenteres som beskeder (Kvantes feedback, elevens scans, knapvalg)
- [ ] Knapper inline i chatten (ikke separat toolbar)
- [ ] Opgaveark som overlay/pull-up med status pr. opgave (lest/aktiv/mangler)
- [ ] Dark theme bevaret men mere poleret

### Tutor personality & redirection
- [ ] Tutor taler varmt og naturligt, ikke som en rigid chatbot
- [ ] Off-topic/upassende input redirectes blidt: "Jeg er her for at hjaelpe dig med matematik — lad os fokusere paa det."
- [ ] Altid opmuontrende, aldrig skammende
- [ ] Opdater system prompts i `backend/app/prompts/*.txt` med personality-retningslinjer

### Sprog
- [ ] Alle UI-labels, notifikationer, fejlbeskeder, gamification-tekst paa dansk
- [ ] Gemini-prompts skal eksplicit instruere modellen til at svare udelukkende paa dansk
- [ ] Audit af eksisterende prompts — tilfoej `Svar KUN paa dansk.` hvor det mangler

---

## Phase 2: Step-by-Step Explanation Engine (KRITISK)

> Status: ExampleView viser trin statisk (alle paa en gang). Ingen animationer, audio eller progressiv reveal.
> Dette er kernevaerdien — skal foeles som en rigtig laerer, ikke en chatbot.

### Paedagogisk forklaringsstruktur
- [ ] Altid foelg progressionen: konkret visuelt -> semi-konkret -> abstrakt/symbolsk
- [ ] Aldrig spring direkte til formlen
- [ ] Opdater `generate_example.txt` prompt til at kraeve denne progression

### Line-by-line text reveal (iOS)
- [ ] Hvert trin i forklaringen vises en linje ad gangen med kort delay
- [ ] Giv eleven tid til at absorbere hvert trin foer naeste vises

### Audio narration per trin
- [ ] Hver forklaringslinje laeser op paa dansk mens den vises
- [ ] Stemme skal foeles naturlig og opmuontrende, ikke robotagtig
- [ ] Afhaengighed: TTS-service (separat fra STT-spec'en — "Plapre designes separat" jf. STT-doc)

### Canvas/SwiftUI tegne-animationer
- [ ] For visuelle opgavetyper: animer selve tegningen som en laerer ved et whiteboard
- [ ] Addition/subtraktion: tegn og fjern objekter (aebler, cirkler), tallinjer
- [ ] Multiplikation: arrays (raekker og kolonner af prikker), skip-counting animation
- [ ] Division: grupper objekter i lige store grupper, array-model
- [ ] Broeker: cirkulaere lagkage-diagrammer, rektangulaere areal-modeller, bar-modeller
- [ ] Koordinatsystemer: animeret plotning af punkter paa et gitter

### LLM-struktureret animations-output
- [ ] Design JSON-schema for animationsinstruktioner (tekst, audio cue, tegne-instruktion pr. trin)
- [ ] Gemini skal returnere forklaringer i dette strukturerede format
- [ ] SwiftUI Canvas renderer baseret paa schema'et
- [ ] Dokumenter schema'et saa backend og iOS er synkroniserede

### Kardinalregel (eksisterer — verificer)
- [x] Tutor giver ALDRIG svaret direkte — kun eksempler, hints og guidede trin

---

## Phase 3: Assignment Submission & Review Flow

> Status: Submission + analysis + feedback pipeline virker. Mangler: usikkerhedsflag, retry-loop UI, succes-state, eskalering.

### Eksisterende (verificer virker)
- [x] Foto-submission af haandskrevet arbejde (`POST /submissions/`)
- [x] AI-analyse og feedback (`work_analyzer` + `feedback_generator`)
- [x] Retry-nummer trackes (`attempt_number` i Submission-model)

### Usikkerhedsflag
- [ ] Knap i iOS: "Jeg er ikke sikker paa, om du har forstaaet min opgave rigtigt — marker den"
- [ ] Flagger opgaven til foraeldre-/laerer-review uden at straffe eleven
- [ ] Backend: tilfoej `flagged_uncertain: bool` felt paa Submission-model

### Retry loop
- [ ] Hvis forkert: tutor tilbyder step-by-step animeret forklaring, derefter nyt forsoeg
- [ ] Eleven genindscanner og resubmitter
- [ ] iOS UI-flow for retry (WorkingView -> forklaring -> scan igen)

### Succes-state
- [ ] Groent bekraeftelses-screen naar korrekt
- [ ] Inkrementer flamme/streak-taeller
- [ ] Kort audio-beloenning paa dansk
- [ ] Backend: track streak per student (nyt felt paa Student eller separat tabel)

### Laerer-eskalering
- [ ] Knap: "Jeg forstaar det stadig ikke — bed min laerer om hjaelp"
- [ ] Vises i laerer-dashboard til asynkron review
- [ ] Backend: `flagged_for_teacher: bool` + `teacher_flag_reason` paa Submission
- [ ] Motiverende dead-end besked: "Det er helt okay. Jeg har oevet mig paa millioner af mateopgaver, og jeg ved, hvor svaert det kan vaere. Din laerer kigger paa det, og I finder ud af det sammen."

---

## Phase 4: Home Mode (Solo/Lektier)

> Status: HomeView har kun "Scan din side". Ingen "Oev dig"-mulighed eller lektie-flow.

### Home mode onboarding
- [ ] Naar app launcher uden classroom-session, vis to klare valg:
  - "Tag billede af din opgave" — snap foto af papir-lektie
  - "Oev dig" — gaa til oevelokaleet (Phase 7)

### Foto-baseret lektie-flow
- [ ] Snap lektie -> Gemini vision ekstrahererer opgaver -> vis som thumbnail-kort i bunden
- [ ] Eleven tapper et kort for at traekkke det op og starte arbejde med tutor-assistance
- [ ] Genbrug eksisterende page_parser men tilpas UI

### Thumbnail card UI
- [ ] Hvert ekstraheret problem vist som flydende kort i bunden
- [ ] Tappable/draggable
- [ ] Visuel status-indikator: ikke startet, i gang, faerdig

---

## Phase 5: Classroom Mode & Laerer-Dashboard

> Status: Intet eksisterer. Helt nyt system.

### Laerer web-dashboard
- [ ] Web-baseret dashboard (separat fra iOS-app)
- [ ] Teknologi-valg: FastAPI + HTML/JS? Separat React/Next.js? (afklar foer implementation)
- [ ] Laerere kan administrere sessioner, generere opgaver, overvage elever

### Session creation
- [ ] Laerer klikker "Start ny session" -> genererer QR-kode og numerisk pin
- [ ] Begge vises paa skaerm til projektion i klasselokalet
- [ ] Backend: `ClassroomSession` model med `pin_code`, `qr_data`, `status`

### Elev join-flow (iOS)
- [ ] "Deltag i klasse" knap paa HomeView
- [ ] Scan QR-kode eller tast pin
- [ ] Instant parring til laererens live session
- [ ] Backend: `POST /classroom/join` endpoint

### On-the-fly opgavegenerering
- [ ] Laerer vaelger emne (multiplikation, division, koordinatsystem, broeeker, etc.)
- [ ] Vaelger svaerhedsgrad og antal
- [ ] Klikker generer -> opgaver pushes digitalt til alle tilsluttede elever
- [ ] Ingen foto-scanning noedvendig — systemet har ground truth for alle svar

### Kurateret opgave-mode
- [ ] Laerer kan bygge og tilpasse opgaver manuelt foer en session
- [ ] Gem og deploy naar klar

### Digitale opgaver = ground truth
- [ ] Systemet genererer problemerne -> kender korrekte svar
- [ ] Eliminerer tvetydighed fra foto-scanning
- [ ] Muliggoer mere praecis, paalidelig feedback

---

## Phase 6: Laerer Analytics Dashboard

> Status: Intet eksisterer. Afhaenger af Phase 5.

### Elev-fremskridtsoversigt
- [ ] Grid/listview af alle elever i en klasse
- [ ] Farvekodning per opgavetype: groen (mestret), gul (kaemper), roed (ikke faerdig/konsekvent forkert)

### Filtrering
- [ ] Filtrer grid efter emne — "hvem kaemper med division lige nu?"

### Oevelsesregistrering
- [ ] Se hvilke elever der har gennemfoert daglig oevetrae, med ugentlig konsistens-data
- [ ] Laerer kan opmuontre elever der ikke oever

### Flaggede opgaver
- [ ] Se alle opgaver flagget af elever for hjaelp
- [ ] Adresser dem naar muligt

---

## Phase 7: Daglig Oevelses-Mode (Duolingo for Matematik)

> Status: Intet eksisterer. Ny major feature.

### Oevelokale
- [ ] Separat rum tilgaengeligt fra homescreen
- [ ] Dedikeret plads til daglig fakta-traening, adskilt fra opgaveloesning

### Daglige oevesessioner
- [ ] Default maal: ti minutter om dagen
- [ ] Push notification dagligt: "Tid til din daglige matematiktraening!"

### Audio ping-pong (tabeller)
- [ ] App taler et tal fra sekvensen hoejt paa dansk
- [ ] Elev svarer mundtligt
- [ ] Speech recognition bekraefter korrekt svar og fortsaetter sekvensen
- [ ] Rytmisk, frem-og-tilbage, som at oeve med en foraelder paa en gaa-tur
- [ ] Afhaengighed: STT-service (spec eksisterer i `docs/superpowers/specs/2026-03-21-stt-integration-design.md`)

### Spaced repetition engine
- [ ] Track hvilke fakta eleven kaemper med
- [ ] Prioriter dem i fremtidige sessioner
- [ ] Mindre tid paa mestrede fakta, mere paa svage

### Progressiv tabel-unlockling
- [ ] Eleven mestrer 2-tabellen foer 3-tabellen unlockes, osv.
- [ ] Klar folelse af progression og praesstation

### Quick-fire visuel mode
- [ ] Hurtigere spoergsmaal med korte tidsgraenser (3-5 sekunder)
- [ ] Bygger automatisering
- [ ] Kan bruges sammen med eller som alternativ til audio-mode

### Streak og gamification
- [ ] Daglig streak-taeller (flamme-ikon)
- [ ] Fejrings-animationer ved gennemfoerelse
- [ ] Opmuontrende danske audio cues ("Godt klaret!" / "Fantastisk!")

### Ingen straf for forkerte svar
- [ ] Lav-tryk miljoe
- [ ] Forkert svar gentager bare spoergsmaalet eller viser det korrekte og gaar videre
- [ ] Opbygger selvtillid, ikke dom

### Laerer-synlighed
- [ ] Laerer-dashboard viser ugentlig oevelses-gennemfoerelse pr. elev
- [ ] Muliggoer ansvarlighed uden at vaere straffende

---

## Tekniske noter (tvaergaaende)

- [ ] **Animation output schema**: Design og implementer struktureret JSON-schema som Gemini returnerer med forklaringer — specificerer hvad der skal tegnes, i hvilken raekkefoelge, med hvilke labels
- [ ] **TTS-service**: Design separat fra STT (som allerede har spec). Dansk tale-syntese til forklaringer og oevelses-mode
- [ ] **STT-service**: Implementer godkendt spec (`docs/superpowers/specs/2026-03-21-stt-integration-design.md`) — Whisper + AI action matching
- [ ] **Alle Gemini-prompts**: Specificer dansk output eksplicit
- [ ] **Spaced repetition data-model**: Student-specifik fakta-tracking tabel i SQLite
- [ ] **Classroom session data-model**: Nye tabeller for ClassroomSession, StudentEnrollment, GeneratedAssignment
- [ ] **Web dashboard teknologi**: Afklar stack (FastAPI templates vs. separat frontend)
- [ ] **Push notifications**: APNs integration for daglige oevelses-reminders

---

## Loste problemer

- [x] Bonjour mDNS browse virkede ikke — fix: AsyncZeroconf + bind til LAN-IP (ikke alle interfaces inkl. Tailscale)
- [x] Xcode projekt opsat med korrekt mappestruktur
- [x] Kamera-tilladelse tilfojet i Info.plist
- [x] Bonjour service discovery virker fra iPhone
- [x] `%en0` interface-suffix fjernet fra resolved URL
