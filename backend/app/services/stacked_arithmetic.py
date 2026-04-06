"""Deterministic step engine for Danish column arithmetic (opstilling).

Given an operation and two numbers, produces the exact sequence of
grouped animation steps. No LLM involved — pure arithmetic.
"""

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
        raise NotImplementedError("Addition not yet implemented")
