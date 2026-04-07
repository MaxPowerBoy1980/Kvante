"""Deterministic step engine for Danish long multiplication (lang opstilling).

Given a multiplicand and multiplier, produces the exact sequence of animation
steps. No LLM involved — pure arithmetic. Caller is responsible for normalising
(larger operand first); compute_steps asserts this invariant.
"""
import random


class LongMultiplicationService:
    @staticmethod
    def compute_steps(multiplicand: int, multiplier: int) -> tuple[list[dict], list[list[dict]]]:
        """Produce display-order step dicts and a parallel mental_steps list.

        Returns: (steps, mental_steps_by_partial)
          - steps: [setup, partial_product * N, sum_partials?, reveal]
          - mental_steps_by_partial[i] is the mental_steps for the i'th
            partial_product step (0-indexed across partial_products only).
        """
        assert multiplicand > 0 and multiplier > 0, "Both numbers must be positive"
        assert multiplicand >= multiplier, "Caller must normalise: larger first"
        assert multiplicand < 1000 and multiplier < 100, "Cap: 3 cifre × 2 cifre"
        assert multiplicand >= 10 or multiplier >= 10, "At least one multi-digit operand"

        multiplicand_digits = [int(d) for d in str(multiplicand)]
        multiplier_digits = [int(d) for d in str(multiplier)]

        steps: list[dict] = [{
            "step": "setup",
            "multiplicand": multiplicand,
            "multiplier": multiplier,
            "multiplicand_digits": multiplicand_digits,
            "multiplier_digits": multiplier_digits,
        }]

        mental_steps_by_partial: list[list[dict]] = []
        partial_values: list[int] = []  # post-shift, for sum_partials

        # Iterate multiplier digits low-to-high (computation order)
        for position, mp_digit in enumerate(reversed(multiplier_digits)):
            partial_value, mental_steps = LongMultiplicationService._compute_partial(
                multiplicand_digits, mp_digit
            )
            carries = LongMultiplicationService._derive_carries(
                multiplicand_digits, mental_steps
            )

            steps.append({
                "step": "partial_product",
                "multiplier_digit": mp_digit,
                "multiplier_position": position,
                "value": partial_value,
                "digits": [int(d) for d in str(partial_value)],
                "shift": position,
                "carries": carries,
                "expression_chain": " → ".join(ms["expression"] for ms in mental_steps),
            })
            mental_steps_by_partial.append(mental_steps)
            partial_values.append(partial_value * (10 ** position))

        if len(partial_values) >= 2:
            steps.append({
                "step": "sum_partials",
                "partials": partial_values,
                "total": sum(partial_values),
            })

        steps.append({
            "step": "reveal",
            "result": multiplicand * multiplier,
        })

        return steps, mental_steps_by_partial

    @staticmethod
    def _compute_partial(multiplicand_digits: list[int], mp_digit: int) -> tuple[int, list[dict]]:
        """Compute multiplicand × mp_digit, returning (value, mental_steps).

        mental_steps is in computation order (column 0 = ones, column 1 = tens, ...).
        """
        carry = 0
        result_digits_low_to_high: list[int] = []
        mental_steps: list[dict] = []

        # Iterate multiplicand digits low-to-high
        for column, mc_digit in enumerate(reversed(multiplicand_digits)):
            product = mc_digit * mp_digit + carry
            digit_written = product % 10
            new_carry = product // 10

            if carry > 0:
                expression = f"{mc_digit}×{mp_digit}+{carry}={product}"
            else:
                expression = f"{mc_digit}×{mp_digit}={product}"

            mental_steps.append({
                "expression": expression,
                "digit_written": digit_written,
                "carry_in": carry,
                "carry_out": new_carry,
                "column": column,
            })

            result_digits_low_to_high.append(digit_written)
            carry = new_carry

        # Any leftover carry becomes the next high-order digit(s)
        while carry > 0:
            result_digits_low_to_high.append(carry % 10)
            carry //= 10

        # Reconstruct integer value
        value = 0
        for i, d in enumerate(result_digits_low_to_high):
            value += d * (10 ** i)

        return value, mental_steps

    @staticmethod
    def _derive_carries(multiplicand_digits: list[int], mental_steps: list[dict]) -> list:
        """Map mental_steps carry_out values to written-order carry array.

        Returns a list parallel to multiplicand_digits (written, high-to-low).
        Each element is None or an int 1-9. The final carry (overflowing past
        the highest column) is excluded — it becomes a leading digit in the
        partial value, not a carry above an existing column.
        """
        n = len(multiplicand_digits)
        carries: list = [None] * n
        for ms in mental_steps:
            # Skip the carry_out from the last column — it overflows into a leading
            # digit of the partial value, not a carry above an existing column.
            if ms["carry_out"] > 0 and ms["column"] < n - 1:
                written_idx = n - 1 - ms["column"]
                carries[written_idx] = ms["carry_out"]
        return carries
