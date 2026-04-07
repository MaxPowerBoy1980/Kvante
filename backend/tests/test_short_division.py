import pytest
from app.services.short_division import ShortDivisionService


class TestComputeSteps:
    def test_simple_no_remainder(self):
        """588 ÷ 4 = 147, no remainder."""
        steps = ShortDivisionService.compute_steps(588, 4)
        assert steps[0]["step"] == "setup"
        assert steps[0]["dividend"] == 588
        assert steps[0]["divisor"] == 4
        assert steps[0]["digits"] == [5, 8, 8]

        process = [s for s in steps if s["step"] == "process_digit"]
        assert len(process) == 3

        assert process[0]["group_value"] == 5
        assert process[0]["quotient_digit"] == 1
        assert process[0]["remainder"] == 1
        assert process[0]["leading"] is False
        assert process[0]["expression"] == "5 ÷ 4 = 1 rest 1"

        assert process[1]["group_value"] == 18
        assert process[1]["quotient_digit"] == 4
        assert process[1]["remainder"] == 2
        assert process[1]["expression"] == "18 ÷ 4 = 4 rest 2"

        assert process[2]["group_value"] == 28
        assert process[2]["quotient_digit"] == 7
        assert process[2]["remainder"] == 0
        assert process[2]["expression"] == "28 ÷ 4 = 7 rest 0"

        assert steps[-1]["step"] == "reveal"
        assert steps[-1]["result"] == "147"
        assert not any(s["step"] == "show_remainder" for s in steps)

    def test_with_remainder_terminating(self):
        """589 ÷ 4 = 147,25 — remainder with terminating decimal."""
        steps = ShortDivisionService.compute_steps(589, 4)

        process = [s for s in steps if s["step"] == "process_digit"]
        assert process[-1]["remainder"] == 1

        remainder_step = next(s for s in steps if s["step"] == "show_remainder")
        assert remainder_step["remainder"] == 1
        assert remainder_step["divisor"] == 4

        fraction_step = next(s for s in steps if s["step"] == "show_fraction")
        assert fraction_step["whole"] == 147
        assert fraction_step["numerator"] == 1
        assert fraction_step["denominator"] == 4

        decimal_step = next(s for s in steps if s["step"] == "show_decimal")
        assert decimal_step["decimal_result"] == "147,25"

        assert steps[-1]["step"] == "reveal"
        assert steps[-1]["result"] == "147,25"

    def test_with_remainder_non_terminating(self):
        """10 ÷ 3 = 3 rest 1 — non-terminating decimal, no show_decimal."""
        steps = ShortDivisionService.compute_steps(10, 3)

        fraction_step = next(s for s in steps if s["step"] == "show_fraction")
        assert fraction_step["whole"] == 3
        assert fraction_step["numerator"] == 1
        assert fraction_step["denominator"] == 3

        assert not any(s["step"] == "show_decimal" for s in steps)

        assert steps[-1]["step"] == "reveal"
        assert steps[-1]["result"] == "3 1/3"

    def test_leading_zero(self):
        """248 ÷ 4 = 62 — first digit < divisor gives leading zero."""
        steps = ShortDivisionService.compute_steps(248, 4)

        process = [s for s in steps if s["step"] == "process_digit"]
        assert process[0]["group_value"] == 2
        assert process[0]["quotient_digit"] == 0
        assert process[0]["remainder"] == 2
        assert process[0]["leading"] is True

        assert process[1]["group_value"] == 24
        assert process[1]["quotient_digit"] == 6
        assert process[1]["leading"] is False

        assert process[2]["group_value"] == 8
        assert process[2]["quotient_digit"] == 2
        assert process[2]["leading"] is False

        assert steps[-1]["result"] == "62"

    def test_zero_in_quotient_middle(self):
        """612 ÷ 6 = 102 — zero in middle of quotient."""
        steps = ShortDivisionService.compute_steps(612, 6)

        process = [s for s in steps if s["step"] == "process_digit"]
        assert process[0]["quotient_digit"] == 1
        assert process[0]["leading"] is False

        assert process[1]["group_value"] == 1
        assert process[1]["quotient_digit"] == 0
        assert process[1]["remainder"] == 1
        assert process[1]["leading"] is False

        assert process[2]["group_value"] == 12
        assert process[2]["quotient_digit"] == 2

        assert steps[-1]["result"] == "102"

    def test_large_number(self):
        """12480 ÷ 8 = 1560."""
        steps = ShortDivisionService.compute_steps(12480, 8)

        process = [s for s in steps if s["step"] == "process_digit"]
        assert len(process) == 5
        assert steps[-1]["result"] == "1560"

    def test_single_digit_dividend(self):
        """8 ÷ 4 = 2."""
        steps = ShortDivisionService.compute_steps(8, 4)

        process = [s for s in steps if s["step"] == "process_digit"]
        assert len(process) == 1
        assert process[0]["quotient_digit"] == 2
        assert process[0]["remainder"] == 0

        assert steps[-1]["result"] == "2"

    def test_remainder_half(self):
        """5 ÷ 2 = 2,5 — simple terminating decimal."""
        steps = ShortDivisionService.compute_steps(5, 2)

        decimal_step = next(s for s in steps if s["step"] == "show_decimal")
        assert decimal_step["decimal_result"] == "2,5"


