# Stacked Arithmetic Animation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `stacked_arithmetic` visual type that animates the Danish column method (opstilling) for addition and subtraction, up to 5 digits.

**Architecture:** Deterministic Python service computes column-by-column steps, LLM writes Danish text per step. New SwiftUI view renders an animated grid with Marker Felt font, vertical column dividers, and ZStack cells for overlays (cross-outs, carry digits). Integrates into existing VisualComponentView router and AnimationPlayer.

**Tech Stack:** Python 3 (backend service + tests), FastAPI (integration), SwiftUI (iOS view), existing ExampleGeneratorService + AIClient

**Spec:** `docs/superpowers/specs/2026-04-06-stacked-arithmetic-animation.md`

---

### Task 1: Backend — StackedArithmeticService (Subtraction)

**Files:**
- Create: `backend/app/services/stacked_arithmetic.py`
- Create: `backend/tests/test_stacked_arithmetic.py`

- [ ] **Step 1: Write failing tests for subtraction**

```python
# backend/tests/test_stacked_arithmetic.py
import pytest
from app.services.stacked_arithmetic import StackedArithmeticService


class TestSubtraction:
    def test_simple_no_borrow(self):
        """85 - 42 = 43, no borrowing needed."""
        groups = StackedArithmeticService.compute_steps("subtraction", 85, 42)
        assert groups[0]["group"] == "setup"
        assert groups[0]["columns"] == ["Ti", "E"]
        assert groups[0]["top"] == [8, 5]
        assert groups[0]["bottom"] == [4, 2]
        assert groups[0]["operation"] == "subtraction"

        # No borrow needed — straight to compute for each column
        compute_groups = [g for g in groups if g["group"] == "compute"]
        assert len(compute_groups) == 2
        # Ones column first (right to left)
        assert compute_groups[0]["column"] == "E"
        assert compute_groups[0]["expression"] == "5 - 2 = 3"
        assert compute_groups[0]["result_value"] == 3
        # Tens column
        assert compute_groups[1]["column"] == "Ti"
        assert compute_groups[1]["expression"] == "8 - 4 = 4"
        assert compute_groups[1]["result_value"] == 4

        assert groups[-1]["group"] == "answer"
        assert groups[-1]["value"] == 43

    def test_single_borrow(self):
        """83 - 47 = 36, borrow from tens."""
        groups = StackedArithmeticService.compute_steps("subtraction", 83, 47)
        # Should have: setup, borrow, compute(E), compute(Ti), answer
        group_types = [g["group"] for g in groups]
        assert group_types == ["setup", "borrow", "compute", "compute", "answer"]

        borrow = groups[1]
        assert borrow["column"] == "E"
        assert borrow["cross_out_column"] == "Ti"
        assert borrow["cross_out_old"] == 8
        assert borrow["replacement_value"] == 7
        assert borrow["carry_value"] == 1

        # Ones: 13 - 7 = 6
        assert groups[2]["expression"] == "13 - 7 = 6"
        assert groups[2]["result_value"] == 6
        # Tens: 7 - 4 = 3
        assert groups[3]["expression"] == "7 - 4 = 3"
        assert groups[3]["result_value"] == 3

        assert groups[-1]["value"] == 36

    def test_chain_borrow(self):
        """1000 - 1 = 999, borrow cascades across 3 columns."""
        groups = StackedArithmeticService.compute_steps("subtraction", 1000, 1)
        assert groups[0]["columns"] == ["T", "H", "Ti", "E"]
        assert groups[0]["top"] == [1, 0, 0, 0]
        assert groups[0]["bottom"] == [0, 0, 0, 1]

        borrow_groups = [g for g in groups if g["group"] == "borrow"]
        # Need to borrow from T through H through Ti to E
        assert len(borrow_groups) == 3

        assert groups[-1]["value"] == 999

    def test_three_digit(self):
        """346 - 178 = 168."""
        groups = StackedArithmeticService.compute_steps("subtraction", 346, 178)
        assert groups[0]["columns"] == ["H", "Ti", "E"]
        assert groups[-1]["value"] == 168

    def test_five_digit(self):
        """54321 - 12345 = 41976."""
        groups = StackedArithmeticService.compute_steps("subtraction", 54321, 12345)
        assert groups[0]["columns"] == ["Tt", "T", "H", "Ti", "E"]
        assert groups[-1]["value"] == 41976

    def test_zero_in_answer(self):
        """50 - 10 = 40, zero in ones column."""
        groups = StackedArithmeticService.compute_steps("subtraction", 50, 10)
        compute_ones = [g for g in groups if g["group"] == "compute" and g["column"] == "E"]
        assert compute_ones[0]["expression"] == "0 - 0 = 0"
        assert compute_ones[0]["result_value"] == 0
        assert groups[-1]["value"] == 40
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_stacked_arithmetic.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'app.services.stacked_arithmetic'`

