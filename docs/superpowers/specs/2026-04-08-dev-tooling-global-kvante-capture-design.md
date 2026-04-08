# Dev-tooling — Global Kvante-capture-knap (2026-04-08)

Dev-only feature der erstatter eksisterende shake-to-screenshot + floating kamera-ikon med en Kvante-branded capture-knap optimeret til note-first TODO-inbox. Feature er `#if DEBUG`-gated og har ingen effekt på release-builds.

Dette dokument er roadmap-item #1 fra `docs/superpowers/specs/2026-04-08-roadmap-reorder.md`. Den er prioriteret #1 fordi PencilKit-annoterede screenshots multiplier på QA-arbejdet for alle efterfølgende pakker (2a, 2b, 3, 4, 5).

## Baggrund

Den eksisterende dev-screenshot-feature (`ios/Kvante/Kvante/Services/DevScreenshotSubmit.swift` + `backend/app/routers/dev_screenshots.py`) er funktionel men har tre begrænsninger der gør den friktionstung:

1. **Ingen annotation** — brugeren kan tilføje en tekst-note, men ikke tegne på screenshottet. Ved bug-rapportering er det et stort tab fordi brugeren vil pege på præcis det område der er problemet.
2. **Screenshot-first semantik** — nuværende flow er "shake → fang skærm → tilføj note". Det passer ikke med den primære use-case som er "feature-idé rammer mig → noter den hurtigt → attach screenshot hvis relevant".
3. **Ingen separation mellem observation og TODO** — alt gemmes i én `dev-screenshots/`-mappe med auto-retention. Feature-idéer og debug-observations blander sig, og vigtige TODOs risikerer at blive auto-slettet når retention rydder op.

Brainstorm 2026-04-08 låste en ny design-retning: note-first sheet med opt-in screenshot, PencilKit-annotation, og to separate storage-paths (TODOs der drænes manuelt vs. observations med auto-retention).

## Beslutninger låst i brainstorm

| Beslutning | Valg | Begrundelse |
|---|---|---|
| Primær use-case | **Idé/TODO-capture (note-first)** | Den primære aktivitet er "få idé → noter hurtigt". Screenshot er sekundært. |
| Auto-capture screenshot ved FAB-tap | **Nej** — opt-in via "Tag billede"-knap i sheet | Holder note-capture ren for kontekst-fri idéer. |
| Shake-gesten | **Fjernes helt** | Brugeren bruger den i praksis ikke. Én trigger (FAB) giver enklere mental model. |
| Observation-path | **Bevares** — som toggle i sheet, default ON = TODO | Brugeren bruger ofte "Claude, kig på sidste screenshot" under dev-sessioner. |
| Knap-placering | **Floating FAB bottom-right** (samme som nuværende kamera-ikon) | Enklest implementation (ViewModifier på ContentView). Visuel redundans med chat-header-Kvante er acceptabel — de har tydeligt forskellige størrelser og roller. |
| Sheet-layout | **Variant A — minimal note-first** | TextField dominerer. Screenshot og toggle som diskret action-row nederst. Hurtig flow. |
| PencilKit-datamodel | **Flat JPEG** — stregerne brændes ind i billedet ved gem | Dev-tooling; re-editering er unødvendig. Halverer data-footprint. |
| Observations annotatable | **Ja** — ingen begrænsning | Annotation er tilgængelig på enhver screenshot-thumbnail, uanset toggle-state. |
| TODO-kategorier | **Flad inbox** — ingen tags | Enkelhed vinder. Kategorisering kan altid tilføjes senere. Brugeren kan skrive "BUG:"-præfiks i note-teksten selv. |
| Nuværende kamera-ikon | **Fjernes** | Erstattes af den nye Kvante-FAB i samme position. |

## Succeskriterier

