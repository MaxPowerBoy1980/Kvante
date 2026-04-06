# Kort division — slikkepindsmetoden

> Dato: 2026-04-06
> Status: Godkendt
> Bygger på: stacked arithmetic-mønsteret (deterministisk backend + SwiftUI view)

## Oversigt

Ny visual type `short_division` der viser kort division med slikkepindsmetoden — den notation danske folkeskoleelever lærer. Divisor i cirkel øverst, lodret streg, progressive tal til venstre, resultatcifre til højre.

Understøtter hele kæden: hel division → rest → brøk → decimal.

## Eksempel

588 ÷ 4 = 147 (uden rest):

```
    (4)        ← divisor i cirkel
     |
  5  | 1       ← 5 ÷ 4 = 1, rest 1
 18  | 4       ← 18 ÷ 4 = 4, rest 2
 28  | 7       ← 28 ÷ 4 = 7, rest 0
_____|_____
              = 147
```

589 ÷ 4 = 147,25 (med rest → brøk → decimal):

```
    (4)
     |
  5  | 1
 18  | 4
 29  | 7       ← rest 1
_____|_____
              = 147 rest 1
              = 147 1/4
              = 147,25
```

## Edge cases

| Case | Eksempel | Håndtering |
|------|----------|------------|
| Første ciffer < divisor | 2488 ÷ 4 | group akkumulerer cifre indtil group >= divisor (skriv 0 i kvotienten for hvert ciffer der ikke rækker) |
| Store tal (4-5 cifre) | 12480 ÷ 8 | Flere rækker, samme flow |
| Rest | 589 ÷ 4 | Vis rest → brøk → decimal |
| Nul i kvotienten | 612 ÷ 6 = 102 | 01 ÷ 6 = 0 rest 1, skriv 0 |
| Tocifret divisor | 864 ÷ 12 | Samme layout, større grupper |

## Routing

Alle divisionsopgaver bruger slikkepindsmetoden. Ingen `should_use_stacked()`-lignende logik nødvendig — `topic == "division"` er nok.

`pick_example_numbers()` matcher antal cifre i dividend og divisor til elevens opgave.

---

## Backend

### Ny service: `backend/app/services/short_division.py`

Deterministisk Python — ingen LLM til matematik.

#### `compute_steps(dividend: int, divisor: int) → list[dict]`

Algoritme:
1. Konvertér dividend til ciffer-array
2. Start med `group = 0`
3. For hvert ciffer venstre-til-højre: `group = group * 10 + digit`
   - Hvis `group < divisor`: `quotient_digit = 0`, behold `group` som rest (skriv kun 0 hvis det ikke er første ciffer)
   - Hvis `group >= divisor`: `quotient_digit = group // divisor`, `group = group % divisor`
4. Når alle cifre er behandlet og `group > 0`: generer rest → brøk → decimal

Dette håndterer alle cases ensartet — encifret divisor, tocifret divisor, og tilfælde hvor flere cifre skal akkumuleres før divisor "går op".

Returnerer grupper:

```python
[
    {"group": "setup", "dividend": 589, "divisor": 4, "digits": [5, 8, 9]},
    {"group": "process_digit", "position": 0, "group_value": 5,
     "quotient_digit": 1, "remainder": 1},
    {"group": "process_digit", "position": 1, "group_value": 18,
     "quotient_digit": 4, "remainder": 2},
    {"group": "process_digit", "position": 2, "group_value": 29,
     "quotient_digit": 7, "remainder": 1},
    {"group": "show_remainder", "remainder": 1, "divisor": 4},
    {"group": "show_fraction", "whole": 147, "numerator": 1, "denominator": 4},
    {"group": "show_decimal", "decimal_result": "147,25"},
    {"group": "reveal", "result": "147,25"}
]
```

#### `pick_example_numbers(assignment_text: str) → tuple[int, int]`

- Parser dividend og divisor fra opgavetekst
- Vælger nye tal med samme antal cifre i dividend og divisor
- Sikrer at eksempeltallene er forskellige fra elevens
- Vælger tal der giver pæne resultater i samme sværhedsgrad

#### `generate_text(groups: list[dict]) → list[str]`

