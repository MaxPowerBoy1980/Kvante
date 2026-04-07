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
    def pick_example_numbers(multiplicand: int, multiplier: int) -> tuple[int, int]:
        """Pick example numbers matching the digit count of both operands.

        Cardinal rule: never returns the same numbers as input. Preserves the
        (larger, smaller) invariant: returned tuple always has a >= b. Avoids
        trivial cases (multiples of 10, numbers < 2).
        """
        mc_digits = len(str(multiplicand))
        mp_digits = len(str(multiplier))
        mc_lo, mc_hi = 10 ** (mc_digits - 1), 10 ** mc_digits - 1
        mp_lo, mp_hi = 10 ** (mp_digits - 1), 10 ** mp_digits - 1

        # If single-digit slot, allow 2-9 (not 0/1)
        mc_lo = max(mc_lo, 2)
        mp_lo = max(mp_lo, 2)

        for _ in range(200):
            ex_a = random.randint(mc_lo, mc_hi)
            ex_b = random.randint(mp_lo, mp_hi)
            if ex_a == multiplicand and ex_b == multiplier:
                continue
            if ex_a % 10 == 0 or ex_b % 10 == 0:
                continue
            if ex_a < ex_b:
                ex_a, ex_b = ex_b, ex_a
                # Re-check digit-count after swap (only an issue if mc_digits == mp_digits)
                if len(str(ex_a)) != mc_digits or len(str(ex_b)) != mp_digits:
                    continue
            return ex_a, ex_b

        # Fallback: deterministic safe values
        fallback_a = mc_lo + 1 if mc_lo + 1 != multiplicand else mc_lo + 3
        fallback_b = mp_lo + 1 if mp_lo + 1 != multiplier else mp_lo + 3
        if fallback_a < fallback_b:
            fallback_a, fallback_b = fallback_b, fallback_a
        return fallback_a, fallback_b

    @staticmethod
    def _derive_carries(multiplicand_digits: list[int], mental_steps: list[dict]) -> list:
        """Map mental_steps carry_in values to written-order carry array.

        On paper, a carry is written above the column WHERE IT IS USED (the next
        column to compute), not above the column where it was generated. So we
        index by the consuming column's carry_in.

        Returns a list parallel to multiplicand_digits (written order, high-to-low).
        Each element is None or an int 1-9. The carry that overflows past the
        highest column never appears here — it becomes a leading digit of the
        partial value instead, and no column above it exists to display it on.
        """
        n = len(multiplicand_digits)
        carries: list = [None] * n
        for ms in mental_steps:
            if ms["carry_in"] > 0:
                # mental_steps is in computation order (column 0 = ones), but
                # multiplicand_digits is in written order (high-to-low). Map by
                # reversing the index.
                written_idx = n - 1 - ms["column"]
                carries[written_idx] = ms["carry_in"]
        return carries
