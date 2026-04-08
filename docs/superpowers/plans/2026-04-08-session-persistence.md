# Session Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOS persisterer elevens chat-historik via eksisterende ChatMessage-endpoints + en ny Scan-upload-primitiv, så hele samtalen overlever app-lukning og reload.

**Architecture:** Ny generisk `Scan`-tabel + `/scans/upload` og `/scans/{id}/image` endpoints på backend. iOS får `ContentValue`-typed JSON-wrapper, `ChatMessagePersistence`-mapping per content_type, `syncedMessageIds: Set<UUID>` sync-semantik, og `isLoadingHistory`-gate. Alle scannede billeder (både Apple- og Vision-OCR-pathe) uploades parallelt med OCR-kæden, så persisteringen overlever uanset hvilken path blev brugt.

**Tech Stack:** FastAPI + SQLAlchemy + pytest (backend), SwiftUI + URLSession + manual QA (iOS — intet XCTest-target eksisterer, så iOS verificeres via backend-tests for kontraktdelen + manuel end-to-end test for flow-delen).

**Source spec:** `docs/superpowers/specs/2026-04-08-session-persistence-design.md`

---

## Filstruktur (decomposition)

**Nye filer:**

| Fil | Ansvar |
|---|---|
| `backend/app/routers/scans.py` | POST /scans/upload + GET /scans/{id}/image. Stateless handlers — al preprocessing kommer fra `image_preprocessor.py`. |
| `backend/tests/test_scans.py` | Pytest-tests der dækker upload, retrieval, og 404-tilfældet. |
| `ios/Kvante/Kvante/Models/ChatMessagePersistence.swift` | `toCreateDTO()` + `fromLoadedDTO()`. Isoleret persist-laget så `ChatMessage`-filen og `ChatViewModel` ikke forurenes med mapping-kode. |
| `ios/Kvante/Kvante/Views/Chat/ScannedImageView.swift` | Viser enten in-memory Data eller AsyncImage fra scanId. Én view for både scenariet "lige scannet" og "loadet fra backend". |

**Modificerede filer:**

| Fil | Ændring |
|---|---|
| `backend/app/models/db.py` | Tilføj `Scan`-model (3 felter: id, image_path, created_at) |
| `backend/app/models/schemas.py` | Tilføj `ScanUploadResponse` med `scan_id`-felt |
| `backend/app/main.py` | Registrér `scans.router` |
| `ios/Kvante/Kvante/Models/APIResponses.swift` | Tilføj `ContentValue`-enum + `ScanUploadResponse`, `ChatMessageCreate`, `ChatMessageOut` DTO-structs |
| `ios/Kvante/Kvante/Services/APIClient.swift` | Tilføj `uploadScan`, `saveMessages`, `loadMessages`, `scanImageURL` |
| `ios/Kvante/Kvante/Models/ChatMessage.swift` | `let id = UUID()` → parameteriseret init. `scannedImage(Data)` → `scannedImage(Data?, scanId: String?)`. Tilføj `assignmentId: String?`. |
| `ios/Kvante/Kvante/Views/Chat/ChatBubble.swift` | Opdater `scannedImageBubble` til at bruge `ScannedImageView`. Opdater case-destruktureringen. |
| `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift` | Stor refaktor: `syncedMessageIds`, `isLoadingHistory`, `appendMessage`-wrapper, alle 20 `messages.append` sites opdateret, `scanAnswer` parallel upload, `requestHelp` indsætter example-anchor-besked. |
| `ios/Kvante/Kvante/Views/Chat/ChatView.swift` | `if viewModel.isLoadingHistory { ProgressView() }` gate før chat-UI'et. |

---

## Vigtigt om Xcode-projektet

Nye Swift-filer skal tilføjes til `Kvante.xcodeproj` før de kompilerer. Efter `Write` af `ChatMessagePersistence.swift` eller `ScannedImageView.swift`:

1. Åbn `/Users/olsen/code/Kvante/ios/Kvante/Kvante.xcodeproj` i Xcode.
2. Højreklik på det tilsvarende gruppe-folder i navigatoren (Models eller Views/Chat).
3. **Add Files to "Kvante"…** → vælg den nye .swift-fil → sæt flueben på "Kvante"-target → Add.
4. Tjek at Build Phases → Compile Sources inkluderer den nye fil.

Dette er en manuel Xcode-operation. CLI-automation kan bryde `project.pbxproj` på subtile måder.

---

## Fase 1: Backend — Scan-tabel, endpoints, tests

### Task 1: Tilføj `Scan`-model til db.py

**Files:**
- Modify: `backend/app/models/db.py`

- [ ] **Step 1: Tilføj Scan-klasse efter Submission-definitionen**

Find slutningen af `Submission`-klassen (omkring linje 103) og tilføj efter den:

```python
class Scan(Base):
    __tablename__ = "scans"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    image_path: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)
```

Ingen FK til Session eller Assignment — bevidst design (se spec beslutning 3).

- [ ] **Step 2: Verificér at modellen indlæses uden fejl**

Kør:
```bash
cd /Users/olsen/code/Kvante/backend && python -c "from app.models.db import Scan; print(Scan.__tablename__)"
```

Expected output: `scans`

- [ ] **Step 3: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/app/models/db.py
git commit -m "feat(backend): add Scan model for generic image blob store"
```

---

### Task 2: Tilføj `ScanUploadResponse` schema

**Files:**
- Modify: `backend/app/models/schemas.py`

- [ ] **Step 1: Tilføj ScanUploadResponse til schemas.py**

Åbn filen og find en passende sektion (fx efter `ErrorResponse` omkring linje 108). Tilføj:

```python
# --- Scans ---

class ScanUploadResponse(BaseModel):
    scan_id: str
```

- [ ] **Step 2: Verificér schema indlæses**

```bash
cd /Users/olsen/code/Kvante/backend && python -c "from app.models.schemas import ScanUploadResponse; print(ScanUploadResponse.model_fields)"
```

Expected: dict der viser `scan_id` som required string.

- [ ] **Step 3: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/app/models/schemas.py
git commit -m "feat(backend): add ScanUploadResponse schema"
```

---

### Task 3: Skriv failing test for POST /scans/upload

**Files:**
- Create: `backend/tests/test_scans.py`

- [ ] **Step 1: Opret test-filen med første test**

Opret `backend/tests/test_scans.py` med indhold:

