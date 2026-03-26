import json
import pytest
from unittest.mock import patch, MagicMock
from app.services.example_generator import ExampleGeneratorService


VALID_RESPONSE = json.dumps({
    "example_problem": "15 - 3",
    "pedagogy": "concrete-first",
    "note": "Dette eksempel bruger andre tal.",
    "steps": [
        {
            "step": 1,
            "phase": "concrete",
            "text": "Vi tegner 15 cirkler.",
            "visual": {"type": "object_collection", "action": "draw", "object": "circle", "count": 15, "layout": "rows", "rows": 2},
            "audio_cue": "Vi tegner femten cirkler."
        },
        {
            "step": 2,
            "phase": "abstract",
            "text": "15 - 3 = 12",
            "visual": {"type": "equation", "action": "reveal", "parts": ["15", "-", "3", "=", "12"], "highlight": 4},
            "audio_cue": "Femten minus tre er lig med tolv."
        }
    ]
})

INVALID_RESPONSE = "This is not JSON at all"


def make_service_with_mock(responses):
    """Create ExampleGeneratorService with mocked AI client."""
    service = ExampleGeneratorService.__new__(ExampleGeneratorService)
    mock_client = MagicMock()
    mock_client.send_text = MagicMock(side_effect=responses)
    service.client = mock_client
    service._system_prompt = "test prompt"
    return service


def test_valid_response_parses():
    service = make_service_with_mock([VALID_RESPONSE])
    result = service.generate_example("subtraction", "simple subtraction", "17 - 8", "da")
    assert result["example_problem"] == "15 - 3"
    assert len(result["steps"]) == 2
    assert result["steps"][0]["visual"]["type"] == "object_collection"


def test_invalid_then_valid_retries():
    service = make_service_with_mock([INVALID_RESPONSE, VALID_RESPONSE])
    result = service.generate_example("subtraction", "simple subtraction", "17 - 8", "da")
    assert result["example_problem"] == "15 - 3"
    assert service.client.send_text.call_count == 2


def test_two_invalid_raises():
    service = make_service_with_mock([INVALID_RESPONSE, INVALID_RESPONSE])
    with pytest.raises(ValueError, match="Failed to parse"):
        service.generate_example("subtraction", "simple subtraction", "17 - 8", "da")


def test_too_many_steps_retries():
    many_steps = json.loads(VALID_RESPONSE)
    many_steps["steps"] = many_steps["steps"] * 5  # 10 steps, over max of 8
    service = make_service_with_mock([json.dumps(many_steps), VALID_RESPONSE])
    result = service.generate_example("subtraction", "simple subtraction", "17 - 8", "da")
    assert len(result["steps"]) <= 8
    assert service.client.send_text.call_count == 2
