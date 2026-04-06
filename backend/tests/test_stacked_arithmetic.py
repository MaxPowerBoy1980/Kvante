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

        compute_groups = [g for g in groups if g["group"] == "compute"]
        assert len(compute_groups) == 2
        assert compute_groups[0]["column"] == "E"
        assert compute_groups[0]["expression"] == "5 - 2 = 3"
        assert compute_groups[0]["result_value"] == 3
        assert compute_groups[1]["column"] == "Ti"
        assert compute_groups[1]["expression"] == "8 - 4 = 4"
        assert compute_groups[1]["result_value"] == 4

        assert groups[-1]["group"] == "answer"
        assert groups[-1]["value"] == 43

    def test_single_borrow(self):
        """83 - 47 = 36, borrow from tens."""
        groups = StackedArithmeticService.compute_steps("subtraction", 83, 47)
        group_types = [g["group"] for g in groups]
        assert group_types == ["setup", "borrow", "compute", "compute", "answer"]

        borrow = groups[1]
        assert borrow["column"] == "E"
        assert borrow["cross_out_column"] == "Ti"
        assert borrow["cross_out_old"] == 8
        assert borrow["replacement_value"] == 7
        assert borrow["carry_value"] == 1

        assert groups[2]["expression"] == "13 - 7 = 6"
        assert groups[2]["result_value"] == 6
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