- [ ] **Step 3: Implement StackedArithmeticService (subtraction)**

```python
# backend/app/services/stacked_arithmetic.py
"""Deterministic step engine for Danish column arithmetic (opstilling).

Given an operation and two numbers, produces the exact sequence of
grouped animation steps. No LLM involved — pure arithmetic.
"""

COLUMN_NAMES = {
    1: ["E"],
    2: ["Ti", "E"],
    3: ["H", "Ti", "E"],
    4: ["T", "H", "Ti", "E"],
    5: ["Tt", "T", "H", "Ti", "E"],
}


class StackedArithmeticService:
    @staticmethod
    def compute_steps(operation: str, a: int, b: int) -> list[dict]:
        if operation == "subtraction":
            return StackedArithmeticService._subtraction(a, b)
        elif operation == "addition":
            return StackedArithmeticService._addition(a, b)
        else:
            raise ValueError(f"Unsupported operation: {operation}")

    @staticmethod
    def _to_digits(n: int, length: int) -> list[int]:
        """Convert number to list of digits, zero-padded to length."""
        digits = []
        for _ in range(length):
            digits.append(n % 10)
            n //= 10
        return list(reversed(digits))

    @staticmethod
    def _subtraction(a: int, b: int) -> list[dict]:
        assert a >= b >= 0, "a must be >= b for subtraction"
        answer = a - b
        num_digits = max(len(str(a)), len(str(b)))
        columns = COLUMN_NAMES[num_digits]
        top = StackedArithmeticService._to_digits(a, num_digits)
        bottom = StackedArithmeticService._to_digits(b, num_digits)

        groups = [
            {
                "group": "setup",
                "operation": "subtraction",
                "columns": columns,
                "top": top,
                "bottom": bottom,
            }
        ]

        # Work right to left, track borrows
        working_top = list(top)  # mutable copy

        for i in range(num_digits - 1, -1, -1):
            col = columns[i]
            t = working_top[i]
            bot = bottom[i]

            if t < bot:
                # Need to borrow — find leftmost column with non-zero digit
                borrow_from = i - 1
                while borrow_from >= 0 and working_top[borrow_from] == 0:
                    borrow_from -= 1

                # Chain borrow from borrow_from through to i
                for j in range(borrow_from, i):
                    old_val = working_top[j]
                    working_top[j] = old_val - 1
                    working_top[j + 1] += 10

                    groups.append({
                        "group": "borrow",
                        "column": col,
                        "cross_out_column": columns[j],
                        "cross_out_old": old_val,
                        "replacement_value": old_val - 1,
                        "carry_value": 1,
                    })

                t = working_top[i]

            result = t - bot
            groups.append({
                "group": "compute",
                "column": col,
                "expression": f"{t} - {bot} = {result}",
                "result_value": result,
            })

        groups.append({"group": "answer", "value": answer})
        return groups
```

- [ ] **Step 4: Run subtraction tests**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_stacked_arithmetic.py::TestSubtraction -v`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/app/services/stacked_arithmetic.py backend/tests/test_stacked_arithmetic.py
git commit -m "feat: stacked arithmetic service — subtraction with borrowing"
```

---

### Task 2: Backend — StackedArithmeticService (Addition)

**Files:**
- Modify: `backend/app/services/stacked_arithmetic.py`
- Modify: `backend/tests/test_stacked_arithmetic.py`

- [ ] **Step 1: Write failing tests for addition**

Add to `backend/tests/test_stacked_arithmetic.py`:

