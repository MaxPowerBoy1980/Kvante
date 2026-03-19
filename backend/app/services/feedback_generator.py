import json
import logging

from app.config import settings
from app.services.claude_client import ClaudeClient

logger = logging.getLogger(__name__)

# Structured prompts for the "work submitted" state.
# Labels are keyed by language. The iOS app renders these as buttons.
STRUCTURED_PROMPTS = {
    "da": [
        {"id": "explain_different", "label": "Forklar på en anden måde"},
        {"id": "another_example", "label": "Vis mig et andet eksempel"},
        {"id": "show_first_step", "label": "Jeg sidder fast — vis mig første skridt"},
        {"id": "what_did_well", "label": "Hvad gjorde jeg godt?"},
        {"id": "try_again", "label": "Jeg vil prøve igen"},
        {"id": "next_assignment", "label": "Næste opgave"},
    ],
    "en": [
        {"id": "explain_different", "label": "Explain in a different way"},
        {"id": "another_example", "label": "Give me another example"},
        {"id": "show_first_step", "label": "I'm stuck — show me the first step"},
        {"id": "what_did_well", "label": "What did I do well?"},
        {"id": "try_again", "label": "I want to try again"},
        {"id": "next_assignment", "label": "Next assignment"},
    ],
}


class FeedbackGeneratorService:
    def __init__(self):
        self.claude = ClaudeClient()
        self._feedback_prompt = (settings.prompts_dir / "give_feedback.txt").read_text()
        self._explain_prompt = (settings.prompts_dir / "explain_method.txt").read_text()

    def generate_feedback(
        self,
        assignment_text: str,
        analysis: dict,
        language: str = "da",
    ) -> dict:
        """Generate kid-friendly, method-focused feedback.

        Never reveals the correct answer.
        """
        user_message = (
            f"Assignment: {assignment_text}\n"
            f"Student's language: {language}\n\n"
            f"Analysis:\n{json.dumps(analysis, indent=2)}\n\n"
            f"Generate warm, method-focused feedback. Return JSON."
        )
        raw = self.claude.send_text(self._feedback_prompt, user_message)
        parsed = self._parse_json(raw)

        # Attach structured prompts for the iOS button bar
        prompts = STRUCTURED_PROMPTS.get(language, STRUCTURED_PROMPTS["en"])
        parsed["structured_prompts"] = prompts

        return parsed

    def generate_followup(
        self,
        assignment_text: str,
        previous_feedback: str,
        action: str,
        language: str = "da",
    ) -> dict:
        """Handle a structured follow-up action.

        Actions: explain_different, another_example, show_first_step, what_did_well, try_again, explain_task
        """
        user_message = (
            f"Assignment: {assignment_text}\n"
            f"Previous feedback: {previous_feedback}\n"
            f"Student's language: {language}\n"
            f"Action requested: {action}\n\n"
            f"Respond according to the action. Return JSON."
        )
        raw = self.claude.send_text(self._explain_prompt, user_message)
        parsed = self._parse_json(raw)

        prompts = STRUCTURED_PROMPTS.get(language, STRUCTURED_PROMPTS["en"])
        parsed["structured_prompts"] = prompts

        return parsed

    def _get_prompts(self, language: str) -> list[dict]:
        return STRUCTURED_PROMPTS.get(language, STRUCTURED_PROMPTS["en"])

    def _parse_json(self, raw: str) -> dict:
        cleaned = raw.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]
        if cleaned.endswith("```"):
            cleaned = cleaned.rsplit("```", 1)[0]
        return json.loads(cleaned.strip())
