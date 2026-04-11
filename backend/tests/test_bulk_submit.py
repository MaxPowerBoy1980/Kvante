"""Tests for bulk-scan submission (Pakke 4)."""

from unittest.mock import patch, MagicMock
import json

from app.services.ai_client import ClaudeAIClient


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
