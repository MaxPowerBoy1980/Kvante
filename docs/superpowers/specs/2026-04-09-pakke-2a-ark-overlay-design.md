# Pakke 2a — Ark-overlay design spec

**Dato**: 2026-04-09
**Status**: Godkendt efter brainstorm, klar til implementeringsplan
**Forgænger**: `2026-04-08-roadmap-reorder.md`, `~/.claude/projects/-Users-olsen-code-Kvante/memory/project_next_features.md`

---

## 1. Formål og baggrund

Den nuværende progres-UI (`ProgressPillView` i top af `ChatView`) er en minimal pill med en dropdown-drawer der viser horisontale nummer-tiles. UX-review har afsløret at eleven kun kan se sin aktuelle opgave i kontekst — ikke hele ugens opgavesæt. Brugerens krav: "det skal føles som papiret eller siden i matematikbogen".

Pakke 2a introducerer en **ark-skærm** mellem Home og Chat — et papir-metafor-baseret overblik over alle opgaver i sessionen, hvor eleven frit vælger hvor de vil starte og kan se deres egen tidligere arbejde (scannede løsninger) direkte på arket.

### Succes-kriterier

1. Alle session-entries (ny weekly, ny practice, fortsæt session) lander på arket først — aldrig direkte i chat.
2. Arket viser alle sessionens opgaver i et grid med status (løst/i gang/ikke startet) synligt på første blik.
3. Completede opgaver viser et thumbnail af elevens scannede løsning i cellen.
4. Eleven kan åbne en feedback-preview uden at forlade arket (via "i"-ikon på completed celler).
5. Navigation frem-og-tilbage mellem ark og chat er frictionless og state er perfekt synkroniseret.
6. Arket er strukturelt klar til at modtage pakke 2b's udvidelser (cirkel-progres, streak, celebration) uden ChatViewModel-refactor.

### Kardinale beslutninger

- **Scope (spørgsmål 1)**: Både weekly og practice sessioner får arket — én kode-sti, én mental model.
- **Entry flow (spørgsmål 2)**: Ark-first for alle entries. Home → Ark → Chat.
- **Layout (spørgsmål 3)**: Grid med 2 kolonner på iPad, større celler med visual-slot.
- **Indhold-scope (spørgsmål 4)**: Kun layout-fleksibilitet for geometri/koordinat-opgaver. Intet nyt indhold i denne pakke.
- **Arkitektur (spørgsmål 5)**: NavigationStack push + shared `@Observable SessionViewModel`.

---

## 2. Arkitektur-overblik

### Navigation-flow

```
ContentView (NavigationStack med SessionRoute-path)
 ├─ NewHomeView (rod)
 │   └─ "Start opgaver" / tap Seneste / via picker-flow
 │        ↓ activeSession sættes, sessionPath = [.ark]
 ├─ AssignmentSheetView ("Mit ark") — NY destination
 │   └─ tap opgave
 │        ↓ session.goToAssignment(index); sessionPath.append(.chat)
 └─ ChatView — eksisterende, refactoreret
     └─ "Tilbage" → sessionPath.removeLast() → Ark
     └─ "Mit ark" i header → sessionPath.removeLast() → Ark
```

### State-ejerskab

```
ContentView
 └─ @State activeSession: SessionViewModel?     ← lever gennem hele session-path
 └─ @State activeChatViewModel: ChatViewModel?  ← lever OGSÅ på ContentView-niveau
 └─ @State sessionPath: [SessionRoute] = []

SessionViewModel (@Observable, NY)               ← delt mellem Ark og Chat
 ├─ assignments (immutable)
 ├─ currentAssignmentIndex (muterer)
 ├─ statusByAssignment (muterer efter submission)
 ├─ latestScanId (muterer)
 ├─ feedbackSummary (muterer)
 └─ teacherComments (altid tom i Pakke 2a)

ChatViewModel (tyndet)
 ├─ let session: SessionViewModel                ← reference, ikke ejet
 ├─ messages, inputText, showScanner, ...
 └─ confirmAnswer() → session.markCompleted(...)
```

**Kritisk livscyklus-detalje**: Både `SessionViewModel` *og* `ChatViewModel` ejes af ContentView som `@State`. `ChatViewModel` oprettes sammen med sessionen og genbruges ved gentagne Ark→Chat-skift. Hvis ChatViewModel blev oprettet i `navigationDestination`-closuren, ville chat-historikken nulstilles ved hvert Ark→Chat→Ark→Chat-loop. Ved at løfte den til ContentView overlever messages, inputText og al AI-state hele session-perioden.

Begge nulstilles når `sessionPath` tømmes helt (eleven går til Home):
```swift
.onChange(of: sessionPath) { _, new in
  if new.isEmpty {
    activeSession = nil
    activeChatViewModel = nil
  }
}
```

### Hvorfor `@Observable` klasse (ikke struct)

To views (Ark og Chat) peger på *samme instans*. Mutationer i Chat opdateres automatisk i Ark uden manuel refresh eller data-refetch. Dette er både den cleaneste løsning og nødvendig for at pakke 2b kan udvide modellen uden Chat-refactor.

