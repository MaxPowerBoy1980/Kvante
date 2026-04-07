# Single-digit multiplikation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bygg en deterministisk single-digit multiplikations-feature (2-9 × 2-9) med en clean array-grid-visualisering der bygges op række for række med skip-counting.

**Architecture:** Spejler det etablerede mønster fra `long_multiplication`, `short_division` og `stacked_arithmetic`: deterministisk Python-service på backend (3 metoder: `compute_steps`, `pick_example_numbers`, `generate_text`) → JSON visual instructions → SwiftUI view på iOS med cumulative state-threading. Ingen LLM i pathen. Routing tilføjes til `example_generator.py` med single-digit foran long_mult i kæden. Try-yours-step bærer `visual: null` hvilket kræver schema-migration på begge sider.

**Tech Stack:** Python (FastAPI, Pydantic, pytest), SwiftUI (iOS 26.2, deployment-target iPad)

**Spec:** `docs/superpowers/specs/2026-04-07-single-digit-multiplication-design.md`

---

## Phase 1: Backend service (deterministisk core)

### Task 1: `SingleDigitMultiplicationService.compute_steps`

**Files:**
- Create: `backend/app/services/single_digit_multiplication.py`
- Test: `backend/tests/test_single_digit_multiplication.py`

- [ ] **Step 1: Skriv den fejlende test for compute_steps (mindste case)**

Opret `backend/tests/test_single_digit_multiplication.py`:

```python
import pytest
from app.services.single_digit_multiplication import SingleDigitMultiplicationService


class TestComputeSteps:
    def test_smallest_case_2x2(self):
        """2 × 2: 1 setup + 2 row + 1 reveal = 4 steps."""
        steps = SingleDigitMultiplicationService.compute_steps(2, 2)

        assert len(steps) == 4
        assert steps[0] == {"step": "setup", "rows": 2, "cols": 2}
        assert steps[1] == {
            "step": "row", "row_index": 0, "row_value": 2, "cumulative": 2
        }
        assert steps[2] == {
            "step": "row", "row_index": 1, "row_value": 2, "cumulative": 4
        }
        assert steps[3] == {"step": "reveal", "result": 4}
```

- [ ] **Step 2: Kør testen for at bekræfte den fejler**

```bash
cd backend && pytest tests/test_single_digit_multiplication.py::TestComputeSteps::test_smallest_case_2x2 -v
```

Forventet: `ModuleNotFoundError: No module named 'app.services.single_digit_multiplication'`

- [ ] **Step 3: Skriv minimal implementation af compute_steps**

Opret `backend/app/services/single_digit_multiplication.py`:

```python
"""Deterministic step engine for single-digit multiplication (areal-model).

Given two single-digit operands (2-9 × 2-9), produces the row-by-row
animation steps for an a × b rectangle. No LLM involved — pure arithmetic.
Caller is responsible for routing — should_use_single_digit_multiplication
in example_generator gates this.
"""


class SingleDigitMultiplicationService:
    @staticmethod
    def compute_steps(a: int, b: int) -> list[dict]:
        """Producer display-order step dicts for a × b.

        Caller skal IKKE normalisere — vi bevarer elevens læseretning:
        a er antal rækker, b er antal i hver række. Pædagogisk betyder
        det at 7 × 9 og 9 × 7 giver to forskellige visuelle layouts.
        """
        assert 2 <= a <= 9, f"a must be 2-9, got {a}"
        assert 2 <= b <= 9, f"b must be 2-9, got {b}"

        steps: list[dict] = [{"step": "setup", "rows": a, "cols": b}]

        for i in range(a):
            steps.append({
                "step": "row",
                "row_index": i,
                "row_value": b,
                "cumulative": (i + 1) * b,
            })

        steps.append({"step": "reveal", "result": a * b})
        return steps
```

- [ ] **Step 4: Kør testen for at bekræfte den passerer**

```bash
cd backend && pytest tests/test_single_digit_multiplication.py::TestComputeSteps::test_smallest_case_2x2 -v
```

Forventet: `1 passed`

- [ ] **Step 5: Tilføj edge-case tests (største case + asymmetri + scope-asserts)**

Tilføj til `TestComputeSteps`-klassen i `backend/tests/test_single_digit_multiplication.py`:

```python
    def test_largest_case_9x9(self):
        """9 × 9 = 81: 11 steps total, sidste row har cumulative=81."""
        steps = SingleDigitMultiplicationService.compute_steps(9, 9)

        assert len(steps) == 11  # 1 setup + 9 row + 1 reveal
        assert steps[0] == {"step": "setup", "rows": 9, "cols": 9}

        row_steps = [s for s in steps if s["step"] == "row"]
        assert len(row_steps) == 9
        assert row_steps[0]["cumulative"] == 9
        assert row_steps[-1]["cumulative"] == 81
        assert all(s["row_value"] == 9 for s in row_steps)

        assert steps[-1] == {"step": "reveal", "result": 81}

    def test_asymmetric_7x9(self):
        """7 × 9 = 63: 7 rows à 9, cumulative 9, 18, ..., 63."""
        steps = SingleDigitMultiplicationService.compute_steps(7, 9)

        row_steps = [s for s in steps if s["step"] == "row"]
        assert len(row_steps) == 7
        assert [s["cumulative"] for s in row_steps] == [9, 18, 27, 36, 45, 54, 63]
        assert all(s["row_value"] == 9 for s in row_steps)
        assert steps[-1]["result"] == 63

    def test_operand_order_preserved(self):
        """3 × 8 ≠ 8 × 3: rows-tæller forskellig, ingen normalisering."""
        steps_3x8 = SingleDigitMultiplicationService.compute_steps(3, 8)
        steps_8x3 = SingleDigitMultiplicationService.compute_steps(8, 3)

        rows_3x8 = [s for s in steps_3x8 if s["step"] == "row"]
        rows_8x3 = [s for s in steps_8x3 if s["step"] == "row"]
        assert len(rows_3x8) == 3
        assert len(rows_8x3) == 8

        # Resultatet er det samme (kommutativitet)
        assert steps_3x8[-1]["result"] == 24
        assert steps_8x3[-1]["result"] == 24

    def test_rejects_below_two(self):
        with pytest.raises(AssertionError, match="a must be 2-9"):
            SingleDigitMultiplicationService.compute_steps(1, 5)
        with pytest.raises(AssertionError, match="b must be 2-9"):
            SingleDigitMultiplicationService.compute_steps(5, 1)

    def test_rejects_above_nine(self):
        with pytest.raises(AssertionError, match="a must be 2-9"):
            SingleDigitMultiplicationService.compute_steps(10, 5)
        with pytest.raises(AssertionError, match="b must be 2-9"):
            SingleDigitMultiplicationService.compute_steps(5, 10)
```

- [ ] **Step 6: Kør hele compute_steps test-klassen**

```bash
cd backend && pytest tests/test_single_digit_multiplication.py::TestComputeSteps -v
```

Forventet: `6 passed`

- [ ] **Step 7: Commit**

```bash
git add backend/app/services/single_digit_multiplication.py backend/tests/test_single_digit_multiplication.py
git commit -m "feat: SingleDigitMultiplicationService.compute_steps

Deterministic step generator for 2-9 × 2-9. Produces setup + row*a +
reveal steps with running cumulative totals. Preserves operand order
(no normalization) so 7×9 and 9×7 are visually distinct."
```

---

### Task 2: `SingleDigitMultiplicationService.pick_example_numbers`

**Files:**
- Modify: `backend/app/services/single_digit_multiplication.py`
- Modify: `backend/tests/test_single_digit_multiplication.py`

- [ ] **Step 1: Skriv fejlende tests for pick_example_numbers**

Tilføj til `backend/tests/test_single_digit_multiplication.py`:

```python
class TestPickExampleNumbers:
    def test_avoids_exact_duplicate(self):
        """Skal aldrig returnere præcis (5, 7) når input er (5, 7)."""
        for _ in range(100):
            ex_a, ex_b = SingleDigitMultiplicationService.pick_example_numbers(5, 7)
            assert (ex_a, ex_b) != (5, 7)

    def test_avoids_commutative_duplicate(self):
        """Skal aldrig returnere (7, 5) når input er (5, 7) — commutative dup."""
        for _ in range(100):
            ex_a, ex_b = SingleDigitMultiplicationService.pick_example_numbers(5, 7)
            assert (ex_a, ex_b) != (7, 5)

    def test_avoids_both_orderings_when_input_is_symmetric(self):
        """5 × 5 input → eksempel må være alt undtagen 5 × 5."""
        for _ in range(100):
            ex_a, ex_b = SingleDigitMultiplicationService.pick_example_numbers(5, 5)
            assert (ex_a, ex_b) != (5, 5)

    def test_returns_in_2_to_9_range(self):
        """Begge tal skal være i [2, 9]."""
        for _ in range(200):
            ex_a, ex_b = SingleDigitMultiplicationService.pick_example_numbers(3, 4)
            assert 2 <= ex_a <= 9
            assert 2 <= ex_b <= 9

    def test_does_not_normalize(self):
        """Returnerer ikke en sorteret tuple — orden kan variere."""
        # Med 200 tries skal vi se mindst ét tilfælde hvor a < b OG ét hvor a > b
        # når vi giver et input der ikke begrænser orienteringen.
        results = set()
        for _ in range(200):
            ex_a, ex_b = SingleDigitMultiplicationService.pick_example_numbers(5, 5)
            results.add(("lt" if ex_a < ex_b else "gt" if ex_a > ex_b else "eq"))
        # Med 200 tries og 5×5 ekskluderet skal vi se både lt og gt orienteringer
        assert "lt" in results, f"never saw a < b; results={results}"
        assert "gt" in results, f"never saw a > b; results={results}"
```

