import json
import logging

from app.config import settings
from app.services.claude_client import ClaudeClient
from app.services.image_preprocessor import preprocess_textbook_page

logger = logging.getLogger(__name__)


class PageParserService:
    def __init__(self):
        self.claude = ClaudeClient()
        self._system_prompt = (settings.prompts_dir / "parse_page.txt").read_text()

    def parse_page(self, image_bytes: bytes) -> dict:
        """Parse a textbook page photo into a list of assignments."""
        preprocessed = preprocess_textbook_page(image_bytes)
        raw_response = self.claude.send_vision(
            self._system_prompt,
            preprocessed,
            "Please identify all assignments on this textbook page and return structured JSON.",
        )
        # Strip markdown code fences if Claude wraps the response
        cleaned = raw_response.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]
        if cleaned.endswith("```"):
            cleaned = cleaned.rsplit("```", 1)[0]
        cleaned = cleaned.strip()

        parsed = json.loads(cleaned)
        logger.info("Parsed %d assignments from page", len(parsed.get("assignments", [])))
        return parsed
