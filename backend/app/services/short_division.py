"""Deterministic step engine for Danish short division (slikkepindsmetoden).

Given a dividend and single-digit divisor, produces the exact sequence of
animation steps. No LLM involved — pure arithmetic.
"""
import random
import re


class ShortDivisionService:
    @staticmethod
    def compute_steps(dividend: int, divisor: int) -> list[dict]:
        assert dividend > 0 and divisor > 0, "Both numbers must be positive"
        assert 1 <= divisor <= 9, "Divisor must be single-digit (1-9)"

        digits = [int(d) for d in str(dividend)]
        steps = [{"step": "setup", "dividend": dividend, "divisor": divisor, "digits": digits}]

        group = 0
        quotient_digits = []
        all_leading = True

        for i, digit in enumerate(digits):
            group = group * 10 + digit
            quotient_digit = group // divisor
            remainder = group % divisor

            if quotient_digit == 0 and all_leading:
                leading = True
            else:
                leading = False
                all_leading = False

            steps.append({
                "step": "process_digit",
                "position": i,
                "group_value": group,
                "quotient_digit": quotient_digit,
                "remainder": remainder,
                "leading": leading,
                "expression": f"{group} ÷ {divisor} = {quotient_digit} rest {remainder}",
            })

            quotient_digits.append((quotient_digit, leading))
            group = remainder

        quotient_str = "".join(
            str(d) for d, is_leading in quotient_digits if not is_leading
        )
        quotient_int = int(quotient_str) if quotient_str else 0
        final_remainder = group

        if final_remainder > 0:
            steps.append({"step": "show_remainder", "remainder": final_remainder, "divisor": divisor})
            steps.append({
                "step": "show_fraction",
                "whole": quotient_int,
                "numerator": final_remainder,
                "denominator": divisor,
            })

            if ShortDivisionService._is_terminating(divisor):
                decimal_value = quotient_int + final_remainder / divisor
                decimal_str = f"{decimal_value:.10f}".rstrip("0").rstrip(".")
                decimal_str = decimal_str.replace(".", ",")
                steps.append({"step": "show_decimal", "decimal_result": decimal_str})
                steps.append({"step": "reveal", "result": decimal_str})
            else:
                result_str = f"{quotient_int} {final_remainder}/{divisor}"
                steps.append({"step": "reveal", "result": result_str})
        else:
            steps.append({"step": "reveal", "result": quotient_str})

        return steps

    @staticmethod
    def _is_terminating(divisor: int) -> bool:
        n = divisor
        while n % 2 == 0:
            n //= 2
        while n % 5 == 0:
            n //= 5
        return n == 1

    @staticmethod
    def pick_example_numbers(dividend: int, divisor: int) -> tuple[int, int]:
        num_digits = len(str(dividend))
        lo = 10 ** (num_digits - 1)
        hi = 10 ** num_digits - 1
        possible_divisors = [d for d in range(2, 10) if d != divisor]

        for _ in range(50):
            ex_divisor = random.choice(possible_divisors)
            ex_dividend = random.randint(lo, hi)
            if ex_dividend != dividend:
                return ex_dividend, ex_divisor

        return lo + 1, possible_divisors[0]

    @staticmethod
    def generate_text(steps: list[dict]) -> list[dict]:
        texts = []

        for i, s in enumerate(steps):
            action = s["step"]

            if action == "setup":
                texts.append({
                    "text": f"Vi skal finde ud af hvad {s['dividend']} divideret med {s['divisor']} giver",
                    "audio_cue": f"{s['dividend']} divideret med {s['divisor']}",
                })

            elif action == "process_digit":
                gv = s["group_value"]
                qd = s["quotient_digit"]
                rem = s["remainder"]
                divisor = steps[0]["divisor"]

                if i == 1:  # First process_digit (right after setup)
                    text = f"{gv} divideret med {divisor} giver {qd}, rest {rem}"
                else:
                    prev_step = steps[i - 1]
                    prev_rem = prev_step.get("remainder", 0)
                    digit = gv % 10 if prev_rem > 0 else gv
                    text = (
                        f"Resten {prev_rem} sættes foran {digit}, det giver {gv}. "
                        f"{gv} divideret med {divisor} giver {qd}, rest {rem}"
                    )
                texts.append({"text": text, "audio_cue": s["expression"]})

            elif action == "show_remainder":
                texts.append({"text": f"Vi har rest {s['remainder']}", "audio_cue": f"Rest {s['remainder']}"})

            elif action == "show_fraction":
                texts.append({
                    "text": f"Det skriver vi som brøken {s['numerator']}/{s['denominator']}",
                    "audio_cue": f"{s['numerator']} over {s['denominator']}",
                })

            elif action == "show_decimal":
                texts.append({"text": f"Det er det samme som {s['decimal_result']}", "audio_cue": s["decimal_result"]})

            elif action == "reveal":
                texts.append({"text": f"Svaret er {s['result']}", "audio_cue": f"Svaret er {s['result']}"})

        return texts
