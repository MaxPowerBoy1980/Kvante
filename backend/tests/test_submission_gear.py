"""Tests for gear_score in single-scan submissions (POST /submissions/)."""

import io
from unittest.mock import MagicMock, patch

from PIL import Image


def _make_test_jpeg() -> bytes:
    img = Image.new("RGB", (100, 100), "white")
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def _create_session_with_assignment(client, text="50 + 30", correct_answer="80"):
    from app.database import get_db
    from app.main import app
    from app.models.db import Assignment, Session

    db = next(app.dependency_overrides[get_db]())
    session = Session(
        student_id="default", mode="practice", name="Test", detected_language="da"
    )
    db.add(session)
    db.flush()
    assignment = Assignment(
        session_id=session.id,
        local_id="1",
        text=text,
        type="calculation",
        topic="addition",
        difficulty_estimate=2,
        correct_answer=correct_answer,
        position=0,
    )
    db.add(assignment)
    db.commit()
    return session.id, assignment.id


def _mock_ai_response():
    """Return a realistic AI analysis dict including gear_score fields."""
    return {
        "student_answer": "80",
        "methodology_sound": True,
        "steps_identified": [
            {"step": 1, "description": "Added 50+30=80", "correct": True}
        ],
        "errors": [],
        "correct_elements": ["Basic addition"],
        "methodology_assessment": "Correct approach.",
        "handwriting_note": "Clear handwriting.",
        "confidence": 0.95,
        "gear_score": {
            "correct_answer": 2,
            "visible_method": 2,
            "notation": 1,
        },
        "improvement_tip": "Husk at vise mellemregninger tydeligt.",
    }


@patch("app.routers.submissions.WorkAnalyzerService")
def test_submission_returns_gear_score(mock_analyzer_cls, client):
    """Submit with mocked WorkAnalyzerService — verify response has gear_score + improvement_tip."""
    session_id, assignment_id = _create_session_with_assignment(client)

    mock_analyzer = MagicMock()
    mock_analyzer_cls.return_value = mock_analyzer
    mock_analyzer.analyze_work.return_value = _mock_ai_response()

    jpeg_bytes = _make_test_jpeg()
    resp = client.post(
        "/submissions/",
        data={
            "session_id": session_id,
            "assignment_id": assignment_id,
            "answer_text": "80",
            "full_ocr_text": "50 + 30 = 80",
        },
        files={"image": ("work.jpg", jpeg_bytes, "image/jpeg")},
    )

    assert resp.status_code == 200
    data = resp.json()

    # gear_score must be present and correct
    assert data["gear_score"] is not None
    assert data["gear_score"]["correct_answer"] == 2
    assert data["gear_score"]["visible_method"] == 2
    assert data["gear_score"]["notation"] == 1
    assert data["gear_score"]["total"] == 5

    # improvement_tip must be present
    assert data["improvement_tip"] == "Husk at vise mellemregninger tydeligt."


@patch("app.routers.submissions.WorkAnalyzerService")
def test_submission_gear_score_fallback_on_analyzer_error(mock_analyzer_cls, client):
    """WorkAnalyzerService raises Exception — submission still succeeds with gear_score=None."""
    session_id, assignment_id = _create_session_with_assignment(client)

    mock_analyzer = MagicMock()
    mock_analyzer_cls.return_value = mock_analyzer
    mock_analyzer.analyze_work.side_effect = Exception("AI service unavailable")

    jpeg_bytes = _make_test_jpeg()
    resp = client.post(
        "/submissions/",
        data={
            "session_id": session_id,
            "assignment_id": assignment_id,
            "answer_text": "80",
            "full_ocr_text": "50 + 30 = 80",
        },
        files={"image": ("work.jpg", jpeg_bytes, "image/jpeg")},
    )

    assert resp.status_code == 200
    data = resp.json()

    # Should succeed but without gear data
    assert data["gear_score"] is None
    assert data["improvement_tip"] is None
    assert "submission_id" in data


@patch("app.routers.submissions.WorkAnalyzerService")
def test_submission_gear_score_stored_in_analysis(mock_analyzer_cls, client):
    """Submit, then GET /sessions/{id} — verify gear_score appears in session detail."""
    session_id, assignment_id = _create_session_with_assignment(client)

    mock_analyzer = MagicMock()
    mock_analyzer_cls.return_value = mock_analyzer
    mock_analyzer.analyze_work.return_value = _mock_ai_response()

    jpeg_bytes = _make_test_jpeg()
    resp = client.post(
        "/submissions/",
        data={
            "session_id": session_id,
            "assignment_id": assignment_id,
            "answer_text": "80",
            "full_ocr_text": "50 + 30 = 80",
        },
        files={"image": ("work.jpg", jpeg_bytes, "image/jpeg")},
    )
    assert resp.status_code == 200

    # Now fetch session detail and verify gear_score is stored
    detail_resp = client.get(f"/sessions/{session_id}")
    assert detail_resp.status_code == 200
    detail = detail_resp.json()

    assignments = detail["assignments"]
    assert len(assignments) == 1
    a = assignments[0]

    assert a["gear_score"] is not None
    assert a["gear_score"]["correct_answer"] == 2
    assert a["gear_score"]["visible_method"] == 2
    assert a["gear_score"]["notation"] == 1
    assert a["gear_score"]["total"] == 5
    assert a["improvement_tip"] == "Husk at vise mellemregninger tydeligt."