---

## 3. Backend — udvidelse af `GET /sessions/{session_id}`

### Nuværende respons (Pakke 1)

```json
{
  "session_id": "abc",
  "assignments": [
    { "id": "...", "local_id": "1", "text": "235 + 487",
      "type": "calculation", "topic": "addition",
      "difficulty_estimate": 2, "position": 0 }
  ]
}
```

### Ny respons (Pakke 2a)

```json
{
  "session_id": "abc",
  "session_name": "Uge 15",
  "current_assignment_index": 4,
  "assignments": [
    {
      "id": "...", "local_id": "1", "text": "235 + 487",
      "type": "calculation", "topic": "addition",
      "difficulty_estimate": 2, "position": 0,

      "ark_status": "done",
      "latest_scan_id": "scan_xyz",
      "latest_ai_feedback_summary": "Flot! Du regnede korrekt.",
      "teacher_comment": null
    }
  ]
}
```

### Pydantic-modeller

```python
# backend/app/models/schemas.py
class ArkAssignment(BaseModel):
    id: str
    local_id: str
    text: str
    type: str
    topic: str
    difficulty_estimate: int
    position: int

    ark_status: Literal["not_started", "in_progress", "done"]
    latest_scan_id: str | None = None
    latest_ai_feedback_summary: str | None = None
    teacher_comment: str | None = None  # altid None i Pakke 2a

class SessionDetailResponse(BaseModel):
    session_id: str
    session_name: str
    current_assignment_index: int
    assignments: list[ArkAssignment]
```

### Beregnede felter

**`ark_status`** — fra Assignment.status + Submission-historik:
```python
def compute_ark_status(a: Assignment, submissions: list[Submission]) -> str:
    if a.status in ("complete", "completed"):   # accept begge pga. kendt bug
        return "done"
    if submissions:
        return "in_progress"
    return "not_started"
```

**`latest_scan_id`** — query ChatMessages for den nyeste `content_type="scanned_image"` med `assignment_id = a.id`. `scan_id` ligger i ChatMessage's `content_value` JSON fra Pakke 1. Fallback til ældre `Submission.work_image_path` er *ikke* implementeret — kun Pakke 1+ submissions vises på arket.

**`latest_ai_feedback_summary`** — `Submission.feedback_text` fra den seneste submission på assignmentet. Trunkeres til ~140 tegn (afkort ved sætnings-grænse + "…") i *backenden*, ikke iOS. Cellen viser yderligere `lineLimit(1)` (~60 tegn) af denne streng som teaser — den fulde ~140-tegns summary vises i FeedbackPreviewSheet.

**`teacher_comment`** — altid `null` i Pakke 2a. Slot'en eksisterer så iOS kan læse feltet uden optional-dancing når klasserums-mode kommer. **Normalisering**: backenden normaliserer evt. tomme strenge til `null` i Pydantic-serialiseringen (field_validator), så iOS aldrig modtager `""`. Dermed er iOS-sidan altid `if let teacherComment` uden ekstra `!isEmpty`-check.

**`session_name`** — fra `Session.name`. Kræver at den kendte "practice sessions har tom name"-bug er fikset (se sektion 8).

**`current_assignment_index`** — den første non-done assignments position. Hvis alle er done, returnér `len(assignments)`. Hvis sessionen er helt fersk, returnér `0`.

### Backwards compat

Endpoint'et blev tilføjet i Pakke 1 og har kun én kaldsted (iOS' "Fortsæt session"). Alle Pakke 1-felter bevares, kun nye tilføjes. Ingen versionering nødvendig.

### Tests (pytest, TDD)

Ny testfil: `backend/tests/test_sessions_ark.py`

1. `test_get_session_returns_session_name_and_current_index`
2. `test_ark_status_not_started_for_fresh_session`
3. `test_ark_status_in_progress_when_submission_exists_but_not_complete`
4. `test_ark_status_done_accepts_both_complete_and_completed` (bug-defensiv)
5. `test_latest_scan_id_from_chat_message`
6. `test_latest_scan_id_null_when_no_scans`
7. `test_latest_ai_feedback_summary_from_submission_feedback_text`
8. `test_latest_ai_feedback_summary_truncated_to_140_chars`
9. `test_teacher_comment_always_null` (kontrakt-lås)
10. `test_current_assignment_index_skips_done_assignments`
11. `test_current_assignment_index_returns_count_when_all_done`
12. `test_backward_compat_assignment_fields_preserved`
13. `test_empty_session_returns_empty_assignments_list`

---

## 4. iOS — `SessionViewModel` (ny)

### Interface

