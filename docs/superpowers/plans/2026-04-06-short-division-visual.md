# Short Division Visual (Slikkepindsmetoden) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `short_division` visual type that animates kort division using the Danish "slikkepindsmetoden" (lollipop method) — divisor in circle, vertical stick, progressive digits left, quotient right.

**Architecture:** Deterministic Python backend service computes steps (no LLM). SwiftUI view renders the slikkepind layout with cumulative state threading. Follows the exact pattern proven by stacked arithmetic.

**Tech Stack:** Python/FastAPI (backend service), SwiftUI (iOS view), pytest (backend tests)

**Spec:** `docs/superpowers/specs/2026-04-06-short-division-visual.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `backend/app/services/short_division.py` | Deterministic division engine: `compute_steps`, `pick_example_numbers`, `generate_text` |
| Create | `backend/tests/test_short_division.py` | Unit tests for all service methods |
| Modify | `backend/app/services/example_generator.py` | Route division topics to short division service |
| Create | `ios/Kvante/Kvante/Views/VisualComponents/ShortDivisionView.swift` | SwiftUI view: slikkepind layout + `ShortDivisionState` struct |
| Modify | `ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift` | Add `"short_division"` case + `cumulativeShortDivisionState` param |
| Modify | `ios/Kvante/Kvante/Views/AnimationPlayer.swift` | Add `cumulativeShortDivisionState` + update/recalculate logic |
| Modify | `ios/Kvante/Kvante/Models/AnimationModels.swift` | Add `boolParam` accessor to `VisualInstruction` |
| Modify | `ios/Kvante/Kvante/Views/AnimatedExplanationView.swift` | Thread `cumulativeShortDivisionState` to `StepCardView` |
| Modify | `ios/Kvante/Kvante/Views/Chat/InlineExampleView.swift` | Thread `cumulativeShortDivisionState` to `StepRow` |

---

## Task 1: Backend — `ShortDivisionService.compute_steps`

**Files:**
- Create: `backend/app/services/short_division.py`
- Create: `backend/tests/test_short_division.py`

- [ ] **Step 1: Write failing tests for `compute_steps`**

Create `backend/tests/test_short_division.py`:

```python
import pytest
from app.services.short_division import ShortDivisionService


