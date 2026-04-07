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
        assert p["carries"] == [None, 2]  # 4×7=28: carry 2 over the '4' → written_idx=1
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