- [ ] **Step 2: Kør tests for at bekræfte at de fejler**

```bash
cd backend && pytest tests/test_single_digit_multiplication.py::TestPickExampleNumbers -v
```

Forventet: `AttributeError: type object 'SingleDigitMultiplicationService' has no attribute 'pick_example_numbers'`

- [ ] **Step 3: Implementér pick_example_numbers**

Tilføj til `backend/app/services/single_digit_multiplication.py` (efter `compute_steps`):

```python
    @staticmethod
    def pick_example_numbers(a: int, b: int) -> tuple[int, int]:
        """Pick (ex_a, ex_b) ≠ (a, b) og ≠ (b, a). Begge 2-9.

        Bevarer (rows, cols)-rolle uden at normalisere. Deterministisk
        fallback hvis 200 random tries fejler (skulle aldrig ske med så
        lille et søgerum, men matcher pattern fra LongMultiplicationService).
        """
        import random

        for _ in range(200):
            ex_a = random.randint(2, 9)
            ex_b = random.randint(2, 9)
            if (ex_a, ex_b) == (a, b):
                continue
            if (ex_a, ex_b) == (b, a):
                continue
            return ex_a, ex_b

        # Deterministisk fallback: scan alle 64 kombinationer
        for ca in range(2, 10):
            for cb in range(2, 10):
                if (ca, cb) != (a, b) and (ca, cb) != (b, a):
                    return ca, cb

        # Skulle aldrig nås (2-9 × 2-9 = 64 par, kun 2 udelukkes)
        raise RuntimeError(f"No example pair found for ({a}, {b})")
```

- [ ] **Step 4: Kør tests for at bekræfte de passerer**

```bash
cd backend && pytest tests/test_single_digit_multiplication.py::TestPickExampleNumbers -v
```

Forventet: `5 passed`

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/single_digit_multiplication.py backend/tests/test_single_digit_multiplication.py
git commit -m "feat: SingleDigitMultiplicationService.pick_example_numbers

Picks an example pair that differs from the student's by both exact
match and commutative reversal. Deterministic fallback scans all 64
pairs if random retry budget exhausts."
```

---

### Task 3: `SingleDigitMultiplicationService.generate_text`

**Files:**
- Modify: `backend/app/services/single_digit_multiplication.py`
- Modify: `backend/tests/test_single_digit_multiplication.py`

- [ ] **Step 1: Skriv fejlende tests for generate_text**

Tilføj til `backend/tests/test_single_digit_multiplication.py`:

```python
class TestGenerateText:
    def _texts_for(self, a: int, b: int):
        steps = SingleDigitMultiplicationService.compute_steps(a, b)
        return SingleDigitMultiplicationService.generate_text(steps), steps

    def test_setup_text_mentions_dimensions(self):
        """Setup-bobble nævner '6 × 8', '6 rækker' og '8 i hver'."""
        texts, _ = self._texts_for(6, 8)
        setup_text = texts[0]["text"]
        assert "6 × 8" in setup_text
        assert "6 rækker" in setup_text
        assert "8 i hver" in setup_text

    def test_setup_audio_cue(self):
        texts, _ = self._texts_for(6, 8)
        assert texts[0]["audio_cue"] == "6 gange 8"

    def test_first_row_no_plus(self):
        """Første row siger bare '8' (ikke '+ 8 = 8')."""
        texts, _ = self._texts_for(6, 8)
        # texts[0]=setup, texts[1]=row 0
        assert texts[1]["text"] == "8"

    def test_subsequent_row_uses_plus_pattern(self):
        """Efter første row: '+ 8 = 16', '+ 8 = 24', ..."""
        texts, _ = self._texts_for(6, 8)
        assert texts[2]["text"] == "+ 8 = 16"
        assert texts[3]["text"] == "+ 8 = 24"
        assert texts[4]["text"] == "+ 8 = 32"
        assert texts[5]["text"] == "+ 8 = 40"
        assert texts[6]["text"] == "+ 8 = 48"

    def test_row_audio_cue_is_cumulative(self):
        """Audio cue er bare det aktuelle running-total tal."""
        texts, _ = self._texts_for(6, 8)
        assert texts[1]["audio_cue"] == "8"
        assert texts[2]["audio_cue"] == "16"
        assert texts[6]["audio_cue"] == "48"

    def test_reveal_text(self):
        """Reveal er '{a} × {b} = {result}'."""
        texts, _ = self._texts_for(6, 8)
        # texts[7]=reveal (index 0 setup + 6 rows + 1 reveal = 8 entries, last index=7)
        assert texts[-1]["text"] == "6 × 8 = 48"
        assert texts[-1]["audio_cue"] == "Svaret er 48"

    def test_text_count_matches_step_count(self):
        """Hver step får én text-entry."""
        for a, b in [(2, 2), (5, 5), (7, 9), (9, 9)]:
            texts, steps = self._texts_for(a, b)
            assert len(texts) == len(steps), f"mismatch for {a}×{b}"

    def test_asymmetric_3x8_uses_correct_addend(self):
        """3 × 8 har row_value=8, så addends er '+ 8 = 16', '+ 8 = 24'."""
        texts, _ = self._texts_for(3, 8)
        assert texts[1]["text"] == "8"
        assert texts[2]["text"] == "+ 8 = 16"
        assert texts[3]["text"] == "+ 8 = 24"
        assert texts[-1]["text"] == "3 × 8 = 24"

    def test_asymmetric_8x3_uses_correct_addend(self):
        """8 × 3 har row_value=3, så addends er '+ 3 = 6', '+ 3 = 9', ..."""
        texts, _ = self._texts_for(8, 3)
        assert texts[1]["text"] == "3"
        assert texts[2]["text"] == "+ 3 = 6"
        assert texts[3]["text"] == "+ 3 = 9"
        assert texts[-1]["text"] == "8 × 3 = 24"
```

- [ ] **Step 2: Kør tests for at bekræfte de fejler**

```bash
cd backend && pytest tests/test_single_digit_multiplication.py::TestGenerateText -v
```

Forventet: `AttributeError: type object 'SingleDigitMultiplicationService' has no attribute 'generate_text'`

- [ ] **Step 3: Implementér generate_text**

Tilføj til `backend/app/services/single_digit_multiplication.py` (efter `pick_example_numbers`):

```python
    @staticmethod
    def generate_text(steps: list[dict]) -> list[dict]:
        """Generér dansk narration. Returnerer [{text, audio_cue}, ...].

        Mappes 1:1 til steps:
        - setup → "Lad os finde {a} × {b}. Vi bygger {a} rækker med {b} i hver."
        - row, index 0 → "{b}"
        - row, index > 0 → "+ {b} = {cumulative}"
        - reveal → "{a} × {b} = {result}"
        """
        # Setup-step bærer dimensionerne — vi har brug for dem til reveal.
        setup = steps[0]
        a = setup["rows"]
        b = setup["cols"]

        texts: list[dict] = []
        for s in steps:
            kind = s["step"]
            if kind == "setup":
                texts.append({
                    "text": (
                        f"Lad os finde {a} × {b}. "
                        f"Vi bygger {a} rækker med {b} i hver."
                    ),
                    "audio_cue": f"{a} gange {b}",
                })
            elif kind == "row":
                if s["row_index"] == 0:
                    text = f"{b}"
                else:
                    text = f"+ {b} = {s['cumulative']}"
                texts.append({
                    "text": text,
                    "audio_cue": f"{s['cumulative']}",
                })
            elif kind == "reveal":
                result = s["result"]
                texts.append({
                    "text": f"{a} × {b} = {result}",
                    "audio_cue": f"Svaret er {result}",
                })

        return texts
```

- [ ] **Step 4: Kør tests for at bekræfte de passerer**

```bash
cd backend && pytest tests/test_single_digit_multiplication.py::TestGenerateText -v
```

Forventet: `9 passed`

- [ ] **Step 5: Kør hele test-filen for at fange regression**

```bash
cd backend && pytest tests/test_single_digit_multiplication.py -v
```

Forventet: `20 passed` (6 compute + 5 pick + 9 text)

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/single_digit_multiplication.py backend/tests/test_single_digit_multiplication.py
git commit -m "feat: SingleDigitMultiplicationService.generate_text

Maps each step to a Danish text + audio cue. Setup names dimensions,
first row drops the leading '+', subsequent rows use '+ b = cum'
chain, reveal closes with the full equation."
```

---

## Phase 2: Backend integration

### Task 4: Schema-migration — `AnimationStep.visual` → Optional

**Files:**
- Modify: `backend/app/models/schemas.py:39`

- [ ] **Step 1: Verificér eksisterende state**

```bash
cd backend && grep -n "visual:" app/models/schemas.py
```

Forventet output (linje 39):
```
39:    visual: VisualInstruction
```

- [ ] **Step 2: Skriv test der dokumenterer at None er gyldig**

Opret `backend/tests/test_animation_step_optional_visual.py`:

```python
"""Verifier at AnimationStep accepterer visual=None for try-yours steps."""
from app.models.schemas import AnimationStep, VisualInstruction


def test_animation_step_accepts_none_visual():
    """Try-yours steps har visual=None — schema skal tillade det."""
    step = AnimationStep(
        step=9,
        phase="concrete",
        text="Nu er det din tur — kan du regne 7 × 9?",
        visual=None,
        audio_cue="Prøv selv",
    )
    assert step.visual is None
    assert step.text.startswith("Nu")


def test_animation_step_still_accepts_visual():
    """Eksisterende kode der sender visual fortsætter med at virke."""
    visual = VisualInstruction(type="single_digit_array", action="setup")
    step = AnimationStep(
        step=1,
        phase="concrete",
        text="Test",
        visual=visual,
        audio_cue="",
    )
    assert step.visual is not None
    assert step.visual.type == "single_digit_array"
```

