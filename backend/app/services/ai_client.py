import base64
import logging
from abc import ABC, abstractmethod

from app.config import settings

logger = logging.getLogger(__name__)


class AIClient(ABC):
    @abstractmethod
    def send_text(self, system_prompt: str, user_message: str) -> str:
        """Send a text-only prompt. Returns the text response."""

    @abstractmethod
    def send_vision(
        self,
        system_prompt: str,
        image_bytes: bytes,
        user_message: str,
        media_type: str = "image/jpeg",
    ) -> str:
        """Send an image + text prompt. Returns the text response."""


class ClaudeAIClient(AIClient):
    def __init__(self):
        import anthropic

        self._client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        self._model = settings.claude_model

    def send_text(self, system_prompt: str, user_message: str) -> str:
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


class GeminiAIClient(AIClient):
    def __init__(self):
        from google import genai

        self._client = genai.Client(api_key=settings.google_api_key)
        self._model = settings.gemini_model

    def send_text(self, system_prompt: str, user_message: str) -> str:
        from google.genai import types

        response = self._client.models.generate_content(
            model=self._model,
            contents=user_message,
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
            ),
        )
        logger.info("Gemini API usage: %s", response.usage_metadata)
        return response.text

    def send_vision(
        self,
        system_prompt: str,
        image_bytes: bytes,
        user_message: str,
        media_type: str = "image/jpeg",
    ) -> str:
        from google.genai import types

        image_part = types.Part.from_bytes(data=image_bytes, mime_type=media_type)
        response = self._client.models.generate_content(
            model=self._model,
            contents=[image_part, user_message],
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
            ),
        )
        logger.info("Gemini API usage: %s", response.usage_metadata)
        return response.text


_PROVIDERS = {
    "claude": ClaudeAIClient,
    "gemini": GeminiAIClient,
}


def get_ai_client() -> AIClient:
    """Return an AI client based on the configured provider."""
    provider = settings.ai_provider.lower()
    if provider not in _PROVIDERS:
        raise ValueError(f"Unknown AI provider '{provider}'. Valid: {', '.join(_PROVIDERS)}")
    return _PROVIDERS[provider]()
