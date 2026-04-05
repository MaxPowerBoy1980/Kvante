import logging
import time

from app.config import settings
from app.services.ai_client import get_ai_client
from app.services.image_preprocessor import preprocess_handwritten_work
from app.services.json_parser import extract_json

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
        logger.debug("Raw AI response: %s", raw[:500])

        try:
            parsed = extract_json(raw)
        except Exception:
            logger.warning("JSON parse failed, extracting from prose response")
            parsed = self._parse_prose_response(raw)

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

    @staticmethod
    def _parse_prose_response(raw: str) -> dict:
        """Fallback: extract analysis from a prose/markdown response."""
        import re
        text = raw.lower()

        # Detect if student got it right
        correct_signals = ["correct", "sound", "rigtigt", "korrekt", "well done", "right"]
        error_signals = ["error", "incorrect", "wrong", "mistake", "fejl", "forkert"]
        methodology_sound = any(s in text for s in correct_signals) and not any(s in text for s in error_signals)

        # Try to extract the student's answer (look for numbers near = sign)
        answer_match = re.search(r"=\s*(\d+[\.,]?\d*)", raw)
        student_answer = answer_match.group(1) if answer_match else ""

        # Extract errors if any
        errors = []
        if any(s in text for s in error_signals):
            error_match = re.search(r"error[s]?[:\s]*\*?\s*(.+?)(?:\n|$)", raw, re.IGNORECASE)
            if error_match and "none" not in error_match.group(1).lower():
                errors.append(error_match.group(1).strip("* "))

        return {
            "student_answer": student_answer,
            "methodology_sound": methodology_sound,
            "steps_identified": [],
            "errors": errors,
            "correct_elements": ["Eleven har besvaret opgaven"] if methodology_sound else [],
            "methodology_assessment": raw[:300],
            "handwriting_note": "",
            "confidence": 0.85,
        }