class TestComputeSteps:
    def test_simple_no_remainder(self):
        """588 ÷ 4 = 147, no remainder."""
        steps = ShortDivisionService.compute_steps(588, 4)
        assert steps[0]["step"] == "setup"
        assert steps[0]["dividend"] == 588
        assert steps[0]["divisor"] == 4
        assert steps[0]["digits"] == [5, 8, 8]

        process = [s for s in steps if s["step"] == "process_digit"]
        assert len(process) == 3

        assert process[0]["group_value"] == 5
        assert process[0]["quotient_digit"] == 1
        assert process[0]["remainder"] == 1
        assert process[0]["leading"] is False
        assert process[0]["expression"] == "5 ÷ 4 = 1 rest 1"

        assert process[1]["group_value"] == 18
        assert process[1]["quotient_digit"] == 4
        assert process[1]["remainder"] == 2
        assert process[1]["expression"] == "18 ÷ 4 = 4 rest 2"

        assert process[2]["group_value"] == 28
        assert process[2]["quotient_digit"] == 7
        assert process[2]["remainder"] == 0
        assert process[2]["expression"] == "28 ÷ 4 = 7 rest 0"

        assert steps[-1]["step"] == "reveal"
        assert steps[-1]["result"] == "147"

        # No remainder steps when remainder is 0
        assert not any(s["step"] == "show_remainder" for s in steps)

    def test_with_remainder_terminating(self):
        """589 ÷ 4 = 147,25 — remainder with terminating decimal."""
        steps = ShortDivisionService.compute_steps(589, 4)

        process = [s for s in steps if s["step"] == "process_digit"]
        assert process[-1]["remainder"] == 1

        remainder_step = next(s for s in steps if s["step"] == "show_remainder")
        assert remainder_step["remainder"] == 1
        assert remainder_step["divisor"] == 4

        fraction_step = next(s for s in steps if s["step"] == "show_fraction")
        assert fraction_step["whole"] == 147
        assert fraction_step["numerator"] == 1
        assert fraction_step["denominator"] == 4

        decimal_step = next(s for s in steps if s["step"] == "show_decimal")
        assert decimal_step["decimal_result"] == "147,25"

        assert steps[-1]["step"] == "reveal"
        assert steps[-1]["result"] == "147,25"

    def test_with_remainder_non_terminating(self):
        """10 ÷ 3 = 3 rest 1 — non-terminating decimal, no show_decimal."""
        steps = ShortDivisionService.compute_steps(10, 3)

        fraction_step = next(s for s in steps if s["step"] == "show_fraction")
        assert fraction_step["whole"] == 3
        assert fraction_step["numerator"] == 1
        assert fraction_step["denominator"] == 3

        # No show_decimal for non-terminating
        assert not any(s["step"] == "show_decimal" for s in steps)

        assert steps[-1]["step"] == "reveal"
        assert steps[-1]["result"] == "3 1/3"

    def test_leading_zero(self):
        """248 ÷ 4 = 62 — first digit < divisor gives leading zero."""
        steps = ShortDivisionService.compute_steps(248, 4)

        process = [s for s in steps if s["step"] == "process_digit"]
        assert process[0]["group_value"] == 2
        assert process[0]["quotient_digit"] == 0
        assert process[0]["remainder"] == 2
        assert process[0]["leading"] is True

        assert process[1]["group_value"] == 24
        assert process[1]["quotient_digit"] == 6
        assert process[1]["leading"] is False

        assert process[2]["group_value"] == 8
        assert process[2]["quotient_digit"] == 2
        assert process[2]["leading"] is False

        assert steps[-1]["result"] == "62"

    def test_zero_in_quotient_middle(self):
        """612 ÷ 6 = 102 — zero in middle of quotient."""
        steps = ShortDivisionService.compute_steps(612, 6)

        process = [s for s in steps if s["step"] == "process_digit"]
        assert process[0]["quotient_digit"] == 1
        assert process[0]["leading"] is False

        assert process[1]["group_value"] == 1
        assert process[1]["quotient_digit"] == 0
        assert process[1]["remainder"] == 1
        assert process[1]["leading"] is False  # NOT leading — it's mid-number

        assert process[2]["group_value"] == 12
        assert process[2]["quotient_digit"] == 2

        assert steps[-1]["result"] == "102"

    def test_large_number(self):
        """12480 ÷ 8 = 1560."""
        steps = ShortDivisionService.compute_steps(12480, 8)

        process = [s for s in steps if s["step"] == "process_digit"]
        assert len(process) == 5
        assert steps[-1]["result"] == "1560"

    def test_single_digit_dividend(self):
        """8 ÷ 4 = 2."""
        steps = ShortDivisionService.compute_steps(8, 4)

        process = [s for s in steps if s["step"] == "process_digit"]
        assert len(process) == 1
        assert process[0]["quotient_digit"] == 2
        assert process[0]["remainder"] == 0

        assert steps[-1]["result"] == "2"

    def test_remainder_half(self):
        """5 ÷ 2 = 2,5 — simple terminating decimal."""
        steps = ShortDivisionService.compute_steps(5, 2)

        decimal_step = next(s for s in steps if s["step"] == "show_decimal")
        assert decimal_step["decimal_result"] == "2,5"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_short_division.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'app.services.short_division'`

- [ ] **Step 3: Implement `ShortDivisionService`**

Create `backend/app/services/short_division.py`:

```python
"""Deterministic step engine for Danish short division (slikkepindsmetoden).

Given a dividend and single-digit divisor, produces the exact sequence of
animation steps. No LLM involved — pure arithmetic.
"""
import math
import random
import re


