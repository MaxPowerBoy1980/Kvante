# Pakke 4 — Bulk-scan hele arket + AI fejlanalyse

## Koncept

Eleven løser opgaver på papir uden hjælp og scanner hele arket med ét eller flere fotos via VisionKit document scanner. Claude Vision matcher automatisk håndskrevne svar til sessionens opgaver, validerer hvert svar, og analyserer fejltyper — alt i ét AI-kald. Arket opdateres med ✓/✗/❓, og chatten får et samlet feedback-kort. Forkerte opgaver kan udforskes via bottom sheet (overblik) → chat (dybde). Ulæselige opgaver får et re-scan flow med pædagogisk nudge om pæn orden.

Bulk-scan **supplerer** det eksisterende step-by-step flow. Eleven kan stadig løse opgaver én ad gangen med hjælp fra chatten. Bulk-scan er til eleven der løser hele arket selvstændigt og bare vil have tjekket sine svar.

## Kardinalregel

Kvante afslører **aldrig** det korrekte svar — heller ikke i bulk-scan. Arket viser kun elevens eget svar + fejltype. Hjælp sker via gennemregnede eksempler med andre tal.

---

## User Flow

### 1. Start bulk-scan

**Indgang:** "Scan hele arket"-knap på ark-skærmen (AssignmentSheetView). Knappen er synlig når sessionen har opgaver der ikke er `complete`.

**Kamera:** VisionKit `VNDocumentCameraViewController` i multi-page mode. Eleven scanner 1+ sider. Auto-crop og perspektivkorrektion er built-in. Alle sider returneres som `[UIImage]`.

**Billedkomprimering:** Hver side nedskaleres til max 2048px på længste side (`CGImage`-baseret downsampling) og JPEG-encodes med quality 0.8. Holder hvert billede under ~1 MB og sikrer god OCR-kvalitet.

### 2. Loading

KvanteFace i headeren skifter til tænker-udtryk (store øjne). Bryst-panel-prikkerne pulserer. Tekst under arket: "Kvante læser dit ark...".

Alle sider sendes til backend i ét kald. Backend sender billederne + sessionens opgaveliste til Claude Vision.

**Timeout:** Hvis backend ikke svarer inden 45 sekunder, viser iOS: "Det tager lidt længere end forventet..." med en "Annullér"-knap. Netværkstimeout sat til 60 sekunder på `URLSession`-kaldet. Backend-side: AI-kaldet har 45s timeout; ved timeout returneres HTTP 504 med fejlbesked.

### 3. AI-analyse (ét kald)

Claude Vision modtager:
- Alle scannede sider som billeder
- Sessionens opgaveliste (opgavenummer, opgavetekst, korrekt svar)

Claude returnerer per-opgave:
- `assignment_index`: hvilket opgave-index der matches (via opgavenummer, regnestykke, tallene)
- `student_answer`: hvad eleven skrev
- `error_type`: fejlkategori hvis forkert (procedural, understanding, careless) — samme som eksisterende `analyze_work.txt`
- `error_description`: kort dansk beskrivelse af fejlen ("Mente-fejl i tieren", "Forkert tabel-produkt")
- `confidence`: 0.0–1.0 for læsbarhed
- `page_index`: hvilken side svaret blev fundet på

AI'en returnerer **ikke** `is_correct` — backend validerer deterministisk med `compare_answer()`. AI'en fokuserer på matching, læsning og fejlklassificering.

Opgaver der ikke matches (eleven sprang over) forbliver `not_started`.

### 4. Backend-validering

Backend modtager Claude's JSON-response og:

1. **Validerer matches** — hvert `assignment_index` skal pege på et gyldigt assignment i sessionen. Duplikerede matches afvises (to svar til samme opgave → tag den med højest confidence).
2. **Skipper allerede-complete opgaver** — matches til opgaver med status `complete` ignoreres. Eleven har allerede fået feedback via step-by-step flowet. AI'en ser hele opgavelisten (for bedre matching-kontekst), men backend filtrerer.
3. **Validerer svar deterministisk** — `compare_answer()` bruges som ground truth. AI'ens fejltype og fejlbeskrivelse beholdes uanset.
4. **Confidence-tærskel** — under `settings.confidence_threshold` (0.6) markeres opgaven som `uncertain` i stedet for rigtigt/forkert.
5. **Opretter Submissions** — én `Submission` per matchet opgave med `analysis`-dict. `page_index` persisteres i `analysis` så iOS kan vise det rigtige scan-billede i bottom sheet. Scan-billedet gemmes som `Scan`-record (1 per side).
6. **Opdaterer Assignment-status** — `complete` (korrekt), `in_progress` (forkert), uændret (usikker/ikke-matchet).
7. **Streak-opdatering** — `update_streak()` kaldes for hver korrekt opgave.

