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


from unittest.mock import MagicMock
from app.services.example_generator import ExampleGeneratorService


class TestIntegration:
    def test_stacked_arithmetic_flow(self):
        """ExampleGeneratorService uses stacked arithmetic for large-number addition."""
        pick_numbers_response = '{"a": 67, "b": 85}'
        write_text_response = '[\
            {"text": "Vi skriver tallene op i kolonner", "audio_cue": "Vi skriver tallene op"},\
            {"text": "7 plus 5 er 12 — vi skriver 2 og husker 1", "audio_cue": "7 plus 5 er 12"},\
            {"text": "6 plus 8 plus 1 er 15 — vi skriver 5 og husker 1", "audio_cue": "6 plus 8 plus 1 er 15"},\
            {"text": "Vi har 1 tilbage — vi skriver 1 i hundreder", "audio_cue": "Vi skriver 1 i hundreder"},\
            {"text": "1 plus 0 plus 0 er 1", "audio_cue": "1 plus 0 er 1"},\
            {"text": "Svaret er 152", "audio_cue": "Svaret er 152"}\
        ]'

        service = ExampleGeneratorService.__new__(ExampleGeneratorService)
        mock_client = MagicMock()
        mock_client.send_text = MagicMock(side_effect=[pick_numbers_response, write_text_response])
        service.client = mock_client
        service._system_prompt = "test prompt"
        service._stacked_text_prompt = "write Danish text"

        result = service.generate_stacked_example(
            assignment_type="addition",
            assignment_text="45 + 78",
            language="da",
        )

        assert result["example_problem"] == "67 + 85 = ?"
        assert len(result["steps"]) >= 3
        assert result["steps"][0]["visual"]["type"] == "stacked_arithmetic"
        assert result["steps"][0]["visual"]["action"] == "setup"
        assert result["steps"][0]["phase"] == "concrete"
        assert result["steps"][0]["text"] == "Vi skriver tallene op i kolonner"
        assert result["steps"][-1]["visual"]["action"] == "answer"


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
