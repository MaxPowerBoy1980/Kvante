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
