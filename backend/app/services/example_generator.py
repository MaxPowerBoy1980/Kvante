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


MULTIPLICATION_PATTERN = re.compile(r'(\d+)\s*[×*·]\s*(\d+)')
DECIMAL_PATTERN = re.compile(r'\d+[,.]\d+')


def _parse_multiplication_operands(assignment_text: str) -> tuple[int, int] | None:
    """Extract the two operands of a multiplication expression from text.

    Returns None if no multiplication expression is found. This is also the
    existence-check for "is this a multiplication expression we can render?"
    — if it returns None we cannot generate long multiplication regardless
    of how the assignment is tagged.
    """
    match = MULTIPLICATION_PATTERN.search(assignment_text)
    if match is None:
        return None
    return int(match.group(1)), int(match.group(2))


def should_use_single_digit_multiplication(assignment_type: str,
                                           assignment_text: str,
                                           assignment_topic: str = "") -> bool:
    """Route multiplication where both operands are 2-9, no decimals.

    Text er autoritativ — hvis vi ikke kan parse en N × M expression
    returnerer vi False, ligesom should_use_long_multiplication.
    """
    if DECIMAL_PATTERN.search(assignment_text):
        return False
    operands = _parse_multiplication_operands(assignment_text)
    if operands is None:
        return False
    a, b = operands
    return 2 <= a <= 9 and 2 <= b <= 9