```swift
@Observable
@MainActor
final class SessionViewModel {
  // Identitet
  let sessionId: String
  let sessionName: String

  // Frozen efter init
  let assignments: [ParsedAssignment]

  // Mutable
  var currentAssignmentIndex: Int
  var statusByAssignment: [String: ArkStatus]
  var latestScanId: [String: String]
  var feedbackSummary: [String: String]
  var teacherComments: [String: String]  // altid tom i Pakke 2a

  // Afledt
  var completedCount: Int {
    statusByAssignment.values.filter { $0 == .done }.count
  }
  var currentAssignment: ParsedAssignment {
    assignments[currentAssignmentIndex]
  }

  // Mutationer
  func goToAssignment(_ index: Int) {
    currentAssignmentIndex = index
  }
  func markCompleted(_ assignmentId: String, feedback: String?) {
    statusByAssignment[assignmentId] = .done
    if let feedback { feedbackSummary[assignmentId] = feedback }
  }
  func recordScan(_ scanId: String, forAssignment assignmentId: String) {
    latestScanId[assignmentId] = scanId
    if statusByAssignment[assignmentId] != .done {
      statusByAssignment[assignmentId] = .inProgress
    }
  }

  // Construction fra backend response
  init(from response: SessionDetailResponse) { ... }
}

enum ArkStatus: String {
  case notStarted
  case inProgress
  case done
}
```

### Invarianter

1. `assignments` er immutable efter init. Kun status-dictionaries ændres.
2. `currentAssignmentIndex` er eneste source-of-truth for "hvor er eleven nu" — både Ark (highlight) og Chat (aktuel opgave) læser derfra.
3. Status-opdateringer sker kun fra ChatViewModel efter backend-bekræftet submission.

---

## 5. iOS — `ChatViewModel` refactor (tyndes)

### Felter der *flyttes* til SessionViewModel

- `allAssignments: [ParsedAssignment]`
- `currentAssignmentIndex: Int`
- `completedAssignmentIds: Set<String>` (bliver `statusByAssignment`)
- `totalAssignments: Int` (bliver computed fra session.assignments.count)

### Felter der *bliver*

- `messages: [ChatMessage]`
- `inputText: String`
- `showScanner: Bool`
- `isLoadingHistory: Bool`
- Alle AI-interaktions-metoder (`sendMessage`, `requestHelp`, `scanAnswer`, etc.)
- Alle chat-rendering-state-felter

### Ny struktur

```swift
@Observable
@MainActor
final class ChatViewModel {
  let session: SessionViewModel   // delt reference
  let apiClient: APIClient

  var messages: [ChatMessage] = []
  var inputText: String = ""
  var showScanner = false
  var isLoadingHistory = false
  // ... eksisterende AI-state ...

  // Convenience
  var currentAssignment: ParsedAssignment { session.currentAssignment }
  var allAssignments: [ParsedAssignment] { session.assignments }

  // Efter korrekt submission:
  private func confirmAnswer(...) async {
    // ... validér ...
    session.markCompleted(session.currentAssignment.id, feedback: aiResponse.summary)
    // Ark opdateres automatisk via @Observable
  }

  // Efter scan:
  private func scanAnswer(_ imageData: Data) async {
    // ... upload, Apple/Vision OCR ...
    if let scanId = uploadedScanId {
      session.recordScan(scanId, forAssignment: session.currentAssignment.id)
    }
  }
}
```

### Constructor + livscyklus-ændring

ChatViewModel kan ikke længere konstrueres uden en `SessionViewModel`. Og den oprettes nu i ContentView's entry-flow-funktioner (startWeeklySession/resumeSession), IKKE i `navigationDestination`-closuren. Begge oprettes sammen og lever som `@State` på ContentView:

```swift
// I startWeeklySession() / resumeSession():
let session = SessionViewModel(from: response)
activeSession = session
activeChatViewModel = ChatViewModel(session: session, apiClient: client)
sessionPath = [.ark]
```

Dette sikrer at chat-historik (messages, inputText, AI-state) overlever Ark→Chat→Ark→Chat-loops. ChatViewModel genbruges — den genskabes ikke ved hvert push til `.chat`-ruten.

---

## 6. iOS — `AssignmentSheetView` og cell-design

### Fil-struktur (nye filer)

```
ios/Kvante/Kvante/Views/Ark/
├── AssignmentSheetView.swift
├── ArkCell.swift
└── FeedbackPreviewSheet.swift
```

Scan-thumbnails håndteres via den eksisterende `ScannedImageView` (udvides med `maxPixelSize`-parameter — se sektion 8). Ingen separat `ArkScanThumbnailView`-fil.

### View-hierarki

