# Long Multiplication Visual Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic Danish long-multiplication visual (multi-cifer × 1-2 cifer, larger ≤ 999, smaller ≤ 99) that respects the cardinal rule, mirrors the slikkepindsmetoden architecture, and replaces the LLM-generated dot/array paths for in-scope multiplication assignments.

**Architecture:** New backend service `LongMultiplicationService` (no LLM), new iOS visual `LongMultiplicationView`, routing wired into `ExampleGeneratorService.generate_example` before short_division. State lives in `AnimationPlayer.cumulativeLongMultiplicationState`; the view's `apply()` uses `setup` as a no-op because AnimationPlayer reassigns the state on each setup, which is what makes the `try_yours` step work.

**Tech Stack:** Python 3 + pytest (backend service + tests), FastAPI (existing routing), SwiftUI + iOS 26.2 (view + animation), Marker Felt font for digits, KvanteTheme tokens for colors.

**Spec:** `docs/superpowers/specs/2026-04-07-long-multiplication-visual.md`

---

## Reference: key contracts

Engineers will hit these enough that they need to be top-of-page.

**`compute_steps(multiplicand, multiplier)` returns `tuple[list[dict], list[list[dict]]]`:**

- `steps`: ordered list of step dicts in **display order**: `setup`, then one `partial_product` per multiplier digit (low-to-high computation order), optionally `sum_partials` (only when ≥ 2 partials), then `reveal`.
- `mental_steps_by_partial`: parallel list — `mental_steps_by_partial[i]` is the mental_steps list for the *i'th* `partial_product` step (0-indexed across partial_products only, NOT across all steps). Other step types have no parallel entry.
- Caller is responsible for normalisation (`multiplicand >= multiplier`); `compute_steps` asserts this.

**Mental_steps shape per partial:** list of dicts with keys
- `expression: str` — Danish-ish ASCII like `"6×4=24"` or `"0×4+2=2"`
- `digit_written: int` — the ones-place of the running computation for this column
- `carry_in: int` — carry coming INTO this column's compute (from previous column)
- `carry_out: int` — carry going OUT of this column's compute
- `column: int` — computation-order index (0 = ones of multiplicand, 1 = tens, etc.)

**Carry array derivation (parallel to `multiplicand_digits` in WRITTEN order, high-to-low):**

```python
written_carries = [None] * len(multiplicand_digits)
for ms in mental_steps:
    if ms["carry_in"] > 0:
        # Computation order → written order: reverse the index
        written_idx = len(multiplicand_digits) - 1 - ms["column"]
        written_carries[written_idx] = ms["carry_in"]
```

For `206 × 4` with `multiplicand_digits = [2, 0, 6]`:
- mental_steps[0]: column=0 (ones=6), 6×4=24, carry_in=0, carry_out=2 → no carry recorded
- mental_steps[1]: column=1 (tens=0), 0×4+2=2, carry_in=2, carry_out=0 → `written_carries[3-1-1]=written_carries[1]=2` (over the `0`)
- mental_steps[2]: column=2 (hundreds=2), 2×4=8, carry_in=0, carry_out=0 → no carry recorded
- Result: `carries = [None, 2, None]` ✓

**Step ordering invariants:**
- `setup` is always first
- Number of `partial_product` steps = number of multiplier digits
- `sum_partials` is present iff ≥ 2 `partial_product` steps
- `reveal` is always last (from `compute_steps` — `try_yours` is appended later by `generate_long_multiplication_example`)

**Routing cap:** `larger ≤ 999`, `smaller ≤ 99`, `larger ≥ 10` (at least one multi-digit).

---

## File structure

### New files

```
backend/app/services/long_multiplication.py        # LongMultiplicationService
backend/tests/test_long_multiplication.py          # pytest unit tests
ios/Kvante/Kvante/Views/VisualComponents/LongMultiplicationView.swift   # SwiftUI view
```

### Modified files (backend)

```
backend/app/services/example_generator.py
  + _parse_multiplication_operands(text) helper
  + should_use_long_multiplication(type, text, topic) helper
  + ExampleGeneratorService.generate_long_multiplication_example(text, language)
  + Branch in generate_example before should_use_short_division
```

### Modified files (iOS)

```
ios/Kvante/Kvante/Models/AnimationModels.swift
  + VisualInstruction.optionalIntArrayParam(_:) -> [Int?]?

ios/Kvante/Kvante/Views/AnimationPlayer.swift
  + private(set) var cumulativeLongMultiplicationState: LongMultiplicationState?
  + reset() clears it
  + recalculateCumulativeState() clears it
  + updateCumulativeState() switch case for ("long_multiplication", _)

ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift
  + Init parameter cumulativeLongMultiplicationState
  + Switch case for "long_multiplication"

ios/Kvante/Kvante/Models/ChatMessage.swift
  ~ exampleStep enum case adds LongMultiplicationState? parameter

ios/Kvante/Kvante/Views/Chat/ChatBubble.swift
  ~ exampleStep switch case extracts longMultState
  ~ exampleStepBubble takes longMultiplicationState parameter
  ~ VisualComponentView call passes it

ios/Kvante/Kvante/Views/Chat/InlineExampleView.swift
  ~ VisualComponentView call passes player.cumulativeLongMultiplicationState

ios/Kvante/Kvante/Views/AnimatedExplanationView.swift
  ~ Subview accepts cumulativeLongMultiplicationState
  ~ Top-level passes player.cumulativeLongMultiplicationState

ios/Kvante/Kvante/ViewModels/ChatViewModel.swift
  ~ showNextExampleStep() builds longMultState alongside gridState/shortDivState
  ~ Both .exampleStep call sites pass the new parameter
```

---

## Phase 1 — Branch setup

### Task 1: Create feature branch

**Files:** none

- [ ] **Step 1: Verify clean working tree**

```bash
git status
```

Expected: `nothing to commit, working tree clean`. If there are uncommitted changes, stop and check with the user.

- [ ] **Step 2: Pull latest main**

```bash
git checkout main && git pull
```

Expected: `Already up to date.` or fast-forward.

- [ ] **Step 3: Create feature branch**

```bash
git checkout -b feature/long-multiplication-visual
git push -u origin feature/long-multiplication-visual
```

Expected: branch created, pushed with upstream tracking.

---

## Phase 2 — Backend service (TDD)

### Task 2: Test scaffold + first compute_steps test (24 × 7)

**Files:**
- Create: `backend/tests/test_long_multiplication.py`

- [ ] **Step 1: Write the test file with first failing test**

```python
import pytest
from app.services.long_multiplication import LongMultiplicationService


class TestComputeStepsBasic:
    def test_single_partial_24_times_7(self):
        """24 × 7 = 168, single-digit multiplier → one partial, no sum_partials."""
        steps, mental = LongMultiplicationService.compute_steps(24, 7)

        # Setup
        assert steps[0]["step"] == "setup"
        assert steps[0]["multiplicand"] == 24
        assert steps[0]["multiplier"] == 7
        assert steps[0]["multiplicand_digits"] == [2, 4]
        assert steps[0]["multiplier_digits"] == [7]

        # Exactly one partial_product
        partials = [s for s in steps if s["step"] == "partial_product"]
        assert len(partials) == 1
        p = partials[0]
        assert p["multiplier_digit"] == 7
        assert p["multiplier_position"] == 0
        assert p["value"] == 168
        assert p["digits"] == [1, 6, 8]
        assert p["shift"] == 0
        # 4×7=28 generates a carry of 2 that is CONSUMED by 2×7+2=16. The mente
        # is displayed above the tens column (the '2'), where it gets used —
        # not above the ones column where it was generated. multiplicand_digits
        # is [2, 4] in WRITTEN order (high-to-low), so the tens position is
        # written_idx 0.
        assert p["carries"] == [2, None]
        assert p["expression_chain"] == "4×7=28 → 2×7+2=16"

        # No sum_partials when only one partial
        assert not any(s["step"] == "sum_partials" for s in steps)

        # Reveal
        assert steps[-1]["step"] == "reveal"
        assert steps[-1]["result"] == 168

        # Mental steps parallel structure
        assert len(mental) == 1
        assert len(mental[0]) == 2  # 2 columns in multiplicand "24"
        assert mental[0][0]["column"] == 0   # ones first (computation order)
        assert mental[0][0]["digit_written"] == 8
        assert mental[0][0]["carry_out"] == 2
        assert mental[0][1]["column"] == 1
        assert mental[0][1]["carry_in"] == 2
        assert mental[0][1]["digit_written"] == 6
```

> **Note for the implementer:** `24 × 7`:
> - column 0 (ones=4): `4 × 7 = 28`, write 8, carry 2
> - column 1 (tens=2): `2 × 7 + 2 = 16`, write 6, carry 1 → no more columns, the leading 1 just becomes the next digit of the partial value
>
> The partial value is 168 (= 24 × 7). The "carry 1 left over after the last column" never appears in `carries[]` — it's already absorbed into `value` and `digits`. `carries` only tracks intermediate carries between adjacent columns of the multiplicand.

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd backend && uv run pytest tests/test_long_multiplication.py -v
```

Expected: `ImportError` or `ModuleNotFoundError: No module named 'app.services.long_multiplication'`. (If `uv run` is not the project's runner, use whatever command runs other tests — check `backend/tests/test_short_division.py` history with `git log -p`.)

### Task 3: Implement compute_steps minimal (single partial)

**Files:**
- Create: `backend/app/services/long_multiplication.py`

- [ ] **Step 1: Write the minimal implementation**

```python
"""Deterministic step engine for Danish long multiplication (lang opstilling).

Given a multiplicand and multiplier, produces the exact sequence of animation
steps. No LLM involved — pure arithmetic. Caller is responsible for normalising
(larger operand first); compute_steps asserts this invariant.
"""
import random