```python
class TestAddition:
    def test_simple_no_carry(self):
        """23 + 14 = 37, no carrying."""
        groups = StackedArithmeticService.compute_steps("addition", 23, 14)
        assert groups[0]["group"] == "setup"
        assert groups[0]["columns"] == ["Ti", "E"]
        assert groups[0]["top"] == [2, 3]
        assert groups[0]["bottom"] == [1, 4]
        assert groups[0]["operation"] == "addition"

        compute_groups = [g for g in groups if g["group"] == "compute"]
        assert len(compute_groups) == 2
        assert compute_groups[0]["column"] == "E"
        assert compute_groups[0]["expression"] == "3 + 4 = 7"
        assert compute_groups[0]["result_value"] == 7
        assert compute_groups[1]["column"] == "Ti"
        assert compute_groups[1]["expression"] == "2 + 1 = 3"
        assert compute_groups[1]["result_value"] == 3

        # No carry groups
        carry_groups = [g for g in groups if g["group"] == "carry"]
        assert len(carry_groups) == 0

        assert groups[-1]["value"] == 37

    def test_single_carry(self):
        """67 + 85 = 152, carry from ones."""
        groups = StackedArithmeticService.compute_steps("addition", 67, 85)
        assert groups[0]["columns"] == ["H", "Ti", "E"]
        assert groups[0]["top"] == [0, 6, 7]
        assert groups[0]["bottom"] == [0, 8, 5]

        group_types = [g["group"] for g in groups]
        # E: compute 7+5=12, carry 1 to Ti; Ti: compute 6+8+1=15, carry 1 to H; H: compute 0+0+1=1
        assert "carry" in group_types
        assert groups[-1]["value"] == 152

    def test_chain_carry(self):
        """999 + 1 = 1000, carry cascades."""
        groups = StackedArithmeticService.compute_steps("addition", 999, 1)
        assert groups[0]["columns"] == ["T", "H", "Ti", "E"]
        assert groups[-1]["value"] == 1000

    def test_five_digit(self):
        """12345 + 67890 = 80235."""
        groups = StackedArithmeticService.compute_steps("addition", 12345, 67890)
        assert groups[0]["columns"] == ["Tt", "T", "H", "Ti", "E"]
        assert groups[-1]["value"] == 80235

    def test_carry_value_in_expression(self):
        """When carrying, the next column expression includes the carry."""
        groups = StackedArithmeticService.compute_steps("addition", 67, 85)
        # Ones: 7 + 5 = 12 → write 2, carry 1
        compute_ones = [g for g in groups if g["group"] == "compute" and g["column"] == "E"]
        assert compute_ones[0]["expression"] == "7 + 5 = 12"
        assert compute_ones[0]["result_value"] == 2

        # Tens: 6 + 8 + 1 = 15 → write 5, carry 1
        compute_tens = [g for g in groups if g["group"] == "compute" and g["column"] == "Ti"]
        assert compute_tens[0]["expression"] == "6 + 8 + 1 = 15"
        assert compute_tens[0]["result_value"] == 5
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_stacked_arithmetic.py::TestAddition -v`
Expected: FAIL with `NotImplementedError` or `ValueError`

- [ ] **Step 3: Implement addition in StackedArithmeticService**

Add the `_addition` method to `backend/app/services/stacked_arithmetic.py`:

```python
@staticmethod
def _addition(a: int, b: int) -> list[dict]:
    assert a >= 0 and b >= 0, "Both numbers must be non-negative"
    answer = a + b
    # Digit count must fit the answer (e.g., 999 + 1 = 1000 needs 4 digits)
    num_digits = max(len(str(a)), len(str(b)), len(str(answer)))
    columns = COLUMN_NAMES[num_digits]
    top = StackedArithmeticService._to_digits(a, num_digits)
    bottom = StackedArithmeticService._to_digits(b, num_digits)

    groups = [
        {
            "group": "setup",
            "operation": "addition",
            "columns": columns,
            "top": top,
            "bottom": bottom,
        }
    ]

    carry = 0
    for i in range(num_digits - 1, -1, -1):
        col = columns[i]
        t = top[i]
        bot = bottom[i]
        total = t + bot + carry

        # Build expression
        if carry > 0:
            expression = f"{t} + {bot} + {carry} = {total}"
        else:
            expression = f"{t} + {bot} = {total}"

        result_digit = total % 10
        new_carry = total // 10

        groups.append({
            "group": "compute",
            "column": col,
            "expression": expression,
            "result_value": result_digit,
        })

        if new_carry > 0 and i > 0:
            groups.append({
                "group": "carry",
                "from_column": col,
                "to_column": columns[i - 1],
                "carry_value": new_carry,
            })

        carry = new_carry

    groups.append({"group": "answer", "value": answer})
    return groups
```

- [ ] **Step 4: Run all stacked arithmetic tests**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_stacked_arithmetic.py -v`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/app/services/stacked_arithmetic.py backend/tests/test_stacked_arithmetic.py
git commit -m "feat: stacked arithmetic service — addition with carrying"
```

---

### Task 3: Backend — Integrate with ExampleGeneratorService

**Files:**
- Modify: `backend/app/services/example_generator.py`
- Modify: `backend/app/prompts/generate_example.txt`
- Create: `backend/app/prompts/stacked_arithmetic_text.txt`
- Modify: `backend/tests/test_stacked_arithmetic.py`