class TestGenerateText:
    def test_simple_division_text(self):
        """Danish text for 588 ÷ 4 = 147."""
        steps = ShortDivisionService.compute_steps(588, 4)
        texts = ShortDivisionService.generate_text(steps)

        assert "slikkepinden" in texts[0]["text"]
        assert "Vi starter med 5" in texts[1]["text"]
        assert "4 går 1 gange op i 5" in texts[1]["text"]
        assert "husker resten 1" in texts[2]["text"]
        assert "18" in texts[2]["text"]
        assert texts[-1]["text"] == "Svaret er 147"

    def test_remainder_text(self):
        """Danish text includes rest → brøk → decimal."""
        steps = ShortDivisionService.compute_steps(589, 4)
        texts = ShortDivisionService.generate_text(steps)

        remainder_texts = [t["text"] for t in texts]
        assert any("til rest" in t for t in remainder_texts)
        assert any("brøken 1/4" in t for t in remainder_texts)
        assert any("147,25" in t for t in remainder_texts)

    def test_text_count_matches_steps(self):
        """Number of text entries must match number of steps."""
        steps = ShortDivisionService.compute_steps(12480, 8)
        texts = ShortDivisionService.generate_text(steps)
        assert len(texts) == len(steps)

    def test_non_terminating_text(self):
        """Non-terminating: shows brøk, no decimal text."""
        steps = ShortDivisionService.compute_steps(10, 3)
        texts = ShortDivisionService.generate_text(steps)

        text_strings = [t["text"] for t in texts]
        assert any("brøken 1/3" in t for t in text_strings)
        # No "det er det samme som" text for non-terminating
        assert not any("det samme som" in t.lower() for t in text_strings)

    def test_reveal_text_terminating_decimal(self):
        """Reveal for terminating decimal: 'Så svaret er' (show_decimal already showed conversion)."""
        steps = ShortDivisionService.compute_steps(589, 4)
        texts = ShortDivisionService.generate_text(steps)
        assert texts[-1]["text"] == "Så svaret er 147,25"

    def test_reveal_text_fraction(self):
        """Reveal for non-terminating fraction: 'Svaret er {whole} og {num}/{den}'."""
        steps = ShortDivisionService.compute_steps(10, 3)
        texts = ShortDivisionService.generate_text(steps)
        assert texts[-1]["text"] == "Svaret er 3 og 1/3"


