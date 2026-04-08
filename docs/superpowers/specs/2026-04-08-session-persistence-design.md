# Session Persistence — Design

**Dato:** 2026-04-08
**Pakke:** 1 (blocker for pakke 2, 4, 5)
**Status:** Brainstorm godkendt, klar til implementation-plan

## Baggrund

Backend har haft `POST /chat/messages/save` og `GET /chat/messages/{session_id}` endpoints siden Phase 2, men iOS-appen kalder dem ikke. Det betyder at elevens chat-historik kun eksisterer i hukommelsen i `ChatViewModel.messages` — ved app-lukning, force-quit eller navigation væk fra session forsvinder al chat. Når eleven genåbner samme session fra NewHomeView, starter chatten fra nul med en frisk velkomst-besked.

Denne pakke lukker persistering-hullet. Den er en foundation der sætter pakke 2 (ark-overlay med status), pakke 4 (bulk-scan der opdaterer assignment-status batch-wise) og pakke 5 (bog-arkivet med gamle sessioner) i stand til at have noget at læne sig op ad.

## Mål

Elevens chat-historik overlever app-lukninger og session-gen-åbninger. Når Lyng åbner en igangværende sessions-tap næste dag, ser hun hele scrollviewet som hun forlod det — tekstbobler, scannede papirer, feedback, celebration-markører — og chatten fortsætter ved næste uløste opgave.

- Ingen manual save-knap. Sync er transparent.
- Scannede billeder genfetches fra backend via et nyt `/scans/{id}/image`-endpoint.
- Apple-OCR-pathen (lokal OCR for simple opgaver) skal også persistere sine billeder — ingen regression.
- Fejl i persistering må aldrig blokere elev-flowet; degrader lydløst.

## Uden for scope

- Ark-overlay UI (pakke 2)
- Streak-tracking (pakke 2)
- Bog-arkivet UI (pakke 5)
- Genafspilning af `.exampleStep`-animationer ved reload (vises som tekst-placeholder)
- Persistering af `.loading` / `.ocrConfirm` / `.example` transient cases
- `scenePhase`-observer til force-save ved `.background` (kan tilføjes senere hvis nødvendigt)
- Offline-support (Kvante er LAN-first)

## Centrale designbeslutninger

Disse beslutninger blev truffet under brainstorm-dialogen og låser rammen for implementation-planen.

### Beslutning 1: Kerne-fidelitet, ikke fuld fidelitet

**Persisterede cases:** `text`, `assignmentIntro`, `scannedImage`, `feedback`, `answerResult`, `tip`, `celebration`.

**Ikke persisterede cases:** `loading`, `ocrConfirm`, `example`, `exampleStep`.

**Eksempel-flows er specialbehandlet:** Når ChatViewModel starter et example-flow (add `.example` eller sekvens af `.exampleStep`), indsættes samtidig én `.text("💡 Kvante viste et eksempel")`-markør i `messages[]` som en synlig ankerbesked. Markøren persisteres som almindelig `text`-case. De faktiske `.example` / `.exampleStep`-cases er ephemerale og spring over af `toCreateDTO()`. Ved reload ser eleven kun markøren — ingen re-afspilning. Denne tilgang undgår at introducere en særskilt `example_placeholder` content_type og holder persistance-laget simpelt.

**Begrundelse:** Fuld fidelitet ville kræve Codable-support for hver nested value-type (AnimationStep, GridState, LongMultiplicationState, ArrayGridState, FeedbackResponse med alle sub-strukturer). Det låser os til at vedligeholde bagudkompatibel serialisering for alle visuelle typer for evigt — hver gang vi redesigner et grid, skal vi også migrere gamle persisterede data. Kerne-fidelitet giver elevens grundlæggende oplevelse ("jeg kan se hvad jeg lavede og hvad Kvante sagde") uden at binde os til nuværende rendering-detaljer. Pakke 5 (bog-arkivet) skal alligevel bruge en komprimeret form af samtalen.

### Beslutning 2: Fuld scrollbar historik ved reload

