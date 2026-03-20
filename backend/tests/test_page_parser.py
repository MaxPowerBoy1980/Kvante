import json
from unittest.mock import MagicMock, patch

import pytest

from app.services.page_parser import PageParserService


MOCK_CLAUDE_RESPONSE = json.dumps({
    "assignments": [
        {
            "id": "3a",
            "text": "347 + 286 =",
            "type": "addition",
            "topic": "three-digit addition with carrying",
            "difficulty_estimate": 2,
            "position_on_page": "top-left",
        },
        {
            "id": "3b",
            "text": "1.203 - 847 =",
            "type": "subtraction",
            "topic": "four-digit subtraction with borrowing",
            "difficulty_estimate": 3,
            "position_on_page": "top-right",
        },
    ],
    "page_context": "Chapter 4: Addition and subtraction",
    "suggested_order": ["3a", "3b"],
    "suggested_start": "3a",
    "reasoning": "3a is simpler.",
    "detected_language": "da",
})


@pytest.fixture
def service():
    mock_client = MagicMock()
    mock_client.send_vision.return_value = MOCK_CLAUDE_RESPONSE
    with patch("app.services.page_parser.get_ai_client", return_value=mock_client), \
         patch("app.services.page_parser.preprocess_textbook_page", side_effect=lambda b: b):
        svc = PageParserService()
        yield svc


def test_parse_page_returns_assignments(service):
    result = service.parse_page(b"fake-image-bytes")
    assert len(result["assignments"]) == 2
    assert result["assignments"][0]["id"] == "3a"
    assert result["assignments"][1]["type"] == "subtraction"


def test_parse_page_includes_suggestion(service):
    result = service.parse_page(b"fake-image-bytes")
    assert result["suggested_start"] == "3a"
    assert result["detected_language"] == "da"


def test_parse_page_sends_image_to_client(service):
    service.parse_page(b"test-image")
    service.client.send_vision.assert_called_once()
    call_args = service.client.send_vision.call_args
    assert b"test-image" in call_args.args or b"test-image" == call_args.args[1]
