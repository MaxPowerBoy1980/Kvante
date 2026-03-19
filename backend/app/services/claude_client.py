import base64
import logging

import anthropic

from app.config import settings

logger = logging.getLogger(__name__)


class ClaudeClient:
    def __init__(self):
        self._client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        self._model = settings.claude_model

    def send_text(self, system_prompt: str, user_message: str) -> str:
        """Send a text-only prompt to Claude. Returns the text response."""
        response = self._client.messages.create(
            model=self._model,
            max_tokens=4096,
            system=system_prompt,
            messages=[{"role": "user", "content": user_message}],
        )
        self._log_usage(response.usage)
        return response.content[0].text

    def send_vision(
        self,
        system_prompt: str,
        image_bytes: bytes,
        user_message: str,
        media_type: str = "image/jpeg",
    ) -> str:
        """Send an image + text prompt to Claude Vision. Returns the text response."""
        image_b64 = base64.b64encode(image_bytes).decode("utf-8")
        response = self._client.messages.create(
            model=self._model,
            max_tokens=4096,
            system=system_prompt,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": media_type,
                                "data": image_b64,
                            },
                        },
                        {"type": "text", "text": user_message},
                    ],
                }
            ],
        )
        self._log_usage(response.usage)
        return response.content[0].text

    def _log_usage(self, usage) -> None:
        logger.info(
            "Claude API usage: input_tokens=%d, output_tokens=%d",
            usage.input_tokens,
            usage.output_tokens,
        )
