# Dev-tooling Capture-knap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Erstat den eksisterende shake-to-screenshot dev-feature med en Kvante-branded capture-knap der har note-first capture-sheet, PencilKit-annotation, og separate storage-paths for TODOs vs observations.

**Architecture:** Backend får ny `/dev/todos`-endpoint-familie der spejler `/dev/screenshots` men med note-required og image-optional semantik (og uden auto-retention). iOS erstatter den eksisterende FAB + shake-gesture med en global Kvante-styled FAB der åbner et note-first sheet; sheet'en har opt-in screenshot + full-screen PencilKit-editor for annotation. Alt iOS-kode er `#if DEBUG`-gated.

**Tech Stack:** FastAPI + Python (backend), SwiftUI + PencilKit (iOS iOS 26.2+), pytest (backend tests), manuel QA (iOS verification)

**Reference:** `docs/superpowers/specs/2026-04-08-dev-tooling-global-kvante-capture-design.md`

---

## Pre-implementation setup

### Task 1: Opret feature-branch

**Files:**
- None (git operation)

- [ ] **Step 1: Verificer clean working tree**

```bash
cd /Users/olsen/code/Kvante
git status
```

Expected: `working tree clean` (eller kun de kendte untracked filer `docs/design/kvante-plush.jpeg` og `icons/`). Hvis der er uncommitted tracked changes, commit eller stash dem først.

- [ ] **Step 2: Opret og skift til branch**

```bash
git checkout main
git pull
git checkout -b feature/dev-tooling-capture
```

Expected: Branch switched to `feature/dev-tooling-capture`.

- [ ] **Step 3: Push branch til origin**

```bash
git push -u origin feature/dev-tooling-capture
```

Expected: Branch etableret på origin som backup.

---

## Phase A — Backend (`/dev/todos` endpoints)

Backend kan udvikles og testes fuldstændigt lokalt via pytest. iOS-arbejdet i Phase B afhænger af at backend'en kører på Mac Mini — der er et deploy-step i Task 9 der skal køres før iOS-arbejdet kan testes end-to-end.

### Task 2: Config + router scaffolding

**Files:**
- Modify: `backend/app/config.py`
- Create: `backend/app/routers/dev_todos.py`
- Modify: `backend/app/main.py`

Målet med denne task er at have et tomt router-module wired ind i `main.py`, plus konfiguration og model-definitioner klar. Ingen endpoints endnu — de følger i efterfølgende tasks.

- [ ] **Step 1: Tilføj `dev_todos_dir` setting i config.py**

Åbn `backend/app/config.py`. Umiddelbart efter linjen `dev_screenshots_keep: int = 20`, tilføj:

```python
    dev_todos_dir: str = "/Users/oleserver/Library/Application Support/Kvante/dev-todos"
```

Resultatet skal se sådan ud i Settings-klassen:

```python
    dev_screenshots_dir: str = "/Users/oleserver/Library/Application Support/Kvante/dev-screenshots"
    dev_screenshots_keep: int = 20
    dev_todos_dir: str = "/Users/oleserver/Library/Application Support/Kvante/dev-todos"
```

Bemærk: Ingen `dev_todos_keep` setting — der er eksplicit ingen auto-retention.

- [ ] **Step 2: Opret `backend/app/routers/dev_todos.py` skeleton**

Opret ny fil `backend/app/routers/dev_todos.py` med følgende indhold:

```python
"""Dev-only TODO/note inbox for capturing ideas and observations from the iOS app.

The iOS Kvante-capture-knap POSTs notes here (with optional images). The
developer (or Claude in a dev session) can GET/list TODOs and DELETE them
after transferring to the project TODO.md.

Unlike /dev/screenshots, this endpoint family has NO auto-retention: TODOs
persist until explicitly deleted so ideas are not lost to background cleanup.

NOT for production — no auth, no rate limiting. LAN-only by virtue of
the backend itself only being reachable on the local network.
"""
from __future__ import annotations

import json
import logging
import time
import uuid
from pathlib import Path
from typing import List, Optional

from fastapi import APIRouter, File, Form, HTTPException, Response, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel

from app.config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/dev/todos", tags=["dev"])

MAX_NOTE_LENGTH = 10_000


class TodoMeta(BaseModel):
    id: str                  # 12-char hex uuid
    timestamp: float         # unix epoch seconds
    note: str                # required, non-empty
    has_image: bool
    base_filename: str       # "<ts>_<id>" uden extension; server deriver .json og .png efter behov


class TodoListResponse(BaseModel):
    todos: List[TodoMeta]


def _storage_dir() -> Path:
    """Resolve the todos directory, creating it if needed."""
    path = Path(settings.dev_todos_dir)
    path.mkdir(parents=True, exist_ok=True)
    return path


def _meta_path(base_filename: str) -> Path:
    """Sidecar JSON metadata file for a given base filename."""
    return _storage_dir() / f"{base_filename}.json"


def _image_path(base_filename: str) -> Path:
    """PNG image file for a given base filename."""
    return _storage_dir() / f"{base_filename}.png"


def _read_meta(meta_file: Path) -> Optional[TodoMeta]:
    """Read sidecar JSON; returns None for corrupt/missing files."""
    try:
        if not meta_file.exists():
            return None
        data = json.loads(meta_file.read_text())
        return TodoMeta(
            id=data.get("id", ""),
            timestamp=data.get("timestamp", 0.0),
            note=data.get("note", ""),
            has_image=data.get("has_image", False),
            base_filename=data.get("base_filename", meta_file.stem),
        )
    except Exception:
        logger.warning("Failed to read meta for %s", meta_file, exc_info=True)
        return None


def _list_todos(newest_first: bool = True) -> List[TodoMeta]:
    """All TODO metadata, sorted by timestamp."""
    storage = _storage_dir()
    metas: List[TodoMeta] = []
    for meta_file in storage.glob("*.json"):
        meta = _read_meta(meta_file)
        if meta is not None:
            metas.append(meta)
    metas.sort(key=lambda m: m.timestamp, reverse=newest_first)
    return metas


def _find_by_id(todo_id: str) -> Optional[TodoMeta]:
    """Locate a TODO by its id. Returns None if not found."""
    for meta in _list_todos():
        if meta.id == todo_id:
            return meta
    return None
```

- [ ] **Step 3: Registrer router i main.py**

Åbn `backend/app/main.py`. Find linjen med `from app.routers import ...` (omkring line 11). Tilføj `dev_todos` til imports alfabetisk korrekt:

```python
from app.routers import assignments, chat, dev_screenshots, dev_todos, feedback, health, library, pages, practice, scans, students, submissions, test_ocr
```

Scroll ned til hvor routers registreres (omkring line 90-101). Efter `app.include_router(dev_screenshots.router)` tilføj:

```python
app.include_router(dev_todos.router)
```

- [ ] **Step 4: Verificer eksisterende tests stadig passer**

Run:
```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/test_dev_screenshots.py -v
```

Expected: Alle eksisterende `test_dev_screenshots.py`-tests passerer. Intet brudt af de nye imports.

- [ ] **Step 5: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/app/config.py backend/app/routers/dev_todos.py backend/app/main.py
git commit -m "feat(backend): scaffold /dev/todos router module

Add TodoMeta model, helper functions, and config setting. No
endpoints yet — they follow in subsequent tasks."
```

---

### Task 3: POST /dev/todos endpoint (TDD)

**Files:**
- Create: `backend/tests/test_dev_todos.py`
- Modify: `backend/app/routers/dev_todos.py`

- [ ] **Step 1: Opret test-fil med POST-tests**

Opret `backend/tests/test_dev_todos.py` med:

```python
"""Tests for the /dev/todos router."""
import io
import json

import pytest
from PIL import Image

from app.config import settings


@pytest.fixture(autouse=True)
def todos_tmp_dir(tmp_path, monkeypatch):
    """Redirect todos storage to a tmp dir for each test."""
    target = tmp_path / "todos"
    monkeypatch.setattr(settings, "dev_todos_dir", str(target))
    return target


