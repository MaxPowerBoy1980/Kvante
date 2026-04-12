"""Unit tests for bulk-scan components (Pakke 4).

These tests cover AIClient.send_vision_multi, build_user_message, parse_ai_response,
and validate_and_build_results — all without touching SQLAlchemy or the FastAPI router.

Router integration tests live in test_bulk_submit_router.py which uses sys.modules
stubs to bypass the Python 3.14 / SQLAlchemy 2.0 incompatibility.
"""

import json
from unittest.mock import MagicMock, patch

import pytest

from app.services.ai_client import ClaudeAIClient
from app.services.bulk_scan_service import build_user_message, parse_ai_response, validate_and_build_results


def test_send_vision_multi_sends_all_images():
    """send_vision_multi should include all images in the messages content."""
    with patch("app.services.ai_client.ClaudeAIClient.__init__", return_value=None):
        client = ClaudeAIClient()
        client._model = "claude-haiku-4-5-20251001"

        mock_response = MagicMock()
        mock_response.content = [MagicMock(text='{"matches": []}')]
        mock_response.usage = MagicMock(input_tokens=100, output_tokens=50)

        mock_anthropic_client = MagicMock()
        mock_anthropic_client.messages.create.return_value = mock_response
        client._client = mock_anthropic_client

        result = client.send_vision_multi(
            system_prompt="test prompt",
            images=[b"fake_image_1", b"fake_image_2"],
            user_message="test message",
        )

        assert result == '{"matches": []}'

        call_args = mock_anthropic_client.messages.create.call_args
        content_blocks = call_args.kwargs["messages"][0]["content"]

        # 2 image blocks + 1 text block
        image_blocks = [b for b in content_blocks if b["type"] == "image"]
        text_blocks = [b for b in content_blocks if b["type"] == "text"]
        assert len(image_blocks) == 2
        assert len(text_blocks) == 1


# ---------------------------------------------------------------------------
# build_user_message
# ---------------------------------------------------------------------------

def test_build_user_message_includes_all_assignments():
    """User message should list all assignments with index, text, and correct answer."""
    assignments = [
        {"index": 0, "text": "34 + 67", "correct_answer": "101"},
        {"index": 1, "text": "245 + 378", "correct_answer": "623"},
        {"index": 2, "text": "7 × 8", "correct_answer": "56"},
    ]
    msg = build_user_message(assignments)

    assert "34 + 67" in msg
    assert "245 + 378" in msg
    assert "101" in msg
    assert "623" in msg
    assert "Opgave 1" in msg
    assert "Opgave 3" in msg


# ---------------------------------------------------------------------------
# parse_ai_response
# ---------------------------------------------------------------------------

def test_parse_ai_response_valid_json():
    """parse_ai_response should extract matches from valid AI JSON."""
    ai_text = json.dumps({
        "matches": [
            {
                "assignment_index": 0,
                "student_answer": "101",
                "confidence": 0.95,
                "page_index": 0,
                "error_type": None,
                "error_description": None,
            },
            {
                "assignment_index": 2,
                "student_answer": "52",
                "confidence": 0.88,
                "page_index": 0,
                "error_type": "careless",
                "error_description": "Forkert tabel-produkt",
            },
        ]
    })
    matches = parse_ai_response(ai_text)
    assert len(matches) == 2
    assert matches[0]["assignment_index"] == 0
    assert matches[0]["student_answer"] == "101"
    assert matches[1]["error_type"] == "careless"


def test_parse_ai_response_strips_markdown_fences():
    """parse_ai_response should handle AI wrapping JSON in ```json ... ``` blocks."""
    ai_text = '```json\n{"matches": [{"assignment_index": 0, "student_answer": "42", "confidence": 0.9, "page_index": 0, "error_type": null, "error_description": null}]}\n```'
    matches = parse_ai_response(ai_text)
    assert len(matches) == 1
    assert matches[0]["student_answer"] == "42"


def test_parse_ai_response_invalid_json_raises():
    """parse_ai_response should raise ValueError on invalid JSON."""
    with pytest.raises(ValueError, match="parse AI"):
        parse_ai_response("this is not json at all")


# ---------------------------------------------------------------------------
# validate_and_build_results
# ---------------------------------------------------------------------------

def _mock_assignment(id="a1", text="34 + 67", correct_answer="101", status="not_started"):
    a = MagicMock()
    a.id = id
    a.text = text
    a.correct_answer = correct_answer
    a.status = status
    return a


def test_validate_correct_answer():
    """Correct student answer should produce status='correct'."""
    assignments = [_mock_assignment(id="a1", text="34 + 67", correct_answer="101")]
    matches = [{"assignment_index": 0, "student_answer": "101", "confidence": 0.95, "page_index": 0, "error_type": None, "error_description": None}]

    results = validate_and_build_results(matches, assignments, confidence_threshold=0.6)
    assert len(results) == 1
    assert results[0]["status"] == "correct"
    assert results[0]["error_type"] is None