- Dev-feature er `#if DEBUG`-gated; release-builds kompilerer ingen af de nye filer
- Fra FAB-tap til "Sendt ✓" på en pure note-capture er 3 interaktioner (FAB → skriv → Send). Med screenshot: 4. Med annotation: 6 (inkl. Annotér, tegn, Færdig).
- PencilKit-annotation fungerer på Apple Pencil OG finger-input (simulator + iPads uden pencil)
- TODOs drænes kun manuelt — ingen auto-retention på `dev-todos/`-mappen
- Eksisterende `/dev/screenshots`-endpoints er uændrede så observation-flowet fortsat fungerer
- Brugeren kan skelne mellem TODO og observation mode i sheet'en, og Send-knappen er intelligently disabled for ugyldige kombinationer (tom TODO eller tom observation)

## Arkitektur-overblik

Feature består af to løst koblede lag: iOS-UI der fanger input, og backend der persisterer til disk. Der er ingen database — al storage er file-based med JSON sidecar-metadata (samme pattern som eksisterende dev-screenshots).

```
iOS (DEBUG only)                      Backend (alle envs)
┌─────────────────────┐               ┌──────────────────────┐
│ Floating Kvante FAB │──tap─────────▶│  POST /dev/todos     │
│ (bottom-right)      │               │  (ny)                │
└─────────────────────┘               │                      │
         │                            │  POST /dev/screenshots│
         ▼                            │  (eksisterende)      │
┌─────────────────────┐               └──────────┬───────────┘
│ Capture-sheet       │                          │
│ - TextField         │                          ▼
│ - "Tag billede"     │               ┌──────────────────────┐
│ - TODO toggle       │               │ ~/Library/Application│
│ - Annotér-knap      │               │   Support/Kvante/    │
│ - Send              │               │                      │
└─────────────────────┘               │ ├── dev-screenshots/ │
         │                            │ │   (retention N)    │
         │ "Annotér"                  │ │                    │
         ▼                            │ └── dev-todos/       │
┌─────────────────────┐               │     (manual drain)   │
│ Full-screen         │               └──────────────────────┘
│ PencilKit editor    │
│ (PKCanvasView +     │
│  PKToolPicker)      │
└─────────────────────┘
```

**Routing-logik i iOS:** Capture-sheet'en beslutter endpoint baseret på TODO-toggle:
- `is_todo = true` → `POST /dev/todos` → gemmes i `dev-todos/`
- `is_todo = false` → `POST /dev/screenshots` → gemmes i `dev-screenshots/` (uændret)

**Lifecycle:**
- TODOs drænes manuelt: brugeren læser via Claude-session (`GET /dev/todos`), overfører relevante items til `TODO.md`, og kalder `DELETE /dev/todos/{id}` for at fjerne fra inbox.
- Observations bruges i realtid: `GET /dev/screenshots/latest` under dev-sessioner, auto-retention holder mappen ren.

## iOS — Knap + capture-sheet

### Floating Kvante FAB

Erstatter `DevScreenshotFloatingButton` i `ios/Kvante/Kvante/Services/DevScreenshotSubmit.swift`. Samme ViewModifier-pattern (`.devScreenshotSubmit(apiClient:)`) på ContentView så knappen er global.

- **Visual:** Kvante-styled avatar i en cirkel ~44pt i diameter. Koral/pink pom-pom-antenne oven på + stiliserede øjne der matcher plush-referencen i `docs/design/kvante-plush.jpeg`. Lille "DEV"-badge i hjørnet af cirklen (monospace-font, 8pt, mørk farve) så det er tydeligt at det er en udviklings-knap, ikke produktions-UI.
- **Placering:** `.overlay(alignment: .bottomTrailing)` med 16pt trailing + 16pt bottom padding. Samme placering som det nuværende kamera-ikon.
- **Farve:** Kvantes orange/koral mix fra paletten. Skygge `0 2px 4px rgba(0,0,0,0.25)`.
- **Tap-action:**
  1. Fanger baggrunds-screenshottet af key-window via eksisterende `ScreenshotCapture.captureKeyWindow()` — returnerer `UIImage?` (kan være nil hvis ingen key window)
  2. Gemmer resultatet i `pendingScreenshot: UIImage?` (i memory, ikke vist i UI endnu) — `nil`-tilfældet håndteres i sheet'en (se under)
  3. Præsenterer capture-sheet uanset om capture lykkedes (brugeren skal kunne lave en note-only TODO selvom screenshot fejlede)

