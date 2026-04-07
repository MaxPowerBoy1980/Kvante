"""Tests for the /dev/screenshots router."""
import io

import pytest
from PIL import Image

from app.config import settings


@pytest.fixture(autouse=True)
def screenshots_tmp_dir(tmp_path, monkeypatch):
    """Redirect screenshot storage to a tmp dir for each test."""
    target = tmp_path / "screenshots"
    monkeypatch.setattr(settings, "dev_screenshots_dir", str(target))
    monkeypatch.setattr(settings, "dev_screenshots_keep", 3)
    return target


def _png(color: str = "red") -> bytes:
    img = Image.new("RGB", (50, 50), color)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def test_upload_returns_metadata(client):
    resp = client.post(
        "/dev/screenshots",
        files={"image": ("shot.png", _png(), "image/png")},
        data={"note": "button is too small"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["note"] == "button is too small"
    assert body["filename"].endswith(".png")
    assert len(body["id"]) == 12
    assert body["timestamp"] > 0


def test_upload_without_note(client):
    resp = client.post(
        "/dev/screenshots",
        files={"image": ("shot.png", _png(), "image/png")},
    )
    assert resp.status_code == 200
    assert resp.json()["note"] == ""


def test_list_newest_first(client):
    import time
    for note in ["first", "second", "third"]:
        client.post(
            "/dev/screenshots",
            files={"image": ("s.png", _png(), "image/png")},
            data={"note": note},
        )
        time.sleep(0.01)  # ensure distinct mtimes

    resp = client.get("/dev/screenshots")
    assert resp.status_code == 200
    notes = [s["note"] for s in resp.json()["screenshots"]]
    assert notes == ["third", "second", "first"]


def test_get_latest_returns_image(client):
    client.post(
        "/dev/screenshots",
        files={"image": ("s.png", _png("blue"), "image/png")},
        data={"note": "latest"},
    )
    resp = client.get("/dev/screenshots/latest")
    assert resp.status_code == 200
    assert resp.headers["content-type"] == "image/png"
    assert len(resp.content) > 0


def test_get_latest_404_when_empty(client):
    resp = client.get("/dev/screenshots/latest")
    assert resp.status_code == 404


def test_get_by_id(client):
    upload = client.post(
        "/dev/screenshots",
        files={"image": ("s.png", _png(), "image/png")},
        data={"note": "find me"},
    )
    screenshot_id = upload.json()["id"]
    resp = client.get(f"/dev/screenshots/{screenshot_id}")
    assert resp.status_code == 200
    assert resp.headers["content-type"] == "image/png"


def test_get_by_id_404(client):
    resp = client.get("/dev/screenshots/nonexistent")
    assert resp.status_code == 404


def test_retention_keeps_only_latest_n(client, screenshots_tmp_dir):
    import time
    # Upload 5; keep limit is 3 (set in fixture)
    for i in range(5):
        client.post(
            "/dev/screenshots",
            files={"image": ("s.png", _png(), "image/png")},
            data={"note": f"shot {i}"},
        )
        time.sleep(0.01)

    resp = client.get("/dev/screenshots")
    assert len(resp.json()["screenshots"]) == 3
    notes = [s["note"] for s in resp.json()["screenshots"]]
    assert notes == ["shot 4", "shot 3", "shot 2"]

    # Verify files on disk
    pngs = list(screenshots_tmp_dir.glob("*.png"))
    jsons = list(screenshots_tmp_dir.glob("*.json"))
    assert len(pngs) == 3
    assert len(jsons) == 3