- [ ] **Step 3: Kør testen for at bekræfte den fejler på `visual=None`**

```bash
cd backend && pytest tests/test_animation_step_optional_visual.py -v
```

Forventet: `test_animation_step_accepts_none_visual` FAIL med Pydantic validation error på `visual` field.

- [ ] **Step 4: Opdater schema til Optional**

Edit `backend/app/models/schemas.py`. Find linje 35-40:

```python
class AnimationStep(BaseModel):
    step: int
    phase: str          # concrete, semi-concrete, abstract
    text: str
    visual: VisualInstruction
    audio_cue: str = ""
```

Erstat med:

```python
class AnimationStep(BaseModel):
    step: int
    phase: str          # concrete, semi-concrete, abstract
    text: str
    visual: VisualInstruction | None = None
    audio_cue: str = ""
```

- [ ] **Step 5: Kør testen for at bekræfte den passerer**

```bash
cd backend && pytest tests/test_animation_step_optional_visual.py -v
```

Forventet: `2 passed`

- [ ] **Step 6: Kør hele backend test-suite for regressioner**

```bash
cd backend && pytest -q
```

Forventet: alle eksisterende tests passerer stadig — schema-ændringen er bagudkompatibel fordi alle eksisterende examples stadig sender et non-null visual.

- [ ] **Step 7: Commit**

```bash
git add backend/app/models/schemas.py backend/tests/test_animation_step_optional_visual.py
git commit -m "feat: AnimationStep.visual is now Optional

Try-yours steps for the upcoming single-digit multiplication feature
need to be text-only (cardinal rule: don't reveal answer via grid
the student could count). Backwards compatible — existing code paths
all send non-null visuals."
```

---

### Task 5: Routing detector `should_use_single_digit_multiplication`

**Files:**
- Modify: `backend/app/services/example_generator.py`
- Modify: `backend/tests/test_single_digit_multiplication.py`

- [ ] **Step 1: Skriv fejlende routing-tests**

Tilføj til `backend/tests/test_single_digit_multiplication.py`:

```python
class TestRouting:
    def test_should_use_positive(self):
        from app.services.example_generator import should_use_single_digit_multiplication
        assert should_use_single_digit_multiplication("multiplication", "7 × 9") is True
        assert should_use_single_digit_multiplication("multiplication", "3 · 4") is True
        assert should_use_single_digit_multiplication("multiplication", "5*5") is True
        # Min/max boundaries
        assert should_use_single_digit_multiplication("multiplication", "2 × 2") is True
        assert should_use_single_digit_multiplication("multiplication", "9 × 9") is True

    def test_should_use_rejects_one(self):
        from app.services.example_generator import should_use_single_digit_multiplication
        assert should_use_single_digit_multiplication("multiplication", "1 × 5") is False
        assert should_use_single_digit_multiplication("multiplication", "5 × 1") is False

    def test_should_use_rejects_above_nine(self):
        from app.services.example_generator import should_use_single_digit_multiplication
        assert should_use_single_digit_multiplication("multiplication", "10 × 3") is False
        assert should_use_single_digit_multiplication("multiplication", "7 × 19") is False
        assert should_use_single_digit_multiplication("multiplication", "100 × 9") is False

    def test_should_use_rejects_decimals(self):
        from app.services.example_generator import should_use_single_digit_multiplication
        assert should_use_single_digit_multiplication("multiplication", "2,5 × 3") is False

    def test_should_use_rejects_non_multiplication(self):
        from app.services.example_generator import should_use_single_digit_multiplication
        assert should_use_single_digit_multiplication("multiplication", "7 + 9") is False
        assert should_use_single_digit_multiplication("multiplication", "Hvad er klokken?") is False
        # Tagged but no parseable expression — text is authoritative
        assert should_use_single_digit_multiplication("multiplication", "Tre gange syv") is False
```

- [ ] **Step 2: Kør for at bekræfte at de fejler**

```bash
cd backend && pytest tests/test_single_digit_multiplication.py::TestRouting -v
```

Forventet: `ImportError: cannot import name 'should_use_single_digit_multiplication'`

- [ ] **Step 3: Tilføj detector-funktionen**

Edit `backend/app/services/example_generator.py`. Find `should_use_long_multiplication` funktionen (omkring linje 87):

```python
def should_use_long_multiplication(assignment_type: str, assignment_text: str,
                                   assignment_topic: str = "") -> bool:
    """Route multiplication where larger ≤ 999, smaller ≤ 99, at least one
    multi-digit operand, no decimals.
    ...
```

Indsæt en NY funktion lige FØR `should_use_long_multiplication`:

```python
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


```

- [ ] **Step 4: Kør routing-tests**

```bash
cd backend && pytest tests/test_single_digit_multiplication.py::TestRouting -v
```

Forventet: `5 passed`

- [ ] **Step 5: Bekræft eksisterende long_multiplication tests stadig passerer**

```bash
cd backend && pytest tests/test_long_multiplication.py -v
```

Forventet: alle passes — vi har kun tilføjet en ny funktion, ikke ændret nogen.

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/example_generator.py backend/tests/test_single_digit_multiplication.py
git commit -m "feat: should_use_single_digit_multiplication routing detector

Mirrors should_use_long_multiplication structure: text is authoritative,
decimals reject, operand parse failure returns False. Both operands
must be 2-9 inclusive."
```

---

### Task 6: `generate_single_digit_multiplication_example` + routing wire-up

**Files:**
- Modify: `backend/app/services/example_generator.py`
- Modify: `backend/tests/test_single_digit_multiplication.py`

- [ ] **Step 1: Skriv fejlende end-to-end test**

Tilføj til `backend/tests/test_single_digit_multiplication.py`:

```python
class TestGenerateExampleEndToEnd:
    def _make_service(self):
        # Skip __init__ — det instantiérer en AI client der kræver API keys.
        # generate_single_digit_multiplication_example bruger ikke AI client.
        from app.services.example_generator import ExampleGeneratorService
        return ExampleGeneratorService.__new__(ExampleGeneratorService)

    def test_full_response_shape(self):
        """Returnér ExampleResponse-shape med korrekt visual type."""
        svc = self._make_service()
        result = svc.generate_single_digit_multiplication_example(
            assignment_text="6 × 8", language="da"
        )

        # Schema-ish checks
        assert "example_problem" in result
        assert "steps" in result
        assert "pedagogy" in result
        assert result["pedagogy"] == "concrete-first"
        assert result["example_problem"].startswith("Regn ud:")
        assert "×" in result["example_problem"]

    def test_example_uses_different_numbers(self):
        """Eksempel-tal må aldrig matche elevens — heller ikke commutative dup."""
        svc = self._make_service()
        for _ in range(20):
            result = svc.generate_single_digit_multiplication_example(
                assignment_text="6 × 8", language="da"
            )
            ex = result["example_problem"]
            # Ingen "6 × 8" eller "8 × 6" som hele expression
            assert "6 × 8" not in ex
            assert "8 × 6" not in ex

    def test_setup_step_has_correct_visual(self):
        """Første step (efter setup) bruger single_digit_array type."""
        svc = self._make_service()
        result = svc.generate_single_digit_multiplication_example(
            assignment_text="6 × 8", language="da"
        )

        first_step = result["steps"][0]
        assert first_step["visual"]["type"] == "single_digit_array"
        assert first_step["visual"]["action"] == "setup"
        assert "rows" in first_step["visual"]
        assert "cols" in first_step["visual"]

    def test_try_yours_step_has_no_visual(self):
        """Sidste step (try-yours) har visual=None."""
        svc = self._make_service()
        result = svc.generate_single_digit_multiplication_example(
            assignment_text="6 × 8", language="da"
        )

        last = result["steps"][-1]
        assert last["visual"] is None
        assert "6 × 8" in last["text"]  # refererer til elevens egne tal

    def test_step_chain_includes_setup_rows_reveal_tryyours(self):
        """Step-sekvensen indeholder alle 4 typer plus try-yours."""
        svc = self._make_service()
        result = svc.generate_single_digit_multiplication_example(
            assignment_text="6 × 8", language="da"
        )

        actions = [s.get("visual", {}).get("action") if s["visual"] else None
                   for s in result["steps"]]
        assert "setup" in actions
        assert "row" in actions
        assert "reveal" in actions
        assert None in actions  # try-yours

    def test_routing_priority_single_digit_before_long_mult(self):
        """generate_example dispatcher routes 7 × 9 til single_digit, ikke long_mult."""
        svc = self._make_service()
        result = svc.generate_example(
            assignment_type="multiplication",
            assignment_topic="multiplication",
            assignment_text="7 × 9",
            language="da",
        )
        # Visual type på første step skal være single_digit_array
        first_visual = result["steps"][0]["visual"]
        assert first_visual is not None
        assert first_visual["type"] == "single_digit_array"

    def test_routing_priority_long_mult_still_fires_for_two_digit(self):
        """7 × 19 skal stadig route til long_multiplication, ikke single_digit."""
        svc = self._make_service()
        result = svc.generate_example(
            assignment_type="multiplication",
            assignment_topic="multiplication",
            assignment_text="7 × 19",
            language="da",
        )
        first_visual = result["steps"][0]["visual"]
        assert first_visual is not None
        assert first_visual["type"] == "long_multiplication"