Danske templates:
- setup: "Vi skal finde ud af hvad {dividend} divideret med {divisor} giver"
- process_digit (første): "{group} divideret med {divisor} giver {quotient}, rest {remainder}"
- process_digit (følgende): "Resten {prev_remainder} sættes foran {next_digit}, det giver {group}. {group} divideret med {divisor} giver {quotient}, rest {remainder}"
- show_remainder: "Vi har rest {remainder}"
- show_fraction: "Det skriver vi som brøken {num}/{den}"
- show_decimal: "{num}/{den} er det samme som {decimal} — så svaret er {result}"
- reveal (ingen rest): "Svaret er {result}"

### Integration i `example_generator.py`

- Ny funktion `should_use_short_division(topic)` → `True` hvis `topic == "division"`
- `generate_example()` router til `generate_short_division_example()`:
  1. `pick_example_numbers(assignment_text)`
  2. `compute_steps(dividend, divisor)`
  3. `generate_text(groups)`
  4. Saml til `ExampleResponse` med `AnimationStep`-liste

### VisualInstruction actions

Type: `"short_division"`

| Action | Flat params |
|--------|-------------|
| `setup` | `dividend: int`, `divisor: int`, `digits: [int]` |
| `process_digit` | `position: int`, `group_value: int`, `quotient_digit: int`, `remainder: int`, `expression: str` |
| `show_remainder` | `remainder: int`, `divisor: int` |
| `show_fraction` | `whole: int`, `numerator: int`, `denominator: int` |
| `show_decimal` | `decimal_result: str` |
| `reveal` | `result: str` |

---

## iOS

### Ny struct: `ShortDivisionState`

```swift
struct ShortDivisionState {
    let divisor: Int
    let digits: [Int]
    var rows: [(groupValue: Int, quotientDigit: Int, remainder: Int)]
    var activeRow: Int?
    var currentExpression: String?
    var remainderValue: Int?
    var fractionText: String?
    var decimalResult: String?
    var showResult: Bool

    static func from(visual: VisualInstruction) -> ShortDivisionState
    mutating func apply(visual: VisualInstruction)
}
```

`from(visual:)` opretter fra `setup`. `apply(visual:)` muterer:
- `process_digit`: tilføj række til `rows`, sæt `activeRow` og `currentExpression`
- `show_remainder`: sæt `remainderValue`
- `show_fraction`: sæt `fractionText`
- `show_decimal`: sæt `decimalResult`
- `reveal`: sæt `showResult = true`, clear `activeRow`

### Ny view: `ShortDivisionView`

Fil: `ios/Kvante/Kvante/Views/VisualComponents/ShortDivisionView.swift`

Layout (VStack):
1. **Expression badge** — viser fx "18 ÷ 4 = 4 rest 2" (teal baggrund, rounded rect)
2. **Slikkepind-layout:**
   - Divisor (cirkel, 48pt, 3px border) centreret
   - HStack pr. række:
     - Venstre (60pt bred): group-tal, rest i orange lille skrift foran
     - Lodret streg (3px)
     - Højre: quotient-ciffer i teal
   - Aktiv række: teal baggrund 0.1 opacity
   - Vandret streg (3px) i bunden
3. **Rest/brøk/decimal** — under slikkepinden som ekstra tekst-rækker
4. **Resultat** — "= 147,25" med glow

Styling: Marker Felt font, 44pt celler, KvanteTheme.Colors (ink, primary/teal), identisk med stacked arithmetic.

### Animationer

| Element | Animation |
|---------|-----------|
| Ny række | slide-in `.spring(duration: 0.3)` |
| Rest-tal (orange) | fade-in `.easeIn(duration: 0.2)` |
| Quotient-ciffer | scale-pop `.spring(duration: 0.4)` |
| Brøk/decimal | fade-in `.easeIn(duration: 0.3)` |
| Resultat-glow | `.spring(duration: 0.5).repeatCount(2)` (som stacked arithmetic) |

### VisualComponentView router

Ny case i `VisualComponentView.swift`:
```swift
case "short_division":
    ShortDivisionView(visual: visual, animate: animate, state: shortDivisionState)
```

Cumulative state-threading: `cumulativeShortDivisionState` i `ExampleAnimation`/`AnimationPlayer`, samme mønster som `cumulativeGridState`.

---

## Tekstprompt

Ny fil: `backend/app/prompts/short_division_text.txt`

Danske templates til `generate_text()`. Ingen LLM — rent template-baseret.

---

## Ikke i scope

- Lang division (2a — bracket-metoden)
- Komma-notation (spec 2b — den alternative inline-notation)
- Multiplikation (kryds/lang) — separat feature
