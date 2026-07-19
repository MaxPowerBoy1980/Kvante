"""Full flow integration test with mocked Claude API.

Workflow: scan page → pick assignment → get example → submit work
"""
import io
import json
from unittest.mock import patch, MagicMock

from PIL import Image
import pytest


def _jpeg() -> bytes:
    img = Image.new("RGB", (200, 200), "white")
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


PARSED_PAGE = json.dumps({
    "assignments": [
        {"id": "1a", "text": "25 + 17 =", "type": "addition",
         "topic": "two-digit addition with carrying", "difficulty_estimate": 1,
         "position_on_page": "top-left"},
        {"id": "1b", "text": "43 - 28 =", "type": "subtraction",
         "topic": "two-digit subtraction with borrowing", "difficulty_estimate": 2,
         "position_on_page": "top-right"},
    ],
    "page_context": "Chapter 1: Addition and subtraction",
    "suggested_order": ["1a", "1b"],
    "suggested_start": "1a",
    "reasoning": "1a is simpler.",
    "detected_language": "da",
})

EXAMPLE = json.dumps({
    "example_problem": "38 + 24 =",
    "pedagogy": "concrete-first",
    "steps": [
        {"step": 1, "phase": "concrete", "text": "Vi tegner 38 cirkler.",
         "visual": {"type": "object_collection", "action": "draw", "object": "circle", "count": 20, "layout": "rows", "rows": 2},
         "audio_cue": "Vi tegner 38 cirkler."},
        {"step": 2, "phase": "abstract", "text": "38 + 24 = 62",
         "visual": {"type": "equation", "action": "reveal", "parts": ["38", "+", "24", "=", "62"], "highlight": 4},
         "audio_cue": "38 plus 24 er lig med 62."},
    ],
    "note": "Bemaerk: dette er andre tal end din opgave!",
})

ANALYSIS = json.dumps({
    "student_answer": "42",
    "methodology_sound": True,
    "steps_identified": [
        {"step": 1, "description": "Added ones: 5+7=12, wrote 2, carried 1", "correct": True},
        {"step": 2, "description": "Added tens: 2+1+1=4", "correct": True},
    ],
    "errors": [],
    "correct_elements": ["Carrying", "Place value"],
    "methodology_assessment": "Perfect method.",
    "handwriting_note": "Clear.",
    "confidence": 0.95,
})

def test_full_workflow(client, test_db):
    """Test the complete Kvante workflow end-to-end."""

    mock_parser = MagicMock()
    mock_parser.send_vision.return_value = PARSED_PAGE
    mock_example = MagicMock()
    mock_example.send_text.return_value = EXAMPLE
    mock_analyzer = MagicMock()
    mock_analyzer.send_vision.return_value = ANALYSIS

    with patch("app.services.page_parser.get_ai_client", return_value=mock_parser), \
         patch("app.services.page_parser.preprocess_textbook_page", side_effect=lambda b: b), \
         patch("app.services.example_generator.get_ai_client", return_value=mock_example), \
         patch("app.services.work_analyzer.get_ai_client", return_value=mock_analyzer), \
         patch("app.services.work_analyzer.preprocess_handwritten_work", side_effect=lambda b: b), \
         patch("app.routers.submissions.read_student_answer",
               return_value={"answer": "42", "readable": True, "elapsed": 0.1}):

        # 1. Scan page
        resp = client.post("/pages/scan", files={"image": ("page.jpg", _jpeg(), "image/jpeg")})
        assert resp.status_code == 200, resp.text
        page_data = resp.json()
        session_id = page_data["session_id"]
        assert len(page_data["assignments"]) == 2
        assignment_id = page_data["assignments"][0]["id"]

        # 2. Get example for first assignment
        resp = client.post(f"/sessions/{session_id}/assignments/{assignment_id}/example")
        assert resp.status_code == 200, resp.text
        example_data = resp.json()
        assert example_data["example_problem"] == "38 + 24 ="
        assert len(example_data["steps"]) >= 1

        # 3. Submit handwritten work
        # Scanned assignments carry no ground truth; methodology_sound == is_correct
        # requires correct_answer to be set (as the practice flow does).
        from app.models.db import Assignment

        db_assignment = test_db.query(Assignment).filter(Assignment.id == assignment_id).first()
        db_assignment.correct_answer = "42"
        test_db.commit()

        resp = client.post(
            "/submissions/",
            data={"session_id": session_id, "assignment_id": assignment_id},
            files={"image": ("work.jpg", _jpeg(), "image/jpeg")},
        )
        assert resp.status_code == 200, resp.text
        submission_data = resp.json()
        assert submission_data["methodology_sound"] is True

    # 4. Health check
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"