def should_use_long_multiplication(assignment_type: str, assignment_text: str,
                                   assignment_topic: str = "") -> bool:
    """Route multiplication where larger ≤ 999, smaller ≤ 99, at least one
    multi-digit operand, no decimals.

    Text is authoritative — if no explicit `N × M` expression can be parsed
    we return False even when assignment_type/topic claims multiplication.
    """
    if DECIMAL_PATTERN.search(assignment_text):
        return False
    operands = _parse_multiplication_operands(assignment_text)
    if operands is None:
        return False
    a, b = operands
    larger, smaller = max(a, b), min(a, b)
    if larger >= 1000 or smaller >= 100:
        return False
    return larger >= 10


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
        if should_use_long_multiplication(assignment_type, assignment_text, assignment_topic):
            return self.generate_long_multiplication_example(
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
        from app.services.stacked_arithmetic import StackedArithmeticService, COLUMN_NAMES, DECIMAL_COLUMNS

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
        if has_decimals:
            # Pick numbers in the scaled integer range
            import random
            scale = 10 ** decimal_places
            lo = scale
            hi = scale * 10 - 1
            student_parsed = _parse_numbers(assignment_text)
            student_scaled = [int(round(n * scale)) for n in student_parsed]
            for _ in range(50):
                a = random.randint(lo, hi)
                b = random.randint(lo, hi)
                if assignment_type == "subtraction" and a < b:
                    a, b = b, a
                if a not in student_scaled and b not in student_scaled:
                    break
        else:
            a, b = StackedArithmeticService.pick_example_numbers(assignment_type, assignment_text)

        # Step 2: Compute steps (deterministic — works on integers)
        groups = StackedArithmeticService.compute_steps(assignment_type, a, b)

        # Step 3: For decimals, remap column names and format answer
        if has_decimals and decimal_places > 0:
            groups = self._apply_decimal_columns(groups, decimal_places)

        # Step 4: Generate Danish text (uses remapped column names)
        texts = StackedArithmeticService.generate_text(groups, assignment_type)

        # Step 5: Assemble ExampleResponse
        op_symbol = "+" if assignment_type == "addition" else "−"

        def fmt(n: int) -> str:
            if has_decimals and decimal_places > 0:
                s = 10 ** decimal_places
                return f"{n / s:.{decimal_places}f}".replace(".", ",")
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

        # Step 6: Add "now try yours" — show student's own problem in grid form
        parsed_nums = _parse_numbers(assignment_text)
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
            if has_decimals and decimal_places > 0:
                s_columns = self._remap_columns(s_columns, decimal_places)
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

    @staticmethod
    def _remap_columns(columns: list[str], decimal_places: int) -> list[str]:
        """Remap integer column names to include decimal positions.

        For decimal_places=1: ["Ti", "E"] → ["E", "td"]
        For decimal_places=2: ["H", "Ti", "E"] → ["E", "td", "hd"]
        """
        from app.services.stacked_arithmetic import COLUMN_NAMES as CN, DECIMAL_COLUMNS
        int_cols = len(columns) - decimal_places
        whole_names = list(CN.get(max(int_cols, 1), ["E"]))
        frac_names = DECIMAL_COLUMNS[:decimal_places]
        return whole_names + frac_names

    @staticmethod
    def _apply_decimal_columns(groups: list[dict], decimal_places: int) -> list[dict]:
        """Post-process compute_steps output to use decimal column names and format answer."""
        from app.services.stacked_arithmetic import DECIMAL_COLUMNS

        for group in groups:
            action = group["group"]
            if action == "setup":
                old_cols = group["columns"]
                group["columns"] = ExampleGeneratorService._remap_columns(old_cols, decimal_places)
            elif action in ("compute", "borrow"):
                # Remap column references
                if "column" in group:
                    old_cols = None
                    for g in groups:
                        if g["group"] == "setup":
                            old_cols = g["columns"]
                            break
                    # Column name is already remapped in setup, compute uses column by name
                    # We need to find which position this column was and use new name
            elif action == "answer":
                # Format answer with comma
                val = group["value"]
                scale = 10 ** decimal_places
                formatted = f"{val / scale:.{decimal_places}f}".replace(".", ",")
                group["value"] = formatted

        # Remap column names in compute/carry/borrow steps
        # Find old→new column mapping from setup
        old_columns = None
        new_columns = None
        for g in groups:
            if g["group"] == "setup":
                new_columns = g["columns"]
                # Reconstruct old columns from the count
                from app.services.stacked_arithmetic import COLUMN_NAMES as CN
                n = len(new_columns)
                old_columns = CN.get(n, CN[min(n, 5)])
                break

        if old_columns and new_columns and len(old_columns) == len(new_columns):
            col_map = {old: new for old, new in zip(old_columns, new_columns)}
            for group in groups:
                for key in ("column", "cross_out_column", "from_column", "to_column"):
                    if key in group and group[key] in col_map:
                        group[key] = col_map[group[key]]

        return groups

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

    def generate_long_multiplication_example(self, assignment_text: str,
                                              language: str = "da") -> dict:
        """Generate a long multiplication example — fully deterministic, no LLM."""
        from app.services.long_multiplication import LongMultiplicationService

        logger.info("Generating long multiplication example for: '%s'", assignment_text)
        start = time.time()

        operands = _parse_multiplication_operands(assignment_text)
        if operands is None:
            raise ValueError(f"Could not parse multiplication operands from: {assignment_text!r}")

        # Normalise: larger first
        student_a, student_b = sorted(operands, reverse=True)
        ex_mc, ex_mp = LongMultiplicationService.pick_example_numbers(student_a, student_b)
        steps, mental = LongMultiplicationService.compute_steps(ex_mc, ex_mp)
        texts = LongMultiplicationService.generate_text(steps, mental)

        anim_steps = []
        for i, (s, text_obj) in enumerate(zip(steps, texts)):
            action = s["step"]
            visual = {"type": "long_multiplication", "action": action}

            if action == "setup":
                visual["multiplicand"] = s["multiplicand"]
                visual["multiplier"] = s["multiplier"]
                visual["multiplicand_digits"] = s["multiplicand_digits"]
                visual["multiplier_digits"] = s["multiplier_digits"]
            elif action == "partial_product":
                visual["multiplier_digit"] = s["multiplier_digit"]
                visual["multiplier_position"] = s["multiplier_position"]
                visual["value"] = s["value"]
                visual["digits"] = s["digits"]
                visual["shift"] = s["shift"]
                visual["carries"] = s["carries"]
                visual["expression_chain"] = s["expression_chain"]
            elif action == "sum_partials":
                visual["partials"] = s["partials"]
                visual["total"] = s["total"]
            elif action == "reveal":
                visual["result"] = s["result"]

            anim_steps.append({
                "step": i + 1,
                "phase": "concrete",
                "text": text_obj["text"],
                "visual": visual,
                "audio_cue": text_obj.get("audio_cue", ""),
            })

        # try_yours: student's own normalised problem in empty grid
        student_mc_digits = [int(d) for d in str(student_a)]
        student_mp_digits = [int(d) for d in str(student_b)]
        anim_steps.append({
            "step": len(anim_steps) + 1,
            "phase": "concrete",
            "text": "Prøv nu selv med din opgave — stil den op på samme måde!",
            "visual": {
                "type": "long_multiplication",
                "action": "setup",
                "multiplicand": student_a,
                "multiplier": student_b,
                "multiplicand_digits": student_mc_digits,
                "multiplier_digits": student_mp_digits,
            },
            "audio_cue": "Prøv nu selv med din opgave",
        })

        elapsed = time.time() - start
        logger.info("Generated long multiplication example in %.3fs: %s × %s",
                    elapsed, ex_mc, ex_mp)

        return {
            "example_problem": f"Regn ud: {ex_mc} × {ex_mp}",
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
