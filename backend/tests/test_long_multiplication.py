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