```
AssignmentSheetView
├── Paper-baggrund (Color + Canvas-grain overlay, opacity 0.04)
├── ArkHeader
│   ├── Drag-handle (dekorativ, slide-down-metafor-reference)
│   ├── "Mit ark" titel
│   └── "\(sessionName) — \(completedCount) af \(total) løst"
└── ScrollView
    └── LazyVGrid(columns: 2, spacing: 12)
        └── ForEach(session.assignments) { assignment in
              ArkCell(
                assignment: assignment,
                status: session.statusByAssignment[id] ?? .notStarted,
                scanId: session.latestScanId[id],
                feedbackSummary: session.feedbackSummary[id],
                isCurrent: session.currentAssignmentIndex == index,
                onTap: { selectAssignment(index) },
                onFeedbackTap: { presentedFeedback = assignment }
              )
            }
.sheet(item: $presentedFeedback) { item in
  // presentedFeedback er en ArkFeedbackItem (Identifiable wrapper med assignment + index)
  FeedbackPreviewSheet(
    assignment: item.assignment,
    session: session,
    apiClient: apiClient,
    onOpenChat: {
      presentedFeedback = nil
      selectAssignment(item.index)
    }
  )
  .presentationDetents([.medium, .large])
}

// Wrapper-model for sheet binding:
// struct ArkFeedbackItem: Identifiable {
//   let id: String   // assignment.id
//   let assignment: ParsedAssignment
//   let index: Int
// }
```

### `ArkCell` — visuel spec

Layout (top til bund):
```
┌────────────────────────────────┐
│  OPG 3                 7 × 8   │  cell-head
├────────────────────────────────┤
│                                │
│  [scan thumb eller placeholder]│  visual-slot (flex)
│                                │
├────────────────────────────────┤
│  ✓ løst · "Flot arbejde"   ⓘ   │  cell-foot
└────────────────────────────────┘
```

- Bredde: `(screen.width - sidePadding*2 - gridGap) / 2`
- Min-højde: 160 pts
- Corner radius: 10

Baggrund per status (bruger `KvanteTheme.Colors`):
- `.notStarted`: `cream`, border `inkSubtle` 1pt
- `.inProgress`: `primary.opacity(0.08)`, border `primary` 2pt
- `.done`: `success.opacity(0.08)`, border `success` 1.5pt

**`isCurrent`-overlay** (uafhængig af status, kan kombineres med alle tre):
Cellen der matcher `session.currentAssignmentIndex` får en ekstra visuel markering:
- 2pt `primary`-border ring *udenfor* den eksisterende status-border (via `.overlay(RoundedRectangle(...).stroke(primary, lineWidth: 2))` med padding)
- Subtle drop-shadow: `.shadow(color: primary.opacity(0.20), radius: 6, y: 2)`
- Lille "▸"-indikator eller pulserende dot i øverste venstre hjørne af cellen

Kombinationer: `.notStarted + isCurrent` = cream bg + primary ring + shadow. `.done + isCurrent` = grøn bg + primary ring. Visuelt er det altid klart hvilken celle der er "den aktuelle" uanset dens status.

Visual-slot indhold:
- `.done` med scanId: `ArkScanThumbnailView(scanId, .cell)` async load
- `.inProgress` med scanId: samme thumbnail + "i gang"-badge overlay
- `.inProgress` uden scanId: placeholder "Du arbejder på den…"
- `.notStarted`: dashed border-placeholder "Tryk for at løse"

Feedback-teaser i cell-foot:
- Kun vist hvis `feedbackSummary != nil`
- Første ~60 tegn via `.lineLimit(1)`, italic muted farve
- Prioriterer status-badge hvis plads-konflikt

"i"-ikon (info):
- Kun vist hvis `feedbackSummary != nil`
- SF Symbol `info.circle.fill` i primary-farve
- Dedikeret Button med `.buttonStyle(.plain)` så hoved-tap og i-tap ikke kolliderer

### `FeedbackPreviewSheet`

```
NavigationStack {
  ScrollView {
    VStack(alignment: .leading, spacing: 16) {
      // Header: opgave-nr + text
      Text("Opgave \(localId) — \(text)").font(.headline)

      // Stor scan-thumbnail (full-width)
      if let scanId {
        ArkScanThumbnailView(scanId: scanId, size: .large, apiClient: apiClient)
      }

      // Kvante-sektion
      VStack(alignment: .leading, spacing: 8) {
        Label("Kvante", systemImage: "sparkles")
        Text(aiFeedback)
          .padding(12)
          .background(KvanteTheme.Colors.cream)
          .cornerRadius(8)
      }

      // Lærer-sektion — hidden when empty
      if let teacherComment, !teacherComment.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Label("Fra lærer", systemImage: "person.fill")
          Text(teacherComment)
        }
      }
      // I Pakke 2a: teacherComment altid nil → sektionen ALDRIG vises

      Button("Åbn fuld chat") { onOpenChat() }
        .buttonStyle(KvanteTheme.TactileButtonStyle.primary)
    }
    .padding(20)
  }
  .navigationTitle("Feedback")
  .toolbar {
    ToolbarItem(placement: .cancellationAction) {
      Button("Luk") { dismiss() }
    }
  }
}
```

### Paper-tekstur

Procedural via SwiftUI Canvas, ingen asset:

```swift
private var paperBackground: some View {
  ZStack {
    KvanteTheme.Colors.cream
    Canvas { context, size in
      // Sparsom pixel-noise, seeded randomness for konsistens
      // ...
    }
    .opacity(0.04)
    .blendMode(.multiply)
    .allowsHitTesting(false)
  }
  .ignoresSafeArea()
}
```

