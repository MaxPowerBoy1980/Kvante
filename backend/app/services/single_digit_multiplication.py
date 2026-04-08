"""Deterministic step engine for single-digit multiplication (areal-model).

Given two single-digit operands (2-9 × 2-9), produces the row-by-row
animation steps for an a × b rectangle. No LLM involved — pure arithmetic.
Caller is responsible for routing — should_use_single_digit_multiplication
in example_generator gates this.
"""


class SingleDigitMultiplicationService:
    @staticmethod
    def compute_steps(a: int, b: int) -> list[dict]:
        """Producer display-order step dicts for a × b.

        Caller skal IKKE normalisere — vi bevarer elevens læseretning:
        a er antal rækker, b er antal i hver række. Pædagogisk betyder
        det at 7 × 9 og 9 × 7 giver to forskellige visuelle layouts.
        """
        assert 2 <= a <= 9, f"a must be 2-9, got {a}"
        assert 2 <= b <= 9, f"b must be 2-9, got {b}"

        steps: list[dict] = [{"step": "setup", "rows": a, "cols": b}]

        for i in range(a):
            steps.append({
                "step": "row",
                "row_index": i,
                "row_value": b,
                "cumulative": (i + 1) * b,
            })

        steps.append({"step": "reveal", "result": a * b})
        return steps