- [ ] **Step 1: Write failing integration test**

Add to `backend/tests/test_stacked_arithmetic.py`:

```python
from unittest.mock import MagicMock
from app.services.example_generator import ExampleGeneratorService


class TestIntegration:
    def test_stacked_arithmetic_flow(self):
        """ExampleGeneratorService uses stacked arithmetic for large-number addition."""
        # Mock LLM to return:
        # 1) Example numbers (pick_numbers prompt)
        # 2) Danish text for each step (write_text prompt)
        pick_numbers_response = '{"a": 67, "b": 85}'
        write_text_response = '[\
            {"text": "Vi skriver tallene op i kolonner", "audio_cue": "Vi skriver tallene op"},\
            {"text": "7 plus 5 er 12 — vi skriver 2 og husker 1", "audio_cue": "7 plus 5 er 12"},\
            {"text": "6 plus 8 plus 1 er 15 — vi skriver 5 og husker 1", "audio_cue": "6 plus 8 plus 1 er 15"},\
            {"text": "Vi har 1 tilbage — vi skriver 1 i hundreder", "audio_cue": "Vi skriver 1 i hundreder"},\
            {"text": "1 plus 0 plus 0 er 1", "audio_cue": "1 plus 0 er 1"},\
            {"text": "Svaret er 152", "audio_cue": "Svaret er 152"}\
        ]'

        service = ExampleGeneratorService.__new__(ExampleGeneratorService)
        mock_client = MagicMock()
        mock_client.send_text = MagicMock(side_effect=[pick_numbers_response, write_text_response])
        service.client = mock_client
        service._system_prompt = "test prompt"
        service._stacked_text_prompt = "write Danish text"

        result = service.generate_stacked_example(
            assignment_type="addition",
            assignment_text="45 + 78",
            language="da",
        )

        assert result["example_problem"] == "67 + 85 = ?"
        assert len(result["steps"]) >= 3
        assert result["steps"][0]["visual"]["type"] == "stacked_arithmetic"
        assert result["steps"][0]["visual"]["action"] == "setup"
        assert result["steps"][0]["phase"] == "concrete"
        assert result["steps"][0]["text"] == "Vi skriver tallene op i kolonner"

        # Last step should be answer
        assert result["steps"][-1]["visual"]["action"] == "answer"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_stacked_arithmetic.py::TestIntegration -v`
Expected: FAIL with `AttributeError: 'ExampleGeneratorService' object has no attribute 'generate_stacked_example'`

- [ ] **Step 3: Create the stacked arithmetic text prompt**

```
# backend/app/prompts/stacked_arithmetic_text.txt
You are writing Danish explanations for a step-by-step arithmetic animation shown to folkeskole students (9-13 years old).

You will receive a JSON array of animation step groups. Each group has a "group" type and mathematical details. Write a short, clear Danish text and audio_cue for each step.

RULES:
- Write natural, correct Danish
- Use "trin" (not "steg"), "prikker" (dots), "kolonner" (columns)
- Use "tiere" / "enere" / "hundreder" / "tusinder" for place values
- Use "låne" for borrowing, "huske" for carrying (mente)
- Keep each text to 1-2 sentences max
- audio_cue should be a shorter spoken version of text
- Tone: calm, clear, like a patient teacher

Return a JSON array with one object per input group:
[
  {"text": "...", "audio_cue": "..."},
  {"text": "...", "audio_cue": "..."}
]

The array must have exactly the same number of elements as the input groups.
```

- [ ] **Step 4: Add generate_stacked_example to ExampleGeneratorService**

Add to `backend/app/services/example_generator.py` after the existing `generate_example` method:

```python
def generate_stacked_example(
    self,
    assignment_type: str,
    assignment_text: str,
    language: str = "da",
) -> dict:
    """Generate a stacked arithmetic example with deterministic math steps.

    Flow:
    1. LLM picks example numbers (different from student's)
    2. StackedArithmeticService computes exact steps
    3. LLM writes Danish text per step
    4. Assemble into ExampleResponse format
    """
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
    import json
    raw_text = self.client.send_text(
        text_prompt,
        f"Animation groups:\n{json.dumps(groups, ensure_ascii=False)}",
    )
    texts = extract_json(raw_text)

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
    logger.info("Generated stacked example in %.1fs: %s %s %s", elapsed, a, op_symbol, b)

    return {
        "example_problem": f"{a} {op_symbol} {b} = ?",
        "pedagogy": "concrete-first",
        "steps": steps,
        "note": "",
    }
```