class ShortDivisionService:
    @staticmethod
    def compute_steps(dividend: int, divisor: int) -> list[dict]:
        """Compute short division steps for dividend ÷ divisor.

        Returns a list of step dicts with step types:
        setup, process_digit, show_remainder, show_fraction, show_decimal, reveal.
        """
        assert dividend > 0 and divisor > 0, "Both numbers must be positive"
        assert 1 <= divisor <= 9, "Divisor must be single-digit (1-9)"

        digits = [int(d) for d in str(dividend)]
        steps = [{"step": "setup", "dividend": dividend, "divisor": divisor, "digits": digits}]

        group = 0
        quotient_digits = []
        all_leading = True

        for i, digit in enumerate(digits):
            group = group * 10 + digit
            quotient_digit = group // divisor
            remainder = group % divisor

            if quotient_digit == 0 and all_leading:
                leading = True
            else:
                leading = False
                all_leading = False

            steps.append({
                "step": "process_digit",
                "position": i,
                "group_value": group,
                "quotient_digit": quotient_digit,
                "remainder": remainder,
                "leading": leading,
                "expression": f"{group} ÷ {divisor} = {quotient_digit} rest {remainder}",
            })

            quotient_digits.append((quotient_digit, leading))
            group = remainder

        # Build quotient string (skip leading zeros)
        quotient_str = "".join(
            str(d) for d, is_leading in quotient_digits if not is_leading
        )
        quotient_int = int(quotient_str) if quotient_str else 0
        final_remainder = group

        if final_remainder > 0:
            steps.append({
                "step": "show_remainder",
                "remainder": final_remainder,
                "divisor": divisor,
            })
            steps.append({
                "step": "show_fraction",
                "whole": quotient_int,
                "numerator": final_remainder,
                "denominator": divisor,
            })

            if ShortDivisionService._is_terminating(divisor):
                decimal_value = quotient_int + final_remainder / divisor
                # Format with Danish comma, strip trailing zeros
                decimal_str = f"{decimal_value:.10f}".rstrip("0").rstrip(".")
                decimal_str = decimal_str.replace(".", ",")
                steps.append({
                    "step": "show_decimal",
                    "decimal_result": decimal_str,
                })
                steps.append({"step": "reveal", "result": decimal_str})
            else:
                result_str = f"{quotient_int} {final_remainder}/{divisor}"
                steps.append({"step": "reveal", "result": result_str})
        else:
            steps.append({"step": "reveal", "result": quotient_str})

        return steps

    @staticmethod
    def _is_terminating(divisor: int) -> bool:
        """Check if 1/divisor is a terminating decimal.

        A fraction terminates iff the denominator (after reducing) only has
        prime factors 2 and 5.
        """
        n = divisor
        while n % 2 == 0:
            n //= 2
        while n % 5 == 0:
            n //= 5
        return n == 1

    @staticmethod
    def pick_example_numbers(dividend: int, divisor: int) -> tuple[int, int]:
        """Pick example numbers different from student's, in similar range.

        Returns (example_dividend, example_divisor) with same digit count
        in dividend and single-digit divisor.
        """
        num_digits = len(str(dividend))
        lo = 10 ** (num_digits - 1)
        hi = 10 ** num_digits - 1

        # Build list of single-digit divisors excluding student's
        possible_divisors = [d for d in range(2, 10) if d != divisor]

        for _ in range(50):
            ex_divisor = random.choice(possible_divisors)
            ex_dividend = random.randint(lo, hi)
            if ex_dividend != dividend:
                return ex_dividend, ex_divisor

        return lo + 1, possible_divisors[0]

    @staticmethod
    def generate_text(steps: list[dict]) -> list[dict]:
        """Generate deterministic Danish text for each step."""
        texts = []
        prev_remainder = 0

        for i, s in enumerate(steps):
            action = s["step"]

            if action == "setup":
                dividend = s["dividend"]
                divisor = s["divisor"]
                texts.append({
                    "text": f"Vi skal finde ud af hvad {dividend} divideret med {divisor} giver",
                    "audio_cue": f"{dividend} divideret med {divisor}",
                })

            elif action == "process_digit":
                gv = s["group_value"]
                qd = s["quotient_digit"]
                rem = s["remainder"]
                divisor = steps[0]["divisor"]

                if i == 1:
                    # First process_digit — no "resten X sættes foran"
                    text = f"{gv} divideret med {divisor} giver {qd}, rest {rem}"
                else:
                    prev_step = steps[i - 1]
                    prev_rem = prev_step.get("remainder", 0)
                    digit = s["group_value"] % 10 if prev_rem > 0 else s["group_value"]
                    text = (
                        f"Resten {prev_rem} sættes foran {digit}, det giver {gv}. "
                        f"{gv} divideret med {divisor} giver {qd}, rest {rem}"
                    )

                texts.append({"text": text, "audio_cue": s["expression"]})
                prev_remainder = rem

            elif action == "show_remainder":
                texts.append({
                    "text": f"Vi har rest {s['remainder']}",
                    "audio_cue": f"Rest {s['remainder']}",
                })

            elif action == "show_fraction":
                texts.append({
                    "text": f"Det skriver vi som brøken {s['numerator']}/{s['denominator']}",
                    "audio_cue": f"{s['numerator']} over {s['denominator']}",
                })

            elif action == "show_decimal":
                dec = s["decimal_result"]
                texts.append({
                    "text": f"Det er det samme som {dec}",
                    "audio_cue": dec,
                })

            elif action == "reveal":
                texts.append({
                    "text": f"Svaret er {s['result']}",
                    "audio_cue": f"Svaret er {s['result']}",
                })

        return texts
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_short_division.py -v`
Expected: All 9 tests PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/short_division.py backend/tests/test_short_division.py
git commit -m "feat: add ShortDivisionService with deterministic step engine"
```

---

## Task 2: Backend — `generate_text` and `pick_example_numbers` tests

**Files:**
- Modify: `backend/tests/test_short_division.py`

