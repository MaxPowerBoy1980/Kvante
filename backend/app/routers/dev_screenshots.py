"""Dev-only screenshot observation-path for the iOS Kvante-capture-knap.

The iOS capture-sheet POSTs screenshots here when the user toggles the
sheet to "Observation" mode (TODO toggle OFF). The developer (or Claude
in a dev session) can then GET the latest screenshot to inspect it
visually via /dev/screenshots/latest.

See also: /dev/todos for the TODO inbox (note-first flow with opt-in image).

NOT for production use — no auth, no rate limiting. LAN-only by virtue of
the backend itself only being reachable on the local network.
"""
from __future__ import annotations

import logging
import os
import time
import uuid
from pathlib import Path
from typing import List, Optional

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel

from app.config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/dev/screenshots", tags=["dev"])


class ScreenshotMeta(BaseModel):
    id: str
    timestamp: float  # unix epoch seconds
    note: str
    filename: str


class ScreenshotListResponse(BaseModel):
    screenshots: List[ScreenshotMeta]


def _storage_dir() -> Path:
    """Resolve the screenshots directory, creating it if needed."""
    path = Path(settings.dev_screenshots_dir)
    path.mkdir(parents=True, exist_ok=True)
    return path


def _meta_path(image_path: Path) -> Path:
    """Sidecar JSON metadata file for an image."""
    return image_path.with_suffix(".json")


def _read_meta(image_path: Path) -> ScreenshotMeta:
    """Read sidecar JSON; tolerate missing/corrupt files by returning defaults."""
    import json
    try:
        meta_file = _meta_path(image_path)
        if meta_file.exists():
            data = json.loads(meta_file.read_text())
            return ScreenshotMeta(
                id=data.get("id", image_path.stem),
                timestamp=data.get("timestamp", image_path.stat().st_mtime),
                note=data.get("note", ""),
                filename=image_path.name,
            )
    except Exception:
        logger.warning("Failed to read meta for %s", image_path, exc_info=True)
    return ScreenshotMeta(
        id=image_path.stem,
        timestamp=image_path.stat().st_mtime,
        note="",
        filename=image_path.name,
    )


def _list_screenshots(newest_first: bool = True) -> List[Path]:
    """All PNG screenshots, sorted by mtime."""
    storage = _storage_dir()
    files = sorted(
        storage.glob("*.png"),
        key=lambda p: p.stat().st_mtime,
        reverse=newest_first,
    )
    return files


def _enforce_retention():
    """Keep only the N newest screenshots; delete the rest with their metadata."""
    files = _list_screenshots(newest_first=True)
    keep = settings.dev_screenshots_keep
    for old in files[keep:]:
        try:
            _meta_path(old).unlink(missing_ok=True)
            old.unlink(missing_ok=True)
            logger.info("Deleted old screenshot %s", old.name)
        except OSError:
            logger.warning("Failed to delete %s", old, exc_info=True)


@router.post("", response_model=ScreenshotMeta)
async def upload_screenshot(
    image: UploadFile = File(...),
    note: str = Form(""),
):
    """Upload a screenshot with an optional note. Returns metadata."""
    contents = await image.read()
    if len(contents) > settings.max_upload_size:
        raise HTTPException(status_code=400, detail="Image exceeds maximum upload size")

    screenshot_id = uuid.uuid4().hex[:12]
    timestamp = time.time()
    storage = _storage_dir()
    # Filename pattern: <unix_ts>_<id>.png so chronological sort works
    filename = f"{int(timestamp)}_{screenshot_id}.png"
    image_path = storage / filename
    image_path.write_bytes(contents)

    import json
    meta = ScreenshotMeta(
        id=screenshot_id,
        timestamp=timestamp,
        note=note.strip(),
        filename=filename,
    )
    _meta_path(image_path).write_text(json.dumps(meta.model_dump()))

    logger.info("Screenshot uploaded: %s (note=%r, %d bytes)", filename, note, len(contents))

    _enforce_retention()
    return meta


@router.get("", response_model=ScreenshotListResponse)
async def list_screenshots():
    """List recent screenshots, newest first."""
    files = _list_screenshots(newest_first=True)
    return ScreenshotListResponse(screenshots=[_read_meta(f) for f in files])


@router.get("/latest")
async def get_latest_screenshot():
    """Return the most recent screenshot as image/png."""
    files = _list_screenshots(newest_first=True)
    if not files:
        raise HTTPException(status_code=404, detail="No screenshots available")
    return FileResponse(files[0], media_type="image/png")


@router.get("/{screenshot_id}")
async def get_screenshot(screenshot_id: str):
    """Return a specific screenshot by id as image/png."""
    files = _list_screenshots(newest_first=True)
    for f in files:
        meta = _read_meta(f)
        if meta.id == screenshot_id:
            return FileResponse(f, media_type="image/png")
    raise HTTPException(status_code=404, detail="Screenshot not found")