Når en session gen-åbnes og har eksisterende chat-historik, loades og renderes alle persisterede beskeder i deres oprindelige rækkefølge. Eleven scroller tilbage og ser alt tidligere arbejde. Den aktive chat fortsætter automatisk ved næste uløste opgave.

**Afviste alternativer:**
- Frisk start + status-bar ("3/6 løst") — hårdt kontekst-tab, dårlig mental model.
- Kompakt opsummering-boble + frisk chat — halv løsning der kræver næsten samme arbejde som fuld historik for mindre værdi.

### Beslutning 3: Nyt backend-endpoint til at hente billeder

Scannede billeder refereres i persisteret chat som `scan_id` (UUID). Ved reload fetches det faktiske JPEG via `GET /scans/{scan_id}/image` over LAN-HTTP.

**Afviste alternativer:**
- Base64-indkodning inline i `content`-dict — skalerer dårligt (100-500KB pr. besked, mange beskeder), dobbelt-transmission (én gang til OCR-analysen, én gang til persistering).
- Lokal iOS-cache i `Documents/scanned/` — overlever ikke app-reinstall eller enhedsskift; kræver oprydnings-logik.

### Beslutning 4: Apple OCR-pathen uploader også billedet til backend

For at undgå en regression hvor single-digit multiplikation og simple stacked-problemer mister deres scannede papirer ved reload, uploades *alle* scannede svar til backend — også dem der OCR'es lokalt. Upload kører parallelt med den lokale OCR-kæde, så elev-perceiveret latency er uændret.

**Afviste alternativer:**
- Hybrid persistering (base64 for Apple-OCR, scan_id for Vision-OCR) — to datamodeller for samme ting, grimt.
- Accepter regressionen — mister billeder for de hyppigste opgavetyper, underminerer pakke 5's bog-arkiv.

### Beslutning 5: Save efter hver besked med en lokal cursor

Hver gang `ChatViewModel.messages` får en ny besked, fyres et save-kald af i baggrunden. En lokal `savedCursor: Int` tracker hvor langt vi er nået — save-kaldet sender kun `messages[cursor..<count]`. Cursor rykker kun frem ved success. Ved fejl retrier næste append automatisk (kumulativ batch).

**Afviste alternativer:**
- Debounced save + force på `.background` — mere kompleksitet uden betydelig gevinst på LAN.
- Kun save på `.background` — risikabelt ved crash eller force-kill.
- Full-list replace-all — backend skulle ændres til DELETE+INSERT; unødvendigt når cursor-modellen virker.

### Beslutning 6: Load async i `ChatViewModel.init()`, conditional welcome

`init()` starter en Task der først kalder `loadMessages(sessionId)`. Hvis resultatet er tomt, kaldes `sendWelcome()`. Hvis ikke, skippes velkomst. `savedCursor` sættes til `messages.count` efter load, så den indledende snapshot ikke re-sendes.

**Afviste alternativer:**
- Altid sende welcome og merge load ovenpå — visuelt flash.
- Betinget welcome baseret på "er session ny"-flag fra calling-site — spreder ansvar.

## Data-kontrakten

### Backend-side

Eksisterende `ChatMessage`-tabel (uændret):

```python
class ChatMessage(Base):
    __tablename__ = "chat_messages"
    id: Mapped[str]
    session_id: Mapped[str]        # FK til Session
    assignment_id: Mapped[str | None]  # FK til Assignment (nullable)
    sender: Mapped[str]            # "kvante" | "student"
    content_type: Mapped[str]      # type-identifikator
    content: Mapped[dict]          # JSON dict, schema per content_type
    created_at: Mapped[datetime]   # auto
```

Eksisterende endpoints (uændret):
- `POST /chat/messages/save` — append-only batch save
- `GET /chat/messages/{session_id}` — order_by(created_at)

Nye entities:

```python
# backend/app/models/db.py
class Scan(Base):
    __tablename__ = "scans"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    image_path: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)
```

Bevidst uden FK til Session eller Assignment — scans er en dum blob-store; chat-beskeden der refererer til scan_id giver semantisk kontekst. Dette gør modellen genanvendelig for pakke 4 (bulk-scan hele arket).

### Nye backend-endpoints

