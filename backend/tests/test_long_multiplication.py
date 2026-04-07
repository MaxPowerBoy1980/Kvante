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
        # 6×4=24 (carry 2 used by 0×4+2=2 in tens column → over the '0')
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

    def test_partial_product_walks_columns_by_name(self):
        """Each multiplicand column is named in the narration."""
        steps, mental = LongMultiplicationService.compute_steps(206, 14)
        texts = LongMultiplicationService.generate_text(steps, mental)
        partial1_text = texts[1]["text"]
        # 3-digit multiplicand → ener / tier / hundreder all mentioned
        assert "enerne" in partial1_text
        assert "tierne" in partial1_text
        assert "hundrederne" in partial1_text
        # Carry pickup is verbalised
        assert "husker" in partial1_text

    def test_leftover_carry_reaches_new_column(self):
        """When the last column produces a carry, narration says where it lands."""
        # 24 × 7 = 168: tens column gives 2×7+2=16; the leading 1 becomes hundreds
        steps, mental = LongMultiplicationService.compute_steps(24, 7)
        texts = LongMultiplicationService.generate_text(steps, mental)
        partial_text = texts[1]["text"]
        # The narration should explicitly route the leftover carry into hundreder
        assert "hundrederne" in partial_text

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


class TestGenerateExampleEndToEnd:
    def _make_service(self):
        # Skip __init__ — it instantiates an AI client which needs API keys.
        # generate_long_multiplication_example doesn't use the AI client at all.
        from app.services.example_generator import ExampleGeneratorService
        return ExampleGeneratorService.__new__(ExampleGeneratorService)

    def test_generates_full_response(self):
        svc = self._make_service()
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
        svc = self._make_service()
        for _ in range(30):
            result = svc.generate_long_multiplication_example("Regn 14 × 206", language="da")
            problem = result["example_problem"]
            # Crude check: the student's numbers should not appear
            # in the example_problem string at all
            assert "14 × 206" not in problem
            assert "206 × 14" not in problem

    def test_step_count_under_max(self):
        """Total steps including try_yours must be ≤ 8 (MAX_STEPS)."""
        from app.services.example_generator import MAX_STEPS
        svc = self._make_service()
        result = svc.generate_long_multiplication_example("Regn 14 × 206", language="da")
        assert len(result["steps"]) <= MAX_STEPS

    def test_handles_2x1_input(self):
        svc = self._make_service()
        result = svc.generate_long_multiplication_example("Regn 24 × 7", language="da")
        last = result["steps"][-1]
        # Normalised: multiplicand=24, multiplier=7
        assert last["visual"]["multiplicand"] == 24
        assert last["visual"]["multiplier"] == 7
