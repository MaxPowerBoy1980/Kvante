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

    @staticmethod
    def pick_example_numbers(a: int, b: int) -> tuple[int, int]:
        """Pick (ex_a, ex_b) ≠ (a, b) og ≠ (b, a). Begge 2-9.

        Bevarer (rows, cols)-rolle uden at normalisere. Deterministisk
        fallback hvis 200 random tries fejler (skulle aldrig ske med så
        lille et søgerum, men matcher pattern fra LongMultiplicationService).
        """
        import random

        for _ in range(200):
            ex_a = random.randint(2, 9)
            ex_b = random.randint(2, 9)
            if (ex_a, ex_b) == (a, b):
                continue
            if (ex_a, ex_b) == (b, a):
                continue
            return ex_a, ex_b

        # Deterministisk fallback: scan alle 64 kombinationer
        for ca in range(2, 10):
            for cb in range(2, 10):
                if (ca, cb) != (a, b) and (ca, cb) != (b, a):
                    return ca, cb

        # Skulle aldrig nås (2-9 × 2-9 = 64 par, kun 2 udelukkes)
        raise RuntimeError(f"No example pair found for ({a}, {b})")

    @staticmethod
    def generate_text(steps: list[dict]) -> list[dict]:
        """Generér dansk narration. Returnerer [{text, audio_cue}, ...].

        Mappes 1:1 til steps:
        - setup → "Lad os finde {a} × {b}. Vi bygger {a} rækker med {b} i hver."
        - row, index 0 → "{b}"
        - row, index > 0 → "+ {b} = {cumulative}"
        - reveal → "{a} × {b} = {result}"
        """
        # Setup-step bærer dimensionerne — vi har brug for dem til reveal.
        setup = steps[0]
        a = setup["rows"]
        b = setup["cols"]

        texts: list[dict] = []
        for s in steps:
            kind = s["step"]
            if kind == "setup":
                texts.append({
                    "text": (
                        f"Lad os finde {a} × {b}. "
                        f"Vi bygger {a} rækker med {b} i hver."
                    ),
                    "audio_cue": f"{a} gange {b}",
                })
            elif kind == "row":
                if s["row_index"] == 0:
                    text = f"{b}"
                else:
                    text = f"+ {b} = {s['cumulative']}"
                texts.append({
                    "text": text,
                    "audio_cue": f"{s['cumulative']}",
                })
            elif kind == "reveal":
                result = s["result"]
                texts.append({
                    "text": f"{a} × {b} = {result}",
                    "audio_cue": f"Svaret er {result}",
                })

        return texts