- [ ] **Step 1: Write tests for `generate_text`**

Append to `backend/tests/test_short_division.py`:

```python
class TestGenerateText:
    def test_simple_division_text(self):
        """Danish text for 588 ÷ 4 = 147."""
        steps = ShortDivisionService.compute_steps(588, 4)
        texts = ShortDivisionService.generate_text(steps)

        assert texts[0]["text"] == "Vi skal finde ud af hvad 588 divideret med 4 giver"
        assert "5 divideret med 4 giver 1, rest 1" in texts[1]["text"]
        assert "Resten 1 sættes foran" in texts[2]["text"]
        assert "18 divideret med 4 giver 4" in texts[2]["text"]
        assert texts[-1]["text"] == "Svaret er 147"

    def test_remainder_text(self):
        """Danish text includes rest → brøk → decimal."""
        steps = ShortDivisionService.compute_steps(589, 4)
        texts = ShortDivisionService.generate_text(steps)

        remainder_texts = [t["text"] for t in texts]
        assert any("rest 1" in t for t in remainder_texts)
        assert any("brøken 1/4" in t for t in remainder_texts)
        assert any("147,25" in t for t in remainder_texts)

    def test_text_count_matches_steps(self):
        """Number of text entries must match number of steps."""
        steps = ShortDivisionService.compute_steps(12480, 8)
        texts = ShortDivisionService.generate_text(steps)
        assert len(texts) == len(steps)

    def test_non_terminating_text(self):
        """Non-terminating: shows brøk, no decimal text."""
        steps = ShortDivisionService.compute_steps(10, 3)
        texts = ShortDivisionService.generate_text(steps)

        text_strings = [t["text"] for t in texts]
        assert any("brøken 1/3" in t for t in text_strings)
        assert not any("," in t for t in text_strings if "det samme som" in t.lower())


class TestPickExampleNumbers:
    def test_different_from_student(self):
        """Example numbers must differ from student's."""
        for _ in range(20):
            ex_div, ex_divisor = ShortDivisionService.pick_example_numbers(588, 4)
            assert ex_div != 588
            assert ex_divisor != 4

    def test_same_digit_count(self):
        """Dividend should have same number of digits."""
        ex_div, _ = ShortDivisionService.pick_example_numbers(588, 4)
        assert 100 <= ex_div <= 999

        ex_div, _ = ShortDivisionService.pick_example_numbers(12480, 8)
        assert 10000 <= ex_div <= 99999

    def test_single_digit_divisor(self):
        """Divisor should always be single-digit."""
        for _ in range(20):
            _, ex_divisor = ShortDivisionService.pick_example_numbers(588, 4)
            assert 2 <= ex_divisor <= 9
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_short_division.py -v`
Expected: All tests PASS (implementation already exists from Task 1)

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_short_division.py
git commit -m "test: add generate_text and pick_example_numbers tests for short division"
```

---

## Task 3: Backend — Route division to short division in `example_generator.py`

**Files:**
- Modify: `backend/app/services/example_generator.py:15-44` (add detection)
- Modify: `backend/app/services/example_generator.py:47-131` (add routing)
- Modify: `backend/tests/test_short_division.py` (integration test)

- [ ] **Step 1: Write failing integration test**

Append to `backend/tests/test_short_division.py`:

```python
from app.services.example_generator import ExampleGeneratorService, should_use_short_division


class TestRouting:
    def test_should_use_short_division(self):
        """Division topic should use short division."""
        assert should_use_short_division("division") is True
        assert should_use_short_division("addition") is False
        assert should_use_short_division("subtraction") is False
        assert should_use_short_division("multiplikation") is False

    def test_short_division_example_flow(self):
        """generate_short_division_example is fully deterministic — no LLM needed."""
        service = ExampleGeneratorService.__new__(ExampleGeneratorService)

        result = service.generate_short_division_example(
            assignment_text="Regn ud: 588 ÷ 4",
            language="da",
        )

        assert len(result["steps"]) >= 4
        assert result["steps"][0]["visual"]["type"] == "short_division"
        assert result["steps"][0]["visual"]["action"] == "setup"
        assert result["steps"][0]["phase"] == "concrete"
        assert "divideret med" in result["steps"][0]["text"]

        reveal_steps = [s for s in result["steps"] if s["visual"]["action"] == "reveal"]
        assert len(reveal_steps) == 1

        # Last step is "try yours"
        assert result["steps"][-1]["text"] == "Prøv nu selv med din opgave — stil den op på samme måde!"
        assert result["steps"][-1]["visual"]["type"] == "short_division"
        assert result["steps"][-1]["visual"]["action"] == "setup"

        # Example numbers should differ from student's
        assert "588" not in result["example_problem"]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_short_division.py::TestRouting -v`
Expected: FAIL — `cannot import name 'should_use_short_division'`

- [ ] **Step 3: Add `should_use_short_division` and `generate_short_division_example`**

In `backend/app/services/example_generator.py`, add after the existing `should_use_stacked` function (after line 44):

```python
def should_use_short_division(topic: str) -> bool:
    """Decide if short division visual is appropriate.

    All division topics use slikkepindsmetoden.
    """
    return topic == "division"
