import json
from unittest.mock import MagicMock, patch

import pytest

from app.services.feedback_generator import FeedbackGeneratorService


MOCK_FEEDBACK = json.dumps({
    "feedback_text": "Flot arbejde! Du har stillet tallene pænt op.",
    "tone": "celebratory",
})

MOCK_FOLLOWUP = json.dumps({
    "feedback_text": "Prøv at tænke på det sådan her: hvis du har 347 bolde...",
    "tone": "encouraging",
})

ANALYSIS = {
    "student_answer": "633",
    "methodology_sound": True,
    "steps_identified": [{"step": 1, "description": "Added ones", "correct": True}],
    "errors": [],
    "correct_elements": ["Carrying technique"],
    "methodology_assessment": "Good approach.",
    "confidence": 0.95,
}


@pytest.fixture
def service():
    mock_client = MagicMock()
    mock_client.send_text.return_value = MOCK_FEEDBACK
    with patch("app.services.feedback_generator.get_ai_client", return_value=mock_client):
        svc = FeedbackGeneratorService()
        yield svc, mock_client


def test_generate_feedback_returns_text_and_tone(service):
    svc, _ = service
    result = svc.generate_feedback(
        assignment_text="347 + 286 =",
        analysis=ANALYSIS,
        language="da",
    )
    assert "feedback_text" in result
    assert result["tone"] in ("celebratory", "encouraging", "supportive")


def test_generate_feedback_includes_structured_prompts(service):
    svc, _ = service
    result = svc.generate_feedback(
        assignment_text="347 + 286 =",
        analysis=ANALYSIS,
        language="da",
    )
    assert "structured_prompts" in result
    prompt_ids = [p["id"] for p in result["structured_prompts"]]
    assert "explain_different" in prompt_ids
    assert "try_again" in prompt_ids
    assert "next_assignment" in prompt_ids


def test_generate_followup(service):
    svc, mock_client = service
    mock_client.send_text.return_value = MOCK_FOLLOWUP
    result = svc.generate_followup(
        assignment_text="347 + 286 =",
        previous_feedback="Flot arbejde!",
        action="explain_different",
        language="da",
    )
    assert "feedback_text" in result
    assert len(result["feedback_text"]) > 0
