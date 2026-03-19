import json
from unittest.mock import MagicMock, patch

import pytest

from app.services.example_generator import ExampleGeneratorService


MOCK_RESPONSE = json.dumps({
    "example_problem": "523 + 389 =",
    "steps": [
        {
            "step": 1,
            "instruction": "Stil tallene op efter pladsværdi",
            "visual": "  523\n+ 389\n-----",
            "explanation": "Vi skriver tallene så enerne er under enerne.",
        },
    ],
    "note": "Bemærk at dette er et andet regnestykke end dit — prøv den samme metode med dine tal!",
})


@pytest.fixture
def service():
    with patch("app.services.example_generator.ClaudeClient") as mock_cls:
        mock_client = MagicMock()
        mock_cls.return_value = mock_client
        mock_client.send_text.return_value = MOCK_RESPONSE
        svc = ExampleGeneratorService()
        svc.claude = mock_client
        yield svc


def test_generate_example_returns_steps(service):
    result = service.generate_example(
        assignment_type="addition",
        assignment_topic="three-digit addition with carrying",
        assignment_text="347 + 286 =",
        language="da",
    )
    assert result["example_problem"] == "523 + 389 ="
    assert len(result["steps"]) >= 1
    assert result["steps"][0]["step"] == 1


def test_generate_example_uses_different_numbers(service):
    result = service.generate_example(
        assignment_type="addition",
        assignment_topic="three-digit addition",
        assignment_text="347 + 286 =",
        language="da",
    )
    assert "347" not in result["example_problem"]
    assert "286" not in result["example_problem"]


def test_generate_example_includes_note(service):
    result = service.generate_example(
        assignment_type="addition",
        assignment_topic="addition",
        assignment_text="1 + 1 =",
        language="da",
    )
    assert "note" in result
    assert len(result["note"]) > 0