```

- [ ] **Step 2: Kør for at bekræfte de fejler**

```bash
cd backend && pytest tests/test_single_digit_multiplication.py::TestGenerateExampleEndToEnd -v
```

Forventet: `AttributeError: 'ExampleGeneratorService' object has no attribute 'generate_single_digit_multiplication_example'`

- [ ] **Step 3: Tilføj generate_single_digit_multiplication_example metoden**

Edit `backend/app/services/example_generator.py`. Find slutningen af `generate_long_multiplication_example` (linje ~562) og tilføj en NY metode lige efter:

```python
    def generate_single_digit_multiplication_example(self, assignment_text: str,
                                                      language: str = "da") -> dict:
        """Generate a single-digit multiplication example — fully deterministic."""
        from app.services.single_digit_multiplication import SingleDigitMultiplicationService

        logger.info("Generating single-digit multiplication example for: '%s'",
                    assignment_text)
        start = time.time()

        operands = _parse_multiplication_operands(assignment_text)
        if operands is None:
            raise ValueError(
                f"Could not parse multiplication operands from: {assignment_text!r}"
            )

        student_a, student_b = operands
        ex_a, ex_b = SingleDigitMultiplicationService.pick_example_numbers(
            student_a, student_b
        )
        steps = SingleDigitMultiplicationService.compute_steps(ex_a, ex_b)
        texts = SingleDigitMultiplicationService.generate_text(steps)

        anim_steps = []
        for i, (s, text_obj) in enumerate(zip(steps, texts)):
            action = s["step"]
            visual = {"type": "single_digit_array", "action": action}

            if action == "setup":
                visual["rows"] = s["rows"]
                visual["cols"] = s["cols"]
            elif action == "row":
                visual["row_index"] = s["row_index"]
                visual["row_value"] = s["row_value"]
                visual["cumulative"] = s["cumulative"]
            elif action == "reveal":
                visual["result"] = s["result"]

            anim_steps.append({
                "step": i + 1,
                "phase": "concrete",
                "text": text_obj["text"],
                "visual": visual,
                "audio_cue": text_obj.get("audio_cue", ""),
            })

        # try_yours: tekst-only, INGEN visual instruction
        anim_steps.append({
            "step": len(anim_steps) + 1,
            "phase": "concrete",
            "text": (
                f"Nu er det din tur — kan du regne {student_a} × {student_b}? "
                f"Skriv svaret på papir og scan."
            ),
            "visual": None,
            "audio_cue": f"Prøv selv med {student_a} gange {student_b}",
        })

        elapsed = time.time() - start
        logger.info("Generated single-digit multiplication example in %.3fs: %s × %s",
                    elapsed, ex_a, ex_b)

        return {
            "example_problem": f"Regn ud: {ex_a} × {ex_b}",
            "pedagogy": "concrete-first",
            "steps": anim_steps,
            "note": "",
        }
```

- [ ] **Step 4: Wire single-digit ind i routing-kæden i `generate_example`**

Edit `backend/app/services/example_generator.py`. Find dispatcher-blokken i `generate_example` (omkring linje 125-141):

```python
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

Erstat med (tilføj single-digit gren FØR long_multiplication):

```python
        detected_op = _detect_operation(assignment_type, assignment_text, assignment_topic)
        if detected_op and should_use_stacked(assignment_type, assignment_text, assignment_topic):
            return self.generate_stacked_example(
                assignment_type=detected_op,
                assignment_text=assignment_text,
                language=language,
            )
        if should_use_single_digit_multiplication(assignment_type, assignment_text, assignment_topic):
            return self.generate_single_digit_multiplication_example(
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

- [ ] **Step 5: Kør integration-tests**

```bash
cd backend && pytest tests/test_single_digit_multiplication.py::TestGenerateExampleEndToEnd -v
```

Forventet: `7 passed`

- [ ] **Step 6: Kør hele test-filen og long_mult tests for regressioner**

```bash
cd backend && pytest tests/test_single_digit_multiplication.py tests/test_long_multiplication.py tests/test_example_generator.py -v
```

Forventet: alle passerer.

- [ ] **Step 7: Manuel sanity check med curl**

Verificér at backend faktisk svarer fornuftigt. Først tjek at backend kører lokalt eller på Mac Mini:

```bash
# Hvis du arbejder på MacBook og backend kører på Mac Mini:
curl -sf http://192.168.1.60:8000/health
# Hvis du arbejder direkte på Mac Mini:
curl -sf http://localhost:8000/health
```

Forventet: `{"status":"ok"}`

Spring dette manuelle step over hvis backend ikke er restartet endnu — det handles i Task 10.

- [ ] **Step 8: Commit**

```bash
git add backend/app/services/example_generator.py backend/tests/test_single_digit_multiplication.py
git commit -m "feat: route single-digit multiplication to dedicated example generator

generate_single_digit_multiplication_example follows the same pattern
as generate_long_multiplication_example: pick example numbers (different
from student), compute deterministic steps, generate Danish text,
assemble animation steps with single_digit_array visual type, append
text-only try-yours.

Routing in generate_example dispatches single-digit BEFORE long_mult
in the chain — they're disjoint sets but simpler-first reads cleanly."
```

---

## Phase 3: iOS Codable migration

### Task 7: Make `AnimationStep.visual` Optional across iOS

**Files:**
- Modify: `ios/Kvante/Kvante/Models/AnimationModels.swift:111-119,132`
- Modify: `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift:265-279`
- Modify: `ios/Kvante/Kvante/Views/AnimationPlayer.swift:87-100,104-133`
- Modify: `ios/Kvante/Kvante/Views/AnimatedExplanationView.swift:135-147`
- Modify: `ios/Kvante/Kvante/Views/Chat/ChatBubble.swift:281-293`
- Modify: `ios/Kvante/Kvante/Views/Chat/InlineExampleView.swift:118-133`

Denne task er en multi-file migration. Hvert step opdaterer én fil; build forbliver brudt indtil sidste step. Commit kun helt til sidst.

- [ ] **Step 1: Opdater AnimationStep model**

Edit `ios/Kvante/Kvante/Models/AnimationModels.swift`. Find linje 106-135:

```swift
struct AnimationStep: Identifiable, Codable {
    var id: Int { step }
    let step: Int
    let phase: String
    let text: String
    let visual: VisualInstruction
    let audioCue: String

    init(step: Int, phase: String, text: String, visual: VisualInstruction, audioCue: String) {
        self.step = step
        self.phase = phase
        self.text = text
        self.visual = visual
        self.audioCue = audioCue
    }

    enum CodingKeys: String, CodingKey {
        case step, phase, text, visual
        case audioCue = "audio_cue"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        step = try container.decode(Int.self, forKey: .step)
        phase = try container.decode(String.self, forKey: .phase)
        text = try container.decode(String.self, forKey: .text)
        visual = try container.decode(VisualInstruction.self, forKey: .visual)
        audioCue = try container.decodeIfPresent(String.self, forKey: .audioCue) ?? ""
    }
}
```

Erstat med:

```swift
struct AnimationStep: Identifiable, Codable {
    var id: Int { step }
    let step: Int
    let phase: String
    let text: String
    let visual: VisualInstruction?
    let audioCue: String

    init(step: Int, phase: String, text: String, visual: VisualInstruction?, audioCue: String) {
        self.step = step
        self.phase = phase
        self.text = text
        self.visual = visual
        self.audioCue = audioCue
    }

    enum CodingKeys: String, CodingKey {
        case step, phase, text, visual
        case audioCue = "audio_cue"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        step = try container.decode(Int.self, forKey: .step)
        phase = try container.decode(String.self, forKey: .phase)
        text = try container.decode(String.self, forKey: .text)
        visual = try container.decodeIfPresent(VisualInstruction.self, forKey: .visual)
        audioCue = try container.decodeIfPresent(String.self, forKey: .audioCue) ?? ""
    }
}
```

- [ ] **Step 2: Opdater ChatViewModel cumulative-state loop**

Edit `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift`. Find linje 263-281:

```swift
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
```

Erstat med:

```swift
        for i in 0...currentExampleStepIndex {
            let s = pendingExampleSteps[i]
            guard let v = s.visual else { continue }
            if v.type == "stacked_arithmetic" {
                if v.action == "setup" {
                    gridState = GridState.from(visual: v)
                }
                gridState?.apply(visual: v)
            } else if v.type == "short_division" {
                if v.action == "setup" {
                    shortDivisionState = ShortDivisionState.from(visual: v)
                }
                shortDivisionState?.apply(visual: v)
            } else if v.type == "long_multiplication" {
                if v.action == "setup" {
                    longMultState = LongMultiplicationState.from(visual: v)
                }
                longMultState?.apply(visual: v)
            }
        }
```

- [ ] **Step 3: Opdater AnimationPlayer pauseDuration**

Edit `ios/Kvante/Kvante/Views/AnimationPlayer.swift`. Find linje 86-100:

```swift
    private func pauseDuration(for step: AnimationStep) -> Double {
        switch step.visual.type {
        case "equation": return 1.5
        case "object_collection":
            let count = step.visual.intParam("count") ?? 0
            return count > 10 ? 3.5 : 2.5
        case "array_grid": return 3.5
        case "number_line":
            let jumps = step.visual.intParam("jumps") ?? 1
            return 2.0 + Double(jumps) * 0.5
        case "stacked_arithmetic": return 2.5
        case "short_division": return 2.5
        default: return 2.5
        }
    }
