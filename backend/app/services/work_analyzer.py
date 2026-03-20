import json
import logging
import time

from app.config import settings
from app.services.ai_client import get_ai_client
from app.services.image_preprocessor import preprocess_handwritten_work

logger = logging.getLogger(__name__)


class WorkAnalyzerService:
    def __init__(self):
        self.client = get_ai_client()
        self._system_prompt = (settings.prompts_dir / "analyze_work.txt").read_text()

    def analyze_work(
        self,
        image_bytes: bytes,
        assignment_text: str,
        assignment_type: str,
        assignment_topic: str,
    ) -> dict:
        """Analyze a photo of handwritten student work.

        Returns structured analysis. Never includes the correct answer.
        """
        logger.info("Analyzing work for '%s' (%d bytes)", assignment_text, len(image_bytes))
        start = time.time()
        preprocessed = preprocess_handwritten_work(image_bytes)
        user_message = (
            f"Assignment: {assignment_text}\n"
            f"Type: {assignment_type}\n"
            f"Topic: {assignment_topic}\n\n"
            f"Please analyze the student's handwritten work in the photo. Return JSON."
        )
        raw = self.client.send_vision(self._system_prompt, preprocessed, user_message)

        cleaned = raw.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]
        if cleaned.endswith("```"):
            cleaned = cleaned.rsplit("```", 1)[0]
        cleaned = cleaned.strip()

        parsed = json.loads(cleaned)

        # Safety: ensure correct_answer is NEVER in the response
        parsed.pop("correct_answer", None)
        elapsed = time.time() - start

        logger.info(
            "Analyzed work for '%s' in %.1fs: confidence=%.2f, methodology_sound=%s",
            assignment_text,
            elapsed,
            parsed.get("confidence", 0),
            parsed.get("methodology_sound"),
        )
        return parsed