```python
import io


def _tiny_jpeg_bytes() -> bytes:
    """Minimal valid JPEG-blob til upload-tests (1x1 hvidt pixel, ~125 bytes)."""
    return bytes.fromhex(
        "ffd8ffe000104a46494600010100000100010000ffdb004300080606"
        "070605080707070909080a0c140d0c0b0b0c1912130f141d1a1f1e1d"
        "1a1c1c20242e2720222c231c1c2837292c30313434341f27393d3832"
        "3c2e333432ffdb0043010909090c0b0c180d0d1832211c213232323232"
        "32323232323232323232323232323232323232323232323232323232"
        "32323232323232323232323232ffc00011080001000103012200021101"
        "031101ffc4001f0000010501010101010100000000000000000102030"
        "405060708090a0bffc400b5100002010303020403050504040000017d"
        "01020300041105122131410613516107227114328191a1082342b1c11"
        "552d1f02433627282090a161718191a25262728292a3435363738393a"
        "434445464748494a535455565758595a636465666768696a737475767"
        "778797a838485868788898a92939495969798999aa2a3a4a5a6a7a8a9"
        "aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae"
        "1e2e3e4e5e6e7e8e9eaf1f2f3f4f5f6f7f8f9faffc4001f01000301010"
        "10101010101010000000000000102030405060708090a0bffc400b511"
        "00020102040403040705040400010277000102031104052131061241"
        "510761711322328108144291a1b1c109233352f0156272d10a162434e"
        "125f11718191a262728292a35363738393a434445464748494a535455"
        "565758595a636465666768696a737475767778797a82838485868788"
        "898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9b"
        "ac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae2e3e4e5e6e7e8e9eaf2"
        "f3f4f5f6f7f8f9faffda000c03010002110311003f00fbfcffd9"
    )


def test_upload_scan_returns_scan_id(client, test_db):
    response = client.post(
        "/scans/upload",
        files={"image": ("scan.jpg", io.BytesIO(_tiny_jpeg_bytes()), "image/jpeg")},
    )
    assert response.status_code == 200
    data = response.json()
    assert "scan_id" in data
    assert len(data["scan_id"]) > 0


def test_upload_scan_creates_db_row(client, test_db):
    from app.models.db import Scan

    response = client.post(
        "/scans/upload",
        files={"image": ("scan.jpg", io.BytesIO(_tiny_jpeg_bytes()), "image/jpeg")},
    )
    scan_id = response.json()["scan_id"]

    scan = test_db.query(Scan).filter(Scan.id == scan_id).first()
    assert scan is not None
    assert scan.image_path.endswith(f"scan_{scan_id}.jpg")
    assert "scans/" in scan.image_path
```

- [ ] **Step 2: Kør test og verificér at det fejler**

```bash
cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_scans.py -v
```

Expected: FAIL med noget i retning af `404 Not Found` fordi `/scans/upload` ikke findes endnu.

- [ ] **Step 3: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/tests/test_scans.py
git commit -m "test(backend): failing test for POST /scans/upload"
```

---

### Task 4: Implementér POST /scans/upload

**Files:**
- Create: `backend/app/routers/scans.py`
- Modify: `backend/app/main.py`

- [ ] **Step 1: Opret scans.py router**

```python
# backend/app/routers/scans.py

import logging
import os

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session as DBSession

from app.config import settings
from app.database import get_db
from app.models.db import Scan
from app.models.schemas import ScanUploadResponse

logger = logging.getLogger(__name__)
router = APIRouter()

_scans_dir = os.path.join(settings.upload_dir, "scans")
os.makedirs(_scans_dir, exist_ok=True)


@router.post("/scans/upload", response_model=ScanUploadResponse)
async def upload_scan(
    image: UploadFile = File(...),
    db: DBSession = Depends(get_db),
):
    """Gem et billede som en generisk scan. Bruges af chat-persistering for at
    kunne re-fetche elevens scannede papirer ved session-reload."""
    contents = await image.read()
    if len(contents) > settings.max_upload_size:
        raise HTTPException(status_code=400, detail="Image exceeds maximum upload size (10 MB)")

    scan = Scan(image_path="")
    db.add(scan)
    db.commit()
    db.refresh(scan)

    image_path = os.path.join(_scans_dir, f"scan_{scan.id}.jpg")
    with open(image_path, "wb") as f:
        f.write(contents)

    scan.image_path = image_path
    db.commit()

    logger.info("Scan uploaded: id=%s bytes=%d", scan.id, len(contents))
    return ScanUploadResponse(scan_id=scan.id)
```

Note: vi kører IKKE `preprocess_handwritten_work` her for at holde pathen billig. Scans er til re-display, ikke til OCR-analyse. Den originale opløsning bevares for at gøre bog-arkivet (pakke 5) tro mod hvad eleven skrev.

- [ ] **Step 2: Registrér router i main.py**

Find linje ~11 i `backend/app/main.py`:

```python
from app.routers import assignments, chat, dev_screenshots, feedback, health, library, pages, practice, students, submissions, test_ocr
```

Ændr til:

```python
from app.routers import assignments, chat, dev_screenshots, feedback, health, library, pages, practice, scans, students, submissions, test_ocr
```

Find linje ~100 hvor routers registreres:

```python
app.include_router(dev_screenshots.router)
```

Tilføj en linje lige efter:

```python
app.include_router(dev_screenshots.router)
app.include_router(scans.router)
```

- [ ] **Step 3: Kør test og verificér at det passerer**

```bash
cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_scans.py -v
```

Expected: Begge tests PASS.

- [ ] **Step 4: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/app/routers/scans.py backend/app/main.py
git commit -m "feat(backend): POST /scans/upload endpoint

Stateless scan upload for chat persistence. Scans are stored under
{upload_dir}/scans/ and referenced by ChatMessage content. No OCR
preprocessing — originals kept as-is for reload fidelity."
```

---

### Task 5: Skriv failing test for GET /scans/{id}/image

**Files:**
- Modify: `backend/tests/test_scans.py`

- [ ] **Step 1: Tilføj to nye tests til test_scans.py**

Tilføj i bunden af filen:

```python
def test_get_scan_image_returns_bytes(client, test_db):
    upload = client.post(
        "/scans/upload",
        files={"image": ("scan.jpg", io.BytesIO(_tiny_jpeg_bytes()), "image/jpeg")},
    )
    scan_id = upload.json()["scan_id"]

    response = client.get(f"/scans/{scan_id}/image")
    assert response.status_code == 200
    assert response.headers["content-type"] == "image/jpeg"
    assert response.content == _tiny_jpeg_bytes()


def test_get_scan_image_404_for_missing(client, test_db):
    response = client.get("/scans/nonexistent-id/image")
    assert response.status_code == 404
```

- [ ] **Step 2: Kør test og verificér at det fejler**

```bash
cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_scans.py::test_get_scan_image_returns_bytes tests/test_scans.py::test_get_scan_image_404_for_missing -v
```

Expected: begge FAIL med `404 Not Found` (endpoint findes ikke).

- [ ] **Step 3: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/tests/test_scans.py
git commit -m "test(backend): failing tests for GET /scans/{id}/image"
```

---

### Task 6: Implementér GET /scans/{id}/image

**Files:**
- Modify: `backend/app/routers/scans.py`

- [ ] **Step 1: Tilføj GET-handler til scans.py**

I `backend/app/routers/scans.py`, tilføj efter `upload_scan`:

```python
@router.get("/scans/{scan_id}/image")
def get_scan_image(scan_id: str, db: DBSession = Depends(get_db)):
    """Returnér billedet for et gemt scan. Bruges af iOS ved session-reload."""
    scan = db.query(Scan).filter(Scan.id == scan_id).first()
    if not scan or not os.path.exists(scan.image_path):
        raise HTTPException(status_code=404, detail="Scan not found")
    return FileResponse(scan.image_path, media_type="image/jpeg")