```

Add `generate_short_division_example` method to `ExampleGeneratorService` class (after `generate_stacked_example`, around line 227):

```python
    def generate_short_division_example(
        self,
        assignment_text: str,
        language: str = "da",
    ) -> dict:
        """Generate a short division example — fully deterministic, no LLM."""
        from app.services.short_division import ShortDivisionService

        logger.info("Generating short division example for: '%s'", assignment_text)
        start = time.time()

        # Parse dividend and divisor from assignment text
        numbers = [int(n) for n in re.findall(r'\d+', assignment_text)]
        if len(numbers) >= 2:
            student_dividend, student_divisor = numbers[0], numbers[1]
        else:
            student_dividend, student_divisor = 84, 4  # fallback

        # Step 1: Pick example numbers
        ex_dividend, ex_divisor = ShortDivisionService.pick_example_numbers(
            student_dividend, student_divisor
        )

        # Step 2: Compute steps
        computed = ShortDivisionService.compute_steps(ex_dividend, ex_divisor)

        # Step 3: Generate Danish text
        texts = ShortDivisionService.generate_text(computed)

        # Step 4: Assemble ExampleResponse with AnimationSteps
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

        # Step 5: Add "try yours" — show student's problem in setup form
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
```

Then update `generate_example` to route division (modify the method starting at line 52). Add this block right after the stacked arithmetic check (after line 71, before `start = time.time()`):

```python
        if should_use_short_division(assignment_topic):
            return self.generate_short_division_example(
                assignment_text=assignment_text,
                language=language,
            )
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_short_division.py -v`
Expected: All tests PASS

- [ ] **Step 5: Run all existing tests to check for regressions**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/ -v --ignore=tests/test_integration.py`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/example_generator.py backend/tests/test_short_division.py
git commit -m "feat: route division topics to short division example generator"
```

---

## Task 4: iOS — Add `boolParam` to `VisualInstruction`

**Files:**
- Modify: `ios/Kvante/Kvante/Models/AnimationModels.swift:59-85`

- [ ] **Step 1: Add `boolParam` accessor**

In `ios/Kvante/Kvante/Models/AnimationModels.swift`, add after the `intParam` method (after line 63):

```swift
    func boolParam(_ key: String) -> Bool? {
        params[key]?.value as? Bool
    }
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd /Users/olsen/code/Kvante/ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad (A16)' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Models/AnimationModels.swift
git commit -m "feat: add boolParam accessor to VisualInstruction"
```

---

## Task 5: iOS — `ShortDivisionState` and `ShortDivisionView`

**Files:**
- Create: `ios/Kvante/Kvante/Views/VisualComponents/ShortDivisionView.swift`

- [ ] **Step 1: Create `ShortDivisionState` struct**

Create `ios/Kvante/Kvante/Views/VisualComponents/ShortDivisionView.swift`:

```swift
import SwiftUI

// MARK: - State

struct ShortDivisionState {
    let divisor: Int
    let digits: [Int]
    var rows: [(groupValue: Int, quotientDigit: Int, remainder: Int, leading: Bool)]
    var activeRow: Int?
    var currentExpression: String?
    var remainderValue: Int?
    var fractionWhole: Int?
    var fractionNumerator: Int?
    var fractionDenominator: Int?
    var decimalResult: String?
    var showResult: Bool
    var resultText: String?

    init(divisor: Int, digits: [Int]) {
        self.divisor = divisor
        self.digits = digits
        self.rows = []
        self.activeRow = nil
        self.currentExpression = nil
        self.remainderValue = nil
        self.fractionWhole = nil
        self.fractionNumerator = nil
        self.fractionDenominator = nil
        self.decimalResult = nil
        self.showResult = false
        self.resultText = nil
    }

    static func from(visual: VisualInstruction) -> ShortDivisionState {
        let divisor = visual.intParam("divisor") ?? 1
        let digits = visual.intArrayParam("digits") ?? []
        return ShortDivisionState(divisor: divisor, digits: digits)
    }

