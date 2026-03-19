import pytest
from unittest.mock import MagicMock, patch

from app.services.claude_client import ClaudeClient


@pytest.fixture
def client():
    with patch("app.services.claude_client.anthropic.Anthropic") as mock_cls:
        mock_instance = MagicMock()
        mock_cls.return_value = mock_instance
        c = ClaudeClient()
        c._client = mock_instance
        yield c, mock_instance


def test_send_text_prompt(client):
    c, mock = client
    mock.messages.create.return_value = MagicMock(
        content=[MagicMock(text='{"result": "ok"}')],
        usage=MagicMock(input_tokens=100, output_tokens=50),
    )
    result = c.send_text("system prompt", "user message")
    assert result == '{"result": "ok"}'
    mock.messages.create.assert_called_once()


def test_send_vision_prompt(client):
    c, mock = client
    mock.messages.create.return_value = MagicMock(
        content=[MagicMock(text='{"assignments": []}')],
        usage=MagicMock(input_tokens=200, output_tokens=100),
    )
    result = c.send_vision("system prompt", b"fake-image-bytes", "What do you see?")
    assert '"assignments"' in result
    call_args = mock.messages.create.call_args
    # Verify image content block was included
    messages = call_args.kwargs["messages"]
    assert any(
        isinstance(block, dict) and block.get("type") == "image"
        for msg in messages
        for block in (msg["content"] if isinstance(msg["content"], list) else [])
    )