```

- [ ] **Step 2: Kør tests og verificér at de passerer**

```bash
cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_scans.py -v
```

Expected: alle 4 tests i test_scans.py PASS.

- [ ] **Step 3: Kør hele backend-suiten for regression-tjek**

```bash
cd /Users/olsen/code/Kvante/backend && python -m pytest -q
```

Expected: alle eksisterende tests stadig PASS.

- [ ] **Step 4: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/app/routers/scans.py
git commit -m "feat(backend): GET /scans/{id}/image endpoint

Returns stored scan bytes as image/jpeg. 404 if scan row missing
or file removed from disk."
```

---

## Fase 2: iOS — DTO-lag og APIClient

### Task 7: Tilføj ContentValue-enum og chat-persistence DTOs

**Files:**
- Modify: `ios/Kvante/Kvante/Models/APIResponses.swift`

- [ ] **Step 1: Tilføj ContentValue, ScanUploadResponse og chat-DTOs**

Find en passende sektion (fx lige efter `PracticeSessionResponse`) og tilføj:

```swift
// MARK: - Scans

struct ScanUploadResponse: Codable {
    let scanId: String

    enum CodingKeys: String, CodingKey {
        case scanId = "scan_id"
    }
}

// MARK: - Chat Persistence

/// Typed leaf value for ChatMessage content dicts. Spec'et content schemas
/// bruger kun String, Int og Bool på leaf-niveau — ingen nested objekter eller
/// arrays. Derfor denne kompakte enum i stedet for en generisk AnyCodable.
enum ContentValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let b = try? c.decode(Bool.self)   { self = .bool(b);   return }
        if let i = try? c.decode(Int.self)    { self = .int(i);    return }
        throw DecodingError.typeMismatch(
            ContentValue.self,
            .init(codingPath: decoder.codingPath,
                  debugDescription: "Unsupported content value type")
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .int(let i):    try c.encode(i)
        case .bool(let b):   try c.encode(b)
        }
    }

    // Convenience accessors
    var stringValue: String? { if case .string(let s) = self { return s } else { return nil } }
    var intValue: Int? { if case .int(let i) = self { return i } else { return nil } }
    var boolValue: Bool? { if case .bool(let b) = self { return b } else { return nil } }
}

struct ChatMessageCreate: Codable {
    let sender: String           // "kvante" | "student"
    let contentType: String
    let content: [String: ContentValue]
    let assignmentId: String?

    enum CodingKeys: String, CodingKey {
        case sender
        case contentType = "content_type"
        case content
        case assignmentId = "assignment_id"
    }
}

struct ChatMessageOut: Codable {
    let id: String
    let sessionId: String
    let assignmentId: String?
    let sender: String
    let contentType: String
    let content: [String: ContentValue]
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, sender, content
        case sessionId = "session_id"
        case assignmentId = "assignment_id"
        case contentType = "content_type"
        case createdAt = "created_at"
    }
}

struct SaveMessagesRequest: Codable {
    let sessionId: String
    let messages: [ChatMessageCreate]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case messages
    }
}

struct SaveMessagesResponse: Codable {
    let savedCount: Int

    enum CodingKeys: String, CodingKey {
        case savedCount = "saved_count"
    }
}

struct LoadMessagesResponse: Codable {
    let sessionId: String
    let messages: [ChatMessageOut]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case messages
    }
}
```

- [ ] **Step 2: Build i Xcode**

Åbn projektet i Xcode og byg (⌘B). Expected: Build succeeder uden fejl.

Hvis der er fejl om ukendte types, sørg for at filen er en del af `Kvante`-target'et (skulle være det siden den eksisterer allerede).

- [ ] **Step 3: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Models/APIResponses.swift
git commit -m "feat(ios): ContentValue enum and chat persistence DTOs"
```

---

### Task 8: Tilføj APIClient-metoder til upload, save, load

**Files:**
- Modify: `ios/Kvante/Kvante/Services/APIClient.swift`

- [ ] **Step 1: Tilføj de fire metoder**

Find slutningen af `submitWork`-metoden (ca. linje 132) og tilføj efter den:

```swift
// MARK: - Scan Upload

func uploadScan(imageData: Data) async throws -> ScanUploadResponse {
    let url = baseURL.appendingPathComponent("scans/upload")
    var request = URLRequest(url: url, timeoutInterval: timeout)
    request.httpMethod = "POST"

    let boundary = UUID().uuidString
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var body = Data()
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"image\"; filename=\"scan.jpg\"\r\n")
    body.append("Content-Type: image/jpeg\r\n\r\n")
    body.append(imageData)
    body.append("\r\n--\(boundary)--\r\n")
    request.httpBody = body

    let (data, response) = try await session.data(for: request)
    try checkResponse(response, data: data)
    return try decoder.decode(ScanUploadResponse.self, from: data)
}

func scanImageURL(scanId: String) -> URL {
    baseURL.appendingPathComponent("scans/\(scanId)/image")
}

// MARK: - Chat Persistence

func saveMessages(sessionId: String, messages: [ChatMessageCreate]) async throws {
    let url = baseURL.appendingPathComponent("chat/messages/save")
    var request = URLRequest(url: url, timeoutInterval: timeout)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let payload = SaveMessagesRequest(sessionId: sessionId, messages: messages)
    let encoder = JSONEncoder()
    request.httpBody = try encoder.encode(payload)

    let (data, response) = try await session.data(for: request)
    try checkResponse(response, data: data)
    _ = try decoder.decode(SaveMessagesResponse.self, from: data)
}

func loadMessages(sessionId: String) async throws -> [ChatMessageOut] {
    let url = baseURL.appendingPathComponent("chat/messages/\(sessionId)")
    var request = URLRequest(url: url, timeoutInterval: timeout)
    request.httpMethod = "GET"

    let (data, response) = try await session.data(for: request)
    try checkResponse(response, data: data)
    let payload = try decoder.decode(LoadMessagesResponse.self, from: data)
    return payload.messages
}
```

- [ ] **Step 2: Build i Xcode**

Build (⌘B). Expected: ingen fejl.

- [ ] **Step 3: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Services/APIClient.swift
git commit -m "feat(ios): APIClient methods for scan upload and chat persistence"
```

---

## Fase 3: iOS — ChatMessage-modelændringer

### Task 9: Parameterisér ChatMessage.id og tilføj assignmentId + scanId

**Files:**
- Modify: `ios/Kvante/Kvante/Models/ChatMessage.swift`

- [ ] **Step 1: Erstat ChatMessageContent + ChatMessage struct**

Find og erstat hele blokken fra `enum ChatMessageContent` til og med `struct ChatMessage`:

```swift
enum ChatMessageContent {
    case text(String)
    case example(ExampleResponse)
    case exampleStep(AnimationStep, Int, Int, GridState?, ShortDivisionState?, LongMultiplicationState?, ArrayGridState?)  // step, stepNumber, totalSteps, states
    case scannedImage(Data?, scanId: String?)
    case feedback(FeedbackResponse)
    case ocrConfirm(OcrConfirmation)
    case answerResult(AnswerResult)
    case loading(String)
    case assignmentIntro(ParsedAssignment)
    case tip(String)
    case celebration(CelebrationTier)
}

struct OcrConfirmation {
    let readText: String
    let imageData: Data
    let source: String
}

struct AnswerResult {
    let studentAnswer: String
    let correctAnswer: String
    let isCorrect: Bool
    let message: String
    var source: String = ""
    var ocrDebug: String = ""
}

struct ChatMessage: Identifiable {
    let id: UUID
    let sender: ChatSender
    let content: ChatMessageContent
    let timestamp: Date
    var actions: [ActionChipModel]
    var assignmentId: String?

    init(
        id: UUID = UUID(),
        sender: ChatSender,
        content: ChatMessageContent,
        timestamp: Date = Date(),
        actions: [ActionChipModel] = [],
        assignmentId: String? = nil
    ) {
        self.id = id
        self.sender = sender
        self.content = content
        self.timestamp = timestamp
        self.actions = actions
        self.assignmentId = assignmentId
    }
}
```

