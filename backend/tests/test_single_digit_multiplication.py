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
