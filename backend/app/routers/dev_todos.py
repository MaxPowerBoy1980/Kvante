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


@router.post("", response_model=TodoMeta)
async def create_todo(
    note: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
):
    """Create a new TODO. Note is required; image is optional.

    Returns TodoMeta for the newly created TODO.
    """
    stripped_note = (note or "").strip()
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
