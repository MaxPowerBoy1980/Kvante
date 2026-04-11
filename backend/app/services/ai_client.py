import base64
import logging
import time
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

    def send_vision_multi(
        self,
        system_prompt: str,
        images: list[bytes],
        user_message: str,
        media_types: list[str] | None = None,
    ) -> str:
        """Send multiple images + text prompt. Returns the text response.
        Default: sends images sequentially and concatenates results.
        """
        # Fallback for providers that don't support multi-image natively
        results = []
        for i, img in enumerate(images):
            mt = media_types[i] if media_types else "image/jpeg"
            r = self.send_vision(system_prompt, img, user_message, mt)
            results.append(r)
        return results[-1] if results else ""


class ClaudeAIClient(AIClient):
    def __init__(self):
        import anthropic

        self._client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        self._model = settings.claude_model

    def send_text(self, system_prompt: str, user_message: str) -> str:
        logger.debug("Claude send_text prompt: %s", system_prompt[:200])
        start = time.time()
        response = self._client.messages.create(
            model=self._model,
            max_tokens=4096,
            system=system_prompt,
            messages=[{"role": "user", "content": user_message}],
        )
        elapsed = time.time() - start
        self._log_usage(response.usage, elapsed)
        return response.content[0].text

    def send_vision(
        self,
        system_prompt: str,
        image_bytes: bytes,
        user_message: str,
        media_type: str = "image/jpeg",
    ) -> str:
        logger.debug("Claude send_vision prompt: %s", system_prompt[:200])
        image_b64 = base64.b64encode(image_bytes).decode("utf-8")
        start = time.time()
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
        elapsed = time.time() - start
        self._log_usage(response.usage, elapsed)
        return response.content[0].text

    def send_vision_multi(
        self,
        system_prompt: str,
        images: list[bytes],
        user_message: str,
        media_types: list[str] | None = None,
    ) -> str:
        """Send multiple images in a single Claude API call."""
        logger.debug("Claude send_vision_multi: %d images, prompt: %s", len(images), system_prompt[:200])

        content_blocks = []
        for i, img_bytes in enumerate(images):
            mt = media_types[i] if media_types else "image/jpeg"
            image_b64 = base64.b64encode(img_bytes).decode("utf-8")
            content_blocks.append({
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": mt,
                    "data": image_b64,
                },
            })
        content_blocks.append({"type": "text", "text": user_message})

        start = time.time()
        response = self._client.messages.create(
            model=self._model,
            max_tokens=4096,
            system=system_prompt,
            messages=[{"role": "user", "content": content_blocks}],
        )
        elapsed = time.time() - start
        self._log_usage(response.usage, elapsed)
        return response.content[0].text

    def _log_usage(self, usage, elapsed: float) -> None:
        logger.info(
            "Claude API: %.1fs, input_tokens=%d, output_tokens=%d",
            elapsed,
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

        logger.debug("Gemini send_text prompt: %s", system_prompt[:200])
        start = time.time()
        response = self._client.models.generate_content(
            model=self._model,
            contents=user_message,
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
            ),
        )
        elapsed = time.time() - start
        logger.info("Gemini API: %.1fs, usage=%s", elapsed, response.usage_metadata)
        return response.text

    def send_vision(
        self,
        system_prompt: str,
        image_bytes: bytes,
        user_message: str,
        media_type: str = "image/jpeg",
    ) -> str:
        from google.genai import types

        logger.debug("Gemini send_vision prompt: %s", system_prompt[:200])
        image_part = types.Part.from_bytes(data=image_bytes, mime_type=media_type)
        start = time.time()
        response = self._client.models.generate_content(
            model=self._model,
            contents=[image_part, user_message],
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
            ),
        )
        elapsed = time.time() - start
        logger.info("Gemini API: %.1fs, usage=%s", elapsed, response.usage_metadata)
        return response.text


class OllamaAIClient(AIClient):
    """Local Ollama models — free, unlimited, no API key needed."""

    def __init__(self):
        import httpx

        self._http = httpx.Client(base_url=settings.ollama_url, timeout=300)
        self._text_model = settings.ollama_text_model
        self._vision_model = settings.ollama_vision_model

    def send_text(self, system_prompt: str, user_message: str) -> str:
        logger.debug("Ollama send_text model=%s", self._text_model)
        start = time.time()
        response = self._http.post(
            "/api/chat",
            json={
                "model": self._text_model,
                "stream": False,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message},
                ],
            },
        )
        response.raise_for_status()
        elapsed = time.time() - start
        data = response.json()
        text = data["message"]["content"]
        logger.info("Ollama API: %.1fs, model=%s", elapsed, self._text_model)
        return text

    def send_vision(
        self,
        system_prompt: str,
        image_bytes: bytes,
        user_message: str,
        media_type: str = "image/jpeg",
    ) -> str:
        logger.debug("Ollama send_vision model=%s", self._vision_model)
        image_b64 = base64.b64encode(image_bytes).decode("utf-8")
        start = time.time()
        response = self._http.post(
            "/api/chat",
            json={
                "model": self._vision_model,
                "stream": False,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {
                        "role": "user",
                        "content": user_message,
                        "images": [image_b64],
                    },
                ],
            },
        )
        response.raise_for_status()
        elapsed = time.time() - start
        data = response.json()
        text = data["message"]["content"]
        logger.info("Ollama API: %.1fs, model=%s", elapsed, self._vision_model)
        return text


_PROVIDERS = {
    "claude": ClaudeAIClient,
    "gemini": GeminiAIClient,
    "ollama": OllamaAIClient,
}


def get_ai_client() -> AIClient:
    """Return an AI client based on the configured provider."""
    provider = settings.ai_provider.lower()
    if provider not in _PROVIDERS:
        raise ValueError(f"Unknown AI provider '{provider}'. Valid: {', '.join(_PROVIDERS)}")
    return _PROVIDERS[provider]()