### Shake-gesture fjernes

`UIWindow.motionEnded`-extension og `.kvanteDeviceDidShake`-notifikation fjernes fra `DevScreenshotSubmit.swift`. `DevScreenshotSubmitModifier.onReceive` for shake-notifikationen fjernes også.

### Capture-sheet state

```swift
@State var note: String = ""
@State var pendingScreenshot: UIImage?    // fanget ved FAB-tap, skjult indtil attached
@State var attachedScreenshot: UIImage?   // sat når brugeren taper "Tag billede"
@State var isTodo: Bool = true            // default ON
@State var isSubmitting = false
@State var errorMessage: String?
@State var didSucceed = false
@FocusState var noteFocused: Bool
```

`pendingScreenshot` initialiseres fra FAB-tap-closure. Ved sheet-onAppear sætter `noteFocused = true` så keyboard kommer op med det samme.

### Sheet-layout (variant A)

- **Nav bar:**
  - Leading: "Annuller" (dismiss uden at sende)
  - Title: **"Ny capture"** (neutral så den fungerer i begge modes)
  - Trailing: "Send" (submit, disabled når ugyldig — se under)
- **TextField:** `TextField("Hvad vil du huske?", text: $note, axis: .vertical)` med `lineLimit(4...8)`, `.textFieldStyle(.roundedBorder)`, auto-focused via `@FocusState`.
- **Screenshot-sektion** (kun synlig når `attachedScreenshot != nil`):
  - Thumbnail: `Image(uiImage: attachedScreenshot!).resizable().scaledToFit().frame(maxHeight: 120)` med `RoundedRectangle(cornerRadius: 8)`-clip og grey stroke
  - Action-row under thumbnail: "Annotér" (primær, åbner full-screen PencilKit-editor) + "Fjern" (sekundær, sætter `attachedScreenshot = nil`)
- **Action-bar nederst:**
  - "📷 Tag billede"-knap — kopierer `pendingScreenshot` til `attachedScreenshot` ved tap. Disabled når enten `attachedScreenshot != nil` (der er allerede et billede) ELLER `pendingScreenshot == nil` (screenshot-capture fejlede). I sidstnævnte tilfælde vises en lille grå fodnote under knappen: "Kunne ikke fange skærmen".
  - `Spacer()`
  - `Toggle("TODO", isOn: $isTodo)` med `.labelsHidden()` og lille "TODO"-tekst ved siden af (compact layout)

### Send-knap enabled/disabled-logik

```swift
var canSubmit: Bool {
    if isSubmitting { return false }
    if isTodo {
        // TODO mode: note required, screenshot optional
        return !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    } else {
        // Observation mode: screenshot required, note optional
        return attachedScreenshot != nil
    }
}
```

| Mode | Note tom | Note non-tom |
|---|---|---|
| **TODO** | Send disabled | Send enabled (screenshot optional) |
| **Observation**, no screenshot | Send disabled | Send disabled (still no screenshot) |
| **Observation**, screenshot attached | Send enabled | Send enabled |

### Submit-flow

```swift
func submit() async {
    guard canSubmit, let apiClient else { return }
    isSubmitting = true
    errorMessage = nil
    do {
        let imageData = attachedScreenshot?.jpegData(compressionQuality: 0.85)
        if isTodo {
            try await apiClient.submitDevTodo(note: note, imageData: imageData)
        } else {
            // attachedScreenshot is guaranteed non-nil by canSubmit
            try await apiClient.submitDevScreenshot(imageData: imageData!, note: note)
        }
        didSucceed = true
        try? await Task.sleep(nanoseconds: 600_000_000)
        onDismiss()
    } catch {
        errorMessage = error.localizedDescription
        isSubmitting = false
    }
}
```

Ny metode på `APIClient`: `submitDevTodo(note:imageData:)` der rammer `POST /dev/todos` med multipart form-data. Eksisterende `submitDevScreenshot(imageData:note:)` er uændret.

### Feedback

