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
        compute_ones = [g for g in groups if g["group"] == "compute" and g["column"] == "E"]
        assert compute_ones[0]["expression"] == "7 + 5 = 12"
        assert compute_ones[0]["result_value"] == 2

        compute_tens = [g for g in groups if g["group"] == "compute" and g["column"] == "Ti"]
        assert compute_tens[0]["expression"] == "6 + 8 + 1 = 15"
        assert compute_tens[0]["result_value"] == 5


from app.services.example_generator import ExampleGeneratorService


class TestIntegration:
    def test_stacked_arithmetic_flow(self):
        """generate_stacked_example is fully deterministic — no LLM needed."""
        service = ExampleGeneratorService.__new__(ExampleGeneratorService)
        # No mock client needed — stacked path doesn't call LLM

        result = service.generate_stacked_example(
            assignment_type="addition",
            assignment_text="45 + 78",
            language="da",
        )

        assert len(result["steps"]) >= 3
        assert result["steps"][0]["visual"]["type"] == "stacked_arithmetic"
        assert result["steps"][0]["visual"]["action"] == "setup"
        assert result["steps"][0]["phase"] == "concrete"
        assert result["steps"][0]["text"] == "Vi stiller tallene op i kolonner"
        # Second-to-last step is answer, last is "try yours"
        answer_steps = [s for s in result["steps"] if s["visual"]["action"] == "answer"]
        assert len(answer_steps) == 1
        # Last step is "try yours" with student's numbers
        assert result["steps"][-1]["visual"]["action"] == "setup"
        assert result["steps"][-1]["text"] == "Prøv nu selv med din opgave — stil den op på samme måde!"
        assert result["steps"][-1]["visual"]["top"] is not None
        # Example numbers should be different from student's
        assert "45" not in result["example_problem"]
        assert "78" not in result["example_problem"]


class TestDanishText:
    def test_addition_text(self):
        """Danish text templates for addition steps."""
        from app.services.stacked_arithmetic import StackedArithmeticService
        groups = StackedArithmeticService.compute_steps("addition", 57, 36)
        texts = StackedArithmeticService.generate_text(groups, "addition")
        assert texts[0]["text"] == "Vi stiller tallene op i kolonner"
        # Compute ones: 7 + 6 = 13
        assert "7 + 6 = 13" in texts[1]["text"]
        assert "enere" in texts[1]["text"]
        assert texts[-1]["text"] == "Svaret er 93"

    def test_subtraction_borrow_text(self):
        """Danish text templates for subtraction with borrow."""
        from app.services.stacked_arithmetic import StackedArithmeticService
        groups = StackedArithmeticService.compute_steps("subtraction", 83, 47)
        texts = StackedArithmeticService.generate_text(groups, "subtraction")
        # Should have borrow text
        borrow_texts = [t for t, g in zip(texts, groups) if g["group"] == "borrow"]
        assert len(borrow_texts) == 1
        assert "låner" in borrow_texts[0]["text"]

    def test_text_count_matches_groups(self):
        """Number of text entries must match number of groups."""
        from app.services.stacked_arithmetic import StackedArithmeticService
        groups = StackedArithmeticService.compute_steps("addition", 999, 1)
        texts = StackedArithmeticService.generate_text(groups, "addition")
        assert len(texts) == len(groups)


class TestNumberPicker:
    def test_picks_different_numbers(self):
        """Example numbers must differ from student's."""
        from app.services.stacked_arithmetic import StackedArithmeticService
        a, b = StackedArithmeticService.pick_example_numbers("addition", "45 + 78")
        assert a != 45 and a != 78
        assert b != 45 and b != 78

    def test_similar_magnitude(self):
        """Example numbers should be in similar range."""
        from app.services.stacked_arithmetic import StackedArithmeticService
        a, b = StackedArithmeticService.pick_example_numbers("addition", "345 + 278")
        assert 100 <= a <= 999
        assert 100 <= b <= 999

    def test_subtraction_a_gte_b(self):
        """For subtraction, a must be >= b."""
        from app.services.stacked_arithmetic import StackedArithmeticService
        for _ in range(20):
            a, b = StackedArithmeticService.pick_example_numbers("subtraction", "500 - 200")
            assert a >= b


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

    def test_calculation_type_detected_from_text(self):
        """Type 'calculation' should detect operation from text."""
        from app.services.example_generator import should_use_stacked
        assert should_use_stacked("calculation", "Regn ud: 486 + 357") is True
        assert should_use_stacked("calculation", "Regn ud: 503 - 247") is True
        assert should_use_stacked("calculation", "Regn ud: 3 + 5") is False
        assert should_use_stacked("calculation", "Regn ud: 6 * 7") is False

    def test_word_problem_detected_from_topic(self):
        """Word problems without +/- in text should use topic to detect."""
        from app.services.example_generator import should_use_stacked
        assert should_use_stacked(
            "calculation",
            "Der er 145 elever i indskolingen og 278 i udskolingen. Hvor mange?",
            assignment_topic="addition"
        ) is True
        assert should_use_stacked(
            "calculation",
            "Jonas har 500 kr og bruger 237. Hvor mange har han tilbage?",
            assignment_topic="subtraction"
        ) is True