Also add `import json` to the top-level imports if not already present.

- [ ] **Step 5: Run integration test**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_stacked_arithmetic.py::TestIntegration -v`
Expected: PASS

- [ ] **Step 6: Run all backend tests to check nothing broke**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest -v`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/app/services/example_generator.py backend/app/prompts/stacked_arithmetic_text.txt backend/tests/test_stacked_arithmetic.py
git commit -m "feat: integrate stacked arithmetic into ExampleGeneratorService"
```

---

### Task 4: Backend — Wire up API router

**Files:**
- Modify: `backend/app/routers/assignments.py`
- Modify: `backend/tests/test_stacked_arithmetic.py`

- [ ] **Step 1: Read the current router**

Read `backend/app/routers/assignments.py` to understand the existing endpoint structure and how `generate_example` is called.

- [ ] **Step 2: Write failing test for the router**

Add to `backend/tests/test_stacked_arithmetic.py`:

```python
class TestRouter:
    def test_should_use_stacked(self):
        """Addition/subtraction with numbers > 30 should use stacked."""
        from app.services.example_generator import should_use_stacked
        assert should_use_stacked("addition", "45 + 78") is True
        assert should_use_stacked("subtraction", "83 - 47") is True
        assert should_use_stacked("addition", "3 + 5") is False
        assert should_use_stacked("multiplication", "6 * 7") is False
        assert should_use_stacked("subtraction", "15 - 8") is False

    def test_threshold_boundary(self):
        """Numbers at the threshold (> 30) should use stacked."""
        from app.services.example_generator import should_use_stacked
        assert should_use_stacked("addition", "31 + 5") is True
        assert should_use_stacked("addition", "30 + 5") is False
        assert should_use_stacked("subtraction", "31 - 5") is True
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_stacked_arithmetic.py::TestRouter -v`
Expected: FAIL with `ImportError: cannot import name 'should_use_stacked'`

- [ ] **Step 4: Add should_use_stacked and wire it into generate_example**

Add to `backend/app/services/example_generator.py` before the class definition:

```python
import re

def should_use_stacked(assignment_type: str, assignment_text: str) -> bool:
    """Decide if stacked arithmetic visual is appropriate.

    Uses stacked for addition/subtraction when any number is > 30.
    Below 30, dots/object_collection is more pedagogically appropriate.
    """
    if assignment_type not in ("addition", "subtraction"):
        return False
    numbers = [int(n) for n in re.findall(r'\d+', assignment_text)]
    return any(n > 30 for n in numbers)
```

Then modify `generate_example` to dispatch to `generate_stacked_example` when appropriate. Add at the beginning of `generate_example`, after the `logger.info` line:

```python
if should_use_stacked(assignment_type, assignment_text):
    return self.generate_stacked_example(
        assignment_type=assignment_type,
        assignment_text=assignment_text,
        language=language,
    )
```

- [ ] **Step 5: Run router tests**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_stacked_arithmetic.py::TestRouter -v`
Expected: All PASS

- [ ] **Step 6: Run all backend tests**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest -v`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/app/services/example_generator.py backend/tests/test_stacked_arithmetic.py
git commit -m "feat: auto-dispatch to stacked arithmetic for numbers > 30"
```

---

### Task 5: iOS — StackedArithmeticView

**Files:**
- Create: `ios/Kvante/Kvante/Views/VisualComponents/StackedArithmeticView.swift`

- [ ] **Step 1: Create the view file with GridState model**