def test_validate_incorrect_answer():
    """Wrong answer should produce status='incorrect' with error info preserved."""
    assignments = [_mock_assignment(id="a1", text="245 + 378", correct_answer="623")]
    matches = [{"assignment_index": 0, "student_answer": "613", "confidence": 0.88, "page_index": 0, "error_type": "procedural", "error_description": "Mente-fejl"}]

    results = validate_and_build_results(matches, assignments, confidence_threshold=0.6)
    assert len(results) == 1
    assert results[0]["status"] == "incorrect"
    assert results[0]["error_type"] == "procedural"
    assert results[0]["error_description"] == "Mente-fejl"


def test_validate_low_confidence_is_uncertain():
    """Confidence below threshold should produce status='uncertain'."""
    assignments = [_mock_assignment()]
    matches = [{"assignment_index": 0, "student_answer": "101", "confidence": 0.3, "page_index": 0, "error_type": None, "error_description": None}]

    results = validate_and_build_results(matches, assignments, confidence_threshold=0.6)
    assert len(results) == 1
    assert results[0]["status"] == "uncertain"


def test_validate_skips_complete_assignments():
    """Already-complete assignments should be skipped."""
    assignments = [_mock_assignment(status="complete")]
    matches = [{"assignment_index": 0, "student_answer": "101", "confidence": 0.95, "page_index": 0, "error_type": None, "error_description": None}]

    results = validate_and_build_results(matches, assignments, confidence_threshold=0.6)
    assert len(results) == 0


def test_validate_deduplicates_highest_confidence():
    """When AI returns two matches for the same assignment, keep highest confidence."""
    assignments = [_mock_assignment()]
    matches = [
        {"assignment_index": 0, "student_answer": "100", "confidence": 0.6, "page_index": 0, "error_type": None, "error_description": None},
        {"assignment_index": 0, "student_answer": "101", "confidence": 0.9, "page_index": 1, "error_type": None, "error_description": None},
    ]

    results = validate_and_build_results(matches, assignments, confidence_threshold=0.6)
    assert len(results) == 1
    assert results[0]["student_answer"] == "101"
    assert results[0]["confidence"] == 0.9


from app.services.bulk_scan_service import validate_bounding_box


# ---------------------------------------------------------------------------
# validate_bounding_box
# ---------------------------------------------------------------------------

def test_validate_bounding_box_valid():
    """A well-formed bounding box passes validation."""
    assert validate_bounding_box([0.05, 0.22, 0.45, 0.18]) == [0.05, 0.22, 0.45, 0.18]


def test_validate_bounding_box_none_input():
    """None input returns None."""
    assert validate_bounding_box(None) is None


def test_validate_bounding_box_wrong_length():
    """List with != 4 elements returns None."""
    assert validate_bounding_box([0.1, 0.2, 0.3]) is None
    assert validate_bounding_box([0.1, 0.2, 0.3, 0.4, 0.5]) is None


def test_validate_bounding_box_out_of_range():
    """Values outside 0.0–1.0 return None."""
    assert validate_bounding_box([-0.1, 0.2, 0.3, 0.4]) is None
    assert validate_bounding_box([0.1, 0.2, 1.5, 0.4]) is None


def test_validate_bounding_box_too_small():
    """Width or height < 0.03 returns None (micro-box misfire)."""
    assert validate_bounding_box([0.1, 0.2, 0.02, 0.5]) is None
    assert validate_bounding_box([0.1, 0.2, 0.5, 0.01]) is None


def test_validate_bounding_box_too_large():
    """Area > 0.50 returns None (covers too much of the page)."""
    assert validate_bounding_box([0.0, 0.0, 0.8, 0.8]) is None  # area = 0.64


def test_validate_bounding_box_at_area_boundary():
    """Area exactly at 0.50 should be rejected (not strictly less)."""
    assert validate_bounding_box([0.0, 0.0, 0.5, 1.0]) is None  # area = 0.50


def test_validate_bounding_box_non_list():
    """Non-list input returns None."""
    assert validate_bounding_box("not a list") is None
    assert validate_bounding_box(42) is None


def test_validate_preserves_bounding_box():
    """Valid bounding_box flows through validate_and_build_results."""
    assignments = [_mock_assignment()]
    matches = [{
        "assignment_index": 0, "student_answer": "101", "confidence": 0.95,
        "page_index": 0, "error_type": None, "error_description": None,
        "bounding_box": [0.05, 0.22, 0.45, 0.18],
    }]
    results = validate_and_build_results(matches, assignments, confidence_threshold=0.6)
    assert results[0]["bounding_box"] == [0.05, 0.22, 0.45, 0.18]


def test_validate_nullifies_invalid_bounding_box():
    """Invalid bounding_box becomes None in results."""
    assignments = [_mock_assignment()]
    matches = [{
        "assignment_index": 0, "student_answer": "101", "confidence": 0.95,
        "page_index": 0, "error_type": None, "error_description": None,
        "bounding_box": [0.0, 0.0, 0.9, 0.9],
    }]
    results = validate_and_build_results(matches, assignments, confidence_threshold=0.6)
    assert results[0]["bounding_box"] is None


def test_validate_handles_missing_bounding_box():
    """Missing bounding_box key in match produces None in results."""
    assignments = [_mock_assignment()]
    matches = [{
        "assignment_index": 0, "student_answer": "101", "confidence": 0.95,
        "page_index": 0, "error_type": None, "error_description": None,
    }]
    results = validate_and_build_results(matches, assignments, confidence_threshold=0.6)
    assert results[0]["bounding_box"] is None
