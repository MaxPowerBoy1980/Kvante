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