```
POST /scans/upload
  body: multipart/form-data med "image" felt
  response: { "scan_id": "uuid" }

GET /scans/{scan_id}/image
  response: image/jpeg binary (FileResponse)
  404 hvis ikke fundet
```

Scan-upload kører `preprocess_handwritten_work()` fra `image_preprocessor.py` (samme pipeline som eksisterende submission-flow) og gemmer til `{settings.upload_dir}/scan_{id}.jpg`.

### Content schema pr. content_type

Hver `content_type` har en fast dict-struktur som iOS mapper til/fra. Backend validerer ikke strukturen — dict er gennemsigtig.

| content_type        | content (dict)                                                                                                         |
|---------------------|------------------------------------------------------------------------------------------------------------------------|
| `text`              | `{"text": "Hej Lyng, lad os tage opgave 4..."}`                                                                        |
| `assignment_intro`  | `{"assignment_id": "uuid", "local_id": "3", "text": "568 + 275 = ?", "type": "stacked_addition", "topic": "addition", "difficulty_estimate": 2}` |
| `scanned_image`     | `{"scan_id": "uuid"}`                                                                                                  |
| `feedback`          | `{"methodology_sound": true, "feedback_text": "Flot — du ...", "assignment_id": "uuid"}`                               |
| `answer_result`     | `{"correct": true, "student_answer": "843", "expected_answer": "843"}`                                                 |
| `tip`               | `{"text": "Husk at låne fra tieren..."}`                                                                               |
| `celebration`       | `{"tier": "great"}`                                                                                                    |

**Ordering:** Backend returnerer `order_by(ChatMessage.created_at)` som autoritativ rækkefølge. iOS sender ikke eget timestamp; backend bruger `_now` default. Dette forenkler racing mellem kald.

**Assignment-association:** Beskeder der hører til en specifik opgave (tekst-dialog under opgave 3, scannede svar, feedback) sættes med `assignment_id` på save-kaldet. Beskeder mellem opgaver (velkomst, session-afslutning) får `assignment_id: null`.

## iOS-ændringer

### APIClient — tre nye metoder

```swift
// ios/Kvante/Kvante/Services/APIClient.swift

func uploadScan(imageData: Data) async throws -> ScanUploadResponse
func saveMessages(sessionId: String, messages: [ChatMessageCreate]) async throws
func loadMessages(sessionId: String) async throws -> [ChatMessageOut]
func scanImageURL(scanId: String) -> URL
```

### Nye DTO-typer

```swift
// ios/Kvante/Kvante/Models/APIResponses.swift

struct ScanUploadResponse: Codable {
    let scanId: String
}

struct ChatMessageCreate: Codable {
    let sender: String           // "kvante" | "student"
    let contentType: String      // "text" | "scanned_image" | ...
    let content: [String: AnyCodable]
    let assignmentId: String?
}

struct ChatMessageOut: Codable {
    let id: String
    let sessionId: String
    let assignmentId: String?
    let sender: String
    let contentType: String
    let content: [String: AnyCodable]
    let createdAt: String
}
```

`AnyCodable` er en ny lille helper (tilføjes i samme PR) der wraps arbitrary JSON-værdier (String, Int, Double, Bool, Array, Dict) i et Codable-kompatibelt envelope.

### `ChatMessage`-udvidelse

```swift
// ios/Kvante/Kvante/Models/ChatMessage.swift

enum ChatMessageContent {
    // ... eksisterende cases ...
    case scannedImage(Data?, scanId: String?)  // ← ÆNDRET fra (Data)
    // ...
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let sender: ChatSender
    let content: ChatMessageContent
    let timestamp: Date            // custom init tillader backend-timestamp ved load
    var actions: [ActionChipModel] = []
    var assignmentId: String? = nil  // ← NY

    init(sender: ChatSender, content: ChatMessageContent, timestamp: Date = Date(), actions: [ActionChipModel] = [], assignmentId: String? = nil)
}
```

Touch-sites der bruger `.scannedImage(data)`: alle opdateres til `.scannedImage(data, scanId: nil)` som initial tilstand. `ChatViewModel.scanAnswer` opdaterer beskeden til `.scannedImage(data, scanId: id)` når upload-kaldet returnerer.