Bemærk at `OcrConfirmation` og `AnswerResult` er uændrede men skal stadig stå i filen — jeg tager dem med i blokken for at gøre erstatningen entydig.

- [ ] **Step 2: Build og observer forventede fejl**

Build (⌘B). Expected: fejl om `.scannedImage(data)` ikke matcher nyt signatur i `ChatViewModel.swift` og `ChatBubble.swift`. Disse rettes i næste task.

- [ ] **Step 3: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Models/ChatMessage.swift
git commit -m "feat(ios): parameterize ChatMessage.id, add assignmentId, extend scannedImage with scanId

Required for stable UUID across in-place mutation (scan-upload path)
and for the syncedMessageIds set in ChatViewModel."
```

---

### Task 10: Opdater alle `.scannedImage(data)` call sites

**Files:**
- Modify: `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift` (line 312)
- Modify: `ios/Kvante/Kvante/Views/Chat/ChatBubble.swift` (lines 88-89, 339)

- [ ] **Step 1: Opdater ChatViewModel.scanAnswer linje 312**

I `ChatViewModel.swift`, find den ene linje:

```swift
            content: .scannedImage(imageData)
```

Erstat med:

```swift
            content: .scannedImage(imageData, scanId: nil)
```

- [ ] **Step 2: Opdater ChatBubble.bubbleContent switch-case**

I `ChatBubble.swift`, find linjerne:

```swift
        case .scannedImage(let data):
            scannedImageBubble(data)
```

Erstat med:

```swift
        case .scannedImage(let data, let scanId):
            scannedImageBubble(data, scanId: scanId)
```

- [ ] **Step 3: Opdater scannedImageBubble-funktionen**

I `ChatBubble.swift`, find `private func scannedImageBubble(_ data: Data) -> some View`. Erstat hele funktionen med en midlertidig version der fortsat virker uden ScannedImageView (som kommer i næste task):

```swift
    private func scannedImageBubble(_ data: Data?, scanId: String?) -> some View {
        Group {
            if let data, let uiImage = UIImage(data: data) {
                VStack(alignment: .trailing, spacing: 4) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220, maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            } else if scanId != nil {
                ProgressView()
                    .frame(width: 220, height: 180)
            } else {
                Text("📷 Billedet kunne ikke hentes")
                    .font(.caption)
                    .foregroundStyle(KvanteTheme.Colors.textMuted)
            }
        }
    }
```

- [ ] **Step 4: Build og verificér at compilation lykkes**

Build (⌘B). Expected: alle fejl fra Task 9 er væk. Build succeeder.

- [ ] **Step 5: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/ViewModels/ChatViewModel.swift ios/Kvante/Kvante/Views/Chat/ChatBubble.swift
git commit -m "fix(ios): update scannedImage call sites for new tuple signature"
```

---

## Fase 4: iOS — Persistence-mapping

### Task 11: Opret ChatMessagePersistence.swift med toCreateDTO

**Files:**
- Create: `ios/Kvante/Kvante/Models/ChatMessagePersistence.swift`

- [ ] **Step 1: Opret filen med toCreateDTO-ekstensionen**

```swift
// ios/Kvante/Kvante/Models/ChatMessagePersistence.swift
import Foundation

extension ChatSender {
    var rawPersistenceString: String {
        switch self {
        case .kvante:  return "kvante"
        case .student: return "student"
        }
    }

    static func fromPersistenceString(_ s: String) -> ChatSender? {
        switch s {
        case "kvante":  return .kvante
        case "student": return .student
        default:        return nil
        }
    }
}

extension CelebrationTier {
    var rawPersistenceString: String {
        switch self {
        case .routine:     return "routine"
        case .persevered:  return "persevered"
        case .setComplete: return "set_complete"
        }
    }

    static func fromPersistenceString(_ s: String) -> CelebrationTier? {
        switch s {
        case "routine":     return .routine
        case "persevered":  return .persevered
        case "set_complete": return .setComplete
        default:            return nil
        }
    }
}

extension ChatMessage {
    /// Konverterer beskeden til en backend-DTO. Returnerer nil for cases vi
    /// ikke persisterer (loading, ocrConfirm, example, exampleStep) eller for
    /// scannedImage der endnu ikke har en scan_id.
    func toCreateDTO() -> ChatMessageCreate? {
        let senderStr = sender.rawPersistenceString

        switch content {
        case .text(let s):
            return ChatMessageCreate(
                sender: senderStr,
                contentType: "text",
                content: ["text": .string(s)],
                assignmentId: assignmentId
            )

        case .assignmentIntro(let parsed):
            return ChatMessageCreate(
                sender: senderStr,
                contentType: "assignment_intro",
                content: [
                    "assignment_id":        .string(parsed.id),
                    "local_id":             .string(parsed.localId),
                    "text":                 .string(parsed.text),
                    "type":                 .string(parsed.type),
                    "topic":                .string(parsed.topic),
                    "difficulty_estimate":  .int(parsed.difficultyEstimate),
                ],
                assignmentId: parsed.id
            )

        case .scannedImage(_, let scanId):
            guard let scanId else { return nil }
            return ChatMessageCreate(
                sender: senderStr,
                contentType: "scanned_image",
                content: ["scan_id": .string(scanId)],
                assignmentId: assignmentId
            )

        case .feedback(let fb):
            return ChatMessageCreate(
                sender: senderStr,
                contentType: "feedback",
                content: [
                    "feedback_text": .string(fb.feedbackText),
                    "tone":          .string(fb.tone),
                ],
                assignmentId: assignmentId
            )

        case .answerResult(let r):
            return ChatMessageCreate(
                sender: senderStr,
                contentType: "answer_result",
                content: [
                    "correct":         .bool(r.isCorrect),
                    "student_answer":  .string(r.studentAnswer),
                    "expected_answer": .string(r.correctAnswer),
                    "message":         .string(r.message),
                ],
                assignmentId: assignmentId
            )

        case .tip(let s):
            return ChatMessageCreate(
                sender: senderStr,
                contentType: "tip",
                content: ["text": .string(s)],
                assignmentId: assignmentId
            )

        case .celebration(let tier):
            return ChatMessageCreate(
                sender: senderStr,
                contentType: "celebration",
                content: ["tier": .string(tier.rawPersistenceString)],
                assignmentId: assignmentId
            )

        // Ikke persisteret — transient UI
        case .loading, .ocrConfirm, .example, .exampleStep:
            return nil
        }
    }
}
```

Bemærk: jeg har udeladt `structured_prompts` fra `feedback`-persisteringen — de er interaktive action-chips der ikke giver mening ved reload. Feedback-teksten + tone er nok til at rekonstruere den visuelle bobbel.

- [ ] **Step 2: Tilføj filen til Xcode-projektet**