### 5. Resultat — Arket

Arket opdateres med tre-status visning per opgave:

| Status | Farve | Ikon | Detalje |
|--------|-------|------|---------|
| Korrekt | Grøn baggrund, grøn venstre-kant | ✓ | Opgavetekst + elevens svar |
| Forkert | Orange baggrund, orange venstre-kant | ✗ | Opgavetekst + elevens svar + fejltype |
| Usikker | Blå baggrund, blå venstre-kant | ❓ | Opgavetekst + "Kan ikke læse" |
| Ikke matchet | Uændret (cream) | — | Som før |

Nederst: samlet feedback-kort med score ("4 af 6 rigtige!") og "Tap på en opgave for at se mere".

### 6. Resultat — Chatten

Et samlet feedback-kort indsættes i chatten:
- Oversigt over alle resultater (✓/✗/❓ per opgave)
- Kort fejltype per forkert opgave
- Opfordring til at tappe for hjælp

Feedback-kortet gemmes som `ChatMessage` med `content_type: "bulk_scan_result"`.

**Timing:** Feedback-kortet indsættes i chatten **efter** arket er opdateret. Arket er den primære feedback — eleven ser ✓/✗/❓ først. Chat-kortet er sekundært og dukker op når eleven navigerer til chatten.

---

## Fejlanalyse-flow (tap forkert opgave)

### Lag 1 — Bottom sheet

Når eleven tapper en forkert opgave (✗) på arket:

1. Bottom sheet slider op med:
   - **Scannet billede** af elevens ark (fra Scan-record, valgt via `page_index` i submission's `analysis`-dict — viser den side hvor svaret blev fundet)
   - **Hvad Kvante læste**: "Du skrev: 613"
   - **Fejlforklaring**: "Mente-fejl i hundrederne" (fra AI-analysen)
   - **"Få hjælp i chatten"**-knap

### Lag 2 — Chat

Knappen navigerer til chatten med fokus på den specifikke opgave. Kvante sender:
- En besked der forklarer fejltypen
- Et gennemregnet eksempel med **andre tal** (kardinalreglen)
- Strukturerede opfølgningsknapper (som eksisterende feedback-flow)

Denne besked genereres on-demand via eksisterende `FeedbackGeneratorService` med submission'ens `analysis`-dict som input.

---

## Ulæselige svar — Re-scan flow (tap ❓-opgave)

Når eleven tapper en usikker opgave (❓) på arket:

### Bottom sheet

1. **Besked**: "Kvante kan ikke læse dit svar til opgave [N]"
2. **Mulighed A**: "Scan igen" → åbner VisionKit kamera. Fokus-guide overlay viser hvilken opgave der scannes. Kun den ene opgave sendes til backend som single submission (eksisterende `POST /submissions/`).
3. **Mulighed B**: "Skriv svaret" → tekstfelt hvor eleven taster svaret ind. Sendes som `answer_text` til eksisterende `POST /submissions/`.
4. **Pædagogisk nudge** (vis kun første gang per session): Tip-boks med ordenstips:
   - "Skriv tydeligt med sort eller blå pen"
   - "Brug linjer eller tern-papir"
   - "Giv god plads mellem opgaverne"
   - "Skriv opgavenummeret ved hvert svar"

   Gemt via `UserDefaults`-flag `hasSeenOrderTips_<sessionId>`. Undgår at gentage tips ved hver ❓-opgave i samme session.

Resultatet opdaterer arket (❓ → ✓ eller ✗) og chatten.

---

## Backend API

### `POST /sessions/{session_id}/bulk-submit`

**Request:** multipart/form-data
- `images`: 1+ billedfiler (JPEG fra VisionKit)

**Response:** `BulkSubmitResponse`

```json
{
  "session_id": "...",
  "results": [
    {
      "assignment_id": "...",
      "assignment_text": "34 + 67",
      "student_answer": "101",
      "status": "correct",
      "error_type": null,
      "error_description": null,
      "confidence": 0.95,
      "submission_id": "..."
    },
    {
      "assignment_id": "...",
      "assignment_text": "245 + 378",
      "student_answer": "613",
      "status": "incorrect",
      "error_type": "procedural",
      "error_description": "Mente-fejl i hundrederne",
      "confidence": 0.88,
      "submission_id": "..."
    },
    {
      "assignment_id": "...",
      "assignment_text": "453 − 187",
      "student_answer": null,
      "status": "uncertain",
      "error_type": null,
      "error_description": null,
      "confidence": 0.3,
      "submission_id": "..."
    }
  ],
  "summary": {
    "total": 6,
    "correct": 3,
    "incorrect": 2,
    "uncertain": 1,
    "not_found": 0
  },
  "scan_ids": ["...", "..."]
}
```

**Status-værdier:** `correct`, `incorrect`, `uncertain`, `not_found` (opgave ikke fundet i scan).

### AI Vision Prompt

Ny prompt-fil: `prompts/bulk_scan.txt`

```
Du er Kvante, en matematikhjælper. Du modtager foto(s) af en elevs håndskrevne svar
på et matematikark, samt en liste over opgaverne eleven skulle løse.

Din opgave:
1. Find hvert håndskrevet svar i billedet/billederne
2. Match hvert svar til den rigtige opgave via opgavenummer, regnestykke, eller tallene
3. Læs elevens svar omhyggeligt — læs hvad der FAKTISK ER SKREVET, beregn IKKE selv
4. Sammenlign med det korrekte svar og klassificér fejltypen hvis forkert. Beskriv fejlen kort på dansk
5. Vurdér din confidence (0.0–1.0) for hvert svar baseret på læsbarhed

Fejltyper:
- "procedural": Rigtig metode, fejl i udførelsen (mente-fejl, forskydningsfejl, ciferfejl)
- "understanding": Forkert metode (brugte subtraktion i stedet for addition)
- "careless": Eleven kan metoden, lille slip (skrev 3 i stedet for 8)

KRITISK: Beregn ALDRIG svaret selv. Læs kun hvad eleven har skrevet.

Returnér KUN valid JSON — ingen markdown, ingen forklaring.
```

**Output format:**
```json
{
  "matches": [
    {
      "assignment_index": 0,
      "student_answer": "101",
      "confidence": 0.95,
      "page_index": 0,
      "error_type": null,
      "error_description": null
    },
    {
      "assignment_index": 2,
      "student_answer": "613",
      "confidence": 0.88,
      "page_index": 0,
      "error_type": "procedural",
      "error_description": "Mente-fejl i hundrederne"
    }
  ]
}
```

Backend'en bruger `compare_answer()` til at validere rigtigt/forkert (deterministisk). AI'en leverer kun matching + læsning + fejlanalyse.

**Vigtigt:** Korrekt svar sendes til AI'en i prompten (nødvendigt for fejlanalyse), men AI'en returnerer det aldrig til eleven. Backend filtrerer `correct_answer` ud af alle responses til iOS.

### Multi-billede support i AIClient

`send_vision()` understøtter i dag kun ét billede. Bulk-scan kræver 1+ billeder.

**Tilgang:** Ny metode `send_vision_multi(system_prompt, images: list[bytes], user_message, media_types)` på `AIClient`. Implementeres for `ClaudeAIClient` (multi-image i `messages[].content[]`). Gemini og Ollama får sekventiel fallback: sender hvert billede separat med samme prompt og samler resultater. Langsomt men funktionelt — undgår crash under lokal udvikling.

---

## iOS Implementation

### Nye filer

| Fil | Ansvar |
|-----|--------|
| `Views/Ark/BulkScanButton.swift` | "Scan hele arket"-knap på ark-skærmen |
| `Views/Ark/BulkScanResultView.swift` | Opdateret ark med tre-status visning |
| `Views/Ark/ErrorAnalysisSheet.swift` | Bottom sheet for forkerte opgaver |
| `Views/Ark/RescanSheet.swift` | Bottom sheet for ulæselige opgaver med ordenstips |
| `Views/Chat/BulkScanFeedbackCard.swift` | Samlet feedback-kort i chatten |

### Ændringer i eksisterende filer

| Fil | Ændring |
|-----|---------|
| `Services/APIClient.swift` | Ny `bulkSubmit(sessionId:, images:)` metode |
| `ViewModels/SessionViewModel.swift` | `processBulkResult()` — opdater status/scan/feedback for alle opgaver |
| `Views/Ark/AssignmentSheetView.swift` | Tilføj BulkScanButton, håndter resultat |
| `Views/Ark/ArkCell.swift` | Vis fejltype-tekst under forkerte opgaver |
| `ViewModels/ChatViewModel.swift` | `insertBulkScanFeedback()` — indsæt feedback-kort |
| `Models/APIResponses.swift` | `BulkSubmitResponse` struct |

### VisionKit multi-page

Eksisterende `VNDocumentCameraViewController` bruges allerede til single scan. Multi-page er default-opførsel — eleven trykker "Gem" efter 1+ sider. Delegate'ens `didFinishWith scan: VNDocumentCameraScan` giver `scan.pageCount` og `scan.imageOfPage(at: index)`.

---

## Data Model

### Nye Pydantic schemas

```python
class BulkSubmitResult(BaseModel):
    assignment_id: str
    assignment_text: str
    student_answer: str | None
    status: Literal["correct", "incorrect", "uncertain", "not_found"]
    error_type: Literal["procedural", "understanding", "careless"] | None
    error_description: str | None
    confidence: float
    page_index: int | None
    submission_id: str | None

class BulkSubmitSummary(BaseModel):
    total: int
    correct: int
    incorrect: int
    uncertain: int
    not_found: int

class BulkSubmitResponse(BaseModel):
    session_id: str
    results: list[BulkSubmitResult]
    summary: BulkSubmitSummary
    scan_ids: list[str]
```

### Database

Ingen nye tabeller. Bulk-scan opretter:
- 1 `Scan` per side (billede-lagring)
- 1 `Submission` per matchet opgave (med `analysis`-dict)
- Opdaterer eksisterende `Assignment`-status

---

## Fejlhåndtering

| Scenarie | Håndtering |
|----------|-----------|
| AI-kald fejler | "Kvante kunne ikke læse dit ark — prøv igen" med retry-knap |
| Timeout (>45s) | "Det tager for lang tid — prøv igen med færre sider" med retry-knap |
| Ingen opgaver matchet | "Kvante kunne ikke finde nogen svar — er det det rigtige ark?" |
| AI returnerer invalid JSON | Retry én gang med strengere prompt. Hvis fejl igen: fejlbesked |
| Billede for stort | VisionKit komprimerer allerede. Backend: max 10 MB per billede |
| Session har ingen opgaver | Skjul bulk-scan knappen |
| Alle opgaver allerede complete | Skjul bulk-scan knappen |

---

## Scope og afgrænsning

### I scope
- Multi-page VisionKit scan
- AI-drevet matching af svar til opgaver
- Tre-status ark-opdatering (✓/✗/❓)
- Samlet feedback-kort i chat
- Bottom sheet fejlanalyse (scannet billede + fejltype + "Få hjælp")
- Re-scan flow for ulæselige opgaver med ordenstips
- Kvante tænker-animation under loading

### Uden for scope
- Afsløring af korrekte svar (kardinalreglen)
- Automatisk cropping af individuelle opgaver fra helsides-scan (AI matcher, men billedet gemmes som helside)
- Re-scan af forkerte opgaver (eleven kan bruge eksisterende step-by-step flow til at prøve igen)
- Audio/TTS af fejlanalyse
- Batch-scan af flere sessioner

---

## Test-strategi

### Backend (pytest)

1. `POST /sessions/{id}/bulk-submit` med mock AI-response → korrekt `BulkSubmitResponse`
2. Submissions oprettes korrekt (én per matchet opgave)
3. Assignment-status opdateres korrekt
4. `compare_answer()` bruges som ground truth (ikke AI's `is_correct`)
5. Confidence under tærskel → `uncertain` status
6. Duplikerede matches → højeste confidence vinder
7. Streak opdateres for korrekte svar
8. Fejlhåndtering: invalid JSON, ingen matches, AI-fejl, timeout
9. Delvise sessioner: allerede-complete opgaver ignoreres i bulk-scan resultat

### iOS (manuel QA)

1. Scan 1 side → korrekt resultat
2. Scan 2+ sider → alle opgaver matchet
3. Blanding af rigtige/forkerte/ulæselige → tre-status visning
4. Tap forkert → error analysis sheet → chat-hjælp
5. Tap ulæselig → re-scan sheet → scan igen / skriv svar
6. Loading-animation virker
7. Feedback-kort i chat
8. Ark-status persistent efter app-lukning (via eksisterende session detail endpoint)