```

Erstat med:

```swift
    private func pauseDuration(for step: AnimationStep) -> Double {
        guard let visual = step.visual else { return 2.5 }
        switch visual.type {
        case "equation": return 1.5
        case "object_collection":
            let count = visual.intParam("count") ?? 0
            return count > 10 ? 3.5 : 2.5
        case "array_grid": return 3.5
        case "number_line":
            let jumps = visual.intParam("jumps") ?? 1
            return 2.0 + Double(jumps) * 0.5
        case "stacked_arithmetic": return 2.5
        case "short_division": return 2.5
        default: return 2.5
        }
    }
```

- [ ] **Step 4: Opdater AnimationPlayer updateCumulativeState**

I samme fil, find linje 104-133:

```swift
    private func updateCumulativeState(for step: AnimationStep) {
        let v = step.visual
        switch (v.type, v.action) {
```

Erstat den første linje (efter funktions-signaturen) for at guard-le visual:

```swift
    private func updateCumulativeState(for step: AnimationStep) {
        guard let v = step.visual else { return }
        switch (v.type, v.action) {
```

(Resten af funktionen er uændret indtil videre — vi tilføjer single_digit_array case i Task 9.)

- [ ] **Step 5: Opdater AnimatedExplanationView**

Edit `ios/Kvante/Kvante/Views/AnimatedExplanationView.swift`. Find linje 135-147:

```swift
            // Visual component
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
            .frame(maxWidth: .infinity)
```

Erstat med:

```swift
            // Visual component (skipped for text-only steps)
            if let visual = step.visual {
                VisualComponentView(
                    visual: visual,
                    animate: animate,
                    cumulativeObjects: cumulativeObjects,
                    cumulativeCrossedOut: cumulativeCrossedOut,
                    cumulativeRows: cumulativeRows,
                    cumulativeGrouped: cumulativeGrouped,
                    cumulativeGridState: cumulativeGridState,
                    cumulativeShortDivisionState: cumulativeShortDivisionState,
                    cumulativeLongMultiplicationState: cumulativeLongMultiplicationState
                )
                .frame(maxWidth: .infinity)
            }
```

- [ ] **Step 6: Opdater ChatBubble.swift**

Edit `ios/Kvante/Kvante/Views/Chat/ChatBubble.swift`. Find linje 281-293:

```swift
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
```

Erstat med:

```swift
            // Visual component (skipped for text-only steps)
            if let visual = step.visual {
                VisualComponentView(
                    visual: visual,
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
```

- [ ] **Step 7: Opdater InlineExampleView.swift**

Edit `ios/Kvante/Kvante/Views/Chat/InlineExampleView.swift`. Find linje 118-133:

```swift
            // Expanded: show visual
            if isExpanded {
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
                .frame(maxWidth: .infinity)
                .padding(.leading, 34)
            }
```

Erstat med:

```swift
            // Expanded: show visual (skipped for text-only steps)
            if isExpanded, let visual = step.visual {
                VisualComponentView(
                    visual: visual,
                    animate: true,
                    cumulativeObjects: player.cumulativeObjects,
                    cumulativeCrossedOut: player.cumulativeCrossedOut,
                    cumulativeRows: player.cumulativeRows,
                    cumulativeGrouped: player.cumulativeGrouped,
                    cumulativeGridState: player.cumulativeGridState,
                    cumulativeShortDivisionState: player.cumulativeShortDivisionState,
                    cumulativeLongMultiplicationState: player.cumulativeLongMultiplicationState
                )
                .frame(maxWidth: .infinity)
                .padding(.leading, 34)
            }
```

- [ ] **Step 8: Bekræft at Xcode bygger uden warnings**

Åbn `ios/Kvante/Kvante.xcodeproj` i Xcode og kør **Cmd+B** (Build). Forventet: clean build, ingen errors og ingen Swift 6 concurrency warnings i de ændrede filer.

Hvis der er compile errors, scan output for `step.visual` og se om der er en call-site jeg har missed. Grep for konfirmation:

```bash
cd /Users/olsen/code/Kvante && grep -rn "step\.visual\." ios/Kvante/Kvante/ --include="*.swift"
```

Skal kun returnere referencer der allerede er guard-let'et eller bruger den nye lokale `visual`-variable.

- [ ] **Step 9: Commit**

```bash
git add ios/Kvante/Kvante/Models/AnimationModels.swift \
        ios/Kvante/Kvante/ViewModels/ChatViewModel.swift \
        ios/Kvante/Kvante/Views/AnimationPlayer.swift \
        ios/Kvante/Kvante/Views/AnimatedExplanationView.swift \
        ios/Kvante/Kvante/Views/Chat/ChatBubble.swift \
        ios/Kvante/Kvante/Views/Chat/InlineExampleView.swift
git commit -m "refactor: AnimationStep.visual is now Optional on iOS

Mirrors the backend schema change. Try-yours steps for the upcoming
single-digit multiplication feature need to render as text-only chat
bubbles without a visual instruction. All call-sites that read
step.visual now guard-let or if-let unwrap. VisualComponentView
itself keeps its non-optional contract — it's only invoked when a
visual exists."
```

---

## Phase 4: iOS visual component

### Task 8: `ArrayGridState` + `ArrayGridCleanView` + `#Preview` blocks

**Files:**
- Create: `ios/Kvante/Kvante/Views/VisualComponents/ArrayGridCleanView.swift`

- [ ] **Step 1: Opret view-filen med state struct og view**

Opret `ios/Kvante/Kvante/Views/VisualComponents/ArrayGridCleanView.swift`:

```swift
import SwiftUI

struct ArrayGridState {
    let rows: Int          // a (multiplikand, antal rækker)
    let cols: Int          // b (multiplikator, antal pr. række)

    var revealedRows: Int           // 0...rows
    var currentCumulative: Int?     // running total, nil før første row
    var showResult: Bool
    var resultText: String?

    init(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
        self.revealedRows = 0
        self.currentCumulative = nil
        self.showResult = false
        self.resultText = nil
    }

    static func from(visual: VisualInstruction) -> ArrayGridState {
        let rows = visual.intParam("rows") ?? 0
        let cols = visual.intParam("cols") ?? 0
        return ArrayGridState(rows: rows, cols: cols)
    }

    mutating func apply(visual: VisualInstruction) {
        switch visual.action {
        case "setup":
            // No-op: AnimationPlayer reassigns the entire state via from(visual:)
            // when it sees a setup action.
            break
        case "row":
            revealedRows = (visual.intParam("row_index") ?? 0) + 1
            currentCumulative = visual.intParam("cumulative")
        case "reveal":
            revealedRows = rows
            showResult = true
            if let r = visual.intParam("result") {
                resultText = String(r)
            }
        default:
            break
        }
    }
}

struct ArrayGridCleanView: View {
    let visual: VisualInstruction
    let animate: Bool
    let state: ArrayGridState

    private let cellSize: CGFloat = 24
    private let cellSpacing: CGFloat = 4

    var body: some View {
        VStack(spacing: 12) {
            // The grid — a × b cells with row-by-row reveal
            VStack(spacing: cellSpacing) {
                ForEach(0..<state.rows, id: \.self) { row in
                    HStack(spacing: cellSpacing) {
                        ForEach(0..<state.cols, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(KvanteTheme.Colors.primary)
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                    .opacity(row < state.revealedRows ? 1 : 0)
                    .scaleEffect(row < state.revealedRows ? 1 : 0.6)
                    .animation(.spring(duration: 0.35), value: state.revealedRows)
                }
            }

            // Running total under the grid (only when at least one row is visible
            // and we haven't yet shown the final result)
            if let cum = state.currentCumulative, !state.showResult {
                Text("\(cum)")
                    .font(.custom("Marker Felt", size: 22))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .transition(.opacity)
            }

            // Final result with celebration treatment
            if state.showResult, let result = state.resultText {
                Text("\(state.rows) × \(state.cols) = \(result)")
                    .font(.custom("Marker Felt", size: 24))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .scaleEffect(1.05)
                    .shadow(color: .teal.opacity(0.6), radius: 8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(16)
    }
}

#Preview("Setup (6×8, ingen rækker afsløret)") {
    let state = ArrayGridState(rows: 6, cols: 8)
    return ArrayGridCleanView(
        visual: VisualInstruction.make(type: "single_digit_array", action: "setup"),
        animate: false,
        state: state
    )
    .padding()
}

#Preview("Mid-state (6×8, 3 rækker, cum=24)") {
    var state = ArrayGridState(rows: 6, cols: 8)
    state.revealedRows = 3
    state.currentCumulative = 24
    return ArrayGridCleanView(
        visual: VisualInstruction.make(type: "single_digit_array", action: "row"),
        animate: false,
        state: state
    )
    .padding()
}

#Preview("Final state (6×8 = 48)") {
    var state = ArrayGridState(rows: 6, cols: 8)
    state.revealedRows = 6
    state.currentCumulative = 48
    state.showResult = true
    state.resultText = "48"
    return ArrayGridCleanView(
        visual: VisualInstruction.make(type: "single_digit_array", action: "reveal"),
        animate: false,
        state: state
    )
    .padding()
}

#Preview("Worst case 9×9 = 81 (iPad)") {
    var state = ArrayGridState(rows: 9, cols: 9)
    state.revealedRows = 9
    state.currentCumulative = 81
    state.showResult = true
    state.resultText = "81"
    return ArrayGridCleanView(
        visual: VisualInstruction.make(type: "single_digit_array", action: "reveal"),
        animate: false,
        state: state
    )
    .padding()
}

#Preview("Worst case 9×9 = 81 (iPhone SE)", traits: .fixedLayout(width: 320, height: 568)) {
    var state = ArrayGridState(rows: 9, cols: 9)
    state.revealedRows = 9
    state.currentCumulative = 81
    state.showResult = true
    state.resultText = "81"
    return ArrayGridCleanView(
        visual: VisualInstruction.make(type: "single_digit_array", action: "reveal"),
        animate: false,
        state: state
    )
    .padding()
}
```

- [ ] **Step 2: Bekræft at Xcode bygger filen**

I Xcode: Cmd+B (Build). Filen skal compile uden errors.

Hvis `VisualInstruction.make` ikke eksisterer, tjek hvordan eksisterende #Preview blocks i andre visual components opretter en VisualInstruction (f.eks. `LongMultiplicationView.swift:340-350`):

```bash
grep -n "VisualInstruction.make\|VisualInstruction(" ios/Kvante/Kvante/Views/VisualComponents/LongMultiplicationView.swift
```

Hvis pattern er anderledes, tilpas previews. (LongMultiplicationView.swift bruger `VisualInstruction.make(type:action:)` i sine previews — det burde virke.)

- [ ] **Step 3: Verificér previews i Xcode preview canvas**

Åbn `ArrayGridCleanView.swift` i Xcode editor. Klik "Resume" på Preview canvas. Bekræft visuelt:

1. **Setup (6×8)**: Grid er tomt, ingen celler vises, ingen running total
2. **Mid-state (6×8, 3 rækker)**: De første 3 rækker er teal-kvadrater, de næste 3 er usynlige, "24" vises under
3. **Final state (6×8 = 48)**: Alle 6 rækker fyldt, "6 × 8 = 48" vises med shadow
4. **Worst case 9×9 (iPad)**: 81 celler i et kvadrat, "9 × 9 = 81" — passer komfortabelt
5. **Worst case 9×9 (iPhone SE)**: 81 celler i et kvadrat, INGEN horisontal scroll — det er det kritiske check. Hvis det ikke passer på 320pt, reducer cellSize fra 24 til 20 og prøv igen.

- [ ] **Step 4: Hvis cellSize måtte reduceres for iPhone SE — opdater spec og fil**

Hvis `cellSize: CGFloat = 24` ikke passer på iPhone SE (320pt bred), reducer:

```swift
private let cellSize: CGFloat = 20
```

(Beregning: 9 × 20 + 8 × 4 + padding 32 = 180 + 32 + 32 = 244pt — passer let i 320pt.)

Genkør preview-step 3.

- [ ] **Step 5: Commit**

```bash
git add ios/Kvante/Kvante/Views/VisualComponents/ArrayGridCleanView.swift
git commit -m "feat: ArrayGridCleanView for single-digit multiplication

ArrayGridState struct + SwiftUI view rendering an a × b rectangle
of teal squares with row-by-row reveal animation, running total
under the grid, and celebration treatment on reveal.

Includes 5 #Preview blocks: setup, mid-state, final, 9×9 worst
case on iPad, and 9×9 worst case fixed-layout iPhone SE width."
```

---

### Task 9: VisualComponentView routing + AnimationPlayer cumulative state

**Files:**
- Modify: `ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift`
- Modify: `ios/Kvante/Kvante/Views/AnimationPlayer.swift`
- Modify: `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift`
- Modify: `ios/Kvante/Kvante/Views/Chat/ChatBubble.swift`
- Modify: `ios/Kvante/Kvante/Views/AnimatedExplanationView.swift`
- Modify: `ios/Kvante/Kvante/Views/Chat/InlineExampleView.swift`

Denne task tråder `cumulativeArrayGridState` gennem alle de samme call-sites som bærer de andre cumulative states. Build forbliver brudt indtil sidste step.

- [ ] **Step 1: Tilføj cumulativeArrayGridState parameter til VisualComponentView**

Edit `ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift`. Hele filen:

```swift
import SwiftUI

/// Routes a VisualInstruction to the correct visual component.
/// Falls back to plain text for unknown types.
struct VisualComponentView: View {
    let visual: VisualInstruction
    let animate: Bool
    let cumulativeObjects: Int
    let cumulativeCrossedOut: Int
    let cumulativeRows: Int
    let cumulativeGrouped: Int
    let cumulativeGridState: GridState?
    let cumulativeShortDivisionState: ShortDivisionState?
    let cumulativeLongMultiplicationState: LongMultiplicationState?
    let cumulativeArrayGridState: ArrayGridState?

    init(visual: VisualInstruction, animate: Bool,
         cumulativeObjects: Int = 0, cumulativeCrossedOut: Int = 0,
         cumulativeRows: Int = 2, cumulativeGrouped: Int = 0,
         cumulativeGridState: GridState? = nil,
         cumulativeShortDivisionState: ShortDivisionState? = nil,
         cumulativeLongMultiplicationState: LongMultiplicationState? = nil,
         cumulativeArrayGridState: ArrayGridState? = nil) {
        self.visual = visual
        self.animate = animate
        self.cumulativeObjects = cumulativeObjects
        self.cumulativeCrossedOut = cumulativeCrossedOut
        self.cumulativeRows = cumulativeRows
        self.cumulativeGrouped = cumulativeGrouped
        self.cumulativeGridState = cumulativeGridState
        self.cumulativeShortDivisionState = cumulativeShortDivisionState
        self.cumulativeLongMultiplicationState = cumulativeLongMultiplicationState
        self.cumulativeArrayGridState = cumulativeArrayGridState
    }

    var body: some View {
        switch visual.type {
        case "equation":
            EquationVisualView(visual: visual, animate: animate)
        case "object_collection":
            ObjectCollectionVisualView(
                visual: visual, animate: animate,
                cumulativeObjects: cumulativeObjects,
                cumulativeCrossedOut: cumulativeCrossedOut,
                cumulativeRows: cumulativeRows
            )
        case "number_line":
            NumberLineVisualView(visual: visual, animate: animate)
        case "array_grid":
            ArrayGridVisualView(visual: visual, animate: animate)
        case "grouping":
            GroupingVisualView(visual: visual, animate: animate, cumulativeGrouped: cumulativeGrouped)
        case "pie_chart":
            PieChartVisualView(visual: visual, animate: animate)
        case "bar_model":
            BarModelVisualView(visual: visual, animate: animate)
        case "coordinate_grid":
            CoordinateGridVisualView(visual: visual, animate: animate)
        case "stacked_arithmetic":
            if let state = cumulativeGridState {
                StackedArithmeticView(visual: visual, animate: animate, gridState: state)
            } else {
                StackedArithmeticView(visual: visual, animate: animate, gridState: GridState.from(visual: visual))
            }
        case "short_division":
            if let state = cumulativeShortDivisionState {
                ShortDivisionView(visual: visual, animate: animate, state: state)
            } else {
                ShortDivisionView(visual: visual, animate: animate,
                                  state: ShortDivisionState.from(visual: visual))
            }
        case "long_multiplication":
            if let state = cumulativeLongMultiplicationState {
                LongMultiplicationView(visual: visual, animate: animate, state: state)
            } else {
                LongMultiplicationView(visual: visual, animate: animate,
                                       state: LongMultiplicationState.from(visual: visual))
            }
        case "single_digit_array":
            if let state = cumulativeArrayGridState {
                ArrayGridCleanView(visual: visual, animate: animate, state: state)
            } else {
                ArrayGridCleanView(visual: visual, animate: animate,
                                   state: ArrayGridState.from(visual: visual))
            }
        default:
            // Fallback: unknown visual type — show nothing (text is shown by parent)
            EmptyView()
        }
    }
}
```

- [ ] **Step 2: Tilføj cumulativeArrayGridState til AnimationPlayer**

Edit `ios/Kvante/Kvante/Views/AnimationPlayer.swift`.

**Sub-step 2a:** Tilføj property efter `cumulativeLongMultiplicationState` (linje 17):

```swift
    private(set) var cumulativeLongMultiplicationState: LongMultiplicationState?
    private(set) var cumulativeArrayGridState: ArrayGridState?
```

**Sub-step 2b:** Tilføj reset i `reset()` (linje 55-66):

```swift
    func reset() {
        currentStepIndex = 0
        cumulativeObjects = 0
        cumulativeCrossedOut = 0
        cumulativeRows = 2
        cumulativeGrouped = 0
        cumulativeGridState = nil
        cumulativeShortDivisionState = nil
        cumulativeLongMultiplicationState = nil
        cumulativeArrayGridState = nil
        isPlaying = false
        autoAdvanceTask?.cancel()
    }
```

**Sub-step 2c:** Tilføj case i `pauseDuration` switch (linje 86-100, efter `case "short_division"`):

```swift
        case "stacked_arithmetic": return 2.5
        case "short_division": return 2.5
        case "single_digit_array": return 2.0
        default: return 2.5
```

**Sub-step 2d:** Tilføj case i `updateCumulativeState` switch (linje 104-133, efter `case ("long_multiplication", _)`):

```swift
        case ("long_multiplication", _):
            if v.action == "setup" {
                cumulativeLongMultiplicationState = LongMultiplicationState.from(visual: v)
            }
            cumulativeLongMultiplicationState?.apply(visual: v)
        case ("single_digit_array", _):
            if v.action == "setup" {
                cumulativeArrayGridState = ArrayGridState.from(visual: v)
            }
            cumulativeArrayGridState?.apply(visual: v)
        default: break
```

**Sub-step 2e:** Tilføj reset i `recalculateCumulativeState` (linje 135-145):

```swift
    private func recalculateCumulativeState() {
        cumulativeObjects = 0
        cumulativeCrossedOut = 0
        cumulativeRows = 2
        cumulativeGrouped = 0
        cumulativeShortDivisionState = nil
        cumulativeLongMultiplicationState = nil
        cumulativeArrayGridState = nil
        for i in 0..<currentStepIndex {
            updateCumulativeState(for: steps[i])
        }
    }
```

- [ ] **Step 3: Træd cumulativeArrayGridState gennem ChatViewModel**

Edit `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift`. Find linje 259-292 (cumulative-state loopet og messages.append-kaldet).

Find:

```swift
        // Build cumulative state for stacked arithmetic, short division, and long multiplication
        var gridState: GridState? = nil
        var shortDivisionState: ShortDivisionState? = nil
        var longMultState: LongMultiplicationState? = nil
        for i in 0...currentExampleStepIndex {
            let s = pendingExampleSteps[i]
            guard let v = s.visual else { continue }
            if v.type == "stacked_arithmetic" {
                if v.action == "setup" {
                    gridState = GridState.from(visual: v)
                }
                gridState?.apply(visual: v)
            } else if v.type == "short_division" {
                if v.action == "setup" {
                    shortDivisionState = ShortDivisionState.from(visual: v)
                }
                shortDivisionState?.apply(visual: v)
            } else if v.type == "long_multiplication" {
                if v.action == "setup" {
                    longMultState = LongMultiplicationState.from(visual: v)
                }
                longMultState?.apply(visual: v)
            }
        }
```

Erstat med (tilføj arrayGridState branch):

```swift
        // Build cumulative state for stacked arithmetic, short division,
        // long multiplication, and single-digit array.
        var gridState: GridState? = nil
        var shortDivisionState: ShortDivisionState? = nil
        var longMultState: LongMultiplicationState? = nil
        var arrayGridState: ArrayGridState? = nil
        for i in 0...currentExampleStepIndex {
            let s = pendingExampleSteps[i]
            guard let v = s.visual else { continue }
            if v.type == "stacked_arithmetic" {
                if v.action == "setup" {
                    gridState = GridState.from(visual: v)
                }
                gridState?.apply(visual: v)
            } else if v.type == "short_division" {
                if v.action == "setup" {
                    shortDivisionState = ShortDivisionState.from(visual: v)
                }
                shortDivisionState?.apply(visual: v)
            } else if v.type == "long_multiplication" {
                if v.action == "setup" {
                    longMultState = LongMultiplicationState.from(visual: v)
                }
                longMultState?.apply(visual: v)
            } else if v.type == "single_digit_array" {
                if v.action == "setup" {
                    arrayGridState = ArrayGridState.from(visual: v)
                }
                arrayGridState?.apply(visual: v)
            }
        }
```

Find derefter `messages.append(ChatMessage(...))`-kaldet (linje 287-291):

```swift
        messages.append(ChatMessage(
            sender: .kvante,
            content: .exampleStep(step, currentExampleStepIndex + 1, pendingExampleSteps.count,
                                  gridState, shortDivisionState, longMultState),
            actions: chips
        ))
```

`ChatMessage.content.exampleStep(...)` skal udvides for at bære `arrayGridState`. Først find ChatMessage definitionen:

```bash
grep -n "exampleStep" ios/Kvante/Kvante/Models/ChatMessage.swift
```

Forventet at ChatMessage har en `case exampleStep(AnimationStep, Int, Int, GridState?, ShortDivisionState?, LongMultiplicationState?)`. Vi udvider den med `, ArrayGridState?` til sidst.

Edit `ios/Kvante/Kvante/Models/ChatMessage.swift` for at tilføje den nye associated value:

Find linjen som matcher (omkring linje 30 — bekræft via grep):

```swift
case exampleStep(AnimationStep, Int, Int, GridState?, ShortDivisionState?, LongMultiplicationState?)
```

Erstat med:

```swift
case exampleStep(AnimationStep, Int, Int, GridState?, ShortDivisionState?, LongMultiplicationState?, ArrayGridState?)
```

Tilbage i `ChatViewModel.swift`, opdater messages.append-kaldet:

```swift
        messages.append(ChatMessage(
            sender: .kvante,
            content: .exampleStep(step, currentExampleStepIndex + 1, pendingExampleSteps.count,
                                  gridState, shortDivisionState, longMultState, arrayGridState),
            actions: chips
        ))
```

- [ ] **Step 4: Opdater ChatBubble for at læse arrayGridState fra exampleStep case**

Edit `ios/Kvante/Kvante/Views/Chat/ChatBubble.swift`. Find hvor `.exampleStep` pattern-matches (sandsynligvis omkring linje 250-280). Brug grep:

```bash
grep -n "case .exampleStep\|case let .exampleStep" ios/Kvante/Kvante/Views/Chat/ChatBubble.swift
```

Find pattern-match-linjen, fx:

```swift
case let .exampleStep(step, stepNumber, total, gridState, shortDivisionState, longMultiplicationState):
```

Erstat med:

```swift
case let .exampleStep(step, stepNumber, total, gridState, shortDivisionState, longMultiplicationState, arrayGridState):
```

Find derefter VisualComponentView-kaldet i samme `case` (vi opdaterede det i Task 7 til at if-let'e visual). Find:

```swift
            // Visual component (skipped for text-only steps)
            if let visual = step.visual {
                VisualComponentView(
                    visual: visual,
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
```

Erstat med:

```swift
            // Visual component (skipped for text-only steps)
            if let visual = step.visual {
                VisualComponentView(
                    visual: visual,
                    animate: true,
                    cumulativeObjects: 0,
                    cumulativeCrossedOut: 0,
                    cumulativeRows: 2,
                    cumulativeGrouped: 0,
                    cumulativeGridState: gridState,
                    cumulativeShortDivisionState: shortDivisionState,
                    cumulativeLongMultiplicationState: longMultiplicationState,
                    cumulativeArrayGridState: arrayGridState
                )
                .frame(maxWidth: .infinity)
            }
```

- [ ] **Step 5: Opdater AnimatedExplanationView for at sende cumulativeArrayGridState**

Edit `ios/Kvante/Kvante/Views/AnimatedExplanationView.swift`. Find VisualComponentView-kaldet (vi har allerede if-let'et det i Task 7):

```swift
            if let visual = step.visual {
                VisualComponentView(
                    visual: visual,
                    animate: animate,
                    cumulativeObjects: cumulativeObjects,
                    cumulativeCrossedOut: cumulativeCrossedOut,
                    cumulativeRows: cumulativeRows,
                    cumulativeGrouped: cumulativeGrouped,
                    cumulativeGridState: cumulativeGridState,
                    cumulativeShortDivisionState: cumulativeShortDivisionState,
                    cumulativeLongMultiplicationState: cumulativeLongMultiplicationState
                )
                .frame(maxWidth: .infinity)
            }
```

Vi skal tilføje `cumulativeArrayGridState`. Den eksisterer ikke som property på `AnimatedExplanationView` endnu — vi skal også tilføje den. Find toppen af struct'en:

```bash
grep -n "cumulativeLongMultiplicationState\|let cumulative" ios/Kvante/Kvante/Views/AnimatedExplanationView.swift
```

Find property-listen (sandsynligvis omkring linje 10-30) og tilføj:

```swift
    let cumulativeArrayGridState: ArrayGridState?
```

… umiddelbart efter `cumulativeLongMultiplicationState`. Hvis init-signaturen tager disse explicit, opdater den til at acceptere den nye parameter med default `nil`.

Opdater så VisualComponentView-kaldet:

```swift
            if let visual = step.visual {
                VisualComponentView(
                    visual: visual,
                    animate: animate,
                    cumulativeObjects: cumulativeObjects,
                    cumulativeCrossedOut: cumulativeCrossedOut,
                    cumulativeRows: cumulativeRows,
                    cumulativeGrouped: cumulativeGrouped,
                    cumulativeGridState: cumulativeGridState,
                    cumulativeShortDivisionState: cumulativeShortDivisionState,
                    cumulativeLongMultiplicationState: cumulativeLongMultiplicationState,
                    cumulativeArrayGridState: cumulativeArrayGridState
                )
                .frame(maxWidth: .infinity)
            }
```

- [ ] **Step 6: Opdater InlineExampleView for at sende player.cumulativeArrayGridState**

Edit `ios/Kvante/Kvante/Views/Chat/InlineExampleView.swift`. Find VisualComponentView-kaldet (vi har allerede if-let'et det i Task 7):

```swift
            if isExpanded, let visual = step.visual {
                VisualComponentView(
                    visual: visual,
                    animate: true,
                    cumulativeObjects: player.cumulativeObjects,
                    cumulativeCrossedOut: player.cumulativeCrossedOut,
                    cumulativeRows: player.cumulativeRows,
                    cumulativeGrouped: player.cumulativeGrouped,
                    cumulativeGridState: player.cumulativeGridState,
                    cumulativeShortDivisionState: player.cumulativeShortDivisionState,
                    cumulativeLongMultiplicationState: player.cumulativeLongMultiplicationState
                )
                .frame(maxWidth: .infinity)
                .padding(.leading, 34)
            }
```

Erstat med:

```swift
            if isExpanded, let visual = step.visual {
                VisualComponentView(
                    visual: visual,
                    animate: true,
                    cumulativeObjects: player.cumulativeObjects,
                    cumulativeCrossedOut: player.cumulativeCrossedOut,
                    cumulativeRows: player.cumulativeRows,
                    cumulativeGrouped: player.cumulativeGrouped,
                    cumulativeGridState: player.cumulativeGridState,
                    cumulativeShortDivisionState: player.cumulativeShortDivisionState,
                    cumulativeLongMultiplicationState: player.cumulativeLongMultiplicationState,
                    cumulativeArrayGridState: player.cumulativeArrayGridState
                )
                .frame(maxWidth: .infinity)
                .padding(.leading, 34)
            }
```

- [ ] **Step 7: Build i Xcode**

Cmd+B i Xcode. Forventet: clean build, ingen errors. Hvis der er compile errors:

```bash
cd /Users/olsen/code/Kvante && grep -rn "cumulativeArrayGridState\|exampleStep(" ios/Kvante/Kvante --include="*.swift"
```

Verificér at hver call-site har samme antal arguments som case'en accepterer.

- [ ] **Step 8: Genkør #Preview blocks i Xcode**

I `ArrayGridCleanView.swift` editor: bekræft at alle 5 previews stadig renderer korrekt (især iPhone SE worst case).

- [ ] **Step 9: Commit**

```bash
git add ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift \
        ios/Kvante/Kvante/Views/AnimationPlayer.swift \
        ios/Kvante/Kvante/ViewModels/ChatViewModel.swift \
        ios/Kvante/Kvante/Models/ChatMessage.swift \
        ios/Kvante/Kvante/Views/Chat/ChatBubble.swift \
        ios/Kvante/Kvante/Views/AnimatedExplanationView.swift \
        ios/Kvante/Kvante/Views/Chat/InlineExampleView.swift
git commit -m "feat: thread cumulativeArrayGridState through iOS render path

VisualComponentView routes single_digit_array to ArrayGridCleanView,
AnimationPlayer accumulates ArrayGridState parallel to the existing
LongMultiplicationState/ShortDivisionState/GridState, and the chat
message exampleStep case carries it down to ChatBubble. Pause
duration for single_digit_array is 2.0s — slightly faster than the
2.5s default to keep skip-counting cadence brisk."
```

---

## Phase 5: End-to-end verification

### Task 10: Manual smoke test

**Files:** None (manual verification)

- [ ] **Step 1: Push backend ændringer til Mac Mini**

```bash
cd /Users/olsen/code/Kvante
./scripts/deploy.sh
```

Forventet: deploy fuldfører uden fejl. Backend genstarter automatisk via uvicorn `--reload`.

- [ ] **Step 2: Verificér backend health**

```bash
curl -sf http://192.168.1.60:8000/health
```

Forventet: `{"status":"ok"}`

- [ ] **Step 3: Manuelt teste single-digit example endpoint**

Find en eksisterende session-id og assignment-id i seed_data, eller opret en hurtig test via curl. Først tjek hvilke endpoints der findes:

```bash
grep -n "@router.post\|@router.get" backend/app/routers/assignments.py | head -10
```

Brug det rette example-endpoint (typisk `/sessions/{session_id}/assignments/{assignment_id}/example`). Erstat IDs med faktiske værdier:

```bash
# Find session/assignment-id i sqlite på Mac Mini:
ssh oleserver@macmini4 "sqlite3 ~/Kvante/backend/kvante.db 'SELECT id, text FROM assignments WHERE text LIKE \"%×%\" LIMIT 5;'"
```

Vælg en assignment hvor text er på formen `7 × 9` (eller lignende 2-9 × 2-9 case). Kald derefter example-endpoint:

```bash
curl -sf -X POST http://192.168.1.60:8000/sessions/<session_id>/assignments/<assignment_id>/example | python3 -m json.tool
```

Forventet output: JSON med `example_problem` der IKKE matcher elevens tal, og `steps` array hvor:
- Første step har `visual.type == "single_digit_array"` og `visual.action == "setup"`
- Mellem-steps har `visual.action == "row"` med stigende `cumulative`
- Næstsidste step har `visual.action == "reveal"` med `result`
- Sidste step har `visual: null` og text refererer til elevens egne tal

- [ ] **Step 4: Tjek backend log for evt. fejl**

```bash
ssh oleserver@macmini4 "tail -30 ~/Library/Logs/Kvante/kvante.log"
```

Skal indeholde linjer som:
```
INFO:app.services.example_generator:Generating single-digit multiplication example for: '7 × 9'
INFO:app.services.example_generator:Generated single-digit multiplication example in 0.001s: 6 × 8
```

(Eksempel-tallene varierer pga. random pick.)

- [ ] **Step 5: Test på iPad Simulator (Xcode)**

I Xcode: vælg iPad-simulator, kør appen (Cmd+R). I appen:

1. Naviger til en session med en multiplikations-opgave (2-9 × 2-9)
2. Vælg opgaven og bed om eksempel ("Vis et eksempel" eller tilsvarende handling)
3. Verificér at chatten viser:
   - Setup-bobble med tom-stand grid og dansk text
   - Række-bobler én ad gangen med voksende grid og running total
   - Reveal-bobble med slutresultat og celebration
   - Try-yours-bobble som ren tekst (ingen visual) der refererer til elevens egne tal
4. Verificér at "Næste trin →" chips fungerer mellem steps
5. Verificér at "Tilbage" eller scroll-up viser tidligere bobler korrekt med deres rette grid-tilstand (cumulative state-threading virker)

- [ ] **Step 6: Test scan-svar end-to-end**

På papir, skriv det korrekte svar (fx `63` for `7 × 9`). Brug iPad-app til at scanne svaret med kameraet.

Forventet:
- OCR læser tallet korrekt (Apple OCR er god til single-tal)
- Feedback genereres normalt
- Korrekt svar trigger celebration-ros
- "via Vision" label vises IKKE (vi bruger Apple OCR, ikke backend Vision)

Hvis OCR fejler, tjek at submission-routing IKKE går gennem `should_use_vision_ocr()`. Den eksisterende default-path skal håndtere det.

- [ ] **Step 7: Verificér long_multiplication regression**

I samme app-session, naviger til en multiplikations-opgave med en operand ≥ 10 (fx `7 × 19` eller `124 × 13`). Bed om eksempel og bekræft at det stadig bruger long_multiplication-visualet (tærskel-rækker, kolonne-narration osv.) — ikke single-digit.

- [ ] **Step 8: Final commit (kun hvis fixes blev nødvendige under smoke test)**

Hvis ingen ændringer var nødvendige, spring dette over. Ellers commit eventuelle bugfix:

```bash
git add <relevant filer>
git commit -m "fix: <specific issue found in smoke test>"
```

- [ ] **Step 9: Opdater TODO.md og memory**

Edit `/Users/olsen/code/Kvante/TODO.md`. Find sektionen "Næste features (prioriteret)" og flyt:

```markdown
### 2. Single-digit multiplikation (array/areal-model)
9 × 7 og lignende single×single hører ikke til long multiplication...
```

… til "Gennemført" sektionen som:

```markdown
- [x] **Single-digit multiplikation (areal-model)** — Ny `SingleDigitMultiplicationService`, `ArrayGridCleanView` med fyldte teal-kvadrater i a×b grid, række-for-række reveal med skip-counting, hybrid "+ n = total" boble-narration, scope 2-9 × 2-9, operand-rækkefølge bevares (7×9 ≠ 9×7 visuelt), try-yours som ren tekst, schema-migration: `AnimationStep.visual` er nu Optional. Apple OCR håndterer single-tal submissions.
```

Edit også `/Users/olsen/.claude/projects/-Users-olsen-code-Kvante/memory/project_next_features.md` til at flytte single-digit multiplikation fra "NÆSTE" sektionen til "DONE".

```bash
git add TODO.md
git commit -m "docs: mark single-digit multiplication as done

Closes the area-model feature shipped through this branch. Sequential
narration animation for long multiplication and AI fejlanalyse remain
the next priorities."
```

(Memory-filen er udenfor repo så committes ikke i samme commit.)

---

## Self-review checklist

Plan vs. spec coverage — alle de centrale designbeslutninger fra spec'en er dækket:

| Spec sektion | Plan task |
|---|---|
| 1. Cell-stil (fyldte kvadrater) | Task 8 — `RoundedRectangle.fill(KvanteTheme.Colors.primary)` |
| 2. Buildup række for række | Task 1 (compute_steps), Task 8 (revealedRows opacity/scale) |
| 3. Try-yours kun tekst | Task 6 (visual: None), Task 7 (if-let i alle call-sites) |
| 4. Multi-bobble narration | Task 1 (1 step per row) |
| 5. Hybrid ordlyd "+ n = total" | Task 3 (generate_text) |
| 6. Scope 2-9 × 2-9 | Task 1 (assert), Task 5 (router) |
| 7. Operand-rækkefølge bevares | Task 1 (test_operand_order_preserved), Task 2 (test_does_not_normalize) |
| 8. Bro til lang multiplikation | Out of scope (spec sektion 8) — ingen task |
| 9. OCR-path Apple | Task 10 step 6 (verifikation) — ingen kode-ændring |
| Backend service contract | Tasks 1, 2, 3 |
| Visual instructions JSON | Task 6 |
| iOS visual component | Task 8 |
| VisualComponentView routing | Task 9 step 1 |
| AnimationPlayer 5 ændringer | Task 9 step 2 (5 sub-steps) |
| Routing detector | Task 5 |
| Routing wire-up | Task 6 step 4 |
| Schema migration backend | Task 4 |
| Schema migration iOS | Task 7 |
| Edge cases (scope asserts, commutative dup) | Tasks 1, 2 |
| Test-strategi (14 service + routing + integration) | Tasks 1-3, 5, 6 |
| iPhone SE preview | Task 8 step 1 (5. preview block) |
| Acceptance criteria | Task 10 dækker alle bullet-points |

Ingen placeholdere. Type-konsistens: `ArrayGridState` bruges samme måde overalt; `cumulativeArrayGridState` er det konsistente parameter-navn på iOS-call-sites; `single_digit_array` er det konsistente visual type-string både backend og iOS; `compute_steps`/`pick_example_numbers`/`generate_text` matcher præcis spec'ens metode-signaturer.