Åbn Xcode → højreklik på `Models`-gruppen → **Add Files to "Kvante"…** → vælg `ChatMessagePersistence.swift` → sæt flueben på "Kvante"-target → Add.

- [ ] **Step 3: Build**

Build (⌘B). Expected: ingen fejl.

- [ ] **Step 4: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Models/ChatMessagePersistence.swift ios/Kvante/Kvante/Kvante.xcodeproj/project.pbxproj
git commit -m "feat(ios): ChatMessage.toCreateDTO() for persistence mapping"
```

---

### Task 12: Tilføj fromLoadedDTO til ChatMessagePersistence.swift

**Files:**
- Modify: `ios/Kvante/Kvante/Models/ChatMessagePersistence.swift`

- [ ] **Step 1: Tilføj fromLoadedDTO-ekstensionen**

I bunden af `ChatMessagePersistence.swift`, tilføj:

```swift
extension ChatMessage {
    /// Rekonstruerer en ChatMessage fra backend-DTO. Returnerer nil hvis
    /// content_type er ukendt eller påkrævede felter mangler — disse
    /// beskeder springes over i reload.
    static func fromLoadedDTO(
        _ dto: ChatMessageOut,
        assignments: [String: ParsedAssignment]
    ) -> ChatMessage? {
        guard let sender = ChatSender.fromPersistenceString(dto.sender) else { return nil }

        let content: ChatMessageContent
        switch dto.contentType {
        case "text":
            guard let text = dto.content["text"]?.stringValue else { return nil }
            content = .text(text)

        case "assignment_intro":
            guard let assignmentId = dto.content["assignment_id"]?.stringValue,
                  let localId = dto.content["local_id"]?.stringValue,
                  let text = dto.content["text"]?.stringValue,
                  let type = dto.content["type"]?.stringValue,
                  let topic = dto.content["topic"]?.stringValue,
                  let difficulty = dto.content["difficulty_estimate"]?.intValue
            else { return nil }
            // Prefer eksisterende assignment fra dictionary hvis det findes
            // (har mere komplet position_on_page-data end det persisterede)
            let parsed = assignments[assignmentId] ?? ParsedAssignment(
                id: assignmentId,
                localId: localId,
                text: text,
                type: type,
                topic: topic,
                difficultyEstimate: difficulty,
                positionOnPage: ""
            )
            content = .assignmentIntro(parsed)

        case "scanned_image":
            guard let scanId = dto.content["scan_id"]?.stringValue else { return nil }
            content = .scannedImage(nil, scanId: scanId)

        case "feedback":
            guard let feedbackText = dto.content["feedback_text"]?.stringValue else { return nil }
            let tone = dto.content["tone"]?.stringValue ?? "warm"
            let fb = FeedbackResponse(
                feedbackText: feedbackText,
                tone: tone,
                structuredPrompts: []  // ikke persisteret, genopbygges ikke
            )
            content = .feedback(fb)

        case "answer_result":
            guard let correct = dto.content["correct"]?.boolValue,
                  let studentAnswer = dto.content["student_answer"]?.stringValue,
                  let expectedAnswer = dto.content["expected_answer"]?.stringValue
            else { return nil }
            let message = dto.content["message"]?.stringValue ?? ""
            content = .answerResult(AnswerResult(
                studentAnswer: studentAnswer,
                correctAnswer: expectedAnswer,
                isCorrect: correct,
                message: message,
                source: "",
                ocrDebug: ""
            ))

        case "tip":
            guard let text = dto.content["text"]?.stringValue else { return nil }
            content = .tip(text)

        case "celebration":
            guard let tierStr = dto.content["tier"]?.stringValue,
                  let tier = CelebrationTier.fromPersistenceString(tierStr)
            else { return nil }
            content = .celebration(tier)

        default:
            return nil  // Ukendt content_type — skip
        }

        // Generér en frisk UUID ved reload. Backend-id'et er ikke relevant for
        // iOS-side identity; kun rækkefølgen er autoritativ.
        return ChatMessage(
            id: UUID(),
            sender: sender,
            content: content,
            timestamp: Date(),  // backend created_at er kun til ordering
            actions: [],
            assignmentId: dto.assignmentId
        )
    }
}
```

`FeedbackResponse` skal kunne konstrueres direkte — verificér at den har en memberwise init (auto-synthesized fra Codable). Hvis Xcode klager, kan struct'en have en custom init der forhindrer det — i så fald tilføj en explicit init.

- [ ] **Step 2: Build**

Build (⌘B). Expected: ingen fejl. Hvis `FeedbackResponse`-init-kaldet fejler, kig på `APIResponses.swift` og tilføj en eksplicit init der matcher feltrækkefølgen.

- [ ] **Step 3: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Models/ChatMessagePersistence.swift
git commit -m "feat(ios): ChatMessage.fromLoadedDTO for reload hydration"
```

---

## Fase 5: iOS — ChatViewModel refaktor

### Task 13: Tilføj syncedMessageIds, isLoadingHistory og appendMessage

**Files:**
- Modify: `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift`

- [ ] **Step 1: Tilføj state properties øverst i klassen**

Find i ChatViewModel.swift (ca. linje 8-12):

```swift
    var messages: [ChatMessage] = []
    var isLoading = false
    var showScanner = false
    var inputText = ""
```

Erstat med:

```swift
    var messages: [ChatMessage] = []
    var isLoading = false
    var isLoadingHistory = true
    var showScanner = false
    var inputText = ""

    private var syncedMessageIds: Set<UUID> = []
    private var isSyncing = false
    private var pendingSync = false
```

- [ ] **Step 2: Tilføj appendMessage og syncUnsavedMessages-metoderne**

Find `// MARK: - Loading Helpers` (ca. linje 661). Tilføj en ny MARK-sektion lige før den:

```swift
    // MARK: - Persistence

    /// Append en besked til messages[] og tag automatisk currentAssignmentId
    /// hvis beskeden ikke selv har et. Alle eksisterende messages.append-kald
    /// skal gå gennem denne metode.
    private func appendMessage(_ msg: ChatMessage) {
        var tagged = msg
        if tagged.assignmentId == nil {
            tagged.assignmentId = currentAssignment.id
        }
        messages.append(tagged)
        syncUnsavedMessages()
    }

    /// Kald dette når en eksisterende besked muterer i-place (fx scanId sat
    /// efter upload er færdig). syncUnsavedMessages tager sig af at plukke de
    /// muterede beskeder op næste gang.
    private func syncUnsavedMessages() {
        if isSyncing {
            pendingSync = true
            return
        }

        // Find unsynced messages og deres DTO-repræsentationer
        let unsynced = messages.filter { !syncedMessageIds.contains($0.id) }
        var pairs: [(id: UUID, dto: ChatMessageCreate)] = []
        for msg in unsynced {
            if let dto = msg.toCreateDTO() {
                pairs.append((msg.id, dto))
            }
        }

        if pairs.isEmpty {
            return  // ingen DTO'er at sende — beskeder med nil DTO forbliver uden for sættet
        }

        let toSave = pairs.map { $0.dto }
        let idsBeingSent = pairs.map { $0.id }
        isSyncing = true

        Task { @MainActor in
            defer {
                self.isSyncing = false
                if self.pendingSync {
                    self.pendingSync = false
                    self.syncUnsavedMessages()
                }
            }
            do {
                try await self.apiClient.saveMessages(sessionId: self.sessionId, messages: toSave)
                self.syncedMessageIds.formUnion(idsBeingSent)
            } catch {
                // Sættet rykker ikke; næste append eller mutation retrier
                print("[ChatViewModel] saveMessages failed: \(error)")
            }
        }
    }

    /// Load eksisterende historik fra backend. Kaldes én gang i init.
    private func loadExistingMessages() async {
        do {
            let dtos = try await apiClient.loadMessages(sessionId: sessionId)
            let byId = Dictionary(uniqueKeysWithValues: allAssignments.map { ($0.id, $0) })
            let loaded = dtos.compactMap { ChatMessage.fromLoadedDTO($0, assignments: byId) }
            self.messages = loaded
            self.syncedMessageIds = Set(loaded.map { $0.id })
        } catch {
            print("[ChatViewModel] loadMessages failed: \(error)")
            // Fail silently — messages forbliver tom, sendWelcome kaldes bagefter
        }
    }
```

