import json
from unittest.mock import patch, MagicMock
import io
from PIL import Image

import pytest


def _make_test_jpeg() -> bytes:
    img = Image.new("RGB", (100, 100), "white")
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "ok"
    assert "version" in data


@patch("app.routers.pages.PageParserService")
def test_page_scan(mock_parser_cls, client):
    mock_parser = MagicMock()
    mock_parser_cls.return_value = mock_parser
    mock_parser.parse_page.return_value = {
        "assignments": [
            {"id": "1a", "text": "2+3=", "type": "addition",
             "topic": "simple addition", "difficulty_estimate": 1,
             "position_on_page": "top-left"}
        ],
        "page_context": "Chapter 1",
        "suggested_order": ["1a"],
        "suggested_start": "1a",
        "reasoning": "Only one assignment.",
        "detected_language": "da",
    }
    jpeg = _make_test_jpeg()
    resp = client.post("/pages/scan", files={"image": ("page.jpg", jpeg, "image/jpeg")})
    assert resp.status_code == 200
    data = resp.json()
    assert "session_id" in data
    assert len(data["assignments"]) == 1


@patch("app.routers.assignments.ExampleGeneratorService")
def test_get_example_404_for_missing_session(mock_gen_cls, client):
    resp = client.post("/sessions/nonexistent/assignments/1a/example")
    assert resp.status_code == 404


@patch("app.services.work_analyzer.preprocess_handwritten_work", side_effect=lambda b: b)
@patch("app.routers.submissions.WorkAnalyzerService")
def test_submit_work(mock_analyzer_cls, mock_preprocess, client):
    # First create a session by scanning a page
    with patch("app.routers.pages.PageParserService") as mock_parser_cls:
        mock_parser = MagicMock()
        mock_parser_cls.return_value = mock_parser
        mock_parser.parse_page.return_value = {
            "assignments": [
                {"id": "1a", "text": "2+3=", "type": "addition",
                 "topic": "addition", "difficulty_estimate": 1,
                 "position_on_page": "top"}
            ],
            "page_context": "Ch 1",
            "suggested_order": ["1a"],
            "suggested_start": "1a",
            "reasoning": "Simple.",
            "detected_language": "da",
        }
        scan_resp = client.post(
            "/pages/scan", files={"image": ("page.jpg", _make_test_jpeg(), "image/jpeg")}
        )
    session_id = scan_resp.json()["session_id"]
    assignments = scan_resp.json()["assignments"]
    assignment_id = assignments[0]["id"]

    mock_analyzer = MagicMock()
    mock_analyzer_cls.return_value = mock_analyzer
    mock_analyzer.analyze_work.return_value = {
        "student_answer": "5",
        "methodology_sound": True,
        "steps_identified": [{"step": 1, "description": "Added 2+3=5", "correct": True}],
        "errors": [],
        "correct_elements": ["Basic addition"],
        "methodology_assessment": "Correct.",
        "handwriting_note": "Clear.",
        "confidence": 0.95,
    }

    resp = client.post(
        "/submissions/",
        data={"session_id": session_id, "assignment_id": assignment_id},
        files={"image": ("work.jpg", _make_test_jpeg(), "image/jpeg")},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["methodology_sound"] is True
    assert "submission_id" in data