### Ny fil: `ChatMessagePersistence.swift`

Placeret i `ios/Kvante/Kvante/Models/`. Indeholder to ekstensioner:

```swift
extension ChatMessage {
    func toCreateDTO() -> ChatMessageCreate?
}

extension ChatMessage {
    static func fromLoadedDTO(_ dto: ChatMessageOut, assignments: [String: ParsedAssignment]) -> ChatMessage?
}
```

`toCreateDTO` dispatcher på `content`-case og returnerer nil for cases vi ikke persisterer (`loading`, `ocrConfirm`, `example`, `exampleStep`) eller for `scannedImage` hvor `scanId` endnu ikke er sat.

`fromLoadedDTO` dispatcher på `contentType` og rekonstruerer det tilsvarende `ChatMessageContent`-case fra `content`-dict'en. Den modtager et assignments-dictionary (fra `PracticeSessionResponse.assignments`) til at hydre `assignmentIntro`-cases. Returnerer nil hvis content_type er ukendt eller dict'en mangler required felter — disse beskeder springes over i reload.

`exampleStep` / `example`-cases har ingen gen-hydrering overhovedet. Det er ChatViewModel's ansvar (se Beslutning 1) at tilføje en `.text`-markørbesked før selve example-flowet starter. Markøren persisteres naturligt som `text`-case og er det eneste eleven ser af eksemplet ved reload.

### `ChatViewModel` — save-cursor og load-flow

```swift
@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    private var savedCursor: Int = 0
    private var isSyncing: Bool = false
    private var pendingSync: Bool = false

    private let sessionId: String
    private let apiClient: APIClient
    var currentAssignment: ParsedAssignment?

    init(assignments: [ParsedAssignment], sessionId: String, apiClient: APIClient) {
        self.sessionId = sessionId
        self.apiClient = apiClient
        self.assignments = assignments

        Task { @MainActor in
            await loadExistingMessages()
            if messages.isEmpty {
                sendWelcome()
            }
            savedCursor = messages.count
        }
    }

    private func loadExistingMessages() async {
        do {
            let dtos = try await apiClient.loadMessages(sessionId: sessionId)
            let byId = Dictionary(uniqueKeysWithValues: assignments.map { ($0.id, $0) })
            messages = dtos.compactMap { ChatMessage.fromLoadedDTO($0, assignments: byId) }
        } catch {
            // Fail silently — start fresh, sendWelcome kaldes bagefter
        }
    }

    private func appendMessage(_ msg: ChatMessage) {
        var tagged = msg
        if tagged.assignmentId == nil {
            tagged.assignmentId = currentAssignment?.id
        }
        messages.append(tagged)
        syncUnsavedMessages()
    }

    private func syncUnsavedMessages() {
        if isSyncing {
            pendingSync = true
            return
        }
        let toSave = messages[savedCursor..<messages.count].compactMap { $0.toCreateDTO() }
        let newCursor = messages.count
        if toSave.isEmpty {
            savedCursor = newCursor
            return
        }
        isSyncing = true
        Task { @MainActor in
            defer {
                isSyncing = false
                if pendingSync {
                    pendingSync = false
                    syncUnsavedMessages()
                }
            }
            do {
                try await apiClient.saveMessages(sessionId: sessionId, messages: toSave)
                savedCursor = newCursor
            } catch {
                // Cursor rykker ikke; næste append retrier
            }
        }
    }
}
```

Alle eksisterende `messages.append(...)` kald i `ChatViewModel` erstattes med `appendMessage(...)`. Det er ~20 kald-sites.

### Scan-upload integration i `scanAnswer`