    mutating func apply(visual: VisualInstruction) {
        switch visual.action {
        case "setup":
            break // Already handled in from()

        case "process_digit":
            let groupValue = visual.intParam("group_value") ?? 0
            let quotientDigit = visual.intParam("quotient_digit") ?? 0
            let remainder = visual.intParam("remainder") ?? 0
            let leading = visual.boolParam("leading") ?? false
            rows.append((groupValue: groupValue, quotientDigit: quotientDigit,
                         remainder: remainder, leading: leading))
            activeRow = rows.count - 1
            currentExpression = visual.stringParam("expression")

        case "show_remainder":
            remainderValue = visual.intParam("remainder")
            activeRow = nil
            currentExpression = nil

        case "show_fraction":
            fractionWhole = visual.intParam("whole")
            fractionNumerator = visual.intParam("numerator")
            fractionDenominator = visual.intParam("denominator")

        case "show_decimal":
            decimalResult = visual.stringParam("decimal_result")

        case "reveal":
            showResult = true
            activeRow = nil
            currentExpression = nil
            resultText = visual.stringParam("result")

        default:
            break
        }
    }
}

// MARK: - View

struct ShortDivisionView: View {
    let visual: VisualInstruction
    let animate: Bool
    let state: ShortDivisionState

    var body: some View {
        VStack(spacing: 12) {
            // Expression badge
            if let expr = state.currentExpression {
                Text(expr)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(KvanteTheme.Colors.primary.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 8))
                    .transition(.scale.combined(with: .opacity))
            }

            // Slikkepind layout
            lollipopView

            // Remainder / fraction / decimal (hidden once reveal shows)
            if !state.showResult, let rem = state.remainderValue {
                Text("rest \(rem)")
                    .font(.custom("Marker Felt", size: 22))
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            }

            if !state.showResult,
               let whole = state.fractionWhole,
               let num = state.fractionNumerator,
               let den = state.fractionDenominator {
                HStack(spacing: 4) {
                    Text("\(whole)")
                        .font(.custom("Marker Felt", size: 28))
                        .foregroundStyle(KvanteTheme.Colors.primary)
                    VStack(spacing: 0) {
                        Text("\(num)")
                            .font(.custom("Marker Felt", size: 18))
                        Rectangle()
                            .fill(KvanteTheme.Colors.ink)
                            .frame(width: 20, height: 2)
                        Text("\(den)")
                            .font(.custom("Marker Felt", size: 18))
                    }
                    .foregroundStyle(KvanteTheme.Colors.primary)
                }
                .transition(.opacity)
            }

            if !state.showResult, let dec = state.decimalResult {
                Text("= \(dec)")
                    .font(.custom("Marker Felt", size: 28))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .transition(.opacity)
            }

            // Final result with glow (replaces intermediate displays)
            if state.showResult, let result = state.resultText {
                Text("= \(result)")
                    .font(.custom("Marker Felt", size: 32))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .shadow(color: .teal.opacity(0.6), radius: state.showResult ? 8 : 0)
                    .scaleEffect(state.showResult ? 1.1 : 1.0)
                    .animation(.spring(duration: 0.5).repeatCount(2, autoreverses: true),
                               value: state.showResult)
            }
        }
        .padding(16)
    }

    // MARK: - Lollipop Layout

    @ViewBuilder
    private var lollipopView: some View {
        let cellSize: CGFloat = 44

        VStack(spacing: 0) {
            // Divisor in circle
            Text("\(state.divisor)")
                .font(.custom("Marker Felt", size: 28))
                .foregroundStyle(KvanteTheme.Colors.ink)
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .stroke(KvanteTheme.Colors.ink, lineWidth: 3)
                )

            // Rows: left = group value, vertical line, right = quotient digit
            ForEach(Array(state.rows.enumerated()), id: \.offset) { idx, row in
                HStack(spacing: 0) {
                    // Left: group value
                    groupValueCell(row: row, idx: idx, cellSize: cellSize)

                    // Vertical line
                    Rectangle()
                        .fill(KvanteTheme.Colors.ink)
                        .frame(width: 3)

                    // Right: quotient digit
                    quotientDigitCell(row: row, idx: idx, cellSize: cellSize)
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            // Horizontal line at bottom
            if !state.rows.isEmpty {
                Rectangle()
                    .fill(KvanteTheme.Colors.ink)
                    .frame(height: 3)
                    .frame(width: CGFloat(state.rows.isEmpty ? 0 : 1) * (120))
            }
        }
    }

    @ViewBuilder
    private func groupValueCell(row: (groupValue: Int, quotientDigit: Int, remainder: Int, leading: Bool),
                                 idx: Int, cellSize: CGFloat) -> some View {
        let isActive = state.activeRow == idx

        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .fill(KvanteTheme.Colors.primary.opacity(0.1))
            }

            // Show carried remainder in orange before the digit
            if idx > 0 {
                let prevRemainder = state.rows[idx - 1].remainder
                if prevRemainder > 0 {
                    HStack(spacing: 0) {
                        Text("\(prevRemainder)")
                            .font(.custom("Marker Felt", size: 18))
                            .foregroundStyle(.orange)
                        Text("\(row.groupValue % 10)")
                            .font(.custom("Marker Felt", size: 28))
                            .foregroundStyle(KvanteTheme.Colors.ink)
                    }
                } else {
                    Text("\(row.groupValue)")
                        .font(.custom("Marker Felt", size: 28))
                        .foregroundStyle(KvanteTheme.Colors.ink)
                }
            } else {
                Text("\(row.groupValue)")
                    .font(.custom("Marker Felt", size: 28))
                    .foregroundStyle(KvanteTheme.Colors.ink)
            }
        }
        .frame(width: 60, height: cellSize)
    }

    @ViewBuilder
    private func quotientDigitCell(row: (groupValue: Int, quotientDigit: Int, remainder: Int, leading: Bool),
                                    idx: Int, cellSize: CGFloat) -> some View {
        let isActive = state.activeRow == idx

        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .fill(KvanteTheme.Colors.primary.opacity(0.1))
            }

            if !row.leading {
                Text("\(row.quotientDigit)")
                    .font(.custom("Marker Felt", size: 28))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .scaleEffect(isActive ? 1.1 : 1.0)
                    .animation(.spring(duration: 0.4), value: isActive)
            }
        }
        .frame(width: cellSize, height: cellSize)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd /Users/olsen/code/Kvante/ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad (A16)' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/VisualComponents/ShortDivisionView.swift
