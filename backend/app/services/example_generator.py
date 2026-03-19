import json
import logging

from app.config import settings
from app.services.claude_client import ClaudeClient

logger = logging.getLogger(__name__)


class ExampleGeneratorService:
    def __init__(self):
        self.claude = ClaudeClient()
        self._system_prompt = (settings.prompts_dir / "generate_example.txt").read_text()

    def generate_example(
        self,
        assignment_type: str,
        assignment_topic: str,
        assignment_text: str,
        language: str = "da",
    ) -> dict:
        """Generate a worked example of a similar but different problem.

        Cardinal rule: The example must NEVER use the same numbers as the real assignment.
        """
        user_message = (
            f"Assignment type: {assignment_type}\n"
            f"Assignment topic: {assignment_topic}\n"
            f"Actual assignment (use DIFFERENT numbers): {assignment_text}\n"
            f"Student's language: {language}\n\n"
            f"Create a worked example with different numbers. Return JSON."
        )
        raw = self.claude.send_text(self._system_prompt, user_message)

        cleaned = raw.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]
        if cleaned.endswith("```"):
            cleaned = cleaned.rsplit("```", 1)[0]
        cleaned = cleaned.strip()

        parsed = json.loads(cleaned)
        logger.info("Generated example for %s: %s", assignment_type, parsed.get("example_problem"))
        return parsed
