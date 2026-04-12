import logging
import os
from io import BytesIO

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from fastapi.responses import FileResponse, Response
from PIL import Image
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


@router.get("/scans/{scan_id}/image")
def get_scan_image(scan_id: str, db: DBSession = Depends(get_db)):
    """Returnér billedet for et gemt scan. Bruges af iOS ved session-reload."""
    scan = db.query(Scan).filter(Scan.id == scan_id).first()
    if not scan or not os.path.exists(scan.image_path):
        raise HTTPException(status_code=404, detail="Scan not found")
    return FileResponse(scan.image_path, media_type="image/jpeg")


@router.get("/scans/{scan_id}/crop")
def crop_scan_image(
    scan_id: str,
    x: float = Query(..., ge=0.0, le=1.0),
    y: float = Query(..., ge=0.0, le=1.0),
    w: float = Query(..., ge=0.0, le=1.0),
    h: float = Query(..., ge=0.0, le=1.0),
    padding: float = Query(0.08, ge=0.0, le=1.0),
    db: DBSession = Depends(get_db),
):
    """Return a cropped region of a scan image. Coordinates are normalized 0.0–1.0."""
    scan = db.query(Scan).filter(Scan.id == scan_id).first()
    if not scan or not os.path.exists(scan.image_path):
        raise HTTPException(status_code=404, detail="Scan not found")

    img = Image.open(scan.image_path)
    img_w, img_h = img.size

    # Apply padding (proportional to box dimensions)
    pad_x = w * padding
    pad_y = h * padding
    left = max(0, round((x - pad_x) * img_w))
    top = max(0, round((y - pad_y) * img_h))
    right = min(img_w, round((x + w + pad_x) * img_w))
    bottom = min(img_h, round((y + h + pad_y) * img_h))

    cropped = img.crop((left, top, right, bottom))

    buf = BytesIO()
    cropped.save(buf, format="JPEG", quality=85)
    body = buf.getvalue()

    return Response(content=body, media_type="image/jpeg")
