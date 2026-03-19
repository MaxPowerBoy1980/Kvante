import json
from unittest.mock import MagicMock, patch

import pytest

from app.services.work_analyzer import WorkAnalyzerService


MOCK_ANALYSIS = json.dumps({
    "student_answer": "633",
    "methodology_sound": True,
    "steps_identified": [
        {"step": 1, "description": "Added ones: 7+6=13, wrote 3, carried 1", "correct": True},
        {"step": 2, "description": "Added tens: 4+8+1=13, wrote 3, carried 1", "correct": True},
        {"step": 3, "description": "Added hundreds: 3+2+1=6", "correct": True},
    ],
    "errors": [],
    "correct_elements": ["Carrying technique", "Place value alignment"],
    "methodology_assessment": "Clean, systematic approach.",
    "handwriting_note": "Numbers are well-formed.",
    "confidence": 0.95,
})

MOCK_UNCLEAR = json.dumps({
    "student_answer": "",
    "methodology_sound": False,
    "steps_identified": [],
    "errors": ["unclear_image"],
    "correct_elements": [],
    "methodology_assessment": "Cannot read the handwritten work.",
    "handwriting_note": "Image is too blurry to analyze.",
    "confidence": 0.2,
})


@pytest.fixture
def service():
    with patch("app.services.work_analyzer.ClaudeClient") as mock_cls, \
         patch("app.services.work_analyzer.preprocess_handwritten_work", side_effect=lambda b: b):
        mock_client = MagicMock()
        mock_cls.return_value = mock_client
        mock_client.send_vision.return_value = MOCK_ANALYSIS
        svc = WorkAnalyzerService()
        svc.claude = mock_client
        yield svc, mock_client


def test_analyze_work_returns_structured_analysis(service):
    svc, _ = service
    result = svc.analyze_work(b"image-bytes", "347 + 286 =", "addition", "three-digit addition")
    assert result["methodology_sound"] is True
    assert result["student_answer"] == "633"
    assert len(result["steps_identified"]) == 3


def test_analyze_work_respects_confidence_threshold(service):
    svc, mock_client = service
    mock_client.send_vision.return_value = MOCK_UNCLEAR
    result = svc.analyze_work(b"blurry-image", "347 + 286 =", "addition", "addition")
    assert result["confidence"] < 0.6
    assert "unclear_image" in result["errors"]


def test_analyze_work_never_includes_correct_answer(service):
    svc, _ = service
    result = svc.analyze_work(b"image", "347 + 286 =", "addition", "addition")
    # The response must NOT have a "correct_answer" field
    assert "correct_answer" not in result
