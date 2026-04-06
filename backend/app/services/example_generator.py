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

    Uses stacked for addition/subtraction when:
    - Any number is > 30, OR
    - Any number has decimals (e.g. 3,4 + 2,8)
    Below 30 with no decimals, dots/object_collection is more appropriate.
    """
    op = _detect_operation(assignment_type, assignment_text, assignment_topic)
    if op is None:
        return False
    # Decimals always use stacked — dots make no sense for 3,4
    if re.search(r'\d+[,.]\d+', assignment_text):
        return True
    numbers = [int(n) for n in re.findall(r'\d+', assignment_text)]
    return any(n > 30 for n in numbers)


def _parse_numbers(text: str) -> list[float]:
    """Parse numbers from text, handling Danish decimal comma and dot notation.

    '3,4 + 2,8' → [3.4, 2.8]
    '45 + 78' → [45.0, 78.0]
    'Regn ud: 3.4 + 2.8' → [3.4, 2.8]
    """
    # Match decimal numbers (comma or dot) or plain integers
    matches = re.findall(r'\d+[,.]\d+|\d+', text)
    return [float(m.replace(",", ".")) for m in matches]


def should_use_short_division(topic: str) -> bool:
    """All division topics use slikkepindsmetoden."""
    return topic == "division"


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
        if should_use_short_division(assignment_topic):
            return self.generate_short_division_example(
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
        from app.services.stacked_arithmetic import StackedArithmeticService, COLUMN_NAMES

        logger.info("Generating stacked example for %s: '%s'", assignment_type, assignment_text)
        start = time.time()

        # Check if assignment has decimals — if so, scale up to integers
        has_decimals = bool(re.search(r'\d+[,.]\d+', assignment_text))
        decimal_places = 0
        if has_decimals:
            parsed = _parse_numbers(assignment_text)
            decimal_places = max(
                len(str(n).split(".")[-1]) if "." in str(n) else 0
                for n in parsed
            )

        # Step 1: Pick example numbers (deterministic, no LLM)
        a, b = StackedArithmeticService.pick_example_numbers(assignment_type, assignment_text)

        if has_decimals:
            # Scale example numbers to have similar decimal range
            # e.g. for 1 decimal place, pick numbers 10-99 and display as 1.0-9.9
            scale = 10 ** decimal_places
            lo = scale
            hi = scale * 10 - 1
            import random
            for _ in range(50):
                a = random.randint(lo, hi)
                b = random.randint(lo, hi)
                if assignment_type == "subtraction" and a < b:
                    a, b = b, a
                break

        # Step 2: Compute steps (deterministic)
        groups = StackedArithmeticService.compute_steps(assignment_type, a, b)

        # Step 3: Generate Danish text (deterministic templates)
        texts = StackedArithmeticService.generate_text(groups, assignment_type)

        # Step 4: Assemble ExampleResponse
        op_symbol = "+" if assignment_type == "addition" else "−"

        # Format numbers for display (with decimals if original had them)
        def fmt(n: int) -> str:
            if has_decimals and decimal_places > 0:
                scale = 10 ** decimal_places
                return f"{n / scale:.{decimal_places}f}".replace(".", ",")
            return str(n)
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

        # Step 5: Add "now try yours" — show student's own problem in grid form
        parsed_nums = _parse_numbers(assignment_text)
        student_numbers = []
        if has_decimals and decimal_places > 0:
            scale = 10 ** decimal_places
            student_numbers = [int(round(n * scale)) for n in parsed_nums]
        else:
            student_numbers = [int(n) for n in parsed_nums]
        if len(student_numbers) >= 2:
            sa, sb = student_numbers[0], student_numbers[1]
            if assignment_type == "subtraction" and sa < sb:
                sa, sb = sb, sa
            s_digits = max(len(str(sa)), len(str(sb)))
            if assignment_type == "addition":
                s_digits = max(s_digits, len(str(sa + sb)))
            s_columns = COLUMN_NAMES.get(s_digits, COLUMN_NAMES[2])
            s_top = StackedArithmeticService._to_digits(sa, s_digits)
            s_bottom = StackedArithmeticService._to_digits(sb, s_digits)

            steps.append({
                "step": len(steps) + 1,
                "phase": "concrete",
                "text": "Prøv nu selv med din opgave — stil den op på samme måde!",
                "visual": {
                    "type": "stacked_arithmetic",
                    "action": "setup",
                    "operation": assignment_type,
                    "columns": s_columns,
                    "top": s_top,
                    "bottom": s_bottom,
                },
                "audio_cue": "Prøv nu selv med din opgave",
            })

        elapsed = time.time() - start
        logger.info("Generated stacked example in %.3fs: %s %s %s", elapsed, a, op_symbol, b)

        return {
            "example_problem": f"Regn ud: {fmt(a)} {op_symbol} {fmt(b)}",
            "pedagogy": "concrete-first",
            "steps": steps,
            "note": "",
        }

    def generate_short_division_example(self, assignment_text: str, language: str = "da") -> dict:
        """Generate a short division example — fully deterministic, no LLM."""
        from app.services.short_division import ShortDivisionService

        logger.info("Generating short division example for: '%s'", assignment_text)
        start = time.time()

        # Parse dividend and divisor from assignment text
        numbers = [int(n) for n in re.findall(r'\d+', assignment_text)]
        if len(numbers) >= 2:
            student_dividend, student_divisor = numbers[0], numbers[1]
        else:
            student_dividend, student_divisor = 84, 4

        ex_dividend, ex_divisor = ShortDivisionService.pick_example_numbers(student_dividend, student_divisor)
        computed = ShortDivisionService.compute_steps(ex_dividend, ex_divisor)
        texts = ShortDivisionService.generate_text(computed)

        anim_steps = []
        for i, (s, text_obj) in enumerate(zip(computed, texts)):
            action = s["step"]
            visual = {"type": "short_division", "action": action}

            if action == "setup":
                visual["dividend"] = s["dividend"]
                visual["divisor"] = s["divisor"]
                visual["digits"] = s["digits"]
            elif action == "process_digit":
                visual["position"] = s["position"]
                visual["group_value"] = s["group_value"]
                visual["quotient_digit"] = s["quotient_digit"]
                visual["remainder"] = s["remainder"]
                visual["leading"] = s["leading"]
                visual["expression"] = s["expression"]
            elif action == "show_remainder":
                visual["remainder"] = s["remainder"]
                visual["divisor"] = s["divisor"]
            elif action == "show_fraction":
                visual["whole"] = s["whole"]
                visual["numerator"] = s["numerator"]
                visual["denominator"] = s["denominator"]
            elif action == "show_decimal":
                visual["decimal_result"] = s["decimal_result"]
            elif action == "reveal":
                visual["result"] = s["result"]

            anim_steps.append({
                "step": i + 1,
                "phase": "concrete",
                "text": text_obj["text"],
                "visual": visual,
                "audio_cue": text_obj.get("audio_cue", ""),
            })

        # "Try yours" step
        student_digits = [int(d) for d in str(student_dividend)]
        anim_steps.append({
            "step": len(anim_steps) + 1,
            "phase": "concrete",
            "text": "Prøv nu selv med din opgave — stil den op på samme måde!",
            "visual": {
                "type": "short_division",
                "action": "setup",
                "dividend": student_dividend,
                "divisor": student_divisor,
                "digits": student_digits,
            },
            "audio_cue": "Prøv nu selv med din opgave",
        })

        elapsed = time.time() - start
        logger.info("Generated short division example in %.3fs: %s ÷ %s", elapsed, ex_dividend, ex_divisor)

        return {
            "example_problem": f"{ex_dividend} ÷ {ex_divisor} = ?",
            "pedagogy": "concrete-first",
            "steps": anim_steps,
            "note": "",
        }

    def _parse_json(self, raw: str) -> dict:
        cleaned = raw.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]
        if cleaned.endswith("```"):
            cleaned = cleaned.rsplit("```", 1)[0]
        return json.loads(cleaned.strip())