```swift
// ios/Kvante/Kvante/Views/VisualComponents/StackedArithmeticView.swift
import SwiftUI

struct GridState {
    let columns: [String]
    let operation: String
    let topDigits: [Int]
    let bottomDigits: [Int]
    var answerDigits: [Int?]
    var crossedOut: [String: Bool]
    var replacements: [String: Int]
    var carries: [String: Int]
    var activeColumn: String?
    var currentExpression: String?
    var showAnswer: Bool

    init(columns: [String], operation: String, top: [Int], bottom: [Int]) {
        self.columns = columns
        self.operation = operation
        self.topDigits = top
        self.bottomDigits = bottom
        self.answerDigits = Array(repeating: nil, count: columns.count)
        self.crossedOut = [:]
        self.replacements = [:]
        self.carries = [:]
        self.activeColumn = nil
        self.currentExpression = nil
        self.showAnswer = false
    }

    /// Build a GridState from a single setup visual instruction.
    static func from(visual: VisualInstruction) -> GridState {
        let columns = visual.stringArrayParam("columns") ?? ["Ti", "E"]
        let operation = visual.stringParam("operation") ?? "?"
        let top = visual.intArrayParam("top") ?? []
        let bottom = visual.intArrayParam("bottom") ?? []
        return GridState(columns: columns, operation: operation, top: top, bottom: bottom)
    }

    /// Apply one visual instruction to mutate the grid state.
    mutating func apply(visual: VisualInstruction) {
        let action = visual.action

        switch action {
        case "borrow":
            if let crossCol = visual.stringParam("cross_out_column") {
                crossedOut[crossCol] = true
                if let replacement = visual.intParam("replacement_value") {
                    replacements[crossCol] = replacement
                }
            }
            if let col = visual.stringParam("column"),
               let carryVal = visual.intParam("carry_value") {
                carries[col] = carryVal
            }
            activeColumn = visual.stringParam("column")
            currentExpression = nil

        case "carry":
            if let toCol = visual.stringParam("to_column"),
               let carryVal = visual.intParam("carry_value") {
                carries[toCol] = carryVal
            }
            activeColumn = visual.stringParam("from_column")
            currentExpression = nil

        case "compute":
            if let col = visual.stringParam("column"),
               let resultVal = visual.intParam("result_value"),
               let colIdx = columns.firstIndex(of: col) {
                answerDigits[colIdx] = resultVal
            }
            activeColumn = visual.stringParam("column")
            currentExpression = visual.stringParam("expression")

        case "answer":
            showAnswer = true
            activeColumn = nil
            currentExpression = nil

        default:
            break
        }
    }
}

/// Renders the Danish column method (opstilling) for stacked arithmetic.
/// Receives a pre-built GridState from AnimationPlayer and renders the current state.
struct StackedArithmeticView: View {
    let visual: VisualInstruction
    let animate: Bool
    let gridState: GridState

    var body: some View {
        let state = gridState
        VStack(spacing: 12) {
            // Expression callout
            if let expr = state.currentExpression {
                Text(expr)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.teal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.teal.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                    .transition(.scale.combined(with: .opacity))
            }

            // Grid
            gridView(state: state)
        }
        .padding(16)
        .animation(.spring(duration: 0.4), value: currentStep)
    }

    @ViewBuilder
    private func gridView(state: GridState) -> some View {
        let opSymbol = state.operation == "addition" ? "+" : "−"
        let cellSize: CGFloat = 44
        let headerHeight: CGFloat = 24

        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: 0) {
                // Operator column (empty header)
                Text("")
                    .frame(width: cellSize, height: headerHeight)

                ForEach(state.columns, id: \.self) { col in
                    Text(col)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: cellSize, height: headerHeight)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 1)
                        }
                }
            }

            Divider()

            // Top number row
            HStack(spacing: 0) {
                Text(opSymbol)
                    .font(.custom("Marker Felt", size: 28))
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(width: cellSize, height: cellSize)

                ForEach(Array(state.columns.enumerated()), id: \.offset) { idx, col in
                    digitCell(
                        digit: state.topDigits[idx],
                        col: col,
                        isCrossedOut: state.crossedOut[col] == true,
                        replacement: state.replacements[col],
                        carry: state.carries[col],
                        isActive: state.activeColumn == col,
                        cellSize: cellSize
                    )
                }
            }

            // Bottom number row
            HStack(spacing: 0) {
                Text("")
                    .frame(width: cellSize, height: cellSize)

                ForEach(Array(state.columns.enumerated()), id: \.offset) { idx, col in
                    plainDigitCell(
                        digit: state.bottomDigits[idx],
                        isActive: state.activeColumn == col,
                        cellSize: cellSize
                    )
                }
            }

            // Divider line
            Rectangle()
                .fill(Color.secondary)
                .frame(height: 2)
                .padding(.leading, cellSize)

            // Answer row
            HStack(spacing: 0) {
                Text("")
                    .frame(width: cellSize, height: cellSize)

                ForEach(Array(state.columns.enumerated()), id: \.offset) { idx, col in
                    answerDigitCell(
                        digit: state.answerDigits[idx],
                        isActive: state.activeColumn == col,
                        showGlow: state.showAnswer,
                        cellSize: cellSize
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func digitCell(digit: Int, col: String, isCrossedOut: Bool,
                           replacement: Int?, carry: Int?,
                           isActive: Bool, cellSize: CGFloat) -> some View {
        ZStack {
            // Active column highlight
            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.teal.opacity(0.1))
            }

            // Main digit
            Text("\(digit)")
                .font(.custom("Marker Felt", size: 28))
                .foregroundStyle(isCrossedOut ? .secondary : .primary)

            // Strikethrough
            if isCrossedOut {
                Path { path in
                    path.move(to: CGPoint(x: 8, y: cellSize - 8))
                    path.addLine(to: CGPoint(x: cellSize - 8, y: 8))
                }
                .stroke(Color.red, lineWidth: 2)
            }

            // Replacement digit (top-left)
            if let repl = replacement {
                Text("\(repl)")
                    .font(.custom("Marker Felt", size: 16))
                    .foregroundStyle(.red)
                    .offset(x: -12, y: -12)
            }

            // Carry digit (top-left, teal — for the receiving column)
            if let c = carry {
                Text("\(c)")
                    .font(.custom("Marker Felt", size: 16))
                    .foregroundStyle(.teal)
                    .offset(x: -12, y: -12)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1)
        }
    }

    @ViewBuilder
    private func plainDigitCell(digit: Int, isActive: Bool, cellSize: CGFloat) -> some View {
        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.teal.opacity(0.1))
            }
            Text("\(digit)")
                .font(.custom("Marker Felt", size: 28))
                .foregroundStyle(.primary)
        }
        .frame(width: cellSize, height: cellSize)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1)
        }
    }

    @ViewBuilder
    private func answerDigitCell(digit: Int?, isActive: Bool,
                                  showGlow: Bool, cellSize: CGFloat) -> some View {
        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.teal.opacity(0.1))
            }
            if let d = digit {
                Text("\(d)")
                    .font(.custom("Marker Felt", size: 28))
                    .foregroundStyle(.teal)
                    .shadow(color: showGlow ? .teal.opacity(0.6) : .clear, radius: showGlow ? 8 : 0)
                    .scaleEffect(showGlow ? 1.1 : 1.0)
                    .animation(.spring(duration: 0.5).repeatCount(showGlow ? 2 : 0, autoreverses: true), value: showGlow)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1)
        }
    }
}
```

