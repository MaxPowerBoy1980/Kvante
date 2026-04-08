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