```swift
func scanAnswer(_ imageData: Data) async {
    let tempMessage = ChatMessage(
        sender: .student,
        content: .scannedImage(imageData, scanId: nil),
        assignmentId: currentAssignment?.id
    )
    appendMessage(tempMessage)
    let tempId = tempMessage.id  // track via UUID, ikke index

    // Parallel upload
    Task { @MainActor in
        do {
            let response = try await apiClient.uploadScan(imageData: imageData)
            if let idx = messages.firstIndex(where: { $0.id == tempId }) {
                messages[idx] = ChatMessage(
                    sender: .student,
                    content: .scannedImage(imageData, scanId: response.scanId),
                    timestamp: tempMessage.timestamp,
                    assignmentId: tempMessage.assignmentId
                )
                syncUnsavedMessages()
            }
        } catch {
            // Upload fejlede — message beholder scanId: nil og persisteres aldrig
        }
    }

    // Fortsæt eksisterende OCR-flow (Apple eller Vision) uændret
    // ...
}
```

### Billed-rendering ved reload

Ny helper-view `ScannedImageView` i `ios/Kvante/Kvante/Views/Chat/`:

```swift
struct ScannedImageView: View {
    let data: Data?
    let scanId: String?
    let apiClient: APIClient

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit()
        } else if let scanId {
            AsyncImage(url: apiClient.scanImageURL(scanId: scanId)) { phase in
                switch phase {
                case .empty: ProgressView()
                case .success(let img): img.resizable().scaledToFit()
                case .failure: Text("📷 Billedet kunne ikke hentes")
                @unknown default: EmptyView()
                }
            }
        } else {
            Text("📷 Billedet kunne ikke hentes")
        }
    }
}
```

Eksisterende steder i chat-rendering der håndterer `.scannedImage(data)` opdateres til at bruge `ScannedImageView(data: data, scanId: scanId, apiClient: apiClient)`.

### `PracticeSessionView` — uændret

`PracticeSessionView.setupSession()` opretter stadig `ChatViewModel` med session-ID og assignments. Al reload-logik lever inde i view-modellen. Dette er vigtigt: når pakke 2 senere tilføjer ark-overlay som nyt entry-point til samme ChatViewModel, virker persistering automatisk.

## Fejlhåndtering og kanttilfælde

**Save-fejl:** Logs til console. Cursor rykker ikke — næste append sender både ny + forrige uafsendte besked som batch. Eventual consistency. Hvis appen lukkes mellem fejl og næste append, tabes 1-2 seneste beskeder. Accepteret.

**Load-fejl:** Logs til console. `messages` forbliver tom, `sendWelcome()` kaldes. Degraderet men funktionel. Ved næste reload prøves load igen.

**Scan-upload-fejl:** Billedet forbliver i in-memory besked, `scanId` forbliver nil, beskeden persisteres aldrig. Ved reload vises placeholder "📷 Billedet kunne ikke hentes". Bevidst — vi fejler hellere lydløst end at blokere OCR-flowet.

**Race: sync mens sync kører:** Håndteret via `isSyncing`/`pendingSync`-flag-par. Anden sync-request merges ind i efterfølgende run, så alle ventende beskeder sendes i én batch.

**Skift af opgave mid-session:** `ChatViewModel.currentAssignment` sættes når eleven vælger en ny opgave. `appendMessage` tagger automatisk den nye besked med `currentAssignment?.id`.

**Reload af session hvor scan-fil er væk på disken:** `/scans/{id}/image` returnerer 404. `ScannedImageView` viser placeholder. Ikke bruger-facing i normal drift.

**Backwards-compat med eksisterende sessioner uden chat-messages:** `loadMessages` returnerer tom liste → `sendWelcome` kører → frisk start. Nul migration-arbejde.

**exampleStep-håndtering:** Før ChatViewModel tilføjer et `.example` eller et `.exampleStep`-flow til `messages[]`, indsætter den først en `.text("💡 Kvante viste et eksempel")`-ankerbesked. Den persisteres naturligt. `.example` og `.exampleStep`-cases er herefter ephemerale — de vises i aktiv session og forsvinder ved reload. Reload viser kun ankerbeskeden.

## Testing

### Backend (pytest)

Ny `tests/test_scans.py`:
- `test_upload_scan_returns_id` — POST multipart, assert response har scan_id, assert DB har row med image_path.
- `test_get_scan_image` — upload, fetch, assert bytes match og content-type er image/jpeg.
- `test_get_missing_scan_returns_404`.