class LongMultiplicationService:
    @staticmethod
    def compute_steps(multiplicand: int, multiplier: int) -> tuple[list[dict], list[list[dict]]]:
        """Produce display-order step dicts and a parallel mental_steps list.

        Returns: (steps, mental_steps_by_partial)
          - steps: [setup, partial_product * N, sum_partials?, reveal]
          - mental_steps_by_partial[i] is the mental_steps for the i'th
            partial_product step (0-indexed across partial_products only).
        """
        assert multiplicand > 0 and multiplier > 0, "Both numbers must be positive"
        assert multiplicand >= multiplier, "Caller must normalise: larger first"
        assert multiplicand < 1000 and multiplier < 100, "Cap: 3 cifre × 2 cifre"
        assert multiplicand >= 10 or multiplier >= 10, "At least one multi-digit operand"

        multiplicand_digits = [int(d) for d in str(multiplicand)]
        multiplier_digits = [int(d) for d in str(multiplier)]

        steps: list[dict] = [{
            "step": "setup",
            "multiplicand": multiplicand,
            "multiplier": multiplier,
            "multiplicand_digits": multiplicand_digits,
            "multiplier_digits": multiplier_digits,
        }]

        mental_steps_by_partial: list[list[dict]] = []
        partial_values: list[int] = []  # post-shift, for sum_partials

        # Iterate multiplier digits low-to-high (computation order)
        for position, mp_digit in enumerate(reversed(multiplier_digits)):
            partial_value, mental_steps = LongMultiplicationService._compute_partial(
                multiplicand_digits, mp_digit
            )
            carries = LongMultiplicationService._derive_carries(
                multiplicand_digits, mental_steps
            )

            steps.append({
                "step": "partial_product",
                "multiplier_digit": mp_digit,
                "multiplier_position": position,
                "value": partial_value,
                "digits": [int(d) for d in str(partial_value)],
                "shift": position,
                "carries": carries,
                "expression_chain": " → ".join(ms["expression"] for ms in mental_steps),
            })
            mental_steps_by_partial.append(mental_steps)
            partial_values.append(partial_value * (10 ** position))

        if len(partial_values) >= 2:
            steps.append({
                "step": "sum_partials",
                "partials": partial_values,
                "total": sum(partial_values),
            })

        steps.append({
            "step": "reveal",
            "result": multiplicand * multiplier,
        })

        return steps, mental_steps_by_partial

    @staticmethod
    def _compute_partial(multiplicand_digits: list[int], mp_digit: int) -> tuple[int, list[dict]]:
        """Compute multiplicand × mp_digit, returning (value, mental_steps).

        mental_steps is in computation order (column 0 = ones, column 1 = tens, ...).
        """
        carry = 0
        result_digits_low_to_high: list[int] = []
        mental_steps: list[dict] = []

        # Iterate multiplicand digits low-to-high
        for column, mc_digit in enumerate(reversed(multiplicand_digits)):
            product = mc_digit * mp_digit + carry
            digit_written = product % 10
            new_carry = product // 10

            if carry > 0:
                expression = f"{mc_digit}×{mp_digit}+{carry}={product}"
            else:
                expression = f"{mc_digit}×{mp_digit}={product}"

            mental_steps.append({
                "expression": expression,
                "digit_written": digit_written,
                "carry_in": carry,
                "carry_out": new_carry,
                "column": column,
            })

            result_digits_low_to_high.append(digit_written)
            carry = new_carry

        # Any leftover carry becomes the next high-order digit(s)
        while carry > 0:
            result_digits_low_to_high.append(carry % 10)
            carry //= 10

        # Reconstruct integer value
        value = 0
        for i, d in enumerate(result_digits_low_to_high):
            value += d * (10 ** i)

        return value, mental_steps

    @staticmethod
    def _derive_carries(multiplicand_digits: list[int], mental_steps: list[dict]) -> list:
        """Map mental_steps carry_in values to written-order carry array.

        Returns a list parallel to multiplicand_digits (written, high-to-low).
        Each element is None or an int 1-9.
        """
        n = len(multiplicand_digits)
        carries: list = [None] * n
        for ms in mental_steps:
            if ms["carry_in"] > 0:
                written_idx = n - 1 - ms["column"]
                carries[written_idx] = ms["carry_in"]
        return carries
```

- [ ] **Step 2: Run the test, verify pass**

```bash
cd backend && uv run pytest tests/test_long_multiplication.py::TestComputeStepsBasic::test_single_partial_24_times_7 -v
```

Expected: `1 passed`.

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_long_multiplication.py backend/app/services/long_multiplication.py
git commit -m "feat: long multiplication compute_steps single-partial path"
```

### Task 4: Test multi-partial + sum_partials (14 × 12)

**Files:**
- Modify: `backend/tests/test_long_multiplication.py`

- [ ] **Step 1: Add the failing test**

Append to `TestComputeStepsBasic`:

```python
    def test_multi_partial_14_times_12(self):
        """14 × 12 = 168, two partials → sum_partials present.

        Note: input is normalised so multiplicand=14, multiplier=12.
        """
        steps, mental = LongMultiplicationService.compute_steps(14, 12)

        partials = [s for s in steps if s["step"] == "partial_product"]
        assert len(partials) == 2

        # Partial 1: 14 × 2 (ones digit of 12)
        assert partials[0]["multiplier_digit"] == 2
        assert partials[0]["multiplier_position"] == 0
        assert partials[0]["value"] == 28
        assert partials[0]["shift"] == 0

        # Partial 2: 14 × 1 (tens digit of 12)
        assert partials[1]["multiplier_digit"] == 1
        assert partials[1]["multiplier_position"] == 1
        assert partials[1]["value"] == 14
        assert partials[1]["shift"] == 1

        # sum_partials: 28 + 140 = 168 (note 140 is post-shift)
        sums = [s for s in steps if s["step"] == "sum_partials"]
        assert len(sums) == 1
        assert sums[0]["partials"] == [28, 140]
        assert sums[0]["total"] == 168

        # Reveal
        assert steps[-1]["step"] == "reveal"
        assert steps[-1]["result"] == 168

        # Two parallel mental_steps lists, one per partial
        assert len(mental) == 2
```

- [ ] **Step 2: Run, expect pass (the implementation already covers this)**

```bash
cd backend && uv run pytest tests/test_long_multiplication.py::TestComputeStepsBasic::test_multi_partial_14_times_12 -v
```

Expected: `1 passed`. (If it fails, the multi-partial + sum_partials logic in Task 3 has a bug — fix the implementation, not the test.)

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_long_multiplication.py
git commit -m "test: multi-partial sum_partials path for long multiplication"
```

### Task 5: Test reference example with carries (206 × 14)

**Files:**
- Modify: `backend/tests/test_long_multiplication.py`

- [ ] **Step 1: Add the failing test**

Append to `TestComputeStepsBasic`:

```python
    def test_reference_206_times_14(self):
        """206 × 14 = 2884 — the spec's reference example. Verifies carries
        derivation, expression_chain format, and sum_partials post-shift values."""
        steps, mental = LongMultiplicationService.compute_steps(206, 14)

        # Setup digits in WRITTEN order
        assert steps[0]["multiplicand_digits"] == [2, 0, 6]
        assert steps[0]["multiplier_digits"] == [1, 4]

        partials = [s for s in steps if s["step"] == "partial_product"]
        assert len(partials) == 2

        # Partial 1: 206 × 4 = 824
        p1 = partials[0]
        assert p1["multiplier_digit"] == 4
        assert p1["value"] == 824
        assert p1["digits"] == [8, 2, 4]
        assert p1["shift"] == 0
        # 4×4=16 (carry 2 over the '0'), 0×4+2=2, 2×4=8
        assert p1["carries"] == [None, 2, None]
        assert p1["expression_chain"] == "6×4=24 → 0×4+2=2 → 2×4=8"

        # Partial 2: 206 × 1 = 206 (pre-shift), shifted to 2060
        p2 = partials[1]
        assert p2["multiplier_digit"] == 1
        assert p2["value"] == 206
        assert p2["digits"] == [2, 0, 6]
        assert p2["shift"] == 1
        assert p2["carries"] == [None, None, None]  # ×1 never carries
        assert p2["expression_chain"] == "6×1=6 → 0×1=0 → 2×1=2"

        # sum_partials post-shift
        sum_step = next(s for s in steps if s["step"] == "sum_partials")
        assert sum_step["partials"] == [824, 2060]
        assert sum_step["total"] == 2884

        # Reveal
        assert steps[-1]["result"] == 2884
```

- [ ] **Step 2: Run the test**

```bash
cd backend && uv run pytest tests/test_long_multiplication.py::TestComputeStepsBasic::test_reference_206_times_14 -v
```

Expected: `1 passed`. (Implementation should already handle this. If not, debug `_derive_carries` and `_compute_partial`.)

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_long_multiplication.py
git commit -m "test: reference example 206x14 with carries derivation"
```

### Task 6: Edge cases and assertion guards

**Files:**
- Modify: `backend/tests/test_long_multiplication.py`

- [ ] **Step 1: Add edge case tests**

Append a new test class:

```python
class TestComputeStepsEdgeCases:
    def test_worst_case_999_times_99(self):
        """999 × 99 = 98901, the worst case under the cap."""
        steps, _ = LongMultiplicationService.compute_steps(999, 99)
        partials = [s for s in steps if s["step"] == "partial_product"]
        assert len(partials) == 2
        assert partials[0]["value"] == 8991  # 999 × 9
        assert partials[1]["value"] == 8991
        assert partials[1]["shift"] == 1
        sum_step = next(s for s in steps if s["step"] == "sum_partials")
        assert sum_step["total"] == 98901
        assert steps[-1]["result"] == 98901

    def test_zeros_100_times_10(self):
        """100 × 10 = 1000 — multiplicand and multiplier with internal zeros."""
        steps, _ = LongMultiplicationService.compute_steps(100, 10)
        partials = [s for s in steps if s["step"] == "partial_product"]
        assert len(partials) == 2
        # 100 × 0 = 0 (ones), 100 × 1 = 100 (tens, shift 1)
        assert partials[0]["value"] == 0
        assert partials[0]["multiplier_digit"] == 0
        assert partials[1]["value"] == 100
        assert partials[1]["shift"] == 1
        assert steps[-1]["result"] == 1000

    def test_3x2_typical_245_times_14(self):
        """245 × 14 = 3430 — typical 4.-6. klasse problem."""
        steps, _ = LongMultiplicationService.compute_steps(245, 14)
        assert steps[-1]["result"] == 3430

    def test_step_count_under_max(self):
        """compute_steps must produce ≤ 5 steps for any in-cap input."""
        for mc, mp in [(999, 99), (245, 14), (206, 14), (24, 7)]:
            steps, _ = LongMultiplicationService.compute_steps(mc, mp)
            assert len(steps) <= 5, f"{mc} × {mp} produced {len(steps)} steps"

    def test_rejects_single_digit_pair(self):
        """compute_steps must reject 9 × 7 (single × single)."""
        with pytest.raises(AssertionError, match="multi-digit"):
            LongMultiplicationService.compute_steps(9, 7)

    def test_rejects_over_cap_smaller(self):
        """compute_steps must reject smaller > 99."""
        with pytest.raises(AssertionError, match="3 cifre × 2 cifre"):
            LongMultiplicationService.compute_steps(245, 134)

    def test_rejects_over_cap_larger(self):
        """compute_steps must reject larger >= 1000."""
        with pytest.raises(AssertionError, match="3 cifre × 2 cifre"):
            LongMultiplicationService.compute_steps(1234, 5)

    def test_rejects_unnormalised_input(self):
        """compute_steps must reject multiplier > multiplicand (caller's job)."""
        with pytest.raises(AssertionError, match="normalise"):
            LongMultiplicationService.compute_steps(7, 24)
```

- [ ] **Step 2: Run, expect 8 passing tests**

```bash
cd backend && uv run pytest tests/test_long_multiplication.py::TestComputeStepsEdgeCases -v
```

Expected: `8 passed`. If anything fails, fix the implementation in `long_multiplication.py`.

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_long_multiplication.py backend/app/services/long_multiplication.py
git commit -m "test: long multiplication edge cases and assertion guards"
```

### Task 7: pick_example_numbers TDD

**Files:**
- Modify: `backend/tests/test_long_multiplication.py`
- Modify: `backend/app/services/long_multiplication.py`

- [ ] **Step 1: Write failing tests**

Append:

```python
class TestPickExampleNumbers:
    def test_never_returns_student_numbers(self):
        """Cardinal rule: example numbers are never the student's numbers (50 iters)."""
        for _ in range(50):
            ex_a, ex_b = LongMultiplicationService.pick_example_numbers(206, 14)
            assert (ex_a, ex_b) != (206, 14)
            assert ex_a != 206 or ex_b != 14

    def test_matches_digit_count(self):
        """Picked example matches the digit count of both operands (50 iters)."""
        for _ in range(50):
            ex_a, ex_b = LongMultiplicationService.pick_example_numbers(206, 14)
            assert len(str(ex_a)) == 3, f"Expected 3-digit, got {ex_a}"
            assert len(str(ex_b)) == 2, f"Expected 2-digit, got {ex_b}"

    def test_preserves_larger_smaller_invariant(self):
        """Returned (ex_a, ex_b) always has ex_a >= ex_b (50 iters)."""
        for _ in range(50):
            ex_a, ex_b = LongMultiplicationService.pick_example_numbers(206, 14)
            assert ex_a >= ex_b

    def test_rejects_multiples_of_ten(self):
        """Picked numbers should not be multiples of 10 (trivial cases)."""
        for _ in range(50):
            ex_a, ex_b = LongMultiplicationService.pick_example_numbers(206, 14)
            assert ex_a % 10 != 0
            assert ex_b % 10 != 0

    def test_rejects_below_two(self):
        """Picked numbers should not include 0 or 1."""
        for _ in range(50):
            ex_a, ex_b = LongMultiplicationService.pick_example_numbers(24, 7)
            assert ex_a >= 2 and ex_b >= 2

    def test_2cif_x_1cif(self):
        """Smaller scope: 2-cifret × 1-cifret should still match digit counts."""
        for _ in range(50):
            ex_a, ex_b = LongMultiplicationService.pick_example_numbers(24, 7)
            assert len(str(ex_a)) == 2
            assert len(str(ex_b)) == 1
            assert ex_a >= ex_b
```

- [ ] **Step 2: Run, expect failures**

```bash
cd backend && uv run pytest tests/test_long_multiplication.py::TestPickExampleNumbers -v
```

Expected: failures (`AttributeError: type object 'LongMultiplicationService' has no attribute 'pick_example_numbers'`).

- [ ] **Step 3: Implement pick_example_numbers**

Add to `LongMultiplicationService` in `long_multiplication.py`:

```python
    @staticmethod
    def pick_example_numbers(multiplicand: int, multiplier: int) -> tuple[int, int]:
        """Pick example numbers matching the digit count of both operands.

        Cardinal rule: never returns the same numbers as input. Preserves the
        (larger, smaller) invariant: returned tuple always has a >= b. Avoids
        trivial cases (multiples of 10, numbers < 2).
        """
        mc_digits = len(str(multiplicand))
        mp_digits = len(str(multiplier))
        mc_lo, mc_hi = 10 ** (mc_digits - 1), 10 ** mc_digits - 1
        mp_lo, mp_hi = 10 ** (mp_digits - 1), 10 ** mp_digits - 1

        # If single-digit slot, allow 2-9 (not 0/1)
        mc_lo = max(mc_lo, 2)
        mp_lo = max(mp_lo, 2)

        for _ in range(200):
            ex_a = random.randint(mc_lo, mc_hi)
            ex_b = random.randint(mp_lo, mp_hi)
            if ex_a == multiplicand and ex_b == multiplier:
                continue
            if ex_a % 10 == 0 or ex_b % 10 == 0:
                continue
            if ex_a < ex_b:
                ex_a, ex_b = ex_b, ex_a
                # Re-check digit-count after swap (only an issue if mc_digits == mp_digits)
                if len(str(ex_a)) != mc_digits or len(str(ex_b)) != mp_digits:
                    continue
            return ex_a, ex_b

        # Fallback: deterministic safe values
        fallback_a = mc_lo + 1 if mc_lo + 1 != multiplicand else mc_lo + 3
        fallback_b = mp_lo + 1 if mp_lo + 1 != multiplier else mp_lo + 3
        if fallback_a < fallback_b:
            fallback_a, fallback_b = fallback_b, fallback_a
        return fallback_a, fallback_b
```

- [ ] **Step 4: Run, expect all pass**

```bash
cd backend && uv run pytest tests/test_long_multiplication.py::TestPickExampleNumbers -v
```

Expected: `6 passed`.

- [ ] **Step 5: Commit**

```bash
git add backend/tests/test_long_multiplication.py backend/app/services/long_multiplication.py
git commit -m "feat: pick_example_numbers for long multiplication"
```

### Task 8: generate_text TDD

**Files:**
- Modify: `backend/tests/test_long_multiplication.py`
- Modify: `backend/app/services/long_multiplication.py`

- [ ] **Step 1: Write failing tests**

Append:

```python
class TestGenerateText:
    def test_setup_text(self):
        steps, mental = LongMultiplicationService.compute_steps(206, 14)
        texts = LongMultiplicationService.generate_text(steps, mental)
        assert len(texts) == len(steps)
        assert "206" in texts[0]["text"]
        assert "14" in texts[0]["text"]
        assert texts[0]["audio_cue"]  # non-empty

    def test_partial_product_text_first_partial(self):
        steps, mental = LongMultiplicationService.compute_steps(206, 14)
        texts = LongMultiplicationService.generate_text(steps, mental)
        # The setup is texts[0], partial 1 is texts[1]
        partial1_text = texts[1]["text"]
        assert "4" in partial1_text  # multiplier digit
        assert "824" in partial1_text  # the partial value
        assert partial1_text  # non-empty

    def test_partial_product_text_explains_shift(self):
        steps, mental = LongMultiplicationService.compute_steps(206, 14)
        texts = LongMultiplicationService.generate_text(steps, mental)
        # Partial 2 (texts[2]) explains the tens-shift
        partial2_text = texts[2]["text"]
        assert "tier" in partial2_text.lower() or "plads" in partial2_text.lower()
        assert "2060" in partial2_text  # post-shift value mentioned

    def test_sum_partials_text(self):
        steps, mental = LongMultiplicationService.compute_steps(206, 14)
        texts = LongMultiplicationService.generate_text(steps, mental)
        # sum_partials is texts[3]
        sum_text = texts[3]["text"]
        assert "824" in sum_text
        assert "2060" in sum_text
        assert "2884" in sum_text

    def test_reveal_text(self):
        steps, mental = LongMultiplicationService.compute_steps(206, 14)
        texts = LongMultiplicationService.generate_text(steps, mental)
        reveal_text = texts[-1]["text"]
        assert "2884" in reveal_text
        assert "svar" in reveal_text.lower()

    def test_no_english_words(self):
        steps, mental = LongMultiplicationService.compute_steps(206, 14)
        texts = LongMultiplicationService.generate_text(steps, mental)
        forbidden = [" the ", " and ", " times ", " plus ", " minus "]
        for t in texts:
            lowered = " " + t["text"].lower() + " "
            for word in forbidden:
                assert word not in lowered, f"English '{word}' in: {t['text']}"

    def test_no_unfilled_placeholders(self):
        steps, mental = LongMultiplicationService.compute_steps(206, 14)
        texts = LongMultiplicationService.generate_text(steps, mental)
        for t in texts:
            assert "{" not in t["text"], f"Unfilled placeholder in: {t['text']}"

    def test_single_partial_no_sum_text(self):
        """24 × 7 has only one partial, no sum_partials → text count matches steps."""
        steps, mental = LongMultiplicationService.compute_steps(24, 7)
        texts = LongMultiplicationService.generate_text(steps, mental)
        assert len(texts) == len(steps)