- **Success:** Kort "Sendt ✓"-tekst grøn vises i sheet'en. Auto-dismiss efter 600ms.
- **Error:** Rød fejl-tekst i sheet'en med `error.localizedDescription`. `isSubmitting = false`. Brugeren kan prøve igen.

### Dismiss-adfærd

- `.interactiveDismissDisabled(isSubmitting)` — brugeren kan ikke swipe-dismiss mens en submit kører.
- "Annuller" dismisses straks hvis ikke submitting; annullerer URLSession-task'en hvis midten af submit.
- Ved manual dismiss (cancel eller swipe): `pendingScreenshot` discarded som del af SwiftUI @State-cleanup. Ingen backend-call. Ingen cleanup nødvendig.

## iOS — Annotation-flow (full-screen PencilKit-editor)

### Entry-point

Brugeren har `attachedScreenshot != nil` og taper "Annotér" under thumbnail'en → ny **full-screen cover** præsenteres (`.fullScreenCover`, ikke `.sheet`) så hele iPad-skærmen er til rådighed for annotation.

### Editor-view struktur

Ny fil: `ios/Kvante/Kvante/Services/DevAnnotationEditor.swift`, også `#if DEBUG`-gated.

```swift
struct DevAnnotationEditor: View {
    let originalImage: UIImage
    let onFinish: (UIImage) -> Void    // ny annoteret image
    let onCancel: () -> Void

    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    // ...
}
```

### Layout

- **Nav bar:** `NavigationStack` med `.toolbar`:
  - Leading: "Annuller" (kalder `onCancel`)
  - Principal: **"Annotér"** (title)
  - Trailing: "Færdig" (flatten → kalder `onFinish(flattenedImage)`)
