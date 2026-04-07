"""Deterministic step engine for Danish short division (slikkepindsmetoden).

Given a dividend and single-digit divisor, produces the exact sequence of
animation steps. No LLM involved — pure arithmetic.
"""
import random


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
        has_remainder = dividend % divisor != 0
        quotient_digits = len(str(dividend // divisor))
        possible_divisors = [d for d in range(2, 10) if d != divisor]

        for _ in range(200):
            ex_divisor = random.choice(possible_divisors)
            ex_dividend = random.randint(lo, hi)
            if ex_dividend == dividend:
                continue
            # Match difficulty: same remainder status AND same quotient digit count
            # so the lollipop diagram has the same visual shape.
            ex_has_remainder = ex_dividend % ex_divisor != 0
            if ex_has_remainder != has_remainder:
                continue
            ex_quotient_digits = len(str(ex_dividend // ex_divisor))
            if ex_quotient_digits != quotient_digits:
                continue
            return ex_dividend, ex_divisor

        return lo + 1, possible_divisors[0]

    @staticmethod
    def generate_text(steps: list[dict]) -> list[dict]:
        texts = []
        digit_count = 0  # track which digit we're on (1st, 2nd, 3rd...)

        for i, s in enumerate(steps):
            action = s["step"]

            if action == "setup":
                texts.append({
                    "text": (
                        f"Vi skal finde ud af hvad {s['dividend']} divideret med {s['divisor']} giver. "
                        f"Vi tegner slikkepinden: {s['divisor']} i cirklen, og {s['dividend']} til venstre"
                    ),
                    "audio_cue": f"{s['dividend']} divideret med {s['divisor']}",
                })

            elif action == "process_digit":
                gv = s["group_value"]
                qd = s["quotient_digit"]
                rem = s["remainder"]
                leading = s["leading"]
                divisor = steps[0]["divisor"]
                digit_count += 1

                prev_step = steps[i - 1] if i > 1 else None
                prev_rem = prev_step.get("remainder", 0) if prev_step else 0

                if digit_count == 1:
                    # First digit — introduce the method
                    if leading:
                        text = (
                            f"Vi starter med {gv}. "
                            f"Hvor mange gange går {divisor} op i {gv}? Det gør den 0 gange — "
                            f"så vi husker {gv} og tager det med til næste ciffer"
                        )
                    elif rem == 0:
                        text = (
                            f"Vi starter med {gv}. "
                            f"Hvor mange gange går {divisor} op i {gv}? "
                            f"{divisor} går {qd} gange op i {gv} — vi skriver {qd}"
                        )
                    else:
                        text = (
                            f"Vi starter med {gv}. "
                            f"Hvor mange gange går {divisor} op i {gv}? "
                            f"{divisor} går {qd} gange op i {gv}, og der er {rem} til rest — vi husker den"
                        )
                elif prev_rem > 0:
                    # Carrying remainder from previous
                    digit = gv % 10
                    if leading:
                        text = (
                            f"Vi husker resten {prev_rem} og sætter den foran {digit}, det giver {gv}. "
                            f"{divisor} går stadig ikke op i {gv} — vi husker {gv}"
                        )
                    elif rem == 0:
                        text = (
                            f"Vi husker resten {prev_rem} og sætter den foran {digit}, det giver {gv}. "
                            f"Hvor mange gange går {divisor} op i {gv}? "
                            f"{qd} gange — vi skriver {qd}"
                        )
                    else:
                        text = (
                            f"Vi husker resten {prev_rem} og sætter den foran {digit}, det giver {gv}. "
                            f"Hvor mange gange går {divisor} op i {gv}? "
                            f"{qd} gange med {rem} til rest — vi husker resten"
                        )
                else:
                    # No carry — plain next digit
                    if leading:
                        text = (
                            f"Næste ciffer er {gv}. "
                            f"{divisor} går ikke op i {gv} — vi husker {gv}"
                        )
                    elif rem == 0:
                        text = (
                            f"Næste ciffer er {gv}. "
                            f"Hvor mange gange går {divisor} op i {gv}? "
                            f"{qd} gange — vi skriver {qd}"
                        )
                    else:
                        text = (
                            f"Næste ciffer er {gv}. "
                            f"Hvor mange gange går {divisor} op i {gv}? "
                            f"{qd} gange med {rem} til rest — vi husker resten"
                        )

                texts.append({"text": text, "audio_cue": s["expression"]})

            elif action == "show_remainder":
                texts.append({
                    "text": f"Vi er færdige med cifrene, men har stadig {s['remainder']} til rest",
                    "audio_cue": f"Rest {s['remainder']}",
                })

            elif action == "show_fraction":
                texts.append({
                    "text": f"Resten {s['numerator']} ud af {s['denominator']} skriver vi som brøken {s['numerator']}/{s['denominator']}",
                    "audio_cue": f"{s['numerator']} over {s['denominator']}",
                })

            elif action == "show_decimal":
                texts.append({
                    "text": f"{s['decimal_result']} — det er det samme som brøken, bare skrevet med komma",
                    "audio_cue": s["decimal_result"],
                })

            elif action == "reveal":
                texts.append({"text": f"Svaret er {s['result']}", "audio_cue": f"Svaret er {s['result']}"})

        return texts