```

- [ ] **Step 2: Run, expect failures**

```bash
cd backend && uv run pytest tests/test_long_multiplication.py::TestGenerateText -v
```

Expected: `AttributeError: ... has no attribute 'generate_text'`.

- [ ] **Step 3: Implement generate_text**

Add to `LongMultiplicationService`:

```python
    @staticmethod
    def generate_text(steps: list[dict],
                      mental_steps_by_partial: list[list[dict]]) -> list[dict]:
        """Generate Danish narration per step. Returns [{text, audio_cue}, ...].

        Indexing: mental_steps_by_partial[i] corresponds to the i'th
        partial_product step (NOT the i'th step overall).
        """
        texts: list[dict] = []
        partial_index = 0

        # Find the multiplicand from the setup step (first step)
        setup = steps[0]
        multiplicand = setup["multiplicand"]
        multiplier = setup["multiplier"]

        for s in steps:
            kind = s["step"]

            if kind == "setup":
                # Could be initial setup or try_yours; both use same template
                texts.append({
                    "text": (
                        f"Vi skal regne {s['multiplicand']} gange {s['multiplier']}. "
                        f"Vi stiller tallene op under hinanden med {s['multiplicand']} øverst"
                    ),
                    "audio_cue": f"{s['multiplicand']} gange {s['multiplier']}",
                })

            elif kind == "partial_product":
                mp_digit = s["multiplier_digit"]
                position = s["multiplier_position"]
                value = s["value"]
                shift = s["shift"]
                shifted_value = value * (10 ** shift)

                if position == 0:
                    # First partial — straightforward
                    text = f"Vi ganger {multiplicand} med {mp_digit}. Det giver {value}"
                else:
                    # Higher positions — explain the shift
                    place_name = LongMultiplicationService._place_name(position)
                    text = (
                        f"Nu ganger vi med {place_name}, {mp_digit}. "
                        f"Vi starter én plads til venstre fordi det er {place_name} — "
                        f"så {multiplicand}×{mp_digit}={value} bliver til {shifted_value}"
                    )

                texts.append({
                    "text": text,
                    "audio_cue": f"{multiplicand} gange {mp_digit} er {value}",
                })
                partial_index += 1

            elif kind == "sum_partials":
                partials = s["partials"]
                total = s["total"]
                expr = " + ".join(str(p) for p in partials)
                texts.append({
                    "text": f"Vi lægger delprodukterne sammen: {expr} = {total}",
                    "audio_cue": f"Sum {total}",
                })

            elif kind == "reveal":
                texts.append({
                    "text": f"Svaret er {s['result']}",
                    "audio_cue": f"Svaret er {s['result']}",
                })

        return texts

    @staticmethod
    def _place_name(position: int) -> str:
        """Return the Danish place-value name for a multiplier position."""
        return {
            0: "enerne",
            1: "tierne",
            2: "hundrederne",
        }.get(position, f"position {position}")
```

- [ ] **Step 4: Run, expect all pass**

```bash
cd backend && uv run pytest tests/test_long_multiplication.py::TestGenerateText -v
```

Expected: `8 passed`.

- [ ] **Step 5: Commit**

```bash
git add backend/tests/test_long_multiplication.py backend/app/services/long_multiplication.py
git commit -m "feat: Danish narration for long multiplication steps"
```

### Task 9: Routing helpers TDD

**Files:**
- Modify: `backend/tests/test_long_multiplication.py`
- Modify: `backend/app/services/example_generator.py`

- [ ] **Step 1: Write failing tests for routing**

Append a new test class to `test_long_multiplication.py`:

```python
class TestRouting:
    def test_parse_simple(self):
        from app.services.example_generator import _parse_multiplication_operands
        assert _parse_multiplication_operands("14 × 206") == (14, 206)

    def test_parse_skips_leading_numbers(self):
        from app.services.example_generator import _parse_multiplication_operands
        assert _parse_multiplication_operands("Opgave 3: Regn 14 × 206") == (14, 206)
        assert _parse_multiplication_operands("Regn 25 opgaver: 14 × 206") == (14, 206)

    def test_parse_no_match(self):
        from app.services.example_generator import _parse_multiplication_operands
        assert _parse_multiplication_operands("Hej") is None
        assert _parse_multiplication_operands("Tre gange syv") is None

    def test_parse_alternative_operators(self):
        from app.services.example_generator import _parse_multiplication_operands
        assert _parse_multiplication_operands("14 * 206") == (14, 206)
        assert _parse_multiplication_operands("14 · 206") == (14, 206)

    def test_should_use_in_cap(self):
        from app.services.example_generator import should_use_long_multiplication
        assert should_use_long_multiplication("multiplication", "14 × 206") is True
        assert should_use_long_multiplication("multiplication", "24 × 7") is True

    def test_should_use_rejects_single_digit_pair(self):
        from app.services.example_generator import should_use_long_multiplication
        assert should_use_long_multiplication("multiplication", "9 × 7") is False

    def test_should_use_rejects_over_cap(self):
        from app.services.example_generator import should_use_long_multiplication
        assert should_use_long_multiplication("multiplication", "245 × 134") is False
        assert should_use_long_multiplication("multiplication", "1234 × 5") is False

    def test_should_use_rejects_decimals(self):
        from app.services.example_generator import should_use_long_multiplication
        assert should_use_long_multiplication("multiplication", "3,4 × 2,5") is False

    def test_should_use_rejects_no_operands(self):
        from app.services.example_generator import should_use_long_multiplication
        assert should_use_long_multiplication("multiplication", "Hvad er klokken?") is False
        # Tagged but no parseable expression — text is authoritative
        assert should_use_long_multiplication("multiplication", "Tre gange syv") is False
```

- [ ] **Step 2: Run, expect ImportError**

```bash
cd backend && uv run pytest tests/test_long_multiplication.py::TestRouting -v
```

Expected: `ImportError: cannot import name '_parse_multiplication_operands'`.

- [ ] **Step 3: Add helpers to example_generator.py**

Add these definitions to `backend/app/services/example_generator.py` near the other helpers (after `should_use_short_division`, before `class ExampleGeneratorService`):

```python
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
```

- [ ] **Step 4: Run, expect all pass**

```bash
cd backend && uv run pytest tests/test_long_multiplication.py::TestRouting -v
```

Expected: `9 passed`.

- [ ] **Step 5: Commit**

```bash
git add backend/tests/test_long_multiplication.py backend/app/services/example_generator.py
git commit -m "feat: routing helpers for long multiplication assignments"
```

### Task 10: generate_long_multiplication_example method

**Files:**
- Modify: `backend/tests/test_long_multiplication.py`
- Modify: `backend/app/services/example_generator.py`

- [ ] **Step 1: Write failing test**

Append to `test_long_multiplication.py`:

```python
class TestGenerateExampleEndToEnd:
    def test_generates_full_response(self):
        from app.services.example_generator import ExampleGeneratorService
        svc = ExampleGeneratorService()
        result = svc.generate_long_multiplication_example("Regn 14 × 206", language="da")

        # Schema-ish checks
        assert "example_problem" in result
        assert "steps" in result
        assert "pedagogy" in result
        assert "note" in result
        assert result["pedagogy"] == "concrete-first"
        assert "Regn ud:" in result["example_problem"]
        assert "×" in result["example_problem"]

        # Each step has the right shape
        for step in result["steps"]:
            assert "step" in step
            assert "phase" in step
            assert "text" in step
            assert "visual" in step
            assert step["visual"]["type"] == "long_multiplication"

        # Last step is try_yours setup with student's normalised numbers
        last = result["steps"][-1]
        assert last["visual"]["action"] == "setup"
        # Student input was 14 × 206 → normalised multiplicand=206, multiplier=14
        assert last["visual"]["multiplicand"] == 206
        assert last["visual"]["multiplier"] == 14

    def test_example_numbers_never_match_student(self):
        """Run 30 generations and verify cardinal rule holds."""
        from app.services.example_generator import ExampleGeneratorService
        svc = ExampleGeneratorService()
        for _ in range(30):
            result = svc.generate_long_multiplication_example("Regn 14 × 206", language="da")
            problem = result["example_problem"]
            # Crude check: the student's numbers should not appear
            # in the example_problem string at all
            assert "14 × 206" not in problem
            assert "206 × 14" not in problem

    def test_step_count_under_max(self):
        """Total steps including try_yours must be ≤ 8 (MAX_STEPS)."""
        from app.services.example_generator import ExampleGeneratorService, MAX_STEPS
        svc = ExampleGeneratorService()
        result = svc.generate_long_multiplication_example("Regn 14 × 206", language="da")
        assert len(result["steps"]) <= MAX_STEPS

    def test_handles_2x1_input(self):
        from app.services.example_generator import ExampleGeneratorService
        svc = ExampleGeneratorService()
        result = svc.generate_long_multiplication_example("Regn 24 × 7", language="da")
        last = result["steps"][-1]
        # Normalised: multiplicand=24, multiplier=7
        assert last["visual"]["multiplicand"] == 24
        assert last["visual"]["multiplier"] == 7