Alternativ: et lille PNG-asset hvis procedural ikke matcher brugerens forventning. Ikke besluttet endnu — kan vælges under implementering ud fra hvad der føles rigtigt.

### Animation

NavigationStack default horizontal push til Ark. Custom navigationTransition (iOS 18+) er **ikke** brugt — for kompliceret for gevinsten.

**Staggered row-appear**: Ønsket effekt er at grid-rækker animerer ind top-til-bund. Dette kræver explicit indeks-tracking i SwiftUI (`@State appeared: Set<Int>` + per-celle `.onAppear { Task.sleep }` + `.opacity`/`.offset`-transition). Det er **polish, ikke struktur** — implementeringsplanen markerer det som optional og kan droppes hvis det komplicerer uden visuel gevinst. Standard `.animation(.spring)` ved first-appear er en acceptabel fallback.

---

## 7. iOS — Navigation og ContentView refactor

### SessionRoute-enum

```swift
enum SessionRoute: Hashable {
  case ark
  case chat
}
```

### ContentView state

```swift
@State private var sessionPath: [SessionRoute] = []
@State private var activeSession: SessionViewModel?
@State private var activeChatViewModel: ChatViewModel?   // lever på ContentView-niveau
```

### NavigationStack-setup

```swift
NavigationStack(path: $sessionPath) {
  // Rod: Home eller picker-flow
  if let profile {
    NewHomeView(
      onPractice: { showPractice = true },
      onWeekly: { startWeeklySession() },
      onTapSession: { summary in resumeSession(summary) }
    )
    .navigationDestination(for: SessionRoute.self) { route in
      switch route {
      case .ark:
        if let session = activeSession {
          AssignmentSheetView(
            session: session,
            apiClient: apiClient,
            onSelectAssignment: { index in
              session.goToAssignment(index)
              sessionPath.append(.chat)
            }
          )
        }
      case .chat:
        // ChatViewModel genbruges — IKKE oprettet her.
        // Allerede konstrueret i startWeeklySession/resumeSession.
        if let vm = activeChatViewModel {
          ChatView(
            viewModel: vm,
            onBack: { sessionPath.removeLast() }
          )
        }
      }
    }
  }
}
.onChange(of: sessionPath) { _, new in
  if new.isEmpty {
    activeSession = nil
    activeChatViewModel = nil
  }
}
```

**Kritisk**: `activeChatViewModel` oprettes SAMMEN med `activeSession` i `startWeeklySession()` / `resumeSession()`, IKKE i `navigationDestination`-closuren. Dette sikrer at chat-historikken overlever Ark→Chat→Ark→Chat-loops.

### Entry flows

**Ny weekly session**:
```swift
private func startWeeklySession() {
  Task {
    isLoading = true
    do {
      let response = try await apiClient.createWeeklySession(...)
      let session = SessionViewModel(from: response)
      activeSession = session
      activeChatViewModel = ChatViewModel(session: session, apiClient: apiClient!)
      sessionPath = [.ark]
    } catch {
      errorMessage = error.localizedDescription
    }
    isLoading = false
  }
}
```

**Ny practice session** (efter topic + difficulty picker): samme pattern — opret begge models sammen.

**Fortsæt session** (fra Seneste eller tidligere SessionDashboardView):
```swift
private func resumeSession(_ summary: SessionSummary) {
  Task {
    isLoading = true
    do {
      let response = try await apiClient.getSession(sessionId: summary.sessionId)
      let session = SessionViewModel(from: response)
      activeSession = session
      activeChatViewModel = ChatViewModel(session: session, apiClient: apiClient!)
      sessionPath = [.ark]
    } catch {
      errorMessage = "Kunne ikke åbne session: \(error.localizedDescription)"
    }
    isLoading = false
  }
}
```

**Kritisk**: `activeChatViewModel` oprettes her (sammen med session), IKKE i `navigationDestination`. Det sikrer at chat-historik, messages, inputText og AI-state overlever gentagne Ark→Chat→Ark→Chat-navigationer.

### Back-button-semantik

| Placering | Knap | Resultat |
|---|---|---|
| Home | (ingen) | — |
| Ark | NavigationStack toolbar "Tilbage" | Pop til Home. `sessionPath = []` → `activeSession = nil` |
| Chat | Custom chat-header "Tilbage" | `sessionPath.removeLast()` → Ark |
| Chat | Custom chat-header "Mit ark" | `sessionPath.removeLast()` → Ark |

### `ChatView` header-ændringer

Ny layout for chat-headeren:

```
┌─────────────────────────────────────────────┐
│ ← Tilbage    🤖 Kvante · Online    📋 Mit ark│
└─────────────────────────────────────────────┘
```