- [ ] **Step 3: Opdater init() til at kalde load async**

Find init-metoden (ca. linje 67-72):

```swift
    init(assignments: [ParsedAssignment], sessionId: String, apiClient: APIClient) {
        self.allAssignments = assignments
        self.sessionId = sessionId
        self.apiClient = apiClient
        sendWelcome()
    }
```

Erstat med:

```swift
    init(assignments: [ParsedAssignment], sessionId: String, apiClient: APIClient) {
        self.allAssignments = assignments
        self.sessionId = sessionId
        self.apiClient = apiClient

        Task { @MainActor in
            await loadExistingMessages()
            if messages.isEmpty {
                sendWelcome()
            }
            isLoadingHistory = false
        }
    }
```

- [ ] **Step 4: Build og verificér at der kun er fejl om `appendMessage`/`messages.append`-inkonsistens**

Build (⌘B). Expected: sandsynligvis ingen kompileringsfejl, men `appendMessage` er endnu ikke brugt nogen steder. De eksisterende `messages.append(...)`-kald rykkes i næste task.

- [ ] **Step 5: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/ViewModels/ChatViewModel.swift
git commit -m "feat(ios): ChatViewModel syncedMessageIds + load-on-init

Adds the sync plumbing without rewiring existing append sites yet.
Existing messages.append() calls continue to work — they just don't
trigger persistence until task 14 routes them through appendMessage."
```

---

### Task 14: Rut alle messages.append gennem appendMessage

**Files:**
- Modify: `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift`

Dette er den mest mekaniske del af planen. Alle 20 direkte `messages.append(...)`-kald (inkl. det i `replaceLoading`'s else-gren) opdateres til `appendMessage(...)`.

- [ ] **Step 1: Opdater alle append-sites**

Brug Xcode's Find & Replace (⌘⌥F) i `ChatViewModel.swift` **kun**:

Find: `messages.append(`
Replace: `appendMessage(`

**VIGTIGT:** `messages[index] = message` på ca. linje 673 i `replaceLoading` skal IKKE erstattes — den er en in-place mutation, ikke en append. Find-replacen matcher heller ikke den, fordi mønstret er `messages[`, ikke `messages.append(`.

`messages.firstIndex` og `messages.contains` skal heller ikke erstattes (og matches ikke af mønstret).

Verificér at alle append-kald er væk:

```bash
grep -c "messages\.append(" /Users/olsen/code/Kvante/ios/Kvante/Kvante/ViewModels/ChatViewModel.swift
```

Expected: `0`.

```bash
grep -c "appendMessage(" /Users/olsen/code/Kvante/ios/Kvante/Kvante/ViewModels/ChatViewModel.swift
```

Expected: `21` (20 call sites + 1 metodedefinition i `private func appendMessage(_ msg: ChatMessage)`).

- [ ] **Step 2: Ret replaceLoading til at trigge sync ved in-place opdatering**

Find `replaceLoading` (ca. linje 671):

```swift
    private func replaceLoading(_ id: UUID, with message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index] = message
        } else {
            appendMessage(message)
        }
        isLoading = false
    }
```

Erstat med:

```swift
    private func replaceLoading(_ id: UUID, with message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            var replacement = message
            if replacement.assignmentId == nil {
                replacement.assignmentId = currentAssignment.id
            }
            messages[index] = replacement
            syncUnsavedMessages()
        } else {
            appendMessage(message)
        }
        isLoading = false
    }
```

Dette sikrer at beskeder der erstatter en loading-spinner (som IKKE persisteres) selv bliver sync'et når de sættes på plads.

- [ ] **Step 3: Build og verificér**

Build (⌘B). Expected: ingen fejl.

- [ ] **Step 4: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/ViewModels/ChatViewModel.swift
git commit -m "refactor(ios): route all messages.append through appendMessage

All 19 append sites now flow through the persistence helper. replaceLoading
also triggers sync when it swaps a loading spinner for a real message.
Loading messages themselves return nil from toCreateDTO so they never
reach the backend."
```

---

### Task 15: Scan-upload parallelt med OCR i scanAnswer

**Files:**
- Modify: `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift`

- [ ] **Step 1: Opdater scanAnswer til at starte upload parallelt**

Find starten af `scanAnswer(_ imageData: Data)` (ca. linje 308). De første linjer er:

```swift
    func scanAnswer(_ imageData: Data) {
        // Student message with scanned image
        appendMessage(ChatMessage(
            sender: .student,
            content: .scannedImage(imageData, scanId: nil)
        ))

        let loadingId = addLoading("Kvante tyder dit svar...")
```

Erstat de linjer med:

```swift
    func scanAnswer(_ imageData: Data) {
        // Student message with scanned image — UUID bevares for senere mutation
        let scanMessageId = UUID()
        appendMessage(ChatMessage(
            id: scanMessageId,
            sender: .student,
            content: .scannedImage(imageData, scanId: nil)
        ))

        // Parallel upload til backend så billedet kan genfetches ved reload
        Task { @MainActor in
            do {
                let response = try await self.apiClient.uploadScan(imageData: imageData)
                if let idx = self.messages.firstIndex(where: { $0.id == scanMessageId }) {
                    let old = self.messages[idx]
                    self.messages[idx] = ChatMessage(
                        id: scanMessageId,                              // ← samme UUID
                        sender: old.sender,
                        content: .scannedImage(imageData, scanId: response.scanId),
                        timestamp: old.timestamp,
                        actions: old.actions,
                        assignmentId: old.assignmentId
                    )
                    self.syncUnsavedMessages()
                }
            } catch {
                // Upload fejlede — beskeden beholder scanId: nil og persisteres aldrig
                print("[ChatViewModel] scan upload failed: \(error)")
            }
        }

        let loadingId = addLoading("Kvante tyder dit svar...")
```

Resten af `scanAnswer` forbliver uændret.

- [ ] **Step 2: Build og verificér**

Build (⌘B). Expected: ingen fejl.

- [ ] **Step 3: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/ViewModels/ChatViewModel.swift
git commit -m "feat(ios): parallel scan upload in scanAnswer

Uploads the scanned image to /scans/upload in a background task while
the OCR pipeline runs. Same UUID is preserved across the mutation so
syncedMessageIds works correctly."
```

---

### Task 16: Indsæt example-anchor-besked i requestHelp

**Files:**
- Modify: `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift`

- [ ] **Step 1: Tilføj ankerbesked før eksempel-flow starter**

Find `requestHelp`-metoden (ca. linje 215) og specifikt blokken der tilføjer intro-beskeden:

```swift
                // Show intro message
                replaceLoading(loadingId, with: ChatMessage(
                    sender: .kvante,
                    content: .text("Her er et eksempel med andre tal: \(example.exampleProblem)")
                ))

                // Show first step
                showNextExampleStep()
```

Erstat med:

```swift
                // Show intro message (denne er nu vores persisterede ankerbesked —
                // de efterfølgende exampleStep-animationer er ephemerale og vises
                // kun under den aktive session)
                replaceLoading(loadingId, with: ChatMessage(
                    sender: .kvante,
                    content: .text("💡 Her er et eksempel med andre tal: \(example.exampleProblem)")
                ))

                // Show first step
                showNextExampleStep()
```

Den eksisterende intro-tekst bliver nu ankerbeskeden. `.exampleStep`-cases returnerer fortsat nil fra `toCreateDTO()` og persisteres ikke. Ved reload ser eleven "💡 Her er et eksempel med andre tal: X" som en almindelig tekstbobble, men ikke selve grid-animationerne.

- [ ] **Step 2: Build og verificér**

Build (⌘B). Expected: ingen fejl.

- [ ] **Step 3: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/ViewModels/ChatViewModel.swift
git commit -m "feat(ios): mark example intro as persistence anchor

Adds 💡 emoji prefix to the example intro message so reload shows a
recognizable marker bubble where the example animation once played.
The exampleStep cases themselves remain ephemeral."
```

---

## Fase 6: iOS — ScannedImageView og ChatView-gate

### Task 17: Opret ScannedImageView helper

**Files:**
- Create: `ios/Kvante/Kvante/Views/Chat/ScannedImageView.swift`

- [ ] **Step 1: Opret filen**

```swift
// ios/Kvante/Kvante/Views/Chat/ScannedImageView.swift
import SwiftUI

/// Viser et scannet billede enten fra in-memory Data (lige scannet) eller
/// via AsyncImage fra backendens /scans/{id}/image (loadet fra historik).
struct ScannedImageView: View {
    let data: Data?
    let scanId: String?
    let apiClient: APIClient

    var body: some View {
        Group {
            if let data, let uiImage = UIImage(data: data) {
                imageFrame(uiImage: uiImage)
            } else if let scanId {
                AsyncImage(url: apiClient.scanImageURL(scanId: scanId)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 220, height: 180)
                    case .success(let img):
                        imageFrameFromSwiftUIImage(img)
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private func imageFrame(uiImage: UIImage) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220, maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func imageFrameFromSwiftUIImage(_ img: Image) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            img
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220, maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var placeholder: some View {
        Text("📷 Billedet kunne ikke hentes")
            .font(.caption)
            .foregroundStyle(KvanteTheme.Colors.textMuted)
            .frame(width: 220, height: 60)
    }
}
```

- [ ] **Step 2: Tilføj filen til Xcode-projektet**

Åbn Xcode → højreklik på `Views/Chat`-gruppen → **Add Files to "Kvante"…** → vælg `ScannedImageView.swift` → sæt flueben på "Kvante"-target → Add.

- [ ] **Step 3: Build**

Build (⌘B). Expected: ingen fejl. Den nye view er ikke brugt endnu.

- [ ] **Step 4: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Views/Chat/ScannedImageView.swift ios/Kvante/Kvante/Kvante.xcodeproj/project.pbxproj
git commit -m "feat(ios): ScannedImageView for in-memory and remote scan rendering"
```

---

### Task 18: ChatBubble bruger ScannedImageView

**Files:**
- Modify: `ios/Kvante/Kvante/Views/Chat/ChatBubble.swift`

- [ ] **Step 1: Udskift scannedImageBubble-funktionen**

ChatBubble skal kende APIClient for at kunne bygge scan-URL'en. Den er allerede tilgængelig via environment eller kan injiceres. Den enkleste tilgang: ChatBubble modtager apiClient som parameter.

Find toppen af `ChatBubble`-struct:

```swift
struct ChatBubble: View {
    let message: ChatMessage
    let onChip: (ActionChipModel) -> Void
    var onConfirmAnswer: ((String) -> Void)?
```

Tilføj `apiClient`:

```swift
struct ChatBubble: View {
    let message: ChatMessage
    let apiClient: APIClient
    let onChip: (ActionChipModel) -> Void
    var onConfirmAnswer: ((String) -> Void)?
```

Find den nuværende `scannedImageBubble`-funktion (ca. linje 339) og erstat hele funktionen med:

```swift
    private func scannedImageBubble(_ data: Data?, scanId: String?) -> some View {
        ScannedImageView(data: data, scanId: scanId, apiClient: apiClient)
    }
```

- [ ] **Step 2: Opdater ChatView til at passe apiClient til ChatBubble**

I `ios/Kvante/Kvante/Views/Chat/ChatView.swift`, find ChatBubble-kaldet (ca. linje 51):

```swift
                        ChatBubble(message: message, onChip: { chip in
                            viewModel.handleChip(chip)
                        }, onConfirmAnswer: { answer in
                            viewModel.confirmAnswer(answer)
                        })
```

Erstat med:

```swift
                        ChatBubble(
                            message: message,
                            apiClient: viewModel.apiClient,
                            onChip: { chip in
                                viewModel.handleChip(chip)
                            },
                            onConfirmAnswer: { answer in
                                viewModel.confirmAnswer(answer)
                            }
                        )
```

- [ ] **Step 3: Build**

Build (⌘B). Expected: ingen fejl.

- [ ] **Step 4: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Views/Chat/ChatBubble.swift ios/Kvante/Kvante/Views/Chat/ChatView.swift
git commit -m "refactor(ios): ChatBubble uses ScannedImageView, accepts APIClient"
```

---

### Task 19: ChatView gater på isLoadingHistory

**Files:**
- Modify: `ios/Kvante/Kvante/Views/Chat/ChatView.swift`

- [ ] **Step 1: Wrap chat-indholdet i en if/else**

Find den ydre `VStack(spacing: 0) { ... }` i `ChatView.body` (ca. linje 8).

Erstat hele body-blokken:

```swift
    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            chatHeader
            ...
```

Med:

```swift
    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            chatHeader

            if viewModel.isLoadingHistory {
                Spacer()
                ProgressView()
                    .scaleEffect(1.4)
                Spacer()
            } else {
                chatContent
            }
        }
        .background(KvanteTheme.Colors.cream)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $viewModel.showScanner) {
            DocumentScannerView(
                onScan: { imageData in
                    viewModel.showScanner = false
                    viewModel.scanAnswer(imageData)
                },
                onCancel: {
                    viewModel.showScanner = false
                }
            )
        }
    }

    @ViewBuilder
    private var chatContent: some View {
        // Progress pill
        if viewModel.allAssignments.count > 1 {
            ProgressPillView(
                currentIndex: viewModel.currentAssignmentIndex,
                totalCount: viewModel.totalAssignments,
                completedIds: viewModel.completedAssignmentIds,
                assignments: viewModel.allAssignments,
                onTapAssignment: { index in
                    viewModel.jumpToAssignment(index)
                }
            )
        }

        // Sticky assignment bar
        HStack(spacing: 8) {
            Text(viewModel.currentAssignment.text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KvanteTheme.Colors.ink)
                .lineLimit(1)
            Spacer()
            Text("Opgave \(viewModel.currentAssignment.localId)")
                .font(.caption.weight(.medium))
                .foregroundStyle(KvanteTheme.Colors.textMuted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(KvanteTheme.Colors.cream)
        .overlay(
            Rectangle()
                .fill(KvanteTheme.Colors.inkSubtle)
                .frame(height: 1),
            alignment: .bottom
        )

        // Messages
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        ChatBubble(
                            message: message,
                            apiClient: viewModel.apiClient,
                            onChip: { chip in
                                viewModel.handleChip(chip)
                            },
                            onConfirmAnswer: { answer in
                                viewModel.confirmAnswer(answer)
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(KvanteTheme.Colors.cream)
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }

        // Input bar
        ChatInputBar(
            text: $viewModel.inputText,
            onSend: { viewModel.sendMessage() },
            onCamera: { viewModel.showScanner = true },
            onHelp: { viewModel.requestHelp() },
            onExplainDifferent: { viewModel.requestExplainDifferent() },
            onSkip: { viewModel.advanceToNextAssignment() }
        )
    }
```

Dette splitter body i to dele: header + loading spinner ELLER header + chat content.

- [ ] **Step 2: Build og verificér**

Build (⌘B). Expected: ingen fejl.

- [ ] **Step 3: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Views/Chat/ChatView.swift
git commit -m "feat(ios): ChatView gates body on isLoadingHistory

Shows ProgressView during async load-from-backend so eleven doesn't
see a blank chat flash on fresh session initialization."
```

---

## Fase 7: Deploy og verifikation

### Task 20: Deploy backend til Mac Mini

**Files:**
- None (bruger eksisterende deploy-script)

- [ ] **Step 1: Verificér at alt er committed**

```bash
cd /Users/olsen/code/Kvante && git status
```

Expected: `working tree clean` eller kun ikke-relaterede filer som TODO.md.

- [ ] **Step 2: Push til origin og deploy**

```bash
cd /Users/olsen/code/Kvante && git push origin main
./scripts/deploy.sh
```

Expected: deploy-scriptet pusher, ssh-puller på Mac Mini, og sundhedstjek passer.

- [ ] **Step 3: Verificér at scan-endpointsene svarer**

```bash
curl -sf http://192.168.1.60:8000/scans/nonexistent/image && echo "FEJL: burde være 404"
curl -sf -o /dev/null -w "%{http_code}\n" http://192.168.1.60:8000/scans/nonexistent/image
```

Expected: første kommando viser "FEJL..." ikke — eller den fejler hvilket er hvad vi vil. Anden viser `404`.

- [ ] **Step 4: Ingen commit nødvendig**

---

### Task 21: End-to-end manuel QA

Det her er primær verifikation for iOS-delen. Kør alle tre scenarier på iPad med den nyligt byggede version.

**Files:**
- None

- [ ] **Step 1: Scenarie A — Apple OCR (single-digit multiplikation)**

1. Start ny session: Øvelser → Gange → Let → Start.
2. Scan et svar på den første opgave (single-digit multiplikation → bruger Apple OCR).
3. Få feedback.
4. Force-quit appen (swipe op i app-switcheren, swipe app'en væk).
5. Åbn appen igen, tap sessionen i session-historikken på home-skærmen.
6. Verificér:
   - **ProgressView** vises kortvarigt.
   - Chat-historikken viser velkomst → assignmentIntro → "Hjælp mig..." (hvis tappet) → scannet billede → feedback.
   - Scrollback virker glat.
   - Det scannede billede renderes (via `/scans/{id}/image`).

- [ ] **Step 2: Scenarie B — Vision OCR (columnar addition med store tal)**

1. Start ny session: Øvelser → Addition → Svær → Start.
2. Scan et svar på en opgave med fx `568 + 275`.
3. Få feedback.
4. Force-quit appen.
5. Åbn appen igen, tap sessionen.
6. Verificér de samme punkter som scenarie A.

- [ ] **Step 3: Scenarie C — Bland med hjælp (example flow)**

1. Start ny session.
2. Tryk på Hjælp-knappen → få et eksempel → klik gennem alle Næste-trin.
3. Scan dit svar → få feedback.
4. Force-quit + genåbn.
5. Verificér:
   - Eksempel-ankerbeskeden ("💡 Her er et eksempel med andre tal: ...") vises.
   - De efterfølgende exampleStep-animationer er IKKE der (tilsigtet).
   - Scannede billede + feedback er der.

- [ ] **Step 4: Backend-inspektion for regressions-tjek**

```bash
ssh oleserver@macmini4 "sqlite3 ~/Kvante/backend/kvante.db 'SELECT session_id, sender, content_type FROM chat_messages ORDER BY created_at DESC LIMIT 20'"
ssh oleserver@macmini4 "ls ~/Kvante/backend/uploads/scans/ | head -20"
```

Expected: rows med content_types `text`, `assignment_intro`, `scanned_image`, `feedback`, `answer_result`, `celebration`. Scans-mappen har scan_*.jpg filer.

- [ ] **Step 5: Opdater TODO.md og project memory**

Flyt "Pakke 1 — Session persistence" fra "Næste features" til "Gennemført" i `TODO.md` med en note om scope og dato.

Opdater `~/.claude/projects/-Users-olsen-code-Kvante/memory/project_next_features.md`: markér pakke 1 som DONE, og pakke 2 som "næste blocker-fri opgave".

- [ ] **Step 6: Commit opdateringer**

```bash
cd /Users/olsen/code/Kvante
git add TODO.md
git commit -m "docs: mark session persistence (pakke 1) as complete"
```

---

## Fase 8: (Valgfri) Merge strategi

Hvis du vil holde alle persistence-commits adskilt fra main indtil QA er færdig:

- [ ] **Alternative Task: Arbejd på en feature-branch**

Hvis du foretrækker at arbejde på en branch i stedet for direkte på main:

```bash
# Før du starter Task 1:
cd /Users/olsen/code/Kvante
git checkout -b feature/session-persistence

# Efter alle tasks + QA passerer:
git checkout main && git pull
git merge --no-ff feature/session-persistence
git push origin main
git branch -d feature/session-persistence
git push origin --delete feature/session-persistence
```

Beslut selv — denne plan er kompatibel med begge strategier.

---

## Succeskriterier (fra spec'et)

- [x] Lyng kan scanne svar, lukke appen, åbne den igen, og se hele historikken inklusive sine scannede papirer.
- [x] Fungerer for både Apple OCR (single-digit, simple stacked) og Vision OCR (long multiplication, columnar).
- [x] Ingen bruger-facing fejl ved netværks-hiccups — degradering er altid lydløs.
- [x] Eksisterende sessioner uden chat-historik i DB'en fungerer uændret (start frisk).
- [x] `exampleStep`-animationer vises som placeholder ved reload, ikke som tom plads.

Disse verificeres i Task 21 (manuel QA).