Sanity-check i `tests/test_chat_messages.py` (eller ny): `save_messages` accepterer `content_type: "scanned_image"` med `content: {scan_id: "..."}` — dict passerer gennemsigtigt.

### iOS (XCTest)

`ChatMessagePersistenceTests.swift`:
- Round-trip hver persisteret case: build ChatMessage → toCreateDTO → serialize til dict → deserialize til ChatMessageOut → fromLoadedDTO → assert equality.
- Skip-cases: assert `toCreateDTO()` returnerer nil for `loading`, `ocrConfirm`, `example`, `exampleStep`, og `scannedImage(data, nil)`.
- Ukendt content_type i `fromLoadedDTO` returnerer nil (ikke crash).

`ChatViewModelPersistenceTests.swift`:
- Mock APIClient, verificér `loadMessages` kaldes i init.
- Mock `loadMessages` returnerer stubbed beskeder → assert `messages` populeret og `sendWelcome` ikke kaldt.
- Mock `loadMessages` returnerer tom → assert `sendWelcome` kaldt.
- Mock `saveMessages` fejler → verificér cursor ikke rykker og næste append-sync inkluderer den forrige.
- To hurtige appends → verificér kun ét sync-kald ad gangen, anden merges ind i næste run.

### End-to-end manuel QA (primær)

1. Fresh session på iPad. Scan et svar via Apple OCR (single-digit). Få feedback. Force-quit.
2. Genåbn session fra NewHomeView. Verificér hele historik + scannede billede renderes.
3. Scan et nyt svar via Vision OCR (columnar). Force-quit. Genåbn. Verificér begge billeder.
4. Backend-inspektion: `sqlite3 backend/kvante.db "SELECT * FROM chat_messages WHERE session_id=..."`, og `ls {upload_dir}/scan_*.jpg`.

## Risikovurdering

**Lav risiko:** Backend-ændringer er additive (ny tabel, to nye endpoints). Ingen migrations, ingen ændringer til eksisterende kontrakter. Hvis scans-delen ikke virker, falder vi gracefully tilbage til "billeder vises kun i aktiv session".

**Medium risiko:** iOS-touch-sites i ChatViewModel er mange (~20 `appendMessage`-opdateringer + ~5 `.scannedImage` case-opdateringer). Mekanisk arbejde, men fejlbehæftet hvis ét kald-site glemmes. Mitigation: grep alle `messages.append(` før refaktoren anses for færdig.

**Medium risiko:** `ChatMessage ↔ DTO` mapping for `assignmentIntro`, `feedback`, `answerResult` har flere felter der skal matches præcist. Mitigation: skriv round-trip-tests først (TDD for persistence-laget specifikt).

**Lav risiko:** Async racing mellem scan-upload og OCR-flow. Mitigation: begge kører parallelt i separate Tasks, state-opdatering går via UUID-lookup (ikke index) for at overleve interleaved state-ændringer.

## Implementation-orden

Implementation-planen vil sandsynligvis følge denne orden (skrives af writing-plans-skill):

1. Backend: `Scan` model + `POST /scans/upload` + `GET /scans/{id}/image` + tests
2. iOS: `AnyCodable` + DTO-structs + APIClient-metoder
3. iOS: `ChatMessage.scannedImage` udvides + touch-sites opdateres
4. iOS: `ChatMessagePersistence.swift` + round-trip tests
5. iOS: `ChatViewModel` save-cursor + load-flow + `appendMessage`-refaktor
6. iOS: `scanAnswer` parallel upload-integration + `ScannedImageView`
7. End-to-end manuel QA

## Succeskriterier

- Lyng kan scanne svar, lukke appen, åbne den igen, og se hele historikken inklusive sine scannede papirer.
- Fungerer for både Apple OCR (single-digit, simple stacked) og Vision OCR (long multiplication, columnar).
- Ingen bruger-facing fejl ved netværks-hiccups — degradering er altid lydløs.
- Eksisterende sessioner uden chat-historik i DB'en fungerer uændret (start frisk).
- `exampleStep`-animationer vises som placeholder ved reload, ikke som tom plads.
