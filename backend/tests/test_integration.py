"""Full flow integration test with mocked Claude API.

Workflow: scan page → pick assignment → get example → submit work → get feedback → followup
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
    "steps": [
        {"step": 1, "instruction": "Stil tallene op", "visual": " 38\n+24\n---",
         "explanation": "Enerne under enerne."},
    ],
    "note": "Bemærk: dette er andre tal end din opgave!",
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

FEEDBACK = json.dumps({
    "feedback_text": "Fantastisk arbejde! Du har mestret mente-teknikken perfekt.",
    "tone": "celebratory",
})

FOLLOWUP = json.dumps({
    "feedback_text": "Du stillede tallene flot op og huskede at gemme mente — det er det vigtigste!",
    "tone": "celebratory",
})


def test_full_workflow(client):
    """Test the complete Kvante workflow end-to-end."""

    with patch("app.services.page_parser.ClaudeClient") as mock_parser_client, \
         patch("app.services.page_parser.preprocess_textbook_page", side_effect=lambda b: b), \
         patch("app.services.example_generator.ClaudeClient") as mock_example_client, \
         patch("app.services.work_analyzer.ClaudeClient") as mock_analyzer_client, \
         patch("app.services.work_analyzer.preprocess_handwritten_work", side_effect=lambda b: b), \
         patch("app.services.feedback_generator.ClaudeClient") as mock_feedback_client:

        mock_parser_client.return_value.send_vision.return_value = PARSED_PAGE
        mock_example_client.return_value.send_text.return_value = EXAMPLE
        mock_analyzer_client.return_value.send_vision.return_value = ANALYSIS
        mock_feedback_client.return_value.send_text.return_value = FEEDBACK

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
        resp = client.post(
            "/submissions/",
            data={"session_id": session_id, "assignment_id": assignment_id},
            files={"image": ("work.jpg", _jpeg(), "image/jpeg")},
        )
        assert resp.status_code == 200, resp.text
        submission_data = resp.json()
        submission_id = submission_data["submission_id"]
        assert submission_data["methodology_sound"] is True

        # 4. Get feedback
        resp = client.post("/feedback/", json={"submission_id": submission_id, "language": "da"})
        assert resp.status_code == 200, resp.text
        feedback_data = resp.json()
        assert "Fantastisk" in feedback_data["feedback_text"]
        assert len(feedback_data["structured_prompts"]) == 6
        prompt_ids = [p["id"] for p in feedback_data["structured_prompts"]]
        assert "explain_different" in prompt_ids
        assert "next_assignment" in prompt_ids

        # 5. Followup — "What did I do well?"
        mock_feedback_client.return_value.send_text.return_value = FOLLOWUP
        resp = client.post(
            f"/feedback/{submission_id}/followup",
            json={"action": "what_did_well"},
        )
        assert resp.status_code == 200, resp.text
        followup_data = resp.json()
        assert len(followup_data["feedback_text"]) > 0

    # 6. Health check
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"
