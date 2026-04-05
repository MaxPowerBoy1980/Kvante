import json
import logging
import time

from app.config import settings
from app.services.ai_client import get_ai_client

logger = logging.getLogger(__name__)

MAX_STEPS = 8


class ExampleGeneratorService:
    def __init__(self):
        self.client = get_ai_client()
        self._system_prompt = (settings.prompts_dir / "generate_example.txt").read_text()

    def generate_example(
        self,
        assignment_type: str,
        assignment_topic: str,
        assignment_text: str,
        language: str = "da",
    ) -> dict:
        """Generate a worked example with animation instructions.

        Cardinal rule: The example must NEVER use the same numbers as the real assignment.
        Retries once on parse failure with the validation error included.
        """
        logger.info("Generating example for %s: '%s'", assignment_type, assignment_text)
        start = time.time()
        lang_name = {"da": "Danish (dansk)", "en": "English"}.get(language, language)
        user_message = (
            f"Assignment type: {assignment_type}\n"
            f"Assignment topic: {assignment_topic}\n"
            f"Actual assignment (use DIFFERENT numbers): {assignment_text}\n"
            f"Student's language: {lang_name}\n\n"
            f"IMPORTANT: Write ALL text, note, and audio_cue fields in {lang_name}.\n"
            f"Create a worked example with different numbers. Return JSON."
        )

        from pydantic import ValidationError
        from app.models.schemas import ExampleResponse as ExampleResponseModel

        last_error = None
        for attempt in range(2):
            if attempt == 0:
                raw = self.client.send_text(self._system_prompt, user_message)
            else:
                logger.warning("Retry after parse error: %s", last_error)
                correction = (
                    f"Your previous response was not valid. "
                    f"Error: {last_error}\n\n"
                    f"Please try again with valid JSON in the required format."
                )
                raw = self.client.send_text(self._system_prompt, f"{user_message}\n\n{correction}")

            try:
                parsed = self._parse_json(raw)
            except (json.JSONDecodeError, ValueError) as e:
                last_error = str(e)
                continue

            if len(parsed.get("steps", [])) > MAX_STEPS:
                last_error = f"Too many steps ({len(parsed['steps'])}), maximum is {MAX_STEPS}"
                continue

            # Validate against Pydantic schema before returning
            try:
                ExampleResponseModel(**parsed)
            except ValidationError as e:
                last_error = str(e)
                continue

            elapsed = time.time() - start
            logger.info(
                "Generated example for %s in %.1fs (attempt %d): %s",
                assignment_type,
                elapsed,
                attempt + 1,
                parsed.get("example_problem"),
            )
            return parsed

        raise ValueError(f"Failed to parse example after 2 attempts. Last error: {last_error}")

    def _parse_json(self, raw: str) -> dict:
        cleaned = raw.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]
        if cleaned.endswith("```"):
            cleaned = cleaned.rsplit("```", 1)[0]
        return json.loads(cleaned.strip())
