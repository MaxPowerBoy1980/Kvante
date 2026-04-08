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
    assert resp.json()["detail"] == "Ingen TODOs"


def test_latest_endpoint_returns_newest(client):
    """GET /dev/todos/latest returns the most recent TODO metadata."""
    import time
    client.post("/dev/todos", data={"note": "old"})
    time.sleep(0.01)
    client.post("/dev/todos", data={"note": "new"})

    resp = client.get("/dev/todos/latest")
    assert resp.status_code == 200
    assert resp.json()["note"] == "new"