- [ ] **Step 2: Add intArrayParam accessor to VisualInstruction**

Add to `ios/Kvante/Kvante/Models/AnimationModels.swift`, inside the `VisualInstruction` struct alongside the existing typed accessors:

```swift
func intArrayParam(_ key: String) -> [Int]? {
    if let arr = params[key]?.value as? [AnyCodable] {
        return arr.compactMap { $0.value as? Int }
    }
    return nil
}
```

- [ ] **Step 3: Build the project to verify compilation**

Run: `cd /Users/olsen/code/Kvante && xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Views/VisualComponents/StackedArithmeticView.swift ios/Kvante/Kvante/Models/AnimationModels.swift
git commit -m "feat: StackedArithmeticView — animated Danish column grid"
```

---

### Task 6: iOS — Router + AnimationPlayer integration

**Files:**
- Modify: `ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift`
- Modify: `ios/Kvante/Kvante/Views/AnimationPlayer.swift`

- [ ] **Step 1: Add stacked_arithmetic case to VisualComponentView**

In `ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift`, add before the `default: EmptyView()` case:

```swift
case "stacked_arithmetic":
    StackedArithmeticView(
        steps: [],  // Will be populated via cumulative rendering
        currentStep: 0,
        animate: animate
    )
```

The router currently passes a single `visual: VisualInstruction` per step. `StackedArithmeticView` accepts a pre-built `GridState` (defined in Task 5) that has been accumulated by `AnimationPlayer`, matching the existing cumulative state pattern.

Update `VisualComponentView.swift` — add a `cumulativeGridState` parameter and pass it through:

```swift
struct VisualComponentView: View {
    let visual: VisualInstruction
    let animate: Bool
    let cumulativeObjects: Int
    let cumulativeCrossedOut: Int
    let cumulativeRows: Int
    let cumulativeGrouped: Int
    let cumulativeGridState: GridState?

    init(visual: VisualInstruction, animate: Bool,
         cumulativeObjects: Int = 0, cumulativeCrossedOut: Int = 0,
         cumulativeRows: Int = 2, cumulativeGrouped: Int = 0,
         cumulativeGridState: GridState? = nil) {
        self.visual = visual
        self.animate = animate
        self.cumulativeObjects = cumulativeObjects
        self.cumulativeCrossedOut = cumulativeCrossedOut
        self.cumulativeRows = cumulativeRows
        self.cumulativeGrouped = cumulativeGrouped
        self.cumulativeGridState = cumulativeGridState
    }
```

And in the `body` switch, add:

```swift
case "stacked_arithmetic":
    if let state = cumulativeGridState {
        StackedArithmeticView(visual: visual, animate: animate, gridState: state)
    } else {
        // Fallback: build state from just this one step
        StackedArithmeticView(visual: visual, animate: animate, gridState: GridState.from(visual: visual))
    }
```

- [ ] **Step 2: Add cumulative grid state tracking to AnimationPlayer**

In `ios/Kvante/Kvante/Views/AnimationPlayer.swift`, add:

```swift
private(set) var cumulativeGridState: GridState?
```

In `updateCumulativeState(for step:)`, add a new case:

```swift
case ("stacked_arithmetic", _):
    if step.visual.action == "setup" {
        cumulativeGridState = GridState.from(visual: step.visual)
    }
    cumulativeGridState?.apply(visual: step.visual)
```

In `reset()`, add:

```swift
cumulativeGridState = nil
```

Add `"stacked_arithmetic"` to `pauseDuration(for:)`:

```swift
case "stacked_arithmetic": return 2.5
```

- [ ] **Step 3: Update all callers of VisualComponentView to pass cumulativeGridState**

Search for all places that create `VisualComponentView` and add `cumulativeGridState: nil` (or the actual state from AnimationPlayer where available).

Key locations:
- `ChatBubble.swift` line ~276: Add `cumulativeGridState: nil` to the init (chat bubbles currently hardcode all cumulative state to 0 anyway — this is an existing bug, not our problem to fix now)
- `AnimatedExplanationView.swift`: Pass `player.cumulativeGridState`
- `InlineExampleView.swift`: Pass from recalculated player state

Since the parameter has a default value of `nil`, existing callers that don't pass it will still compile. Only update callers that have access to `AnimationPlayer`.

- [ ] **Step 4: Build the project**

Run: `cd /Users/olsen/code/Kvante && xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift ios/Kvante/Kvante/Views/VisualComponents/StackedArithmeticView.swift ios/Kvante/Kvante/Views/AnimationPlayer.swift
git commit -m "feat: wire StackedArithmeticView into router and AnimationPlayer"
```

---

### Task 7: End-to-end test with backend

**Files:** No new files — manual integration testing

- [ ] **Step 1: Start the backend**

Run: `cd /Users/olsen/code/Kvante/backend && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000`

- [ ] **Step 2: Test the example endpoint with a stacked-arithmetic-worthy problem**

Run:
```bash
curl -s http://localhost:8000/sessions/test/assignments/test-add/example \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"assignment_type": "addition", "assignment_topic": "arithmetic", "assignment_text": "67 + 85"}' \
  | python -m json.tool
```

Verify:
- Response contains `"type": "stacked_arithmetic"` in visual steps
- First step has `"action": "setup"` with columns, top, bottom arrays
- Math is correct (answer matches `a + b`)
- Danish text is present in each step's `text` field
- Steps follow the right order: setup → (compute/carry)* → answer

- [ ] **Step 3: Test subtraction with borrowing**

Run:
```bash
curl -s http://localhost:8000/sessions/test/assignments/test-sub/example \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"assignment_type": "subtraction", "assignment_topic": "arithmetic", "assignment_text": "83 - 47"}' \
  | python -m json.tool
```

Verify:
- Response contains borrow steps
- Math is correct
- Borrow chain is valid (cross_out_old - 1 = replacement_value)

- [ ] **Step 4: Test that small numbers still use dots**

Run:
```bash
curl -s http://localhost:8000/sessions/test/assignments/test-small/example \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"assignment_type": "addition", "assignment_topic": "arithmetic", "assignment_text": "3 + 5"}' \
  | python -m json.tool
```

Verify: Response uses `"type": "object_collection"`, NOT `"stacked_arithmetic"`

- [ ] **Step 5: Build and run iOS app on simulator, navigate to a problem with large numbers, request help, verify the stacked arithmetic grid renders**

- [ ] **Step 6: Commit any fixes found during testing**

```bash
cd /Users/olsen/code/Kvante
git add -A
git commit -m "fix: adjustments from end-to-end stacked arithmetic testing"
```

---

## Task Dependency Order

```
Task 1 (subtraction service)
  → Task 2 (addition service)
    → Task 3 (ExampleGenerator integration)
      → Task 4 (router + should_use_stacked)
        → Task 7 (end-to-end test)

Task 5 (iOS StackedArithmeticView)
  → Task 6 (iOS router + AnimationPlayer)
    → Task 7 (end-to-end test)
```

Tasks 1-4 (backend) and Tasks 5-6 (iOS) can be worked in parallel. Task 7 requires both to be complete.