def _png(color: str = "red") -> bytes:
    img = Image.new("RGB", (50, 50), color)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def test_post_note_only(client, todos_tmp_dir):
    """POST with note only — no image — creates a .json file only."""
    resp = client.post(
        "/dev/todos",
        data={"note": "Husk at tilføje long division"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["note"] == "Husk at tilføje long division"
    assert body["has_image"] is False
    assert len(body["id"]) == 12
    assert body["timestamp"] > 0
    assert body["base_filename"].endswith(body["id"])

    # Verify disk state
    jsons = list(todos_tmp_dir.glob("*.json"))
    pngs = list(todos_tmp_dir.glob("*.png"))
    assert len(jsons) == 1
    assert len(pngs) == 0


def test_post_note_and_image(client, todos_tmp_dir):
    """POST with note and image — both .json and .png are created."""
    resp = client.post(
        "/dev/todos",
        data={"note": "knappen er for lille"},
        files={"image": ("shot.png", _png(), "image/png")},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["note"] == "knappen er for lille"
    assert body["has_image"] is True

    jsons = list(todos_tmp_dir.glob("*.json"))
    pngs = list(todos_tmp_dir.glob("*.png"))
    assert len(jsons) == 1
    assert len(pngs) == 1


def test_post_missing_note(client):
    """POST without note field — 400 Bad Request."""
    resp = client.post("/dev/todos", data={})
    assert resp.status_code == 400


def test_post_whitespace_note(client):
    """POST with whitespace-only note — 400 Bad Request."""
    resp = client.post("/dev/todos", data={"note": "   \n\t  "})
    assert resp.status_code == 400


def test_post_note_too_long(client):
    """POST with note > 10000 chars — 400 Bad Request."""
    resp = client.post("/dev/todos", data={"note": "x" * 10_001})
    assert resp.status_code == 400


def test_post_oversized_image(client, monkeypatch):
    """POST with image > max_upload_size — 400 Bad Request."""
    monkeypatch.setattr(settings, "max_upload_size", 100)  # tiny limit
    big_png = _png() * 10  # definitely > 100 bytes
    resp = client.post(
        "/dev/todos",
        data={"note": "test"},
        files={"image": ("shot.png", big_png, "image/png")},
    )
    assert resp.status_code == 400
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/test_dev_todos.py -v
```

Expected: ALLE tests fejler med `404 Not Found` eller lignende (endpoint ikke implementeret endnu).

- [ ] **Step 3: Implementer POST-handleren i dev_todos.py**

Åbn `backend/app/routers/dev_todos.py`. Efter `_find_by_id()`-funktionen, tilføj:

```python
@router.post("", response_model=TodoMeta)
async def create_todo(
    note: str = Form(...),
    image: Optional[UploadFile] = File(None),
):
    """Create a new TODO. Note is required; image is optional.

    Returns TodoMeta for the newly created TODO.
    """
    stripped_note = note.strip()
    if not stripped_note:
        raise HTTPException(status_code=400, detail="Note er påkrævet")
    if len(stripped_note) > MAX_NOTE_LENGTH:
        raise HTTPException(status_code=400, detail="Note for lang")

    image_bytes: Optional[bytes] = None
    if image is not None:
        image_bytes = await image.read()
        if len(image_bytes) > settings.max_upload_size:
            raise HTTPException(
                status_code=400,
                detail="Billedet overskrider maksimal størrelse",
            )

    todo_id = uuid.uuid4().hex[:12]
    timestamp = time.time()
    base_filename = f"{int(timestamp)}_{todo_id}"

    meta = TodoMeta(
        id=todo_id,
        timestamp=timestamp,
        note=stripped_note,
        has_image=(image_bytes is not None),
        base_filename=base_filename,
    )

    storage = _storage_dir()
    (storage / f"{base_filename}.json").write_text(json.dumps(meta.model_dump()))
    if image_bytes is not None:
        (storage / f"{base_filename}.png").write_bytes(image_bytes)

    logger.info(
        "TODO created: %s (has_image=%s, note=%r)",
        base_filename,
        meta.has_image,
        stripped_note[:80],
    )
    return meta
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/test_dev_todos.py -v
```

Expected: ALLE 6 tests passerer.

- [ ] **Step 5: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/app/routers/dev_todos.py backend/tests/test_dev_todos.py
git commit -m "feat(backend): POST /dev/todos endpoint with validation

Note required, image optional. Validates empty/whitespace/too-long
notes (400) and oversized images (400). Stores both .json sidecar and
.png if image attached."
```

---

### Task 4: GET /dev/todos listing + /latest endpoint (TDD)

**Files:**
- Modify: `backend/tests/test_dev_todos.py`
- Modify: `backend/app/routers/dev_todos.py`

- [ ] **Step 1: Tilføj listing-tests til test_dev_todos.py**

Åbn `backend/tests/test_dev_todos.py`. Efter den sidste test-funktion, tilføj:

```python
def test_list_empty(client):
    """GET /dev/todos on empty directory returns empty list."""
    resp = client.get("/dev/todos")
    assert resp.status_code == 200
    assert resp.json() == {"todos": []}


def test_list_newest_first(client):
    """GET /dev/todos returns TODOs sorted by timestamp, newest first."""
    import time
    for note in ["first", "second", "third"]:
        client.post("/dev/todos", data={"note": note})
        time.sleep(0.01)  # ensure distinct timestamps

    resp = client.get("/dev/todos")
    assert resp.status_code == 200
    notes = [t["note"] for t in resp.json()["todos"]]
    assert notes == ["third", "second", "first"]


def test_latest_endpoint_empty(client):
    """GET /dev/todos/latest on empty returns 404."""
    resp = client.get("/dev/todos/latest")
    assert resp.status_code == 404


def test_latest_endpoint_returns_newest(client):
    """GET /dev/todos/latest returns the most recent TODO metadata."""
    import time
    client.post("/dev/todos", data={"note": "old"})
    time.sleep(0.01)
    client.post("/dev/todos", data={"note": "new"})

    resp = client.get("/dev/todos/latest")
    assert resp.status_code == 200
    assert resp.json()["note"] == "new"
```

- [ ] **Step 2: Run new tests to verify they fail**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/test_dev_todos.py::test_list_empty tests/test_dev_todos.py::test_list_newest_first tests/test_dev_todos.py::test_latest_endpoint_empty tests/test_dev_todos.py::test_latest_endpoint_returns_newest -v
```

Expected: 4 tests fejler med 404 eller lignende.

- [ ] **Step 3: Implementer GET listing + /latest i dev_todos.py**

Åbn `backend/app/routers/dev_todos.py`. Efter `create_todo`-funktionen, tilføj:

```python
@router.get("", response_model=TodoListResponse)
async def list_todos():
    """List all TODOs sorted newest-first by timestamp."""
    return TodoListResponse(todos=_list_todos(newest_first=True))


# IMPORTANT: /latest MUST be declared before /{todo_id} — FastAPI matches
# routes in declaration order, and /{todo_id} would otherwise capture
# "latest" as an id value and return 404.
@router.get("/latest", response_model=TodoMeta)
async def get_latest_todo():
    """Return metadata for the most recent TODO."""
    todos = _list_todos(newest_first=True)
    if not todos:
        raise HTTPException(status_code=404, detail="Ingen TODOs")
    return todos[0]
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/test_dev_todos.py -v
```

Expected: Alle 10 tests passerer (6 fra Task 3 + 4 nye).

- [ ] **Step 5: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/app/routers/dev_todos.py backend/tests/test_dev_todos.py
git commit -m "feat(backend): GET /dev/todos listing + /latest endpoint

Listing returns newest-first by timestamp. /latest returns metadata
for the most recent TODO or 404 if empty. Added critical route-ordering
comment (/latest before /{todo_id} per FastAPI matching semantics)."
```

---

### Task 5: GET /dev/todos/{id} + /dev/todos/{id}/image (TDD)

**Files:**
- Modify: `backend/tests/test_dev_todos.py`
- Modify: `backend/app/routers/dev_todos.py`

- [ ] **Step 1: Tilføj tests for metadata og image retrieval**

Åbn `backend/tests/test_dev_todos.py`. Efter den sidste test, tilføj:

```python
def test_get_metadata_by_id(client):
    """GET /dev/todos/{id} returns metadata for a specific TODO."""
    upload = client.post("/dev/todos", data={"note": "find me"})
    todo_id = upload.json()["id"]

    resp = client.get(f"/dev/todos/{todo_id}")
    assert resp.status_code == 200
    assert resp.json()["note"] == "find me"
    assert resp.json()["id"] == todo_id


def test_get_metadata_by_id_404(client):
    """GET /dev/todos/{id} returns 404 for unknown id."""
    resp = client.get("/dev/todos/nonexistent1")
    assert resp.status_code == 404


def test_get_image_by_id(client):
    """GET /dev/todos/{id}/image returns PNG for TODO with image."""
    upload = client.post(
        "/dev/todos",
        data={"note": "with image"},
        files={"image": ("shot.png", _png("blue"), "image/png")},
    )
    todo_id = upload.json()["id"]

    resp = client.get(f"/dev/todos/{todo_id}/image")
    assert resp.status_code == 200
    assert resp.headers["content-type"] == "image/png"
    assert len(resp.content) > 0


def test_get_image_404_when_no_image(client):
    """GET /dev/todos/{id}/image returns 404 when TODO has no image."""
    upload = client.post("/dev/todos", data={"note": "no image"})
    todo_id = upload.json()["id"]

    resp = client.get(f"/dev/todos/{todo_id}/image")
    assert resp.status_code == 404


def test_get_image_404_for_unknown_id(client):
    """GET /dev/todos/{id}/image returns 404 for unknown TODO id."""
    resp = client.get("/dev/todos/nonexistent1/image")
    assert resp.status_code == 404
```

- [ ] **Step 2: Run new tests to verify they fail**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/test_dev_todos.py::test_get_metadata_by_id tests/test_dev_todos.py::test_get_metadata_by_id_404 tests/test_dev_todos.py::test_get_image_by_id tests/test_dev_todos.py::test_get_image_404_when_no_image tests/test_dev_todos.py::test_get_image_404_for_unknown_id -v
```

Expected: 5 tests fejler.

- [ ] **Step 3: Implementer GET /{id} og /{id}/image**

Åbn `backend/app/routers/dev_todos.py`. Efter `get_latest_todo`-funktionen, tilføj:

```python
@router.get("/{todo_id}", response_model=TodoMeta)
async def get_todo(todo_id: str):
    """Return metadata for a specific TODO."""
    meta = _find_by_id(todo_id)
    if meta is None:
        raise HTTPException(status_code=404, detail="TODO ikke fundet")
    return meta


@router.get("/{todo_id}/image")
async def get_todo_image(todo_id: str):
    """Return the PNG image for a specific TODO. 404 if no image attached."""
    meta = _find_by_id(todo_id)
    if meta is None:
        raise HTTPException(status_code=404, detail="TODO ikke fundet")
    if not meta.has_image:
        raise HTTPException(status_code=404, detail="TODO har ikke et billede")
    image_file = _image_path(meta.base_filename)
    if not image_file.exists():
        raise HTTPException(status_code=404, detail="Billede mangler på disk")
    return FileResponse(image_file, media_type="image/png")
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/test_dev_todos.py -v
```

Expected: Alle 15 tests passerer.

- [ ] **Step 5: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/app/routers/dev_todos.py backend/tests/test_dev_todos.py
git commit -m "feat(backend): GET /dev/todos/{id} metadata and image endpoints

Metadata endpoint returns TodoMeta JSON. Image endpoint returns PNG
for TODOs that have an image, 404 otherwise. Route ordering (declared
after /latest) is intentional."
```

---

### Task 6: DELETE /dev/todos/{id} (TDD, 204 No Content)

**Files:**
- Modify: `backend/tests/test_dev_todos.py`
- Modify: `backend/app/routers/dev_todos.py`

- [ ] **Step 1: Tilføj DELETE-tests**

Åbn `backend/tests/test_dev_todos.py`. Efter den sidste test, tilføj:

```python
def test_delete_removes_both_files(client, todos_tmp_dir):
    """DELETE /dev/todos/{id} removes both .json and .png."""
    upload = client.post(
        "/dev/todos",
        data={"note": "delete me"},
        files={"image": ("shot.png", _png(), "image/png")},
    )
    todo_id = upload.json()["id"]
    assert len(list(todos_tmp_dir.glob("*.json"))) == 1
    assert len(list(todos_tmp_dir.glob("*.png"))) == 1

    resp = client.delete(f"/dev/todos/{todo_id}")
    assert resp.status_code == 204
    assert resp.content == b""  # no body for 204

    assert len(list(todos_tmp_dir.glob("*.json"))) == 0
    assert len(list(todos_tmp_dir.glob("*.png"))) == 0


def test_delete_note_only(client, todos_tmp_dir):
    """DELETE /dev/todos/{id} works for note-only TODOs (no .png to delete)."""
    upload = client.post("/dev/todos", data={"note": "no image"})
    todo_id = upload.json()["id"]

    resp = client.delete(f"/dev/todos/{todo_id}")
    assert resp.status_code == 204
    assert len(list(todos_tmp_dir.glob("*.json"))) == 0


def test_delete_nonexistent(client):
    """DELETE /dev/todos/{id} returns 404 for unknown id."""
    resp = client.delete("/dev/todos/nonexistent1")
    assert resp.status_code == 404
```

- [ ] **Step 2: Run new tests to verify they fail**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/test_dev_todos.py::test_delete_removes_both_files tests/test_dev_todos.py::test_delete_note_only tests/test_dev_todos.py::test_delete_nonexistent -v
```

Expected: 3 tests fejler.

- [ ] **Step 3: Implementer DELETE-handleren**

Åbn `backend/app/routers/dev_todos.py`. Efter `get_todo_image`-funktionen, tilføj:

```python
@router.delete("/{todo_id}", status_code=204)
async def delete_todo(todo_id: str):
    """Delete a specific TODO and its associated image (if any).

    Returns 204 No Content on success, 404 if the id is unknown.
    """
    meta = _find_by_id(todo_id)
    if meta is None:
        raise HTTPException(status_code=404, detail="TODO ikke fundet")

    meta_file = _meta_path(meta.base_filename)
    image_file = _image_path(meta.base_filename)

    try:
        meta_file.unlink(missing_ok=True)
        image_file.unlink(missing_ok=True)
    except OSError as e:
        logger.warning("Failed to delete TODO files for %s: %s", todo_id, e)
        raise HTTPException(status_code=500, detail="Kunne ikke slette TODO")

    logger.info("TODO deleted: %s", todo_id)
    return Response(status_code=204)
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/test_dev_todos.py -v
```

Expected: Alle 18 tests passerer.

- [ ] **Step 5: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/app/routers/dev_todos.py backend/tests/test_dev_todos.py
git commit -m "feat(backend): DELETE /dev/todos/{id} returns 204 No Content

Removes both .json sidecar and .png image (if present). Follows
HTTP convention (204 No Content for DELETE without response body).
Note-only TODOs are deleted correctly without error on missing .png."
```

---

### Task 7: No-retention verification test + dev_screenshots docstring update

**Files:**
- Modify: `backend/tests/test_dev_todos.py`
- Modify: `backend/app/routers/dev_screenshots.py`

Formålet: Eksplicit verificere at `dev-todos/` ikke har nogen skjult retention-logik der kun manifesterer sig via filsystem-inspektion. Samtidig opdaterer vi docstring i dev_screenshots.py nu hvor shake-gesten fjernes i Phase B.

- [ ] **Step 1: Tilføj no-retention-test**

Åbn `backend/tests/test_dev_todos.py`. Efter den sidste test, tilføj:

```python
def test_no_auto_retention(client, todos_tmp_dir):
    """Verify NO retention — all TODOs persist until manually deleted.

    dev_screenshots/ has keep-N retention; dev_todos/ explicitly does not.
    We create more items than dev_screenshots_keep (20) to catch any
    accidental retention logic that might have been copy-pasted.
    """
    import time
    # Create 25 TODOs
    for i in range(25):
        resp = client.post("/dev/todos", data={"note": f"todo {i}"})
        assert resp.status_code == 200
        time.sleep(0.001)

    # Verify all 25 .json files exist on disk (not just in API response)
    json_files = list(todos_tmp_dir.glob("*.json"))
    assert len(json_files) == 25, f"Expected 25 .json files on disk, got {len(json_files)}"

    # Create one more to trigger any would-be retention
    resp = client.post("/dev/todos", data={"note": "todo 26"})
    assert resp.status_code == 200

    # Verify 26 .json files — NO retention kicked in
    json_files = list(todos_tmp_dir.glob("*.json"))
    assert len(json_files) == 26, f"Expected 26 .json files on disk after 26th POST, got {len(json_files)}"
```

- [ ] **Step 2: Run test**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/test_dev_todos.py::test_no_auto_retention -v
```

Expected: PASS (der er ingen retention-logik at starte med, så den skal bare passere).

- [ ] **Step 3: Opdater docstring på dev_screenshots.py**

Åbn `backend/app/routers/dev_screenshots.py`. Erstat den eksisterende top-of-file docstring (linje 1-9) med:

```python
"""Dev-only screenshot observation-path for the iOS Kvante-capture-knap.

The iOS capture-sheet POSTs screenshots here when the user toggles the
sheet to "Observation" mode (TODO toggle OFF). The developer (or Claude
in a dev session) can then GET the latest screenshot to inspect it
visually via /dev/screenshots/latest.

See also: /dev/todos for the TODO inbox (note-first flow with opt-in image).

NOT for production use — no auth, no rate limiting. LAN-only by virtue of
the backend itself only being reachable on the local network.
"""
```

- [ ] **Step 4: Run full backend test suite**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/test_dev_todos.py tests/test_dev_screenshots.py -v
```

Expected: Alle 19 dev_todos tests og alle dev_screenshots tests passerer.

- [ ] **Step 5: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/tests/test_dev_todos.py backend/app/routers/dev_screenshots.py
git commit -m "test(backend): verify dev_todos has no retention + update screenshots docs

Explicit no-retention test creates 26 TODOs (> dev_screenshots_keep) and
asserts all files remain on disk. Catches accidental copy-paste of
retention logic from dev_screenshots.py. Also updates dev_screenshots.py
docstring to reference the new /dev/todos observation-path relationship."
```

---

### Task 8: Deploy backend til Mac Mini + smoke test

**Files:**
- None (deploy + manual verification)

Backend-arbejdet er komplet. Inden iOS-arbejdet kan testes end-to-end, skal backend'en køre på Mac Mini. Kvante har et standardiseret deploy-script.

- [ ] **Step 1: Verificer clean state**

```bash
cd /Users/olsen/code/Kvante
git status
```

Expected: `nothing to commit, working tree clean` på `feature/dev-tooling-capture`-branchen.

- [ ] **Step 2: Push branch + deploy til Mac Mini**

```bash
git push
./scripts/deploy.sh
```

Expected: Script pusher til origin, ssh'er til Mac Mini, puller branchen, og kører health check. Output slutter med `Deploy OK` eller lignende.

**Bemærk:** `deploy.sh` pull'er default-branchen — hvis scriptet kun pull'er main, så skal du manuelt på Mac Mini skifte til feature-branchen:

```bash
ssh oleserver@macmini4 'cd ~/Kvante && git fetch && git checkout feature/dev-tooling-capture && git pull'
```

Derefter vil uvicorn auto-reload picke ændringerne op.

- [ ] **Step 3: Smoke test nye endpoints via curl**

```bash
# Create a note-only TODO
curl -s -X POST http://192.168.1.60:8000/dev/todos \
  -F "note=Dette er en test" | python -m json.tool

# List
curl -s http://192.168.1.60:8000/dev/todos | python -m json.tool

# Get latest
curl -s http://192.168.1.60:8000/dev/todos/latest | python -m json.tool
```

Expected: Første curl returnerer TodoMeta JSON med `has_image: false`. Listing viser 1+ TODO. Latest returnerer den nyeste.

- [ ] **Step 4: Smoke test med image**

```bash
# Create a test PNG
python -c "from PIL import Image; Image.new('RGB', (100, 100), 'red').save('/tmp/test.png')"

# Upload TODO with image
curl -s -X POST http://192.168.1.60:8000/dev/todos \
  -F "note=Test med billede" \
  -F "image=@/tmp/test.png" | python -m json.tool

# Get the image back
LATEST_ID=$(curl -s http://192.168.1.60:8000/dev/todos/latest | python -c "import sys, json; print(json.load(sys.stdin)['id'])")
curl -s http://192.168.1.60:8000/dev/todos/$LATEST_ID/image -o /tmp/retrieved.png
file /tmp/retrieved.png
```

Expected: `file` output viser `PNG image data, 100 x 100`.

- [ ] **Step 5: Smoke test DELETE + cleanup**

```bash
# Delete the test TODOs
curl -s http://192.168.1.60:8000/dev/todos | \
  python -c "import sys, json; [print(t['id']) for t in json.load(sys.stdin)['todos']]" | \
  while read id; do curl -s -X DELETE http://192.168.1.60:8000/dev/todos/$id; done

# Verify empty
curl -s http://192.168.1.60:8000/dev/todos | python -m json.tool
rm /tmp/test.png /tmp/retrieved.png
```

Expected: Empty list `{"todos": []}`.

- [ ] **Step 6: Ingen commit**

Deploy + smoke test lavede ingen kode-ændringer. Ingen commit nødvendig. Hvis ssh-pull-kommandoen blev kørt direkte på Mac Mini, lad den være — det er bare en kontekst-switch på den anden maskine.

---

## Phase B — iOS (SwiftUI + PencilKit)

iOS-arbejdet kan ikke TDD-tests som backend — Kvante har ikke unit test-infrastruktur for SwiftUI-views. Hver task ender med `xcodebuild` verification + commit. Slut-verification er manuel QA-tjekliste i Task 15.

### Task 9: APIClient.submitDevTodo method

**Files:**
- Modify: `ios/Kvante/Kvante/Services/APIClient.swift`

- [ ] **Step 1: Tilføj submitDevTodo method**

Åbn `ios/Kvante/Kvante/Services/APIClient.swift`. Find den eksisterende `submitDevScreenshot`-method (omkring line 362). Umiddelbart efter `#endif` (line 386), INDE i `#if DEBUG`-blokken — dvs. før `#endif` — tilføj:

Find linjerne:
```swift
    func submitDevScreenshot(imageData: Data, note: String) async throws {
        // ... eksisterende kode ...
    }
    #endif
```

Erstat `#endif`-linjen med:

```swift
    /// Upload a TODO (required note, optional image) to /dev/todos.
    /// Used by the new Kvante-capture-knap for note-first TODO inbox.
    func submitDevTodo(note: String, imageData: Data?) async throws {
        let url = baseURL.appendingPathComponent("dev/todos")
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // note field (required)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"note\"\r\n\r\n")
        body.append(note)
        body.append("\r\n")

        // image field (optional)
        if let imageData {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"shot.png\"\r\n")
            body.append("Content-Type: image/png\r\n\r\n")
            body.append(imageData)
            body.append("\r\n")
        }

        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
    }
    #endif
```

- [ ] **Step 2: Build verify (via Xcode eller xcodebuild)**

```bash
cd /Users/olsen/code/Kvante/ios/Kvante
xcodebuild -project Kvante.xcodeproj -scheme Kvante -configuration Debug -destination 'platform=iOS Simulator,name=iPad (A16)' build 2>&1 | tail -20
```

(Hvis "iPad (A16)" ikke er tilgængelig, brug et andet iPad simulator-navn fra `xcodebuild -showdestinations -project Kvante.xcodeproj -scheme Kvante`.)

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Services/APIClient.swift
git commit -m "feat(ios): APIClient.submitDevTodo for /dev/todos endpoint

Multipart upload with required note and optional image. DEBUG-only.
Existing submitDevScreenshot method is unchanged — observations still
flow through the existing path."
```

---

### Task 10: Rename DevScreenshotSubmit.swift → DevCaptureButton.swift (manual Xcode step)

**Files:**
- Rename: `ios/Kvante/Kvante/Services/DevScreenshotSubmit.swift` → `DevCaptureButton.swift`

Denne task kræver **manuel Xcode GUI-interaktion** fordi Xcode vedligeholder filrefencer i `Kvante.xcodeproj/project.pbxproj`. Omdøbning via `git mv` alene vil brække projekt-filen.

- [ ] **Step 1: Åbn Xcode**

```bash
open /Users/olsen/code/Kvante/ios/Kvante/Kvante.xcodeproj
```

- [ ] **Step 2: Rename i Project Navigator**

1. I Project Navigator (venstre sidebar), naviger til `Kvante > Services > DevScreenshotSubmit.swift`
2. Single-click på filnavnet → det bliver redigérbart (eller right-click → "Rename")
3. Skriv `DevCaptureButton.swift` og tryk Enter
4. Xcode opdaterer både filen på disk og `project.pbxproj`

- [ ] **Step 3: Luk Xcode**

Xcode → Quit Xcode (⌘Q). Vi vil have ren git-status inden vi committer.

- [ ] **Step 4: Verificer git detekterer rename**

```bash
cd /Users/olsen/code/Kvante
git status
```

Expected output should indicate en af to varianter:

Variant A (ren rename, kun hvis Xcode ikke ændrede indhold):
```
	renamed:    ios/Kvante/Kvante/Services/DevScreenshotSubmit.swift -> ios/Kvante/Kvante/Services/DevCaptureButton.swift
	modified:   ios/Kvante/Kvante.xcodeproj/project.pbxproj
```

Variant B (delete + add, hvis Xcode tilføjede/ændrede whitespace):
```
	deleted:    ios/Kvante/Kvante/Services/DevScreenshotSubmit.swift
	new file:   ios/Kvante/Kvante/Services/DevCaptureButton.swift
	modified:   ios/Kvante/Kvante.xcodeproj/project.pbxproj
```

Begge er acceptable — git's rename detection kører automatisk ved `git diff` og `git log --follow`.

- [ ] **Step 5: Build verify at projektet stadig kompilerer**

```bash
cd /Users/olsen/code/Kvante/ios/Kvante
xcodebuild -project Kvante.xcodeproj -scheme Kvante -configuration Debug -destination 'platform=iOS Simulator,name=iPad (A16)' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. Hvis build fejler med "No such file", er Xcode's rename ikke nået til disk — genåbn Xcode, ændr noget og gem for at tvinge opdatering.

- [ ] **Step 6: Commit**

```bash
cd /Users/olsen/code/Kvante
git add -A ios/Kvante
git commit -m "refactor(ios): rename DevScreenshotSubmit.swift to DevCaptureButton.swift

Preparatory rename ahead of the capture-button redesign. Filename now
reflects the new feature scope (capture, not just screenshot submission).
Xcode project file updated automatically via rename-in-navigator."
```

---

### Task 11: Rewrite DevCaptureButton.swift — fjern shake, ny Kvante-styled FAB, ny modifier

**Files:**
- Modify (rewrite): `ios/Kvante/Kvante/Services/DevCaptureButton.swift`
- Modify: `ios/Kvante/Kvante/ContentView.swift`

Dette er en substantiel rewrite. Vi beholder `ScreenshotCapture.captureKeyWindow()`-helperen men fjerner shake-infrastrukturen og erstatter FAB'en + sheet-præsentationen. Selve capture-sheet'en flyttes ud til en separat fil i Task 12 — her skaber vi bare stub'en.

- [ ] **Step 1: Erstat hele indholdet af DevCaptureButton.swift**

Åbn `ios/Kvante/Kvante/Services/DevCaptureButton.swift`. Erstat hele filens indhold med:

```swift
// DevCaptureButton.swift
//
// Debug-only feature: a global floating Kvante-styled capture button.
// Tap opens a note-first capture sheet where the user can write a TODO,
// optionally attach a screenshot of the underlying screen, and annotate
// it with Apple Pencil. Replaces the old shake-to-submit screenshot flow.
//
// Note-first semantics: the screenshot is captured in the background when
// the button is tapped, but only attached to the TODO if the user
// explicitly taps "Tag billede" in the sheet. This keeps pure note-capture
// friction-free while still making the underlying screen available.
//
// All code in this file is gated by #if DEBUG and stripped from release
// builds.

#if DEBUG
import SwiftUI
import UIKit

// MARK: - Screenshot capture (unchanged helper)

enum ScreenshotCapture {
    /// Render the current key window into a UIImage.
    /// Returns nil if no key window is available (unlikely in practice).
    static func captureKeyWindow() -> UIImage? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })
        else { return nil }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
    }
}

// MARK: - Floating Kvante FAB

private struct DevKvanteFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                // Base circle — Kvante orange/coral
                Circle()
                    .fill(Color(red: 0.85, green: 0.48, blue: 0.35))
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

                // Stylized eyes (two black dots)
                HStack(spacing: 6) {
                    Circle().fill(Color.black).frame(width: 5, height: 5)
                    Circle().fill(Color.black).frame(width: 5, height: 5)
                }
                .offset(x: 12, y: 18)

                // Coral pom-pom antenna
                Path { path in
                    path.move(to: CGPoint(x: 22, y: 2))
                    path.addLine(to: CGPoint(x: 22, y: -4))
                }
                .stroke(Color(red: 0.93, green: 0.4, blue: 0.55), lineWidth: 2)
                .offset(x: 0, y: 0)

                Circle()
                    .fill(Color(red: 0.93, green: 0.4, blue: 0.55))
                    .frame(width: 6, height: 6)
                    .offset(x: 19, y: -8)

                // DEV badge
                Text("DEV")
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(2)
                    .offset(x: -2, y: 28)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dev capture")
    }
}

// MARK: - View modifier

private struct DevCaptureButtonModifier: ViewModifier {
    let apiClient: APIClient?

    // pendingScreenshot is captured BEFORE the sheet is presented
    // (at FAB tap time), held in memory, and only attached to a submission
    // if the user explicitly taps "Tag billede" in the sheet.
    @State private var pendingScreenshot: UIImage?
    @State private var sheetPresented = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                DevKvanteFloatingButton(action: triggerCapture)
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .allowsHitTesting(!sheetPresented)
            }
            .sheet(isPresented: $sheetPresented) {
                DevCaptureSheet(
                    pendingScreenshot: pendingScreenshot,
                    apiClient: apiClient,
                    onDismiss: {
                        sheetPresented = false
                        pendingScreenshot = nil
                    }
                )
            }
    }

    private func triggerCapture() {
        pendingScreenshot = ScreenshotCapture.captureKeyWindow()
        sheetPresented = true
    }
}

extension View {
    /// Attach the dev capture feature (floating Kvante button + sheet).
    /// Debug-only; becomes a no-op in release builds.
    func devCaptureButton(apiClient: APIClient?) -> some View {
        modifier(DevCaptureButtonModifier(apiClient: apiClient))
    }
}

#else

import SwiftUI

extension View {
    /// Release builds: no-op so callers don't need their own #if DEBUG.
    func devCaptureButton(apiClient: Any?) -> some View {
        self
    }
}

#endif
```

Bemærk: Dette refererer til en `DevCaptureSheet`-struct der ikke eksisterer endnu — den bygges i Task 12. Build vil fejle nu, og det er forventet.

- [ ] **Step 2: Opdater ContentView.swift til nyt modifier-navn**

Åbn `ios/Kvante/Kvante/ContentView.swift`. Find linjen (omkring line 105):

```swift
        .devScreenshotSubmit(apiClient: apiClient)
```

Erstat med:

```swift
        .devCaptureButton(apiClient: apiClient)
```

- [ ] **Step 3: Verificér build fejler med forventet fejl**

```bash
cd /Users/olsen/code/Kvante/ios/Kvante
xcodebuild -project Kvante.xcodeproj -scheme Kvante -configuration Debug -destination 'platform=iOS Simulator,name=iPad (A16)' build 2>&1 | tail -20
```

Expected: BUILD FAILED med `cannot find 'DevCaptureSheet' in scope`. Dette er forventet — vi bygger sheet'en i næste task.

- [ ] **Step 4: Commit work-in-progress**

Vi committer en WIP-tilstand her fordi ændringerne er logisk afsluttede for denne task (shake fjernet, FAB omskrevet, modifier omdøbt). Den næste task tilføjer DevCaptureSheet og gør koden kompilerbar igen.

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Services/DevCaptureButton.swift ios/Kvante/Kvante/ContentView.swift
git commit -m "refactor(ios): WIP — Kvante FAB + new view modifier, remove shake

Replace DevScreenshotFloatingButton with DevKvanteFloatingButton
(Kvante-styled avatar + DEV badge). Remove UIWindow.motionEnded shake
gesture infrastructure entirely. Rename view modifier from
.devScreenshotSubmit to .devCaptureButton.

NOTE: Build is broken at this commit — references DevCaptureSheet which
is added in the next commit. WIP state is intentional so the FAB/modifier
changes have their own logical commit."
```

---

### Task 12: Create DevCaptureSheet.swift + add to Xcode project

**Files:**
- Create: `ios/Kvante/Kvante/Services/DevCaptureSheet.swift`

Denne task opretter den nye capture-sheet som en separat fil. Xcode skal være åben for at tilføje filen til target.

- [ ] **Step 1: Opret filen via shell**

```bash
cat > /Users/olsen/code/Kvante/ios/Kvante/Kvante/Services/DevCaptureSheet.swift << 'SWIFT_EOF'
// DevCaptureSheet.swift
//
// Debug-only: note-first capture sheet presented by the Kvante FAB.
// Primary input is the TextField (auto-focused); screenshot and
// annotation are opt-in secondary actions.
//
// Two submit modes via the TODO toggle:
//   TODO (default ON):   note required, image optional, POST /dev/todos
//   Observation (off):   image required, note optional, POST /dev/screenshots
//
// All code in this file is gated by #if DEBUG and stripped from release
// builds.

#if DEBUG
import SwiftUI
import UIKit

struct DevCaptureSheet: View {
    let pendingScreenshot: UIImage?
    let apiClient: APIClient?
    let onDismiss: () -> Void

    @State private var note: String = ""
    @State private var attachedScreenshot: UIImage?
    @State private var isTodo: Bool = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSucceed = false
    @State private var showAnnotationEditor = false
    @FocusState private var noteFocused: Bool

    private var canSubmit: Bool {
        if isSubmitting { return false }
        if isTodo {
            return !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return attachedScreenshot != nil
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("Hvad vil du huske?", text: $note, axis: .vertical)
                    .lineLimit(4...8)
                    .textFieldStyle(.roundedBorder)
                    .focused($noteFocused)
                    .padding(.horizontal)

                if let attachedScreenshot {
                    VStack(spacing: 8) {
                        Image(uiImage: attachedScreenshot)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        HStack(spacing: 16) {
                            Button("Annotér") {
                                showAnnotationEditor = true
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Fjern") {
                                self.attachedScreenshot = nil
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                    .padding(.horizontal)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                if didSucceed {
                    Text("Sendt ✓")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal)
                }

                Spacer()

                // Action bar at the bottom
                VStack(spacing: 4) {
                    HStack {
                        Button(action: {
                            attachedScreenshot = pendingScreenshot
                        }) {
                            Label("Tag billede", systemImage: "camera")
                        }
                        .buttonStyle(.bordered)
                        .disabled(attachedScreenshot != nil || pendingScreenshot == nil)

                        Spacer()

                        HStack(spacing: 6) {
                            Text("TODO")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Toggle("TODO", isOn: $isTodo)
                                .labelsHidden()
                        }
                    }
                    .padding(.horizontal)

                    if pendingScreenshot == nil {
                        Text("Kunne ikke fange skærmen")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.top, 12)
            .navigationTitle("Ny capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuller", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task { await submit() }
                    }
                    .disabled(!canSubmit)
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .onAppear {
                noteFocused = true
            }
            .fullScreenCover(isPresented: $showAnnotationEditor) {
                if let attachedScreenshot {
                    DevAnnotationEditor(
                        originalImage: attachedScreenshot,
                        onFinish: { annotated in
                            self.attachedScreenshot = annotated
                            showAnnotationEditor = false
                        },
                        onCancel: {
                            showAnnotationEditor = false
                        }
                    )
                }
            }
        }
    }

    private func submit() async {
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
}

#endif
SWIFT_EOF
```

- [ ] **Step 2: Tilføj filen til Xcode target (manuel Xcode-interaktion)**

1. Åbn Xcode: `open /Users/olsen/code/Kvante/ios/Kvante/Kvante.xcodeproj`
2. I Project Navigator, find `Kvante > Services`-gruppen
3. Right-click på Services → **"Add Files to Kvante..."**
4. Naviger til og vælg `DevCaptureSheet.swift`
5. Sørg for at "Copy items if needed" er **OFF** (filen er allerede i projektet)
6. Sørg for at "Add to targets: Kvante" er **ON**
7. Klik "Add"
8. Quit Xcode (⌘Q)

- [ ] **Step 3: Verificér build stadig fejler (forventet på DevAnnotationEditor)**

```bash
cd /Users/olsen/code/Kvante/ios/Kvante
xcodebuild -project Kvante.xcodeproj -scheme Kvante -configuration Debug -destination 'platform=iOS Simulator,name=iPad (A16)' build 2>&1 | tail -20
```

Expected: BUILD FAILED med `cannot find 'DevAnnotationEditor' in scope`. `DevCaptureSheet` er nu kendt, men den refererer til editor'en der bygges i næste task.

- [ ] **Step 4: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Services/DevCaptureSheet.swift ios/Kvante/Kvante.xcodeproj/project.pbxproj
git commit -m "feat(ios): DevCaptureSheet note-first capture UI

New capture sheet with auto-focused TextField, opt-in screenshot
thumbnail, and TODO toggle. Send button intelligently disabled for
invalid combinations (empty TODO, empty observation). Routes to
submitDevTodo or submitDevScreenshot based on toggle state.

NOTE: Build still broken at this commit — references DevAnnotationEditor
added in next task."
```

---

### Task 13: Create DevAnnotationEditor.swift with CanvasRepresentable + flatten

**Files:**
- Create: `ios/Kvante/Kvante/Services/DevAnnotationEditor.swift`

- [ ] **Step 1: Opret filen**

```bash
cat > /Users/olsen/code/Kvante/ios/Kvante/Kvante/Services/DevAnnotationEditor.swift << 'SWIFT_EOF'
// DevAnnotationEditor.swift
//
// Debug-only: full-screen PencilKit editor for annotating captured
// screenshots. Presented from DevCaptureSheet's "Annotér" button when
// an attached screenshot exists.
//
// Critical design note: canvas frame MUST match originalImage.size
// (in points) so the PKDrawing coordinate space matches the flatten
// output coordinate space. If this file is ever changed to use
// scaledToFit or aspectRatio, the flatten logic must be rewritten to
// handle the coordinate mismatch.
//
// All code in this file is gated by #if DEBUG and stripped from release
// builds.

#if DEBUG
import SwiftUI
import UIKit
import PencilKit

struct DevAnnotationEditor: View {
    let originalImage: UIImage
    let onFinish: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var canvasView = PKCanvasView()

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                ZStack {
                    Image(uiImage: originalImage)
                        .frame(
                            width: originalImage.size.width,
                            height: originalImage.size.height
                        )
                    CanvasRepresentable(canvasView: $canvasView)
                        .frame(
                            width: originalImage.size.width,
                            height: originalImage.size.height
                        )
                }
            }
            .navigationTitle("Annotér")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuller", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Færdig") {
                        onFinish(flattenedImage())
                    }
                }
            }
            .onAppear {
                // Activate the system tool picker for the canvas.
                if let window = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap({ $0.windows })
                    .first(where: { $0.isKeyWindow }),
                   let toolPicker = PKToolPicker.shared(for: window) {
                    toolPicker.setVisible(true, forFirstResponder: canvasView)
                    toolPicker.addObserver(canvasView)
                    canvasView.becomeFirstResponder()
                }
            }
        }
    }

    /// Render the PKCanvasView drawing on top of the original image
    /// and return a flat UIImage. Coordinate space is consistent
    /// because the canvas frame matches originalImage.size.
    ///
    /// If the layout ever changes to use scaledToFit or a different
    /// canvas frame, this function must be rewritten to transform the
    /// drawing coordinates accordingly.
    private func flattenedImage() -> UIImage {
        let size = originalImage.size  // points
        let format = UIGraphicsImageRendererFormat()
        format.scale = originalImage.scale  // native pixel density
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
}

// MARK: - SwiftUI wrapper for PKCanvasView

struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput   // Apple Pencil + finger
        canvasView.backgroundColor = .clear    // background image visible through
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // No-op — PKCanvasView instance is @Binding-owned by parent
    }
}

#endif
SWIFT_EOF
```

- [ ] **Step 2: Tilføj filen til Xcode target**

1. Åbn Xcode: `open /Users/olsen/code/Kvante/ios/Kvante/Kvante.xcodeproj`
2. Project Navigator → `Kvante > Services`
3. Right-click → **"Add Files to Kvante..."**
4. Vælg `DevAnnotationEditor.swift`
5. "Copy items if needed" OFF, "Add to targets: Kvante" ON
6. Klik "Add"
7. Quit Xcode (⌘Q)

- [ ] **Step 3: Build verify**

```bash
cd /Users/olsen/code/Kvante/ios/Kvante
xcodebuild -project Kvante.xcodeproj -scheme Kvante -configuration Debug -destination 'platform=iOS Simulator,name=iPad (A16)' build 2>&1 | tail -30
```

Expected: `BUILD SUCCEEDED`. Alle tre filer (DevCaptureButton, DevCaptureSheet, DevAnnotationEditor) kompilerer nu sammen.

- [ ] **Step 4: Verify Release build også bygger (production-safety check)**

```bash
xcodebuild -project Kvante.xcodeproj -scheme Kvante -configuration Release -destination 'generic/platform=iOS' build 2>&1 | tail -30
```

Expected: `BUILD SUCCEEDED`. Dette verificerer at `#if DEBUG`-gates er korrekte — Release-builds må ikke kompilere nogen af de nye filer.

- [ ] **Step 5: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Services/DevAnnotationEditor.swift ios/Kvante/Kvante.xcodeproj/project.pbxproj
git commit -m "feat(ios): DevAnnotationEditor full-screen PencilKit annotation

Canvas frame matches originalImage.size exactly so coordinate space
is consistent between display and flatten. ScrollView handles images
larger than the screen. PKToolPicker activated on appear; .anyInput
drawing policy supports both Apple Pencil and finger drawing.

Flatten logic renders at originalImage.scale (not UIScreen) for
native pixel-density fidelity. Kritical: layout must NOT use
scaledToFit or the flatten math breaks (documented in code comment)."
```

---

### Task 14: Build + deploy sanity check

**Files:**
- None

Alt iOS-kode er nu skrevet. Denne task verificerer at branchen kompilerer rent, og at backend på Mac Mini stadig er op-to-date med vores branch.

- [ ] **Step 1: Kør fuld backend test-suite en sidste gang**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest -v 2>&1 | tail -30
```

Expected: Alle tests passerer. Ingen regressioner fra de backend-ændringer vi lavede.

- [ ] **Step 2: Verificer Mac Mini har den nyeste kode**

```bash
ssh oleserver@macmini4 'cd ~/Kvante && git rev-parse HEAD && git status'
```

Expected: HEAD commit matcher den seneste `feature/dev-tooling-capture`-commit på din lokale branch. `git status` er clean.

Hvis Mac Mini ikke er up-to-date:
```bash
cd /Users/olsen/code/Kvante
git push
ssh oleserver@macmini4 'cd ~/Kvante && git pull'
```

Uvicorn auto-reloads ved kode-ændringer.

- [ ] **Step 3: Quick health check**

```bash
curl -s http://192.168.1.60:8000/health | python -m json.tool
curl -s http://192.168.1.60:8000/dev/todos | python -m json.tool
```

Expected: Health check returnerer ok. `/dev/todos` returnerer liste (evt. med test-TODOs hvis de ikke blev ryddet i Task 8).

- [ ] **Step 4: Ingen commit**

Denne task er verification-only. Ingen ændringer at committe.

---

### Task 15: Manuel QA-tjekliste

**Files:**
- None

Den endelige verifikation skal gøres interaktivt på en faktisk iPad eller iPad-simulator. Kør appen, gennemgå denne tjekliste, og verificer hver del. Hvis noget fejler, dokumentér fejlen i en TODO og bestem om det er en blocker eller et follow-up.

- [ ] **Step 1: Build og kør appen på simulator**

Åbn Xcode → vælg iPad-simulator i target → `Cmd+R` for at bygge og køre. Appen skulle åbne på home-skærmen.

- [ ] **Step 2: Verificer Kvante FAB er synlig**

Du skulle se en lille cirkulær Kvante-figur (orange/koral) i nederste højre hjørne med en "DEV"-badge. Det gamle kamera-ikon skulle være væk.

- [ ] **Step 3: Tap FAB — sheet åbner med TextField focused**

Tap på Kvante-FAB'en. En sheet slider op fra bunden:
- Titel: "Ny capture"
- TextField er tom med placeholder "Hvad vil du huske?"
- **Keyboard er allerede fremme** (TextField er auto-focused)
- "Annuller"-knap til venstre i nav bar
- "Send"-knap til højre, **disabled** (note er tom)
- Action bar nederst: "Tag billede"-knap + TODO-toggle (default ON)
- **Ingen thumbnail** synlig (intet screenshot attached endnu)

- [ ] **Step 4: Note-only TODO**

Skriv "Test note uden billede" i TextField. Verificer:
- Send-knap aktiveres (enabled)
- TODO-toggle er stadig ON

Tap Send. Verificer:
- Kort "Sendt ✓"-tekst vises
- Sheet auto-dismisses efter 600ms

Verificer backend modtog det:
```bash
curl -s http://192.168.1.60:8000/dev/todos/latest | python -m json.tool
```
Expected: Den TODO du lige sendte, med `has_image: false`.

- [ ] **Step 5: TODO med screenshot**

Tap FAB igen. Verificer:
- Sheet åbner
- TextField er tom igen
- **Ingen attached screenshot** (det fangede screenshot er pending, ikke attached)

Tap "Tag billede". Verificer:
- Thumbnail dukker op under TextField med "Annotér" og "Fjern" knapper
- "Tag billede"-knappen er nu disabled (eller forsvundet)

Skriv en note. Tap Send. Verificer:
- "Sendt ✓"
- Auto-dismiss

Verificer backend:
```bash
LATEST_ID=$(curl -s http://192.168.1.60:8000/dev/todos/latest | python -c "import sys, json; print(json.load(sys.stdin)['id'])")
curl -s http://192.168.1.60:8000/dev/todos/$LATEST_ID | python -m json.tool
```
Expected: `has_image: true`.

Hent billedet og åbn det:
```bash
curl -s http://192.168.1.60:8000/dev/todos/$LATEST_ID/image -o /tmp/captured.png
open /tmp/captured.png
```
Expected: Billedet viser den Kvante home-skærm du var på da du tappede FAB'en.

- [ ] **Step 6: Annotation-flow (kræver Apple Pencil simulator eller finger)**

Tap FAB → Tag billede → Annotér. Verificer:
- Full-screen editor åbner
- Nav bar har "Annuller", "Annotér" (title), "Færdig"
- Screenshot er synlig i canvas-området
- **PencilKit tool picker** er synlig (palette med pen, viskelæder, farver osv)

Tegn en cirkel rundt om et UI-element med finger eller Apple Pencil.

Tap "Færdig". Verificer:
- Editor dismisses
- Sheet'en viser den opdaterede thumbnail med din tegning brændt ind

Tap Send. Hent billedet:
```bash
LATEST_ID=$(curl -s http://192.168.1.60:8000/dev/todos/latest | python -c "import sys, json; print(json.load(sys.stdin)['id'])")
curl -s http://192.168.1.60:8000/dev/todos/$LATEST_ID/image -o /tmp/annotated.png
open /tmp/annotated.png
```
Expected: Billedet viser screenshottet MED dine pencil-streger på den korrekte position (ikke øverst-venstre hjørne eller forkert skaleret — dette er hvad koordinat-rum-fixet sikrer).

- [ ] **Step 7: Observation-mode**

Tap FAB. Slå TODO-toggle OFF. Verificer:
- Send-knap er disabled (selv hvis noten er tom, fordi observation kræver screenshot)

Skriv "observation note" (Send stadig disabled — kræver screenshot).

Tap "Tag billede". Verificer:
- Send-knap bliver enabled

Tap Send. Verificer:
- "Sendt ✓"

Verificer backend:
```bash
curl -s http://192.168.1.60:8000/dev/screenshots/latest -o /tmp/obs.png
file /tmp/obs.png
```
Expected: PNG fil. Observationen gik til `/dev/screenshots`, ikke `/dev/todos`.

```bash
curl -s http://192.168.1.60:8000/dev/todos/latest | python -m json.tool
```
Expected: Den sidste TODO (fra Step 5/6), IKKE observation-noten. Bekræfter at toggle-routing fungerer.

- [ ] **Step 8: Cancel-flow**

Tap FAB. Skriv noget. Tap Annuller. Verificer:
- Sheet dismisses
- Ingen submission til backend

Backend stil samme state som før:
```bash
curl -s http://192.168.1.60:8000/dev/todos/latest | python -m json.tool
```
Expected: Uændret.

- [ ] **Step 9: Ryd test-data op**

```bash
# Delete test TODOs
curl -s http://192.168.1.60:8000/dev/todos | \
  python -c "import sys, json; [print(t['id']) for t in json.load(sys.stdin)['todos']]" | \
  while read id; do curl -s -X DELETE http://192.168.1.60:8000/dev/todos/$id; done

# Verify clean
curl -s http://192.168.1.60:8000/dev/todos
```
Expected: `{"todos": []}`.

Observation-screenshots ryddes naturligt af dev_screenshots retention. Lad dem være.

- [ ] **Step 10: Final branch-status**

```bash
cd /Users/olsen/code/Kvante
git log --oneline main..HEAD
```

Expected: Alle branchens commits er synlige (ca. 10-12 commits afhængig af hvordan WIP-commits endte). Ingen uncommitted changes.

---

### Task 16: Merge branch til main

**Files:**
- None

- [ ] **Step 1: Verify branch er ahead og clean**

```bash
cd /Users/olsen/code/Kvante
git status
git log --oneline -5
```

Expected: Clean working tree, branch `feature/dev-tooling-capture` ahead of main.

- [ ] **Step 2: Push branch en sidste gang**

```bash
git push
```

- [ ] **Step 3: Merge til main**

```bash
git checkout main
git pull
git merge feature/dev-tooling-capture
```

Expected: Fast-forward merge eller clean merge (ingen conflicts). Hvis der er conflicts, stop og resolve dem før du går videre.

- [ ] **Step 4: Push main**

```bash
git push
```

- [ ] **Step 5: Deploy til Mac Mini fra main**

```bash
./scripts/deploy.sh
```

Expected: Mac Mini pull'er main og backend reloads.

- [ ] **Step 6: Ryd branch op**

```bash
git branch -d feature/dev-tooling-capture
git push origin --delete feature/dev-tooling-capture
```

- [ ] **Step 7: Opdater TODO.md — marker item #1 som gennemført**

Åbn `TODO.md`. Flyt "1. Dev-tooling — Global Kvante-capture-knap"-sektionen fra "Næste features (prioriteret)" til en ny entry under "Gennemført":

```markdown
### 2026-04-08 (efter roadmap-reorder)
- [x] **Item #1: Dev-tooling Global Kvante-capture-knap** — Erstatter shake-to-submit med note-first capture sheet. Global Kvante-styled FAB (bottom-right, DEV badge), PencilKit full-screen annotation, to separate storage paths (dev-todos/ no retention, dev-screenshots/ unchanged). Backend: nye `/dev/todos` endpoints (POST/GET list/latest/{id}/{id}/image/DELETE). iOS: DevCaptureButton, DevCaptureSheet, DevAnnotationEditor — alt #if DEBUG-gated. Spec: `docs/superpowers/specs/2026-04-08-dev-tooling-global-kvante-capture-design.md`. Plan: `docs/superpowers/plans/2026-04-08-dev-tooling-capture.md`.
```

Renumerér items 2-11 til 1-10 i "Næste features"-listen (pakke 2a bliver #1, SF Symbols bliver #2, osv.).

- [ ] **Step 8: Opdater project_next_features.md i memory**

Åbn `/Users/olsen/.claude/projects/-Users-olsen-code-Kvante/memory/project_next_features.md`. I sektionen "Prioriteret køreplan (11 items)", marker "### 1. Dev-tooling — Global Kvante-capture-knap" som færdig (f.eks. tilføj "— DONE 2026-04-08" i headeren) og renumerér de resterende items.

- [ ] **Step 9: Commit TODO + memory opdateringer**

```bash
git add TODO.md
git commit -m "docs: mark item #1 (dev-tooling capture-knap) as complete"
git push
```

(Memory-filen er uden for repo'et og committes ikke.)

- [ ] **Step 10: Verify final state**

```bash
git log --oneline -10
curl -s http://192.168.1.60:8000/dev/todos | python -m json.tool
```

Expected: Seneste commits på main inkluderer hele feature-brancen. Backend er reachable og tom TODO-liste.

---

## Self-review checklist (run after plan is saved)

**Spec coverage:**
- [x] Backend POST /dev/todos — Task 3
- [x] Backend GET /dev/todos listing — Task 4
- [x] Backend GET /dev/todos/latest — Task 4
- [x] Backend GET /dev/todos/{id} metadata — Task 5
- [x] Backend GET /dev/todos/{id}/image — Task 5
- [x] Backend DELETE /dev/todos/{id} returns 204 — Task 6
- [x] Backend no-retention verification — Task 7
- [x] dev_screenshots.py docstring update — Task 7
- [x] Route ordering (/latest before /{id}) — Task 4, explicit code comment
- [x] FastAPI HTTPException with Danish text — all tasks
- [x] iOS APIClient.submitDevTodo — Task 9
- [x] DevScreenshotSubmit.swift rename to DevCaptureButton.swift — Task 10
- [x] Shake gesture removed — Task 11
- [x] Kvante-styled FAB with DEV badge — Task 11
- [x] ViewModifier renamed to devCaptureButton — Task 11
- [x] ContentView call-site updated — Task 11
- [x] DevCaptureSheet.swift created and added to Xcode — Task 12
- [x] Note-first layout with auto-focused TextField — Task 12
- [x] Screenshot opt-in via "Tag billede" — Task 12
- [x] "Kunne ikke fange skærmen" fallback — Task 12
- [x] TODO toggle routes to right endpoint — Task 12
- [x] canSubmit logic matches spec — Task 12
- [x] Success "Sendt ✓" + 600ms auto-dismiss — Task 12
- [x] interactiveDismissDisabled during submit — Task 12
- [x] DevAnnotationEditor.swift with CanvasRepresentable — Task 13
- [x] Flatten logic with originalImage.size consistency — Task 13
- [x] ScrollView + explicit frame (no scaledToFit) — Task 13
- [x] PKToolPicker activated — Task 13
- [x] .anyInput drawingPolicy — Task 13
- [x] #if DEBUG gating verified via Release build — Task 13
- [x] Manual QA checklist — Task 15
- [x] Merge + deploy + TODO update — Task 16

All spec requirements covered.

**Placeholder scan:** No TBD, TODO, or vague instructions remain. Every code block contains complete executable code.

**Type consistency:**
- `TodoMeta` fields (`id`, `timestamp`, `note`, `has_image`, `base_filename`) are consistent across backend tasks
- `submitDevTodo(note: String, imageData: Data?)` signature consistent between APIClient (Task 9) and DevCaptureSheet (Task 12)
- `DevAnnotationEditor(originalImage:onFinish:onCancel:)` signature consistent between declaration (Task 13) and usage (Task 12)
- `CanvasRepresentable(canvasView: $canvasView)` parameter name consistent

No inconsistencies found.