class TestPickExampleNumbers:
    def test_different_from_student(self):
        """Example numbers must differ from student's."""
        for _ in range(20):
            ex_div, ex_divisor = ShortDivisionService.pick_example_numbers(588, 4)
            assert ex_div != 588
            assert ex_divisor != 4

    def test_same_digit_count(self):
        """Dividend should have same number of digits."""
        ex_div, _ = ShortDivisionService.pick_example_numbers(588, 4)
        assert 100 <= ex_div <= 999

        ex_div, _ = ShortDivisionService.pick_example_numbers(12480, 8)
        assert 10000 <= ex_div <= 99999

    def test_single_digit_divisor(self):
        """Divisor should always be single-digit."""
        for _ in range(20):
            _, ex_divisor = ShortDivisionService.pick_example_numbers(588, 4)
            assert 2 <= ex_divisor <= 9

    def test_same_quotient_digit_count(self):
        """Example quotient must have same digit count as student's quotient.

        588 ÷ 4 = 147 (3-digit quotient) → example must also produce 3-digit quotient.
        This ensures the lollipop diagram has the same number of rows.
        """
        student_dividend, student_divisor = 588, 4
        student_quotient_digits = len(str(student_dividend // student_divisor))

        for _ in range(50):
            ex_div, ex_divisor = ShortDivisionService.pick_example_numbers(
                student_dividend, student_divisor
            )
            ex_quotient_digits = len(str(ex_div // ex_divisor))
            assert ex_quotient_digits == student_quotient_digits, (
                f"{ex_div} ÷ {ex_divisor} = {ex_div // ex_divisor} "
                f"({ex_quotient_digits} digits), expected {student_quotient_digits} digits"
            )


from app.services.example_generator import ExampleGeneratorService, should_use_short_division


class TestRouting:
    def test_should_use_short_division(self):
        assert should_use_short_division("division") is True
        assert should_use_short_division("addition") is False
        assert should_use_short_division("subtraction") is False
        assert should_use_short_division("multiplikation") is False

    def test_short_division_example_flow(self):
        """generate_short_division_example is fully deterministic — no LLM needed."""
        service = ExampleGeneratorService.__new__(ExampleGeneratorService)
        result = service.generate_short_division_example(
            assignment_text="Regn ud: 588 ÷ 4",
            language="da",
        )
        assert len(result["steps"]) >= 4
        assert result["steps"][0]["visual"]["type"] == "short_division"
        assert result["steps"][0]["visual"]["action"] == "setup"
        assert result["steps"][0]["phase"] == "concrete"
        assert "divideret med" in result["steps"][0]["text"]

        reveal_steps = [s for s in result["steps"] if s["visual"]["action"] == "reveal"]
        assert len(reveal_steps) == 1

        assert result["steps"][-1]["text"] == "Prøv nu selv med din opgave — stil den op på samme måde!"
        assert result["steps"][-1]["visual"]["type"] == "short_division"
        assert result["steps"][-1]["visual"]["action"] == "setup"

        assert "588" not in result["example_problem"]


class TestEndToEnd:
    def test_full_response_validates_against_schema(self):
        """ExampleResponse from short division passes Pydantic validation."""
        from pydantic import ValidationError
        from app.models.schemas import ExampleResponse as ExampleResponseModel

        service = ExampleGeneratorService.__new__(ExampleGeneratorService)
        result = service.generate_short_division_example(
            assignment_text="Regn ud: 84 ÷ 4",
            language="da",
        )
        # Should not raise
        ExampleResponseModel(**result)

    def test_all_visuals_are_short_division(self):
        """All steps should have visual type short_division."""
        service = ExampleGeneratorService.__new__(ExampleGeneratorService)
        result = service.generate_short_division_example(
            assignment_text="Regn ud: 589 ÷ 4",
            language="da",
        )
        for step in result["steps"]:
            assert step["visual"]["type"] == "short_division"

    def test_remainder_flow_includes_fraction(self):
        """Assignments with remainder include fraction step."""
        from app.services.short_division import ShortDivisionService
        steps = ShortDivisionService.compute_steps(589, 4)
        assert any(s["step"] == "show_fraction" for s in steps)

    def test_no_remainder_flow_skips_fraction(self):
        """Assignments without remainder skip fraction/decimal steps."""
        from app.services.short_division import ShortDivisionService
        steps = ShortDivisionService.compute_steps(588, 4)
        assert not any(s["step"] == "show_fraction" for s in steps)