```

- [ ] **Step 2: Run, expect failures**

```bash
cd backend && uv run pytest tests/test_long_multiplication.py::TestGenerateExampleEndToEnd -v
```

Expected: `AttributeError: ... has no attribute 'generate_long_multiplication_example'`.

- [ ] **Step 3: Implement generate_long_multiplication_example**

Add this method to `ExampleGeneratorService` in `example_generator.py`, near `generate_short_division_example`:

```python
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
```

- [ ] **Step 4: Run, expect 4 passing**

```bash
cd backend && uv run pytest tests/test_long_multiplication.py::TestGenerateExampleEndToEnd -v
```

Expected: `4 passed`.

- [ ] **Step 5: Commit**

```bash
git add backend/tests/test_long_multiplication.py backend/app/services/example_generator.py
git commit -m "feat: generate_long_multiplication_example end-to-end"
```

### Task 11: Wire long multiplication into generate_example routing

**Files:**
- Modify: `backend/app/services/example_generator.py:74-99`

- [ ] **Step 1: Read the existing branch**

Read the `generate_example` method around lines 74-99 to confirm the current order: stacked → short_division → LLM fallback.

- [ ] **Step 2: Insert the long_multiplication branch BEFORE short_division**

Replace the routing section in `generate_example`:

```python
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
```

- [ ] **Step 3: Run the full backend test suite**

```bash
cd backend && uv run pytest -q
```

Expected: all green. Pay special attention to `test_example_generator.py` and `test_integration.py` — make sure no existing routes were stolen.

- [ ] **Step 4: Commit**

```bash
git add backend/app/services/example_generator.py
git commit -m "feat: route multiplication assignments to long_multiplication path"
```

### Task 12: Backend deploy + smoke check

**Files:** none

- [ ] **Step 1: Verify hostname**

```bash
hostname
```

If `macair.home.lab` (MacBook), continue. If `macmini4`, skip the SSH and run tests locally.

- [ ] **Step 2: Run deploy script**

```bash
./scripts/deploy.sh
```

Expected: deploy script pushes, ssh-pulls on macmini4, restarts daemon, health-checks. Look for `OK` output.

- [ ] **Step 3: Smoke test against the live backend**

```bash
curl -sf http://192.168.1.60:8000/health
```

Expected: `{"status": "ok"}` or similar.

There is no commit in this task.

---

## Phase 3 — iOS state and helpers

### Task 13: Add optionalIntArrayParam helper

**Files:**
- Modify: `ios/Kvante/Kvante/Models/AnimationModels.swift:80-89`

- [ ] **Step 1: Add the helper next to `intArrayParam`**

After the `intArrayParam` method in `VisualInstruction`, add:

```swift
    /// Decode an array that may contain nulls (e.g. carry slots).
    /// Returns nil if the parameter is missing entirely.
    /// Each element is `Int?` — `nil` for explicit JSON `null`, an Int otherwise.
    func optionalIntArrayParam(_ key: String) -> [Int?]? {
        guard let arr = params[key]?.value as? [AnyCodable] else { return nil }
        return arr.map {
            if let i = $0.value as? Int { return Int?(i) }
            if let d = $0.value as? Double { return Int?(Int(d)) }
            return nil
        }
    }
```

- [ ] **Step 2: Verify it builds (compile only — no Swift tests)**

```bash
xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'generic/platform=iOS Simulator' build-for-testing 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. If the build fails, fix syntax errors before continuing.

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Models/AnimationModels.swift
git commit -m "feat: optionalIntArrayParam helper for nullable carry arrays"
```

### Task 14: Create LongMultiplicationState struct

**Files:**
- Create: `ios/Kvante/Kvante/Views/VisualComponents/LongMultiplicationView.swift`

- [ ] **Step 1: Write the state struct (no view yet)**

Create the file with this initial content:

```swift
import SwiftUI

struct LongMultiplicationState {
    let multiplicand: Int
    let multiplier: Int
    let multiplicandDigits: [Int]
    let multiplierDigits: [Int]

    var partials: [Partial]
    var activePartialIndex: Int?
    var currentExpressionChain: String?
    var currentCarries: [Int?]    // parallel to multiplicandDigits, written order
    var showSum: Bool
    var sumTotal: Int?
    var showResult: Bool
    var resultText: String?

    struct Partial {
        let value: Int
        let digits: [Int]
        let shift: Int
    }

    init(multiplicand: Int, multiplier: Int,
         multiplicandDigits: [Int], multiplierDigits: [Int]) {
        self.multiplicand = multiplicand
        self.multiplier = multiplier
        self.multiplicandDigits = multiplicandDigits
        self.multiplierDigits = multiplierDigits
        self.partials = []
        self.activePartialIndex = nil
        self.currentExpressionChain = nil
        self.currentCarries = Array(repeating: nil, count: multiplicandDigits.count)
        self.showSum = false
        self.sumTotal = nil
        self.showResult = false
        self.resultText = nil
    }

    static func from(visual: VisualInstruction) -> LongMultiplicationState {
        let mc = visual.intParam("multiplicand") ?? 0
        let mp = visual.intParam("multiplier") ?? 0
        let mcDigits = visual.intArrayParam("multiplicand_digits") ?? []
        let mpDigits = visual.intArrayParam("multiplier_digits") ?? []
        return LongMultiplicationState(
            multiplicand: mc,
            multiplier: mp,
            multiplicandDigits: mcDigits,
            multiplierDigits: mpDigits
        )
    }

    mutating func apply(visual: VisualInstruction) {
        switch visual.action {
        case "setup":
            // No-op: AnimationPlayer reassigns the entire state via from(visual:)
            // when it sees a setup action. This is also how try_yours resets to
            // a fresh, empty grid with the student's numbers.
            break

        case "partial_product":
            let value = visual.intParam("value") ?? 0
            let digits = visual.intArrayParam("digits") ?? []
            let shift = visual.intParam("shift") ?? 0
            partials.append(Partial(value: value, digits: digits, shift: shift))
            activePartialIndex = partials.count - 1
            currentExpressionChain = visual.stringParam("expression_chain")

            // carries: parallel to multiplicandDigits, may be missing entirely
            if let cs = visual.optionalIntArrayParam("carries") {
                currentCarries = cs
            } else {
                currentCarries = Array(repeating: nil, count: multiplicandDigits.count)
            }

        case "sum_partials":
            showSum = true
            sumTotal = visual.intParam("total")
            currentCarries = Array(repeating: nil, count: multiplicandDigits.count)
            activePartialIndex = nil
            currentExpressionChain = nil

        case "reveal":
            showResult = true
            if let r = visual.intParam("result") {
                resultText = String(r)
            }
            // Single-partial case: sum_partials was skipped, so reveal must
            // also clear the lingering carry/active state.
            if !showSum {
                currentCarries = Array(repeating: nil, count: multiplicandDigits.count)
                activePartialIndex = nil
                currentExpressionChain = nil
            }

        default:
            break
        }
    }
}
```

- [ ] **Step 2: Build to verify the file compiles standalone**

```bash
xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'generic/platform=iOS Simulator' build-for-testing 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. The view is missing but Swift will compile the file with just the struct.

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/VisualComponents/LongMultiplicationView.swift
git commit -m "feat: LongMultiplicationState struct with apply semantics"
```

---

## Phase 4 — iOS view rendering

### Task 15: Base layout (multiplicand row, multiplier row, line)

**Files:**
- Modify: `ios/Kvante/Kvante/Views/VisualComponents/LongMultiplicationView.swift`

- [ ] **Step 1: Append the view skeleton with base rows**

Append to `LongMultiplicationView.swift`:

```swift
struct LongMultiplicationView: View {
    let visual: VisualInstruction
    let animate: Bool
    let state: LongMultiplicationState

    @State private var revealedSegments: Int = 0
    @State private var chainAnimationTask: Task<Void, Never>?

    private let cellSize: CGFloat = 36
    private let largeFont: Font = .custom("Marker Felt", size: 28)
    private let smallFont: Font = .custom("Marker Felt", size: 18)

