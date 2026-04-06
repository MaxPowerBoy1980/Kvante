import json
import logging
import time

from app.config import settings
from app.services.json_parser import extract_json
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
            f"Actual assignment (use DIFFERENT numbers): {assignment_text}\n\n"
            f"Create a worked example with different numbers. Return JSON."
        )

        # Prepend language requirement to system prompt so the model can't ignore it
        system_prompt = (
            f"CRITICAL: You MUST write ALL text, example_problem, note, and audio_cue "
            f"fields in {lang_name}. Never use English.\n\n"
            + self._system_prompt
        )

        from pydantic import ValidationError
        from app.models.schemas import ExampleResponse as ExampleResponseModel

        last_error = None
        for attempt in range(2):
            if attempt == 0:
                raw = self.client.send_text(system_prompt, user_message)
            else:
                logger.warning("Retry after parse error: %s", last_error)
                correction = (
                    f"Your previous response was not valid. "
                    f"Error: {last_error}\n\n"
                    f"Please try again with valid JSON in the required format."
                )
                raw = self.client.send_text(system_prompt, f"{user_message}\n\n{correction}")

            try:
                parsed = extract_json(raw)
            except (Exception,) as e:
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

    def generate_stacked_example(
        self,
        assignment_type: str,
        assignment_text: str,
        language: str = "da",
    ) -> dict:
        """Generate a stacked arithmetic example with deterministic math steps."""
        from app.services.stacked_arithmetic import StackedArithmeticService

        logger.info("Generating stacked example for %s: '%s'", assignment_type, assignment_text)
        start = time.time()

        lang_name = {"da": "Danish (dansk)", "en": "English"}.get(language, language)

        # Step 1: LLM picks example numbers
        pick_prompt = (
            f"The student's assignment is: {assignment_text}\n"
            f"Pick TWO different numbers for a {assignment_type} example. "
            f"The numbers MUST be different from the student's numbers. "
            f"Use numbers appropriate for folkeskole (9-13 year olds). "
            f"Return JSON: {{\"a\": <number>, \"b\": <number>}}"
        )
        raw_numbers = self.client.send_text(
            "You pick example numbers for a math tutoring app. Return only JSON.",
            pick_prompt,
        )
        numbers = extract_json(raw_numbers)
        a, b = numbers["a"], numbers["b"]

        # For subtraction, ensure a >= b
        if assignment_type == "subtraction" and a < b:
            a, b = b, a

        # Step 2: Deterministic step computation
        groups = StackedArithmeticService.compute_steps(assignment_type, a, b)

        # Step 3: LLM writes Danish text per step
        if not hasattr(self, '_stacked_text_prompt'):
            self._stacked_text_prompt = (
                settings.prompts_dir / "stacked_arithmetic_text.txt"
            ).read_text()

        text_prompt = (
            f"CRITICAL: Write ALL text in {lang_name}.\n\n"
            + self._stacked_text_prompt
        )
        raw_text = self.client.send_text(
            text_prompt,
            f"Animation groups:\n{json.dumps(groups, ensure_ascii=False)}",
        )
        texts = extract_json(raw_text)

        # Step 4: Assemble ExampleResponse
        from itertools import zip_longest
        op_symbol = "+" if assignment_type == "addition" else "-"
        steps = []
        for i, (group, text_obj) in enumerate(zip_longest(groups, texts, fillvalue={})):
            action = group["group"]
            visual = {"type": "stacked_arithmetic", "action": action}

            if action == "setup":
                visual["operation"] = assignment_type
                visual["columns"] = group["columns"]
                visual["top"] = group["top"]
                visual["bottom"] = group["bottom"]
            elif action == "borrow":
                visual["column"] = group["column"]
                visual["cross_out_column"] = group["cross_out_column"]
                visual["cross_out_old"] = group["cross_out_old"]
                visual["replacement_value"] = group["replacement_value"]
                visual["carry_value"] = group["carry_value"]
            elif action == "carry":
                visual["from_column"] = group["from_column"]
                visual["to_column"] = group["to_column"]
                visual["carry_value"] = group["carry_value"]
            elif action == "compute":
                visual["column"] = group["column"]
                visual["expression"] = group["expression"]
                visual["result_value"] = group["result_value"]
            elif action == "answer":
                visual["value"] = group["value"]

            steps.append({
                "step": i + 1,
                "phase": "concrete",
                "text": text_obj.get("text", ""),
                "visual": visual,
                "audio_cue": text_obj.get("audio_cue", ""),
            })

        elapsed = time.time() - start
        logger.info("Generated stacked example in %.1fs: %s %s %s", elapsed, a, op_symbol, b)

        return {
            "example_problem": f"{a} {op_symbol} {b} = ?",
            "pedagogy": "concrete-first",
            "steps": steps,
            "note": "",
        }

    def _parse_json(self, raw: str) -> dict:
        cleaned = raw.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]
        if cleaned.endswith("```"):
            cleaned = cleaned.rsplit("```", 1)[0]
        return json.loads(cleaned.strip())
