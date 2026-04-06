"""Deterministic step engine for Danish column arithmetic (opstilling).

Given an operation and two numbers, produces the exact sequence of
grouped animation steps. No LLM involved — pure arithmetic.
"""
import random
import re

COLUMN_NAMES = {
    1: ["E"],
    2: ["Ti", "E"],
    3: ["H", "Ti", "E"],
    4: ["T", "H", "Ti", "E"],
    5: ["Tt", "T", "H", "Ti", "E"],
}


class StackedArithmeticService:
    @staticmethod
    def compute_steps(operation: str, a: int, b: int) -> list[dict]:
        if operation == "subtraction":
            return StackedArithmeticService._subtraction(a, b)
        elif operation == "addition":
            return StackedArithmeticService._addition(a, b)
        else:
            raise ValueError(f"Unsupported operation: {operation}")

    @staticmethod
    def _to_digits(n: int, length: int) -> list[int]:
        """Convert number to list of digits, zero-padded to length."""
        digits = []
        for _ in range(length):
            digits.append(n % 10)
            n //= 10
        return list(reversed(digits))

    @staticmethod
    def _subtraction(a: int, b: int) -> list[dict]:
        assert a >= b >= 0, "a must be >= b for subtraction"
        answer = a - b
        num_digits = max(len(str(a)), len(str(b)))
        columns = COLUMN_NAMES[num_digits]
        top = StackedArithmeticService._to_digits(a, num_digits)
        bottom = StackedArithmeticService._to_digits(b, num_digits)

        groups = [
            {
                "group": "setup",
                "operation": "subtraction",
                "columns": columns,
                "top": top,
                "bottom": bottom,
            }
        ]

        working_top = list(top)

        for i in range(num_digits - 1, -1, -1):
            col = columns[i]
            t = working_top[i]
            bot = bottom[i]

            if t < bot:
                borrow_from = i - 1
                while borrow_from >= 0 and working_top[borrow_from] == 0:
                    borrow_from -= 1

                for j in range(borrow_from, i):
                    old_val = working_top[j]
                    working_top[j] = old_val - 1
                    working_top[j + 1] += 10

                    groups.append({
                        "group": "borrow",
                        "column": col,
                        "cross_out_column": columns[j],
                        "cross_out_old": old_val,
                        "replacement_value": old_val - 1,
                        "carry_value": 1,
                    })

                t = working_top[i]

            result = t - bot
            groups.append({
                "group": "compute",
                "column": col,
                "expression": f"{t} - {bot} = {result}",
                "result_value": result,
            })

        groups.append({"group": "answer", "value": answer})
        return groups

    @staticmethod
    def _addition(a: int, b: int) -> list[dict]:
        assert a >= 0 and b >= 0, "Both numbers must be non-negative"
        answer = a + b
        num_digits = max(len(str(a)), len(str(b)), len(str(answer)))
        columns = COLUMN_NAMES[num_digits]
        top = StackedArithmeticService._to_digits(a, num_digits)
        bottom = StackedArithmeticService._to_digits(b, num_digits)

        groups = [
            {
                "group": "setup",
                "operation": "addition",
                "columns": columns,
                "top": top,
                "bottom": bottom,
            }
        ]

        carry = 0
        for i in range(num_digits - 1, -1, -1):
            col = columns[i]
            t = top[i]
            bot = bottom[i]
            total = t + bot + carry

            if carry > 0:
                expression = f"{t} + {bot} + {carry} = {total}"
            else:
                expression = f"{t} + {bot} = {total}"

            result_digit = total % 10
            new_carry = total // 10

            groups.append({
                "group": "compute",
                "column": col,
                "expression": expression,
                "result_value": result_digit,
            })

            if new_carry > 0 and i > 0:
                groups.append({
                    "group": "carry",
                    "from_column": col,
                    "to_column": columns[i - 1],
                    "carry_value": new_carry,
                })

            carry = new_carry

        groups.append({"group": "answer", "value": answer})
        return groups

    # --- Danish text templates ---

    COLUMN_DANISH = {
        "E": "enere", "Ti": "tiere", "H": "hundreder",
        "T": "tusinder", "Tt": "titusinder",
    }

    @staticmethod
    def generate_text(groups: list[dict], operation: str) -> list[dict]:
        """Generate deterministic Danish text for each step group."""
        col_name = StackedArithmeticService.COLUMN_DANISH
        texts = []

        for group in groups:
            action = group["group"]

            if action == "setup":
                texts.append({
                    "text": "Vi stiller tallene op i kolonner",
                    "audio_cue": "Vi stiller tallene op i kolonner",
                })
            elif action == "compute":
                col = group["column"]
                expr = group["expression"]
                result = group["result_value"]
                cn = col_name.get(col, col)
                texts.append({
                    "text": f"{expr} — vi skriver {result} i {cn}",
                    "audio_cue": expr,
                })
            elif action == "carry":
                to_col = group["to_column"]
                cn = col_name.get(to_col, to_col)
                texts.append({
                    "text": f"Mente: vi flytter 1 til {cn}",
                    "audio_cue": f"Mente: vi flytter 1 til {cn}",
                })
            elif action == "borrow":
                col = group["column"]
                cross_col = group["cross_out_column"]
                cn = col_name.get(col, col)
                ccn = col_name.get(cross_col, cross_col)
                texts.append({
                    "text": f"Vi kan ikke i {cn} — vi låner fra {ccn}",
                    "audio_cue": f"Vi låner fra {ccn}",
                })
            elif action == "answer":
                value = group["value"]
                texts.append({
                    "text": f"Svaret er {value}",
                    "audio_cue": f"Svaret er {value}",
                })
            else:
                texts.append({"text": "", "audio_cue": ""})

        return texts

    # --- Random example number generation ---

    @staticmethod
    def pick_example_numbers(operation: str, assignment_text: str) -> tuple[int, int]:
        """Pick example numbers different from the student's, in a similar range."""
        student_numbers = [int(n) for n in re.findall(r'\d+', assignment_text)]

        if student_numbers:
            max_num = max(student_numbers)
            num_digits = len(str(max_num))
        else:
            num_digits = 2

        lo = 10 ** (num_digits - 1)
        hi = 10 ** num_digits - 1

        for _ in range(50):
            a = random.randint(lo, hi)
            b = random.randint(lo, hi)
            if operation == "subtraction" and a < b:
                a, b = b, a
            if a not in student_numbers and b not in student_numbers:
                return a, b

        return lo + 1, lo + 2