git commit -m "feat: add ShortDivisionView with slikkepind layout and state"
```

---

## Task 6: iOS — Wire up cumulative state and router

**Files:**
- Modify: `ios/Kvante/Kvante/Views/AnimationPlayer.swift:10-15,53-62,99-128`
- Modify: `ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift`
- Modify: `ios/Kvante/Kvante/Views/AnimatedExplanationView.swift`
- Modify: `ios/Kvante/Kvante/Views/Chat/InlineExampleView.swift`

- [ ] **Step 1: Add `cumulativeShortDivisionState` to `AnimationPlayer`**

In `ios/Kvante/Kvante/Views/AnimationPlayer.swift`:

Add the property after line 15 (`cumulativeGridState`):

```swift
    private(set) var cumulativeShortDivisionState: ShortDivisionState?
```

In `reset()` (around line 53), add before the closing brace:

```swift
        cumulativeShortDivisionState = nil
```

In `updateCumulativeState(for:)` (around line 99), add a new case before `default`:

```swift
        case ("short_division", _):
            if v.action == "setup" {
                cumulativeShortDivisionState = ShortDivisionState.from(visual: v)
            }
            cumulativeShortDivisionState?.apply(visual: v)
```

In `recalculateCumulativeState()` (around line 120), add after resetting `cumulativeGrouped`:

```swift
        cumulativeShortDivisionState = nil
```

In `pauseDuration(for:)` (around line 82), add a case before `default`:

```swift
        case "short_division": return 2.5
```

- [ ] **Step 2: Add `cumulativeShortDivisionState` param to `VisualComponentView`**

In `ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift`:

Add property after `cumulativeGridState` (after line 12):

```swift
    let cumulativeShortDivisionState: ShortDivisionState?
```

Update the `init` to include the new param (modify lines 14-25):

```swift
    init(visual: VisualInstruction, animate: Bool,
         cumulativeObjects: Int = 0, cumulativeCrossedOut: Int = 0,
         cumulativeRows: Int = 2, cumulativeGrouped: Int = 0,
         cumulativeGridState: GridState? = nil,
         cumulativeShortDivisionState: ShortDivisionState? = nil) {
        self.visual = visual
        self.animate = animate
        self.cumulativeObjects = cumulativeObjects
        self.cumulativeCrossedOut = cumulativeCrossedOut
        self.cumulativeRows = cumulativeRows
        self.cumulativeGrouped = cumulativeGrouped
        self.cumulativeGridState = cumulativeGridState
        self.cumulativeShortDivisionState = cumulativeShortDivisionState
    }
```

Add the `"short_division"` case in the body switch, before `default` (before line 56):

```swift
        case "short_division":
            if let state = cumulativeShortDivisionState {
                ShortDivisionView(visual: visual, animate: animate, state: state)
            } else {
                ShortDivisionView(visual: visual, animate: animate,
                                  state: ShortDivisionState.from(visual: visual))
            }
