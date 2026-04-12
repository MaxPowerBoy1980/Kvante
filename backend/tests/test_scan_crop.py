"""Tests for GET /scans/{id}/crop endpoint."""

import os
import sys
from io import BytesIO
from unittest.mock import MagicMock

import pytest
from PIL import Image

# sys.modules stub to avoid SQLAlchemy crash on Python 3.14
_FakeScan = MagicMock(name="Scan")
_fake_db_module = MagicMock()
_fake_db_module.Scan = _FakeScan
sys.modules.setdefault("app.models.db", _fake_db_module)
sys.modules.setdefault("app.database", MagicMock())

from app.routers.scans import crop_scan_image  # noqa: E402


def _make_test_jpeg(width=1000, height=1500) -> str:
    """Create a temporary JPEG file and return its path."""
    img = Image.new("RGB", (width, height), color=(200, 180, 160))
    path = "/tmp/test_crop_scan.jpg"
    img.save(path, format="JPEG")
    return path


def _mock_db_with_scan(image_path: str):
    db = MagicMock()
    scan = MagicMock()
    scan.image_path = image_path
    inner = MagicMock()
    f = MagicMock()
    inner.filter.return_value = f
    f.first.return_value = scan
    db.query.return_value = inner
    return db


def _mock_db_no_scan():
    db = MagicMock()
    inner = MagicMock()
    f = MagicMock()
    inner.filter.return_value = f
    f.first.return_value = None
    db.query.return_value = inner
    return db


def test_crop_returns_jpeg():
    """Crop endpoint returns a JPEG image with correct dimensions."""
    path = _make_test_jpeg(1000, 1500)
    db = _mock_db_with_scan(path)

    response = crop_scan_image("scan-1", x=0.1, y=0.2, w=0.5, h=0.3, padding=0.0, db=db)

    assert response.media_type == "image/jpeg"
    img = Image.open(BytesIO(response.body))
    assert img.size == (500, 450)


def test_crop_with_padding():
    """Padding expands the crop region."""
    path = _make_test_jpeg(1000, 1500)
    db = _mock_db_with_scan(path)

    response = crop_scan_image("scan-1", x=0.2, y=0.2, w=0.4, h=0.3, padding=0.1, db=db)

    img = Image.open(BytesIO(response.body))
    # x: 0.2 - 0.04 = 0.16, w: 0.4 + 0.08 = 0.48 → 480px
    # y: 0.2 - 0.03 = 0.17, h: 0.3 + 0.06 = 0.36 → 540px
    assert img.size == (480, 540)


def test_crop_padding_clamps_to_edges():
    """Padding near image edges clamps to 0 and image dimensions."""
    path = _make_test_jpeg(1000, 1500)
    db = _mock_db_with_scan(path)

    response = crop_scan_image("scan-1", x=0.0, y=0.0, w=0.3, h=0.2, padding=0.5, db=db)

    img = Image.open(BytesIO(response.body))
    assert img.size[0] == 450
    assert img.size[1] == 450


def test_crop_404_for_missing_scan():
    """Crop returns 404 for non-existent scan."""
    from fastapi import HTTPException

    db = _mock_db_no_scan()
    with pytest.raises(HTTPException) as exc_info:
        crop_scan_image("nonexistent", x=0.1, y=0.2, w=0.5, h=0.3, db=db)
    assert exc_info.value.status_code == 404


def test_crop_404_for_missing_file():
    """Crop returns 404 if scan record exists but file is gone."""
    from fastapi import HTTPException

    db = _mock_db_with_scan("/tmp/nonexistent_scan_file.jpg")
    with pytest.raises(HTTPException) as exc_info:
        crop_scan_image("scan-1", x=0.1, y=0.2, w=0.5, h=0.3, db=db)
    assert exc_info.value.status_code == 404