- **Canvas-område:** `ScrollView([.horizontal, .vertical])` der wrapper en `ZStack` med `Image(uiImage: originalImage)` + `CanvasRepresentable`. **Begge har eksplicit `.frame(width: originalImage.size.width, height: originalImage.size.height)`** — dvs. canvas og image deler det samme koordinat-rum (image's native point-dimensioner). ScrollView håndterer tilfældet hvor image er større end skærmen (fx 12.9" iPad screenshot på 11" iPad Pro). **Ingen `scaledToFit`** — det ville skabe et mismatch mellem display-koordinater og flatten-koordinater (se "Flatten-logik" under).
- **PKToolPicker:** Aktiveres via `toolPicker.setVisible(true, forFirstResponder: canvasView)` + `canvasView.becomeFirstResponder()` i `.onAppear`. Viser standard Apple pencil tools (pen, højtvisning, viskelæder, farve-picker, undo/redo).

### CanvasRepresentable (ny UIViewRepresentable-wrapper)

PKCanvasView er UIKit-only — vi skal selv skrive en SwiftUI-wrapper. Lille struct i samme fil som `DevAnnotationEditor`:

```swift
struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput   // Apple Pencil + finger
        canvasView.backgroundColor = .clear    // baggrunds-image synlig igennem
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // No-op — PKCanvasView-instansen er @Binding-ejet af parent view'et
    }
}
```

### Input-kilder

```swift
canvasView.drawingPolicy = .anyInput  // Apple Pencil + finger drawing
canvasView.backgroundColor = .clear   // så baggrunds-image kan ses igennem
```

### Flatten-logik (save til flat JPEG)

**Kritisk:** Koordinat-rummet mellem PKCanvasView og flatten-output skal være det samme. Hvis canvas'en vises i en anden størrelse end `originalImage.size`, vil stregerne blive forkert-positionerede i det fladede billede (de er tegnet i canvas-koordinater, ikke image-koordinater). Vores layout sikrer at canvas-frame matcher `originalImage.size` præcis, så koordinaterne er konsistente.

Ved tap på "Færdig":

```swift
func flattenedImage() -> UIImage {
    // originalImage.size er i points (UIImage.size er altid points, ikke pixels)
    // Canvas-frame er sat til originalImage.size i layoutet, så koordinat-rummet matcher
    let size = originalImage.size
    let format = UIGraphicsImageRendererFormat()
    format.scale = originalImage.scale  // render ved image's native pixel-density
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { _ in
        originalImage.draw(in: CGRect(origin: .zero, size: size))
        let canvasImage = canvasView.drawing.image(
            from: CGRect(origin: .zero, size: size),
            scale: originalImage.scale
        )
        canvasImage.draw(in: CGRect(origin: .zero, size: size))
    }
}
```

**Nøgle-principper:**
1. **`size = originalImage.size` bruges konsistent** — både som canvas-frame i layoutet, som CGRect i `drawing.image(from:)`, og som renderer-størrelse. Det holder hele kæden i samme (point) koordinat-rum.
2. **`scale = originalImage.scale` i stedet for `UIScreen.main.scale`** — sikrer at rendered output har samme pixel-density som input image, uafhængigt af hvilken skærm brugeren tegnede på.
3. **ScrollView håndterer display** — canvas kan være større end den synlige skærm; brugeren scroller for at tegne alle steder. Det påvirker ikke flatten-matematikken.

Resultatet er ét enkelt UIImage med pencil-stregerne brændt ind i original-billedet. Returneres til capture-sheet via `onFinish`-closure, som sætter `attachedScreenshot = flattenedImage` → thumbnail'en i sheet'en opdateres automatisk.

### Cancel-adfærd

Ved tap på "Annuller":
- Ingen flatten
- `onCancel()` kaldes → capture-sheet genvises med `attachedScreenshot` uændret (den ikke-annoterede version)
- Brugeren kan taper "Annotér" igen for at prøve forfra

### Edge cases

| Situation | Håndtering |
|---|---|
| Rotation mid-annotation | `PKCanvasView.drawing` persister på tværs af layout-ændringer. ScrollView re-flow uden at ændre canvas-frame. |
| App i baggrunden | PKCanvasView beholder state. Editor er som brugeren forlod den ved retur. |
| Store screenshots (iPad ~12MB RAW) | Canvas-frame matches image-size i points. ScrollView tillader scroll hvis image > skærm. Flatten sker ved `originalImage.scale` for native pixel-fidelitet. Memory-footprint er acceptabel på moderne iPads. |
| Undo/redo | Håndteres af PKToolPicker's indbyggede undo/redo-knapper. |
| **Koordinat-rum-mismatch** | Forhindret af design: canvas-frame OG flatten CGRect bruger begge `originalImage.size`. Hvis layoutet nogensinde ændres til `scaledToFit`, skal flatten-matematikken genskrives — dokumenteret i kode-kommentar på `flattenedImage()`. |

## Backend — Endpoints + storage

### Nye endpoints (`/dev/todos`)

```
POST   /dev/todos              → opret ny TODO (note required, image optional)
GET    /dev/todos              → list alle TODOs med metadata (newest first)
GET    /dev/todos/latest       → seneste TODO med metadata (convenience)
GET    /dev/todos/{id}         → metadata JSON for specifik TODO
GET    /dev/todos/{id}/image   → image for specifik TODO (404 hvis ingen)
DELETE /dev/todos/{id}         → fjern TODO + evt. image-fil
```

### Eksisterende `/dev/screenshots`-endpoints — uændrede

`POST /dev/screenshots`, `GET /dev/screenshots`, `GET /dev/screenshots/latest`, `GET /dev/screenshots/{id}` bevares præcis som de er. Observation-flowet fra iOS-sheet'en kalder `POST /dev/screenshots` uændret. Kode-mæssigt er eneste ændring at opdatere docstring i `dev_screenshots.py` til at reflektere at shake-gesten er væk.

### Storage-struktur

```
~/Library/Application Support/Kvante/
├── dev-screenshots/          (eksisterende, uændret)
│   ├── <ts>_<id>.png         retention: keep N newest
│   └── <ts>_<id>.json
└── dev-todos/                (ny)
    ├── <ts>_<id>.png         (kun hvis TODO har image)
    └── <ts>_<id>.json        (altid — sidecar metadata)
```

**TODO med image:** `<unix_ts>_<id>.png` + `<unix_ts>_<id>.json`
**TODO uden image:** kun `<unix_ts>_<id>.json`

JSON-sidecar matches eksisterende dev-screenshots pattern:

```python
class TodoMeta(BaseModel):
    id: str                  # 12-char hex uuid
    timestamp: float         # unix epoch seconds
    note: str                # required, non-empty
    has_image: bool
    base_filename: str       # "<ts>_<id>" uden extension; server deriver .json og .png efter behov
```

### Request-shapes

**`POST /dev/todos`:**
```
Content-Type: multipart/form-data
Fields:
  note: str (required, non-empty after strip(), max 10000 chars)
  image: UploadFile (optional)

Responses:
  200: TodoMeta
  400: Note er tom, note > 10000 chars, eller image > max_upload_size
```

**`GET /dev/todos`:**
```json
{
  "todos": [
    { "id": "a1b2c3def456", "timestamp": 1712345678.0, "note": "Husk...", "has_image": true, "base_filename": "1712345678_a1b2c3def456" },
    ...
  ]
}
```

Sorteret newest-first efter `timestamp`.

**`GET /dev/todos/latest`:** Returner `TodoMeta` for nyeste TODO. 404 hvis mappen er tom.

**`GET /dev/todos/{id}`:** Returner `TodoMeta` for specifik TODO. 404 hvis ikke fundet.

**`GET /dev/todos/{id}/image`:** Returner PNG-fil hvis `has_image = true`. 404 hvis ikke fundet eller ingen image.

**`DELETE /dev/todos/{id}`:** Fjern `.json` + evt. `.png`. **204 No Content** ved success (HTTP-konvention for DELETE uden response body), 404 hvis id ikke findes.

### Retention-policy — vigtig forskel fra dev-screenshots

**Ingen auto-retention på `dev-todos/`.** `dev-screenshots/` bruger `dev_screenshots_keep` setting til at slette gamle filer automatisk. `dev-todos/` gør det IKKE — TODOs fjernes kun via eksplicit `DELETE /dev/todos/{id}`. Rationalet: en glemt TODO er en mistet idé. Vi vil hellere have at mappen vokser og brugeren selv dræner den, end at vigtige items ryger ud i baggrunden.

### Fil-modul

Ny fil: `backend/app/routers/dev_todos.py` der følger samme pattern som `dev_screenshots.py` — helper-funktioner (`_storage_dir`, `_meta_path`, `_read_meta`, `_list_todos`) plus endpoint-handlers. Router includes i `backend/app/main.py`:

```python
from app.routers import dev_todos
app.include_router(dev_todos.router)
```

**Route-ordering: kritisk.** FastAPI matcher routes i deklarations-rækkefølge. `/latest` **skal deklareres før** `/{todo_id}` — ellers vil `/{todo_id}` fange strengen `"latest"` som et todo-id og returnere 404. Eksisterende `dev_screenshots.py` har samme constraint og håndterer det korrekt (se `dev_screenshots.py:139-156`). Tilføj inline code-comment ved `/latest`-route i `dev_todos.py`:

```python
# IMPORTANT: /latest MUST be declared before /{todo_id} — FastAPI matches
# routes in declaration order, and /{todo_id} would otherwise capture
# "latest" as an id value and return 404.
@router.get("/latest", response_model=TodoMeta)
async def get_latest_todo():
    ...

@router.get("/{todo_id}", response_model=TodoMeta)
async def get_todo(todo_id: str):
    ...
```

### Konfiguration

Ny setting i `backend/app/config.py`:
```python
dev_todos_dir: str = "~/Library/Application Support/Kvante/dev-todos"
```

`max_upload_size` er delt med dev-screenshots (no new setting). Ingen `dev_todos_keep`-setting (ingen retention).

## Edge cases, fejlhåndtering, tests

### iOS edge cases

| Situation | Adfærd |
|---|---|
| Backend unreachable | Rød fejl-tekst i sheet: "Kunne ikke nå backend". `isSubmitting = false`. Brugeren prøver igen. Ingen lokal retry-queue. |
| Double-tap på Send | `isSubmitting`-flag disabler Send-knappen straks. Second tap er no-op. |
| Swipe-to-dismiss mid-submit | `.interactiveDismissDisabled(isSubmitting)`. |
| Screenshot fanget, sheet cancelled | `pendingScreenshot` discarded som del af SwiftUI state-cleanup. Ingen backend-call. |
| **`captureKeyWindow()` returnerer nil** (ingen key window) | Sheet åbner alligevel. "Tag billede"-knap er disabled med fodnote "Kunne ikke fange skærmen". Brugeren kan stadig lave en note-only TODO. |
| Rotation mid-annotation | `PKCanvasView.drawing` persister på tværs af layout-ændringer. |
| App i baggrunden mid-annotation | PKCanvasView beholder state. Editor er som brugeren forlod den. |
| Meget lang note | Ingen hard limit i UI. Backend-validering: `len(note.strip()) <= 10000`, 400 hvis overskredet. |

### Backend edge cases

| Situation | Adfærd |
|---|---|
| POST uden note eller whitespace-only | 400, "Note er påkrævet" |
| POST med note > 10000 chars | 400, "Note for lang" |
| POST med image > max_upload_size | 400, "Billedet overskrider maksimal størrelse" |
| DELETE på ikke-eksisterende id | 404 |
| Samtidige POSTs | Ingen lås nødvendig — `uuid4().hex[:12]` + unix_ts giver unikke filnavne. |
| Disk fuldt | FastAPI fejler med 500; iOS viser generisk fejl. |
| Ekstern mutation af dev-todos/ (fx manuel sletning af en .json) | `_read_meta`/`_list_todos` har try/except-tolerance som eksisterende `dev_screenshots.py`. Ødelagte filer ignoreres, ikke 500. |

### Fejl-semantik

- **iOS-fejl-tekster** er på dansk: "Kunne ikke nå backend", "Noget gik galt", "Billedet er for stort"
- **Backend-fejl-responses** følger FastAPI `HTTPException` med tekst — ikke stack traces, ikke intern info

### Tests

**Backend — `backend/tests/test_dev_todos.py`**

Spejler `test_dev_screenshots.py` med tilpasninger til den nye note-required semantik:

- `test_post_note_only` — POST uden image → 200, kun `.json` på disk, ingen `.png`
- `test_post_note_and_image` — POST med image → 200, både `.json` og `.png` på disk
- `test_post_missing_note` — POST uden note → 400
- `test_post_whitespace_note` — POST med whitespace-only note → 400
- `test_post_note_too_long` — POST med note > 10000 chars → 400
- `test_post_oversized_image` — POST med image > max_upload_size → 400
- `test_list_newest_first` — GET `/dev/todos` → newest timestamp first
- `test_latest_endpoint` — GET `/dev/todos/latest` → seneste; 404 hvis tom
- `test_get_metadata_by_id` — GET `/dev/todos/{id}` → metadata JSON
- `test_get_image_by_id` — GET `/dev/todos/{id}/image` → image hvis til stede, 404 hvis ikke
- `test_delete_removes_both_files` — DELETE fjerner `.json` + `.png`
- `test_delete_nonexistent` — DELETE på ikke-eksisterende id → 404
- `test_no_auto_retention` — Opret 25 TODOs, assertér at alle 25 `.json`-filer findes på disk (direkte `Path.glob` på storage-dir, ikke bare API-response). POST en yderligere TODO og assertér 26 `.json`-filer på disk. Sikrer at der ikke er nogen skjult retention-logik der kun ville manifestere sig via fil-system-inspektion.

**iOS** — Kvante har ikke fuld test-dækning. Feature er `#if DEBUG`-only, så tests her er lav prioritet. Hvis tid tillader:
- Unit test af `canSubmit`-logikken på `DevCaptureSheet` (note-validation, screenshot-validation, toggle-mode-kombinationer)
- Snapshot test af sheet-layout (nice-to-have, ikke essentielt)
- Manuel QA-tjekliste bliver det primære verification-værktøj. Tjeklisten kører i en separat implementation-plan-fase.

### Production-safety

- **Alt nyt iOS-kode er `#if DEBUG`-gated** — samme pattern som eksisterende `DevScreenshotSubmit.swift`. Release-builds kompilerer ikke `DevCaptureSheet`, `DevAnnotationEditor` eller tilhørende helpers. Verificeres via `xcodebuild -configuration Release` uden fejl og manuel inspektion af resulting `.ipa` (ingen dev-strings).
- **Backend-endpoints er auth-frie** — samme security-posture som eksisterende `/dev/screenshots`. LAN-only er den reelle security-garanti (backend er ikke eksponeret udenfor lokalt netværk). Dokumenteret i CLAUDE.md.
- **Ingen ny data-eksponering** — dev-todos er lokale filer på Mac Mini'en, præcis som dev-screenshots. Ingen cloud, ingen eksterne services.

## Ændringer til eksisterende kode

### Filer der ændres

- `ios/Kvante/Kvante/Services/DevScreenshotSubmit.swift` omdøbes til `DevCaptureButton.swift` — **brug `git mv` (ikke delete+add) så git-historik bevares**
  - `DevScreenshotFloatingButton` erstattes med ny `DevKvanteFloatingButton` (Kvante-styled)
  - `DevScreenshotSubmitSheet` erstattes med ny `DevCaptureSheet` (note-first layout)
  - Shake-gesture-infrastruktur fjernes: `UIWindow.motionEnded`-extension, `.kvanteDeviceDidShake`-notifikation, `.onReceive`-observer i modifier
  - View modifier `.devScreenshotSubmit(apiClient:)` omdøbes til `.devCaptureButton(apiClient:)` (opdater også opkaldet i `ContentView.swift`)
- `ios/Kvante/Kvante/ContentView.swift`
  - Opdater `.devScreenshotSubmit(apiClient: apiClient)` til det nye modifier-navn
- `ios/Kvante/Kvante/Services/APIClient.swift`
  - Tilføj ny `submitDevTodo(note: String, imageData: Data?)` async throws metode
- `backend/app/main.py`
  - Import og include ny `dev_todos.router`
- `backend/app/config.py`
  - Tilføj `dev_todos_dir` setting
- `backend/app/routers/dev_screenshots.py`
  - Kun docstring-opdatering (shake-gesten er væk)

### Nye filer

- `ios/Kvante/Kvante/Services/DevCaptureSheet.swift` — ny capture-sheet (separat fil for læsbarhed — den omdøbte `DevCaptureButton.swift` indeholder kun FAB + modifier)
- `ios/Kvante/Kvante/Services/DevAnnotationEditor.swift` — ny full-screen PencilKit-editor
- `backend/app/routers/dev_todos.py` — ny endpoint-fil
- `backend/tests/test_dev_todos.py` — test-fil

### Filer der skal tilføjes til Xcode-projektet

`DevCaptureSheet.swift` og `DevAnnotationEditor.swift` er nye filer og skal tilføjes til `Kvante.xcodeproj`-target'et. Det kræver manuel indgriben i Xcode (drag-n-drop i project navigator) eller direkte edit af `project.pbxproj`. Omdøbningen af `DevScreenshotSubmit.swift` → `DevCaptureButton.swift` kræver også opdatering af projekt-filen hvis ikke filnavnet automatisk opdateres ved rename.

## Ændringer der IKKE er med i denne spec

- Omdøbning af eksisterende `dev-screenshots/`-mappe eller migrering af gamle screenshots til den nye struktur — vi beholder begge mapper separate
- Kategorisering af TODOs (bug/feature/spørgsmål) — flad inbox er besluttet
- Re-editable annotations (PKDrawing + base image) — flat JPEG er besluttet
- Web-baseret admin-UI til at læse dev-todos — Claude læser direkte via curl under dev-sessioner
- Auto-overførsel af TODOs til `TODO.md` — manuel overførsel er beslutningsmæssigt

## Næste skridt efter denne spec

1. Brugeren reviewer spec'en
2. Ved godkendelse: invoke `superpowers:writing-plans` til at oprette detaljeret implementeringsplan med sekventielle tasks
3. Implementeringsplan udføres i separat session (evt. i git worktree)
4. Efter implementation: manuel QA-tjekliste kører mod Mac Mini backend + MacBook simulator/device
5. Branch merge → TODO.md opdateres med "Gennemført"-note for item #1