```

- [ ] **Step 3: Thread state through `AnimatedExplanationView` and `InlineExampleView`**

In `ios/Kvante/Kvante/Views/AnimatedExplanationView.swift`, find where `VisualComponentView` is constructed and add `cumulativeShortDivisionState: player.cumulativeShortDivisionState` to its arguments. The exact location depends on the existing code, but follow the same pattern as `cumulativeGridState`.

In `ios/Kvante/Kvante/Views/Chat/InlineExampleView.swift`, do the same — add `cumulativeShortDivisionState: player.cumulativeShortDivisionState` wherever `VisualComponentView` is instantiated.

- [ ] **Step 4: Build to verify it compiles**

Run: `cd /Users/olsen/code/Kvante/ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad (A16)' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add ios/Kvante/Kvante/Views/AnimationPlayer.swift \
        ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift \
        ios/Kvante/Kvante/Views/AnimatedExplanationView.swift \
        ios/Kvante/Kvante/Views/Chat/InlineExampleView.swift
git commit -m "feat: wire short division cumulative state through animation pipeline"
```

---

## Task 7: End-to-end smoke test

**Files:**
- Modify: `backend/tests/test_short_division.py`

- [ ] **Step 1: Write end-to-end test that validates the full response format**

Append to `backend/tests/test_short_division.py`:

```python
class TestEndToEnd:
    def test_full_response_validates_against_schema(self):
        """ExampleResponse from short division passes Pydantic validation."""
        from pydantic import ValidationError
        from app.models.schemas import ExampleResponse as ExampleResponseModel

        service = ExampleGeneratorService.__new__(ExampleGeneratorService)
        result = service.generate_short_division_example(
            assignment_text="Regn ud: 84 ÷ 4",
            language="da",
        )

        # Should not raise
        ExampleResponseModel(**result)

    def test_division_topic_routes_correctly(self):
        """generate_example routes division topic to short division."""
        service = ExampleGeneratorService.__new__(ExampleGeneratorService)
        result = service.generate_short_division_example(
            assignment_text="Regn ud: 589 ÷ 4",
            language="da",
        )

        # Check visual types are all short_division
        for step in result["steps"]:
            assert step["visual"]["type"] == "short_division"

    def test_remainder_flow_includes_fraction(self):
        """Assignments with remainder include fraction step."""
        service = ExampleGeneratorService.__new__(ExampleGeneratorService)
        # Force a known remainder by using specific numbers
        from app.services.short_division import ShortDivisionService
        steps = ShortDivisionService.compute_steps(589, 4)
        has_fraction = any(s["step"] == "show_fraction" for s in steps)
        assert has_fraction

    def test_no_remainder_flow_skips_fraction(self):
        """Assignments without remainder skip fraction/decimal steps."""
        from app.services.short_division import ShortDivisionService
        steps = ShortDivisionService.compute_steps(588, 4)
        has_fraction = any(s["step"] == "show_fraction" for s in steps)
        assert not has_fraction
```

- [ ] **Step 2: Run all short division tests**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_short_division.py -v`
Expected: All tests PASS

- [ ] **Step 3: Run the full test suite**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/ -v --ignore=tests/test_integration.py`
Expected: All tests PASS, no regressions

- [ ] **Step 4: Commit**

```bash
git add backend/tests/test_short_division.py
git commit -m "test: add end-to-end tests for short division example generation"
```

---

## Task 8: Manual test on device

- [ ] **Step 1: Start the backend**

Run: `cd /Users/olsen/code/Kvante/backend && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000`

- [ ] **Step 2: Test the API endpoint manually**

In a separate terminal, create a division session and request an example:

```bash
# Create a session with a division problem
curl -s http://192.168.1.60:8000/health | python3 -m json.tool

# Use an existing division assignment or create one via the app
# Then request an example for a division assignment and verify the response
# contains visual type "short_division" with the expected step structure
```

- [ ] **Step 3: Run the iOS app on iPad simulator**

Build and run in Xcode. Navigate to a division problem and tap "Vis eksempel". Verify:
- Slikkepind layout renders (circle, vertical line, rows)
- Steps animate correctly when tapping through
- Remainder → fraction → decimal chain shows when applicable
- "Prøv selv" step shows student's own numbers

- [ ] **Step 4: Fix any visual issues found during testing**

Adjust sizing, spacing, or animation timing as needed based on how it looks on device.

- [ ] **Step 5: Commit any fixes**

```bash
git add -u
git commit -m "fix: adjust short division visual based on device testing"
```
