import pytest
from unittest.mock import MagicMock, patch

from app.services.ai_client import ClaudeAIClient, GeminiAIClient, get_ai_client


@pytest.fixture
def claude_client():
    with patch("anthropic.Anthropic") as mock_cls:
        mock_instance = MagicMock()
        mock_cls.return_value = mock_instance
        c = ClaudeAIClient()
        c._client = mock_instance
        yield c, mock_instance


def test_send_text_prompt(claude_client):
    c, mock = claude_client
    mock.messages.create.return_value = MagicMock(
        content=[MagicMock(text='{"result": "ok"}')],
        usage=MagicMock(input_tokens=100, output_tokens=50),
    )
    result = c.send_text("system prompt", "user message")
    assert result == '{"result": "ok"}'
    mock.messages.create.assert_called_once()


def test_send_vision_prompt(claude_client):
    c, mock = claude_client
    mock.messages.create.return_value = MagicMock(
        content=[MagicMock(text='{"assignments": []}')],
        usage=MagicMock(input_tokens=200, output_tokens=100),
    )
    result = c.send_vision("system prompt", b"fake-image-bytes", "What do you see?")
    assert '"assignments"' in result
    call_args = mock.messages.create.call_args
    messages = call_args.kwargs["messages"]
    assert any(
        isinstance(block, dict) and block.get("type") == "image"
        for msg in messages
        for block in (msg["content"] if isinstance(msg["content"], list) else [])
    )


def test_get_ai_client_returns_claude():
    with patch("app.services.ai_client.settings") as mock_settings, \
         patch("anthropic.Anthropic"):
        mock_settings.ai_provider = "claude"
        mock_settings.anthropic_api_key = "fake-key"
        mock_settings.claude_model = "claude-sonnet-4-20250514"
        client = get_ai_client()
        assert isinstance(client, ClaudeAIClient)


def test_get_ai_client_returns_gemini():
    with patch("app.services.ai_client.settings") as mock_settings, \
         patch("google.genai.Client"):
        mock_settings.ai_provider = "gemini"
        mock_settings.google_api_key = "fake-key"
        mock_settings.gemini_model = "gemini-2.5-flash"
        client = get_ai_client()
        assert isinstance(client, GeminiAIClient)


def test_get_ai_client_invalid_provider():
    with patch("app.services.ai_client.settings") as mock_settings:
        mock_settings.ai_provider = "invalid"
        with pytest.raises(ValueError, match="Unknown AI provider"):
            get_ai_client()