    /// Total grid width: enough cells to show the widest row.
    /// Worst case: a partial value can be wider than the multiplicand
    /// (e.g. 999 × 9 = 8991 is 4 digits when multiplicand is 3 digits).
    private var gridWidth: Int {
        var width = max(state.multiplicandDigits.count, state.multiplierDigits.count)
        for p in state.partials {
            width = max(width, p.digits.count + p.shift)
        }
        if state.showSum, let t = state.sumTotal {
            width = max(width, String(t).count)
        }
        return width
    }

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            // Mente row (placeholder; filled in next task)
            // Multiplicand row
            digitRow(state.multiplicandDigits, alignRight: true,
                     prefix: "", color: KvanteTheme.Colors.ink)
            // Multiplier row with × prefix
            digitRow(state.multiplierDigits, alignRight: true,
                     prefix: "×", color: KvanteTheme.Colors.ink)
            // Line under multiplier
            Rectangle()
                .fill(KvanteTheme.Colors.ink.opacity(0.5))
                .frame(height: 3)
                .frame(width: CGFloat(gridWidth + 1) * cellSize)
            // Partial product rows + sum row + result come in later tasks
        }
        .padding(16)
    }

    @ViewBuilder
    private func digitRow(_ digits: [Int], alignRight: Bool, prefix: String,
                          color: Color) -> some View {
        let leadingEmptyCells = gridWidth - digits.count
        HStack(spacing: 0) {
            // Operator cell on the very left
            Text(prefix)
                .font(largeFont)
                .foregroundStyle(KvanteTheme.Colors.primary)
                .frame(width: cellSize, height: cellSize)
            // Empty leading cells to right-align
            ForEach(0..<leadingEmptyCells, id: \.self) { _ in
                Color.clear.frame(width: cellSize, height: cellSize)
            }
            // Digit cells
            ForEach(Array(digits.enumerated()), id: \.offset) { _, d in
                Text("\(d)")
                    .font(largeFont)
                    .foregroundStyle(color)
                    .frame(width: cellSize, height: cellSize)
            }
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'generic/platform=iOS Simulator' build-for-testing 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/VisualComponents/LongMultiplicationView.swift
git commit -m "feat: base layout for LongMultiplicationView (multiplicand + multiplier + line)"
```

### Task 16: Partial product rows (with shifted zeros)

**Files:**
- Modify: `ios/Kvante/Kvante/Views/VisualComponents/LongMultiplicationView.swift`

- [ ] **Step 1: Add partial-product row rendering to the body**

Replace the body's `// Partial product rows ...` placeholder with the partial-rendering logic and add a `partialRow(_:)` builder. Update `body`:

```swift
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            // Multiplicand row
            digitRow(state.multiplicandDigits, alignRight: true,
                     prefix: "", color: KvanteTheme.Colors.ink)
            // Multiplier row with × prefix
            digitRow(state.multiplierDigits, alignRight: true,
                     prefix: "×", color: KvanteTheme.Colors.ink)
            // Line under multiplier
            Rectangle()
                .fill(KvanteTheme.Colors.ink.opacity(0.5))
                .frame(height: 3)
                .frame(width: CGFloat(gridWidth + 1) * cellSize)
            // Partial product rows
            ForEach(Array(state.partials.enumerated()), id: \.offset) { idx, partial in
                partialRow(partial, isActive: state.activePartialIndex == idx)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .padding(16)
        .animation(.easeOut(duration: 0.3), value: state.partials.count)
    }

    @ViewBuilder
    private func partialRow(_ partial: LongMultiplicationState.Partial,
                            isActive: Bool) -> some View {
        // Render with shifted zeros: a partial of digits=[8,2,4] and shift=1
        // becomes "8 2 4 0" (one extra '0' on the right).
        let displayDigits = partial.digits + Array(repeating: 0, count: partial.shift)
        let leadingEmptyCells = gridWidth - displayDigits.count

        HStack(spacing: 0) {
            // Empty operator cell column
            Color.clear.frame(width: cellSize, height: cellSize)
            // Empty leading cells
            ForEach(0..<leadingEmptyCells, id: \.self) { _ in
                Color.clear.frame(width: cellSize, height: cellSize)
            }
            // Digit cells
            ForEach(Array(displayDigits.enumerated()), id: \.offset) { _, d in
                Text("\(d)")
                    .font(largeFont)
                    .foregroundStyle(KvanteTheme.Colors.ink)
                    .frame(width: cellSize, height: cellSize)
            }
        }
        .background(
            isActive
                ? KvanteTheme.Colors.primary.opacity(0.1)
                : Color.clear
        )
    }
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'generic/platform=iOS Simulator' build-for-testing 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/VisualComponents/LongMultiplicationView.swift
git commit -m "feat: partial product rows with shifted-zero rendering"
```

### Task 17: Mente row (carries above multiplicand)

**Files:**
- Modify: `ios/Kvante/Kvante/Views/VisualComponents/LongMultiplicationView.swift`

- [ ] **Step 1: Add carryRow as the first row in body**

Update `body` to add `carryRow()` BEFORE the multiplicand row:

```swift
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            // Mente (carry) row
            carryRow()
            // Multiplicand row
            digitRow(state.multiplicandDigits, alignRight: true,
                     prefix: "", color: KvanteTheme.Colors.ink)
            // Multiplier row with × prefix
            digitRow(state.multiplierDigits, alignRight: true,
                     prefix: "×", color: KvanteTheme.Colors.ink)
            // Line under multiplier
            Rectangle()
                .fill(KvanteTheme.Colors.ink.opacity(0.5))
                .frame(height: 3)
                .frame(width: CGFloat(gridWidth + 1) * cellSize)
            // Partial product rows
            ForEach(Array(state.partials.enumerated()), id: \.offset) { idx, partial in
                partialRow(partial, isActive: state.activePartialIndex == idx)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .padding(16)
        .animation(.easeOut(duration: 0.3), value: state.partials.count)
    }

    @ViewBuilder
    private func carryRow() -> some View {
        // currentCarries is parallel to multiplicandDigits in WRITTEN order.
        // Pad on the left so the carry positions line up with the multiplicand
        // row above the line.
        let leadingEmptyCells = gridWidth - state.multiplicandDigits.count

        HStack(spacing: 0) {
            // Operator cell column
            Color.clear.frame(width: cellSize, height: cellSize / 1.5)
            // Empty leading cells
            ForEach(0..<leadingEmptyCells, id: \.self) { _ in
                Color.clear.frame(width: cellSize, height: cellSize / 1.5)
            }
            // Carry cells
            ForEach(Array(state.currentCarries.enumerated()), id: \.offset) { _, carry in
                if let c = carry {
                    Text("\(c)")
                        .font(smallFont)
                        .foregroundStyle(.orange)
                        .frame(width: cellSize, height: cellSize / 1.5)
                        .transition(.opacity)
                } else {
                    Color.clear.frame(width: cellSize, height: cellSize / 1.5)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.currentCarries.map { $0 ?? -1 })
    }
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'generic/platform=iOS Simulator' build-for-testing 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/VisualComponents/LongMultiplicationView.swift
git commit -m "feat: mente (carry) row above multiplicand"
```

### Task 18: Expression chain bubble + sequential reveal animation

**Files:**
- Modify: `ios/Kvante/Kvante/Views/VisualComponents/LongMultiplicationView.swift`

- [ ] **Step 1: Add the expression bubble above the body's main VStack**

Wrap the existing `VStack(alignment: .center)` in a new outer VStack and add the bubble at the top. Update `body`:

```swift
    var body: some View {
        VStack(spacing: 12) {
            if let chain = state.currentExpressionChain {
                expressionBubble(chain)
                    .transition(.scale.combined(with: .opacity))
            }

            VStack(alignment: .center, spacing: 4) {
                // Mente (carry) row
                carryRow()
                // Multiplicand row
                digitRow(state.multiplicandDigits, alignRight: true,
                         prefix: "", color: KvanteTheme.Colors.ink)
                // Multiplier row with × prefix
                digitRow(state.multiplierDigits, alignRight: true,
                         prefix: "×", color: KvanteTheme.Colors.ink)
                // Line under multiplier
                Rectangle()
                    .fill(KvanteTheme.Colors.ink.opacity(0.5))
                    .frame(height: 3)
                    .frame(width: CGFloat(gridWidth + 1) * cellSize)
                // Partial product rows
                ForEach(Array(state.partials.enumerated()), id: \.offset) { idx, partial in
                    partialRow(partial, isActive: state.activePartialIndex == idx)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.3), value: state.partials.count)
        }
        .padding(16)
        .onChange(of: state.currentExpressionChain) { _, newChain in
            startChainReveal(for: newChain)
        }
        .onAppear {
            startChainReveal(for: state.currentExpressionChain)
        }
        .onDisappear {
            chainAnimationTask?.cancel()
        }
    }

    private func startChainReveal(for chain: String?) {
        chainAnimationTask?.cancel()
        revealedSegments = 0
        guard let chain else { return }
        let segmentCount = chain.split(separator: "→").count
        chainAnimationTask = Task { @MainActor in
            for i in 1...segmentCount {
                try? await Task.sleep(for: .milliseconds(300))
                if Task.isCancelled { return }
                revealedSegments = i
            }
        }
    }

    @ViewBuilder
    private func expressionBubble(_ chain: String) -> some View {
        let segments = chain.split(separator: "→").map { $0.trimmingCharacters(in: .whitespaces) }
        let visibleCount = min(revealedSegments, segments.count)
        let visibleText = segments.prefix(visibleCount).joined(separator: " → ")

        Text(visibleText.isEmpty ? " " : visibleText)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(KvanteTheme.Colors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                KvanteTheme.Colors.primary.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .animation(.easeOut(duration: 0.2), value: visibleCount)
    }
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'generic/platform=iOS Simulator' build-for-testing 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/VisualComponents/LongMultiplicationView.swift
git commit -m "feat: expression chain bubble with sequential segment reveal"
```

### Task 19: Sum row, double underline, and result

**Files:**
- Modify: `ios/Kvante/Kvante/Views/VisualComponents/LongMultiplicationView.swift`

- [ ] **Step 1: Append sum + result rendering inside the inner VStack**

Update the inner `VStack(alignment: .center)` in `body` to include sum row, double underline, and result. Replace the body's inner VStack with:

```swift
            VStack(alignment: .center, spacing: 4) {
                // Mente (carry) row
                carryRow()
                // Multiplicand row
                digitRow(state.multiplicandDigits, alignRight: true,
                         prefix: "", color: KvanteTheme.Colors.ink)
                // Multiplier row with × prefix
                digitRow(state.multiplierDigits, alignRight: true,
                         prefix: "×", color: KvanteTheme.Colors.ink)
                // Line under multiplier
                Rectangle()
                    .fill(KvanteTheme.Colors.ink.opacity(0.5))
                    .frame(height: 3)
                    .frame(width: CGFloat(gridWidth + 1) * cellSize)
                // Partial product rows
                ForEach(Array(state.partials.enumerated()), id: \.offset) { idx, partial in
                    partialRow(partial, isActive: state.activePartialIndex == idx)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                // Sum line + sum row (only when showSum)
                if state.showSum, let total = state.sumTotal {
                    Rectangle()
                        .fill(KvanteTheme.Colors.ink.opacity(0.5))
                        .frame(height: 3)
                        .frame(width: CGFloat(gridWidth + 1) * cellSize)
                        .transition(.opacity)
                    sumRow(total: total)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                // Double underline (only when showResult)
                if state.showResult {
                    VStack(spacing: 3) {
                        Rectangle()
                            .fill(KvanteTheme.Colors.ink)
                            .frame(height: 3)
                        Rectangle()
                            .fill(KvanteTheme.Colors.ink)
                            .frame(height: 3)
                    }
                    .frame(width: CGFloat(gridWidth + 1) * cellSize)
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.3), value: state.partials.count)
            .animation(.easeOut(duration: 0.3), value: state.showSum)
            .animation(.easeOut(duration: 0.3), value: state.showResult)
```

Then add `sumRow` as another @ViewBuilder helper at the end of the struct:

```swift
    @ViewBuilder
    private func sumRow(total: Int) -> some View {
        let totalDigits = String(total).map { Int(String($0)) ?? 0 }
        let leadingEmptyCells = gridWidth - totalDigits.count

        HStack(spacing: 0) {
            Color.clear.frame(width: cellSize, height: cellSize)
            ForEach(0..<leadingEmptyCells, id: \.self) { _ in
                Color.clear.frame(width: cellSize, height: cellSize)
            }
            ForEach(Array(totalDigits.enumerated()), id: \.offset) { _, d in
                Text("\(d)")
                    .font(largeFont)
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .frame(width: cellSize, height: cellSize)
                    .shadow(
                        color: state.showResult ? .teal.opacity(0.6) : .clear,
                        radius: state.showResult ? 8 : 0
                    )
                    .scaleEffect(state.showResult ? 1.05 : 1.0)
                    .animation(
                        .spring(duration: 0.5).repeatCount(state.showResult ? 2 : 0,
                                                            autoreverses: true),
                        value: state.showResult
                    )
            }
        }
    }
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'generic/platform=iOS Simulator' build-for-testing 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/VisualComponents/LongMultiplicationView.swift
git commit -m "feat: sum row and double-underline for long multiplication result"
```

### Task 20: Preview block

**Files:**
- Modify: `ios/Kvante/Kvante/Views/VisualComponents/LongMultiplicationView.swift`

- [ ] **Step 1: Add four preview states**

Append at the bottom of the file:

```swift
#Preview("Setup (206 × 14)") {
    let state = LongMultiplicationState(
        multiplicand: 206, multiplier: 14,
        multiplicandDigits: [2, 0, 6], multiplierDigits: [1, 4]
    )
    LongMultiplicationView(
        visual: VisualInstruction.make(type: "long_multiplication", action: "setup"),
        animate: false,
        state: state
    )
    .padding()
}

#Preview("After partial 1 (824 + carry)") {
    var state = LongMultiplicationState(
        multiplicand: 206, multiplier: 14,
        multiplicandDigits: [2, 0, 6], multiplierDigits: [1, 4]
    )
    state.partials = [.init(value: 824, digits: [8, 2, 4], shift: 0)]
    state.activePartialIndex = 0
    state.currentExpressionChain = "6×4=24 → 0×4+2=2 → 2×4=8"
    state.currentCarries = [nil, 2, nil]
    return LongMultiplicationView(
        visual: VisualInstruction.make(type: "long_multiplication",
                                        action: "partial_product"),
        animate: false,
        state: state
    )
    .padding()
}

#Preview("After reveal (full)") {
    var state = LongMultiplicationState(
        multiplicand: 206, multiplier: 14,
        multiplicandDigits: [2, 0, 6], multiplierDigits: [1, 4]
    )
    state.partials = [
        .init(value: 824, digits: [8, 2, 4], shift: 0),
        .init(value: 206, digits: [2, 0, 6], shift: 1),
    ]
    state.showSum = true
    state.sumTotal = 2884
    state.showResult = true
    state.resultText = "2884"
    return LongMultiplicationView(
        visual: VisualInstruction.make(type: "long_multiplication", action: "reveal"),
        animate: false,
        state: state
    )
    .padding()
}

#Preview("Try yours (178 × 23 reset)") {
    let state = LongMultiplicationState(
        multiplicand: 178, multiplier: 23,
        multiplicandDigits: [1, 7, 8], multiplierDigits: [2, 3]
    )
    LongMultiplicationView(
        visual: VisualInstruction.make(type: "long_multiplication", action: "setup"),
        animate: false,
        state: state
    )
    .padding()
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'generic/platform=iOS Simulator' build-for-testing 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/VisualComponents/LongMultiplicationView.swift
git commit -m "feat: four LongMultiplicationView previews including try_yours reset"
```

---

## Phase 5 — iOS integration

### Task 21: AnimationPlayer cumulative state for long_multiplication

**Files:**
- Modify: `ios/Kvante/Kvante/Views/AnimationPlayer.swift:15-16` (state property)
- Modify: `ios/Kvante/Kvante/Views/AnimationPlayer.swift:54-64` (reset)
- Modify: `ios/Kvante/Kvante/Views/AnimationPlayer.swift:100-126` (updateCumulativeState)
- Modify: `ios/Kvante/Kvante/Views/AnimationPlayer.swift:128-137` (recalculateCumulativeState)

- [ ] **Step 1: Add the cumulative state property**

In `AnimationPlayer.swift`, after the `cumulativeShortDivisionState` declaration, add:

```swift
    private(set) var cumulativeLongMultiplicationState: LongMultiplicationState?
```

- [ ] **Step 2: Reset it in `reset()`**

In the `reset()` method, after `cumulativeShortDivisionState = nil`, add:

```swift
        cumulativeLongMultiplicationState = nil
```

- [ ] **Step 3: Add updateCumulativeState case**

In `updateCumulativeState`, add the case after the `("short_division", _)` case:

```swift
        case ("long_multiplication", _):
            if v.action == "setup" {
                cumulativeLongMultiplicationState = LongMultiplicationState.from(visual: v)
            }
            cumulativeLongMultiplicationState?.apply(visual: v)
```

- [ ] **Step 4: Reset it in `recalculateCumulativeState`**

In `recalculateCumulativeState`, after `cumulativeShortDivisionState = nil`, add:

```swift
        cumulativeLongMultiplicationState = nil
```

- [ ] **Step 5: Build**

```bash
xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'generic/platform=iOS Simulator' build-for-testing 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add ios/Kvante/Kvante/Views/AnimationPlayer.swift
git commit -m "feat: AnimationPlayer state machine for long multiplication"
```

### Task 22: VisualComponentView routing case

**Files:**
- Modify: `ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift`

- [ ] **Step 1: Add the constructor parameter and stored property**

After `let cumulativeShortDivisionState: ShortDivisionState?`, add:

```swift
    let cumulativeLongMultiplicationState: LongMultiplicationState?
```

Update the `init` method to take it (with a default of `nil`):

```swift
    init(visual: VisualInstruction, animate: Bool,
         cumulativeObjects: Int = 0, cumulativeCrossedOut: Int = 0,
         cumulativeRows: Int = 2, cumulativeGrouped: Int = 0,
         cumulativeGridState: GridState? = nil,
         cumulativeShortDivisionState: ShortDivisionState? = nil,
         cumulativeLongMultiplicationState: LongMultiplicationState? = nil) {
        self.visual = visual
        self.animate = animate
        self.cumulativeObjects = cumulativeObjects
        self.cumulativeCrossedOut = cumulativeCrossedOut
        self.cumulativeRows = cumulativeRows
        self.cumulativeGrouped = cumulativeGrouped
        self.cumulativeGridState = cumulativeGridState
        self.cumulativeShortDivisionState = cumulativeShortDivisionState
        self.cumulativeLongMultiplicationState = cumulativeLongMultiplicationState
    }
```

- [ ] **Step 2: Add the routing case**

In the `body` switch, after the `case "short_division":` block, add:

```swift
        case "long_multiplication":
            if let state = cumulativeLongMultiplicationState {
                LongMultiplicationView(visual: visual, animate: animate, state: state)
            } else {
                LongMultiplicationView(visual: visual, animate: animate,
                                       state: LongMultiplicationState.from(visual: visual))
            }
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'generic/platform=iOS Simulator' build-for-testing 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift
git commit -m "feat: VisualComponentView routes long_multiplication visuals"
```

### Task 23: Thread LongMultiplicationState through the ChatMessage flow

This is a single atomic change across three coupled files. The build will be broken between sub-steps — only commit at the very end of the task once all sub-steps are done.

**Files:**
- Modify: `ios/Kvante/Kvante/Models/ChatMessage.swift:17`
- Modify: `ios/Kvante/Kvante/Views/Chat/ChatBubble.swift:80-81,254,273-284`
- Modify: `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift:235-270,366`

- [ ] **Step 1: Extend the ChatMessage enum case**

In `ChatMessage.swift`, change line 17 from:

```swift
    case exampleStep(AnimationStep, Int, Int, GridState?, ShortDivisionState?)  // step, stepNumber, totalSteps, gridState, shortDivisionState
```

to:

```swift
    case exampleStep(AnimationStep, Int, Int, GridState?, ShortDivisionState?, LongMultiplicationState?)  // step, stepNumber, totalSteps, gridState, shortDivisionState, longMultiplicationState
```

- [ ] **Step 2: Update the ChatBubble switch case**

In `ChatBubble.swift` around line 80, change:

```swift
        case .exampleStep(let step, let num, let total, let gridState, let shortDivisionState):
            exampleStepBubble(step, stepNumber: num, total: total, gridState: gridState, shortDivisionState: shortDivisionState)
```

to:

```swift
        case .exampleStep(let step, let num, let total, let gridState, let shortDivisionState, let longMultState):
            exampleStepBubble(step, stepNumber: num, total: total,
                              gridState: gridState,
                              shortDivisionState: shortDivisionState,
                              longMultiplicationState: longMultState)
```

- [ ] **Step 3: Update the exampleStepBubble signature and pass-through**

In `ChatBubble.swift`, replace the `exampleStepBubble` function (around line 254) with:

```swift
    private func exampleStepBubble(_ step: AnimationStep, stepNumber: Int, total: Int,
                                   gridState: GridState? = nil,
                                   shortDivisionState: ShortDivisionState? = nil,
                                   longMultiplicationState: LongMultiplicationState? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Step header
            HStack(spacing: 8) {
                Text("\(stepNumber)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(KvanteTheme.Colors.primary, in: Circle())
                Text("Trin \(stepNumber) af \(total)")
                    .font(.caption)
                    .foregroundStyle(KvanteTheme.Colors.primary)
            }

            // Step text
            Text(step.text)
                .font(.body)
                .foregroundStyle(KvanteTheme.Colors.ink)

            // Visual component
            VisualComponentView(
                visual: step.visual,
                animate: true,
                cumulativeObjects: 0,
                cumulativeCrossedOut: 0,
                cumulativeRows: 2,
                cumulativeGrouped: 0,
                cumulativeGridState: gridState,
                cumulativeShortDivisionState: shortDivisionState,
                cumulativeLongMultiplicationState: longMultiplicationState
            )
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(KvanteTheme.Colors.kvanteBubble, in: kvanteBubbleShape)
        .overlay(
            kvanteBubbleShape.stroke(KvanteTheme.Colors.primary.opacity(0.2), lineWidth: 2)
        )
    }
```

- [ ] **Step 4: Update ChatViewModel.showNextExampleStep**

Replace the body of `showNextExampleStep` (around lines 235-270) with:

```swift
    private func showNextExampleStep() {
        guard currentExampleStepIndex < pendingExampleSteps.count else { return }

        let step = pendingExampleSteps[currentExampleStepIndex]
        let isLast = currentExampleStepIndex == pendingExampleSteps.count - 1

        // Build cumulative state for stacked arithmetic, short division, and long multiplication
        var gridState: GridState? = nil
        var shortDivisionState: ShortDivisionState? = nil
        var longMultState: LongMultiplicationState? = nil
        for i in 0...currentExampleStepIndex {
            let s = pendingExampleSteps[i]
            if s.visual.type == "stacked_arithmetic" {
                if s.visual.action == "setup" {
                    gridState = GridState.from(visual: s.visual)
                }
                gridState?.apply(visual: s.visual)
            } else if s.visual.type == "short_division" {
                if s.visual.action == "setup" {
                    shortDivisionState = ShortDivisionState.from(visual: s.visual)
                }
                shortDivisionState?.apply(visual: s.visual)
            } else if s.visual.type == "long_multiplication" {
                if s.visual.action == "setup" {
                    longMultState = LongMultiplicationState.from(visual: s.visual)
                }
                longMultState?.apply(visual: s.visual)
            }
        }

        let chips: [ActionChipModel] = isLast
            ? []
            : [ActionChipModel(id: "next_step", label: "Næste trin →", icon: "arrow.right", isPrimary: false)]

        messages.append(ChatMessage(
            sender: .kvante,
            content: .exampleStep(step, currentExampleStepIndex + 1, pendingExampleSteps.count,
                                  gridState, shortDivisionState, longMultState),
            actions: chips
        ))

        currentExampleStepIndex += 1
    }
```

- [ ] **Step 5: Update the second .exampleStep call site (stacked completion)**

Around line 366, change:

```swift
                                content: .exampleStep(step, 1, 1, completedState, nil),
```

to:

```swift
                                content: .exampleStep(step, 1, 1, completedState, nil, nil),
```

- [ ] **Step 6: Build**

```bash
xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'generic/platform=iOS Simulator' build-for-testing 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 7: Commit**

```bash
git add ios/Kvante/Kvante/Models/ChatMessage.swift \
        ios/Kvante/Kvante/Views/Chat/ChatBubble.swift \
        ios/Kvante/Kvante/ViewModels/ChatViewModel.swift
git commit -m "feat: thread LongMultiplicationState through ChatMessage flow"
```

### Task 24: Update remaining call sites (InlineExampleView + AnimatedExplanationView)

**Files:**
- Modify: `ios/Kvante/Kvante/Views/Chat/InlineExampleView.swift:120-129`
- Modify: `ios/Kvante/Kvante/Views/AnimatedExplanationView.swift:34-39` (top-level call), `:107` (subview property), `:134-143` (subview's VisualComponentView call)

- [ ] **Step 1: InlineExampleView — pass through long multiplication state**

In `InlineExampleView.swift`, replace the `VisualComponentView(...)` call at lines 120-129 with:

```swift
                VisualComponentView(
                    visual: step.visual,
                    animate: true,
                    cumulativeObjects: player.cumulativeObjects,
                    cumulativeCrossedOut: player.cumulativeCrossedOut,
                    cumulativeRows: player.cumulativeRows,
                    cumulativeGrouped: player.cumulativeGrouped,
                    cumulativeGridState: player.cumulativeGridState,
                    cumulativeShortDivisionState: player.cumulativeShortDivisionState,
                    cumulativeLongMultiplicationState: player.cumulativeLongMultiplicationState
                )
```

- [ ] **Step 2: AnimatedExplanationView — top-level call to StepCardView**

Replace the `StepCardView(...)` call at lines 29-40 with:

```swift
                            StepCardView(
                                step: step,
                                isActive: index == player.currentStepIndex,
                                isCompleted: index < player.currentStepIndex,
                                animate: index == player.currentStepIndex,
                                cumulativeObjects: player.cumulativeObjects,
                                cumulativeCrossedOut: player.cumulativeCrossedOut,
                                cumulativeRows: player.cumulativeRows,
                                cumulativeGrouped: player.cumulativeGrouped,
                                cumulativeGridState: player.cumulativeGridState,
                                cumulativeShortDivisionState: player.cumulativeShortDivisionState,
                                cumulativeLongMultiplicationState: player.cumulativeLongMultiplicationState
                            )
```

- [ ] **Step 3: AnimatedExplanationView — StepCardView property and inner call**

Add a stored property to `StepCardView` after line 107 (`let cumulativeShortDivisionState: ShortDivisionState?`):

```swift
    let cumulativeLongMultiplicationState: LongMultiplicationState?
```

Then replace the inner `VisualComponentView(...)` call at lines 134-143 with:

```swift
            VisualComponentView(
                visual: step.visual,
                animate: animate,
                cumulativeObjects: cumulativeObjects,
                cumulativeCrossedOut: cumulativeCrossedOut,
                cumulativeRows: cumulativeRows,
                cumulativeGrouped: cumulativeGrouped,
                cumulativeGridState: cumulativeGridState,
                cumulativeShortDivisionState: cumulativeShortDivisionState,
                cumulativeLongMultiplicationState: cumulativeLongMultiplicationState
            )
```

(`StepCardView` does not declare an explicit initializer — Swift's memberwise init automatically picks up the new property, no extra changes needed.)

- [ ] **Step 4: Build**

```bash
xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'generic/platform=iOS Simulator' build-for-testing 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. If errors remain, run:

```bash
grep -rn "VisualComponentView(" ios/Kvante/Kvante/
```

…and patch any remaining call site to pass the new parameter (or the default-`nil` from the init).

- [ ] **Step 5: Commit**

```bash
git add ios/Kvante/Kvante/Views/Chat/InlineExampleView.swift \
        ios/Kvante/Kvante/Views/AnimatedExplanationView.swift
git commit -m "feat: pass cumulativeLongMultiplicationState through remaining call sites"
```

---

## Phase 6 — Verification and merge

### Task 25: Manual end-to-end verification

**Files:** none

- [ ] **Step 1: Verify backend is on the feature branch**

```bash
ssh oleserver@macmini4 "cd ~/Kvante && git fetch && git checkout feature/long-multiplication-visual && git pull"
```

Expected: branch checked out, up to date. (The launchd `--reload` will pick up the new code automatically.)

- [ ] **Step 2: Smoke test the API directly**

```bash
curl -sf http://192.168.1.60:8000/health
```

Expected: `{"status":"ok"}` or similar.

Then trigger a multiplication example:

```bash
curl -sf -X POST http://192.168.1.60:8000/sessions/test/assignments/test/example \
  -H "Content-Type: application/json" \
  -d '{"assignment_text": "Regn 14 × 206", "assignment_type": "multiplication", "assignment_topic": "multiplication"}'
```

Expected: JSON response with `example_problem` starting with `Regn ud:`, steps array with `visual.type == "long_multiplication"`, the last step is `try_yours` with student's `multiplicand=206, multiplier=14`. (Endpoint shape may differ — check `backend/app/routers/assignments.py` if the URL is different.)

- [ ] **Step 3: Build and run iOS app on the simulator**

```bash
xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante \
  -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. Then open Xcode and run, OR ask the user to run the simulator manually.

- [ ] **Step 4: Manual checklist on simulator/device**

Walk through these in the running app and confirm each:

1. Create a multiplication assignment with `14 × 206` (or use seed data)
2. Tap "Vis eksempel" to trigger the example flow
3. Verify: example shows different numbers (NOT 14 × 206)
4. Step through: setup → partial 1 → partial 2 → sum_partials → reveal → try_yours
5. On partial 1: confirm the carry digit appears in orange above the multiplicand
6. On partial 1: confirm the expression chain reveals segment by segment (~300ms apart)
7. Tap "Næste" mid-chain-animation: confirm the next step takes over cleanly (no stuck text)
8. On partial 2: confirm the partial is rendered with a trailing zero (e.g. `2060`, not `206·`)
9. On reveal: confirm the result has the spring + teal shadow animation
10. On try_yours: confirm the grid resets to an empty state with the student's numbers (`14 × 206` normalised to `206 × 14`)

If any step fails, capture a dev screenshot:

```bash
curl -sf http://192.168.1.60:8000/dev/screenshots/latest -o /tmp/kvante-latest.png
```

…and read it via the `Read` tool to debug visually. Fix the issue, recommit, redeploy, and re-verify.

- [ ] **Step 5: Run the full backend test suite one more time**

```bash
cd backend && uv run pytest -q
```

Expected: all green.

(No commit in this task — verification only.)

### Task 26: Merge to main

**Files:** none

- [ ] **Step 1: Confirm clean working tree on the feature branch**

```bash
git status
```

Expected: `nothing to commit, working tree clean`.

- [ ] **Step 2: Update TODO.md and project memory**

Move the long multiplication item in `TODO.md` from "Næste features" to "Gennemført":

```bash
# Edit TODO.md manually — move the section, add date, then:
git add TODO.md
git commit -m "docs: mark long multiplication visual as done"
```

Also update `~/.claude/projects/-Users-olsen-code-Kvante/memory/project_next_features.md` to reflect the completed status (use the Edit tool, not git).

- [ ] **Step 3: Merge the branch**

Ask the user before merging. If they approve:

```bash
git checkout main && git pull
git merge feature/long-multiplication-visual
```

Expected: fast-forward or clean merge.

- [ ] **Step 4: Push and clean up**

```bash
git push origin main
git branch -d feature/long-multiplication-visual
git push origin --delete feature/long-multiplication-visual
```

Expected: branch deleted locally and on origin.

- [ ] **Step 5: Final deploy**

```bash
./scripts/deploy.sh
```

Expected: deploys main, health check passes.
