import json
import logging
import re
import time

from app.config import settings
from app.services.json_parser import extract_json
from app.services.ai_client import get_ai_client

logger = logging.getLogger(__name__)

MAX_STEPS = 8


def _detect_operation(assignment_type: str, assignment_text: str,
                      assignment_topic: str = "") -> str | None:
    """Detect if assignment is addition or subtraction.

    Checks type, topic, and text for + or - operators.
    Returns 'addition', 'subtraction', or None.
    """
    for field in (assignment_type, assignment_topic):
        if field in ("addition", "subtraction"):
            return field
    # Detect from text: look for operators between numbers
    if re.search(r'\d\s*\+\s*\d', assignment_text):
        return "addition"
    if re.search(r'\d\s*-\s*\d', assignment_text):
        return "subtraction"
    return None


def should_use_stacked(assignment_type: str, assignment_text: str,
                       assignment_topic: str = "") -> bool:
    """Decide if stacked arithmetic visual is appropriate.

    Uses stacked for addition/subtraction when any number is > 30.
    Below 30, dots/object_collection is more pedagogically appropriate.
    """
    op = _detect_operation(assignment_type, assignment_text, assignment_topic)
    if op is None:
        return False
    numbers = [int(n) for n in re.findall(r'\d+', assignment_text)]
    return any(n > 30 for n in numbers)


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
        detected_op = _detect_operation(assignment_type, assignment_text, assignment_topic)
        if detected_op and should_use_stacked(assignment_type, assignment_text, assignment_topic):
            return self.generate_stacked_example(
                assignment_type=detected_op,
                assignment_text=assignment_text,
                language=language,
            )
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
        """Generate a stacked arithmetic example — fully deterministic, no LLM."""
        from app.services.stacked_arithmetic import StackedArithmeticService

        logger.info("Generating stacked example for %s: '%s'", assignment_type, assignment_text)
        start = time.time()

        # Step 1: Pick example numbers (deterministic, no LLM)
        a, b = StackedArithmeticService.pick_example_numbers(assignment_type, assignment_text)

        # Step 2: Compute steps (deterministic)
        groups = StackedArithmeticService.compute_steps(assignment_type, a, b)

        # Step 3: Generate Danish text (deterministic templates)
        texts = StackedArithmeticService.generate_text(groups, assignment_type)

        # Step 4: Assemble ExampleResponse
        op_symbol = "+" if assignment_type == "addition" else "-"
        steps = []
        for i, (group, text_obj) in enumerate(zip(groups, texts)):
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
                "text": text_obj["text"],
                "visual": visual,
                "audio_cue": text_obj.get("audio_cue", ""),
            })

        elapsed = time.time() - start
        logger.info("Generated stacked example in %.3fs: %s %s %s", elapsed, a, op_symbol, b)

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