- "Tilbage" til venstre (uændret, nye onBack pop'er `sessionPath`)
- Centreret avatar + "Kvante · Online" (uændret)
- "Mit ark"-knap til højre (NY) — samme callback som Tilbage (`sessionPath.removeLast()`) men semantisk eksplicit

### Filer der fjernes

- `ios/Kvante/Kvante/Views/Chat/ProgressPillView.swift` — funktionen er erstattet af arket
- `ios/Kvante/Kvante/Views/Dashboard/SessionDashboardView.swift` — erstattet af ark-first entry flow. Dets funktion (vis "Fortsæt session"-knap + session-metadata) er nu integreret direkte i ark-headeren.

---

## 8. Data loading — scans, feedback, fejl-håndtering

### Scan-thumbnails (client-side downsampling + cache)

Scan-billeder fra Pakke 1 er gemt i original opløsning (2-5 MB per fil). At hente dem til 180×100 pts celle-thumbnails er spild.

Løsning: iOS downsampler ved modtagelse via ImageIO's `CGImageSourceCreateThumbnailAtIndex` med `kCGImageSourceThumbnailMaxPixelSize = 400`. Gemmer kun den downsamplede `UIImage` i cache. Ingen backend-thumbnail-generering.

### `ScanImageCache` (singleton)

```swift
@MainActor
final class ScanImageCache {
  static let shared = ScanImageCache()
  private let cache = NSCache<NSString, UIImage>()

  func image(for scanId: String, apiClient: APIClient) async -> UIImage? {
    if let cached = cache.object(forKey: scanId as NSString) { return cached }
    do {
      let url = apiClient.baseURL.appendingPathComponent("scans/\(scanId)/image")
      let (data, _) = try await URLSession.shared.data(from: url)
      guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, [
              kCGImageSourceCreateThumbnailFromImageAlways: true,
              kCGImageSourceThumbnailMaxPixelSize: 400,
              kCGImageSourceShouldCacheImmediately: true,
            ] as CFDictionary) else { return nil }
      let image = UIImage(cgImage: thumb)
      cache.setObject(image, forKey: scanId as NSString)
      return image
    } catch {
      return nil
    }
  }
}
```

Singleton med `NSCache` i stedet for `[String: UIImage]` — OS evict'er automatisk under memory pressure. Scans er immutable, ingen invalidation nødvendig. Ingen `@Observable` nødvendig da cache'en aldrig er en binding-source.

### `ArkScanThumbnailView` (eller udvidet `ScannedImageView`)

**Anbefalet**: Udvid eksisterende `ScannedImageView` med en `maxPixelSize: Int?` parameter (default `nil` = fuld opløsning som i dag). Ark cells bruger `maxPixelSize: 400`. En enkelt kode-sti til scan-rendering.

```swift
struct ScannedImageView: View {
  let scanId: String
  let apiClient: APIClient
  var maxPixelSize: Int? = nil

  @State private var image: UIImage?
  @State private var failed = false

  var body: some View {
    Group {
      if let image {
        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
      } else if failed {
        // Fallback-ikon
      } else {
        ProgressView()
      }
    }
    .task(id: scanId) {
      if let maxPixelSize {
        image = await ScanImageCache.shared.image(for: scanId, apiClient: apiClient)
      } else {
        // Load fuld opløsning (eksisterende path)
      }
      if image == nil { failed = true }
    }
  }
}
```

### Feedback summary — synchronously available

`latest_ai_feedback_summary` kommer med i session-load-responsen og lever i `SessionViewModel.feedbackSummary`. Ingen separat async load for teaser'en eller "i"-ikon-synligheden. Celle-renders er hurtige.

### Fejltilstande

| Fejl | Hvor | Håndtering |
|---|---|---|
| `getSession` 404 / netværk | ContentView.resumeSession | Alert, bliver på Home. `sessionPath` ikke pushed |
| `createWeeklySession` fejl | ContentView.startWeeklySession | Alert, bliver på Home |
| Empty assignments fra backend | SessionViewModel.init | Arket viser tom grid + "Ingen opgaver i denne session" |
| Scan thumbnail 404 / timeout | ArkScanThumbnailView | Fallback-ikon per celle, resten uforstyrret |
| AI feedback null for done assignment | ArkCell | Ingen "i"-ikon, ingen teaser, kun status-badge |
| teacher_comment tom string (ikke null) | SessionViewModel.init + FeedbackPreviewSheet | Behandl som null — defensive check `!teacher.isEmpty` |

### Ingen prefetch

Scan-thumbnails prefetches *ikke* proaktivt ved session-load. LazyVGrid loader kun synlige celler. First-paint af arket (skeletter + equations + status) er vigtigere end at alle billeder er klar.

---

## 9. Follow-up bugs der bundles i Pakke 2a

Disse er *kendte bugs* fra TODO.md `Kendte bugs`-sektionen som ligger i samme kodestier som pakke 2a rører. Det giver mening at bundle dem i samme PR fordi vi alligevel rører koden.

### Bug 1: "complete" vs "completed" status-mismatch

`submissions.submit_work` sætter `Assignment.status = "complete"`, men `practice.get_session_history` counter `a.status == "completed"`. Strings matcher aldrig → `completed_count` er altid 0.

**Fix**: Vælg kanonisk værdi (foreslår `"complete"`) og opdater tælleren til at matche. I ark-endpoint'et accepterer `compute_ark_status()` defensivt begge varianter for at være robust mod ikke-migrerede data.

**Filer**: `backend/app/routers/practice.py` (én linje), ny test der asserterer matchen.

### Bug 2: Practice sessions har tom `name`-felt

`practice.create_practice_session` opretter Session-rows uden at sætte `name`. Weekly sessions har derimod et name ("Ugematematik — uge X"). Arket ville vise blank titel for practice sessions.

**Fix**: Generér et name ved oprettelse, fx `f"Øvelser — {topic_label} ({difficulty_label})"`.

**Filer**: `backend/app/routers/practice.py` (få linjer), ny test.

---

## 10. Scope-afgrænsning

### Eksplicit IKKE i Pakke 2a

- Geometri/koordinat-assignments som rigtigt indhold — kun layout-fleksibilitet i cellen
- Cirkel-progres fra Kvantes bryst-panel (pakke 2b)
- Streak-tabel og streak-model (pakke 2b)
- Lyn-zigzag celebration-signatur (pakke 2b)
- Bulk-scan hele arket (pakke 4)
- AI fejlanalyse på tap af rød opgave (pakke 4)
- Redigering af assignments (tilføj/fjern/omarranger)
- Delete/restart session-knap i ark-header
- Papir-tekstur som bundled asset (procedural Canvas-grain, evt. PNG hvis det ikke ser rigtigt ud)
- Lærer-kommentar backend (`teacher_comments`-tabel eller lignende)
- Deep-link restoration (app-kill midt i chat → Home ved re-open)
- Thumbnail-generering server-side (client-side downsampling i stedet)

### Beslutningslog (defaults låst)

1. **Grid-kolonner**: 2 på iPad (både orientation). Til fremtidig iPhone-support: 1 kolonne.
2. **Session-header-format**: `"\(sessionName) — \(completedCount) af \(totalCount) løst"`. Ingen dato, ingen procent.
3. **Cell-tap**: går altid til Chat, inklusive done-celler. Feedback-only-stien er "i"-ikon.
4. **Marker som ikke-færdig**: ikke supporteret. Gen-scan i Chat → eksisterende submission-flow dækker behovet.
5. **Paper-tekstur**: procedural Canvas, opacity 0.04, multiply blend. Kan udskiftes til asset hvis det ikke føles rigtigt under implementering.
6. **Slide-down-animation**: NavigationStack default horizontal push + staggered row-appear i grid'et.
7. **Feedback-teaser**: første ~60 tegn, én linje, italic muted. Fuld feedback i PreviewSheet.
8. **SessionDashboardView**: slettes. Dets funktion er absorberet af ark-headeren.
9. **ProgressPillView**: slettes helt. Erstattet af arket + "Mit ark"-knap i chat-header.

---

## 11. Filer der røres

### Backend (nye)

- `backend/tests/test_sessions_ark.py` — 13 nye pytest-tests

### Backend (modificerede)

- `backend/app/routers/practice.py` — udvid GET /sessions/{id}, fix status-bug, generér practice session name
- `backend/app/models/schemas.py` — nye Pydantic-modeller (`ArkAssignment`, `SessionDetailResponse`)

### iOS (nye)

- `ios/Kvante/Kvante/ViewModels/SessionViewModel.swift`
- `ios/Kvante/Kvante/Views/Ark/AssignmentSheetView.swift`
- `ios/Kvante/Kvante/Views/Ark/ArkCell.swift`
- `ios/Kvante/Kvante/Views/Ark/FeedbackPreviewSheet.swift`
- `ios/Kvante/Kvante/Services/ScanImageCache.swift`

### iOS (modificerede)

- `ios/Kvante/Kvante/ContentView.swift` — NavigationStack path + activeSession state + entry flows
- `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift` — tyndes, holder session reference
- `ios/Kvante/Kvante/Views/Chat/ChatView.swift` — fjern ProgressPillView-kald, tilføj "Mit ark"-knap, opdater onBack
- `ios/Kvante/Kvante/Views/Chat/ScannedImageView.swift` — tilføj `maxPixelSize` parameter
- `ios/Kvante/Kvante/Models/APIResponses.swift` — ny `SessionDetailResponse` + `ArkAssignment` structs
- `ios/Kvante/Kvante/Services/APIClient.swift` — `getSession(sessionId:)` returtype ændres

### iOS (slettes)

- `ios/Kvante/Kvante/Views/Chat/ProgressPillView.swift`
- `ios/Kvante/Kvante/Views/Dashboard/SessionDashboardView.swift`

---

## 12. Verifikations-strategi

### Backend — pytest TDD per endpoint

Samme pattern som Pakke 1 og dev-tooling Pakke A. Hver feltudvidelse får sin egen test i `test_sessions_ark.py` før implementering.

### iOS — xcodebuild per task + manuel QA ved slut

Ingen unit-test-infrastruktur for SwiftUI views. Per-task verification er `xcodebuild Debug -destination 'platform=iOS Simulator,name=iPad (A16)'` + commit.

### Manuel QA-tjekliste (slut)

1. Start ny weekly session → Ark first (ikke Chat)
2. Grid viser alle ugens opgaver med korrekt status pr. opgave
3. Tap opgave → åbner Chat for den
4. "Tilbage" i Chat → tilbage til Ark (ikke Home)
5. "Tilbage" i Ark → Home
6. "Mit ark"-knap i chat-header → Ark
7. Løs opgave i Chat → Ark viser nu done med feedback-teaser og "i"-ikon
8. Scan-thumbnail vises på done-celler efter async load
9. Tap "i"-ikon → FeedbackPreviewSheet uden at forlade arket
10. "Åbn fuld chat"-knap fra sheet → Chat for den opgave
11. Fortsæt eksisterende session fra Seneste → Ark med korrekt state
12. Force-quit midt i session → reopen → Home → tap Seneste → Ark med korrekt state
13. Release-build kompilerer (ingen utilsigtede DEBUG-afhængigheder)
14. Ark med 0 løste opgaver renderer (ingen i-ikoner, ingen teasers)
15. Ark med alle løste opgaver renderer (alle grønne, alle med teaser)
16. Scan-thumb fejl-fallback: slet scan-fil, reload → "billede ikke tilgængeligt" uden crash
17. Practice session har nu et name på arket (bug fix verified)
18. `completed_count` på Seneste-liste matcher faktiske løste opgaver (bug fix verified)

### Mac Mini sync + smoke-test

Efter backend-ændringer: deploy til Mac Mini via `./scripts/deploy.sh`, curl `/sessions/{id}` for en test-session, verificer at alle nye felter er til stede.

---

## 13. Afhængigheder og relation til andre pakker

### Bygger på

- **Pakke 1 (Session persistence, merget 2026-04-08)**: ChatMessage-tabellen med `content_type="scanned_image"` og `scan_id`-referencer er kilden for `latest_scan_id`-feltet. Uden Pakke 1 ville der ikke være data til ark-thumbnails.

### Forbereder

- **Pakke 2b (Cirkel-progres + streak + celebration)**: `SessionViewModel` er designet til at udvides med `circleState`, `streak`, `celebrationEvents` uden ChatViewModel-ændringer. Komponenten bygges i Pakke 2b men monteres først i Pakke 3's nye home.
- **Pakke 3 (Home redesign)**: Ark-first entry flow betyder at home-siden ikke længere har kompleks session-history-logik — tap Seneste går direkte til Ark. Det er kompatibelt med pakke 3's "i dag"-boks.
- **Pakke 4 (Bulk-scan + AI fejlanalyse)**: Arkets status-model (`not_started`/`in_progress`/`done`) vil naturligt blive udvidet med `wrong_needs_retry` når fejlanalyse kommer. Cell-rendering er strukturelt klar.
- **Pakke 5 (Bog-arkivet)**: Arket viser *aktuelle* sessions. Bogen viser *færdige* sessions. De er parallelle visninger med overlappende celle-komponenter — `ArkCell` kan genbruges i bogsider.

### Ingen direkte dependency til

- Pakke 4's AI fejlanalyse (kan bygges uafhængigt og folder sig ind senere)
- Pakke 5 bog-arkivet
- Dev-tooling capture-knap (allerede merget)
- Single-digit og long mult polish-bundles

---

## 14. Åbne spørgsmål at afklare i implementeringsplanen

Ingen kritiske. Alle kardinale beslutninger er låst i denne spec. Mindre detaljer der kan afgøres under implementering:

- Eksakt spacing og font-weights i ArkHeader og ArkCell (design-polish, ikke struktur)
- Paper-tekstur: Canvas vs PNG-asset — vælges ud fra hvad der ser bedst ud i simulator
- Trunkerings-strategi for feedback-summary når den er lige på grænsen af 60 tegn (brækk på ord-grænse?)

## 15. Review-log

Bruger-review 2026-04-09 identificerede 6 punkter. Alle adresseret i rev 2:

1. **[Kritisk, fikset]** ChatViewModel genskabes ved hvert Ark→Chat-skift → Løst ved at løfte `activeChatViewModel` til `@State` på ContentView-niveau, oprettes sammen med session, genbruges ved navigation.
2. **[Kritisk, fikset]** `index` ikke i scope i `.sheet(item:)` closure → Løst med `ArkFeedbackItem` Identifiable wrapper der bærer `(assignment, index)`.
3. **[Fikset]** ScanImageCache ubegrænset dict → Skiftet til `NSCache` med OS-managed eviction.
4. **[Fikset]** isCurrent-cell manglede visuel spec → Tilføjet: primary border-ring + drop-shadow + pulserende dot, kombinérbar med alle tre status-farver.
5. **[Fikset]** Staggered animation + LazyVGrid ikke trivielt → Markeret som polish/optional med acceptable fallback.
6. **[Fikset]** teacher_comment tom-streng normalisering → Backenden normaliserer `""` til `null` i Pydantic field_validator. iOS behøver ikke `!isEmpty`-check.
