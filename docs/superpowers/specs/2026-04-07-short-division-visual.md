# Kort division — slikkepindsmetoden

> Dato: 2026-04-07
> Status: Godkendt
> Bygger på: stacked arithmetic-mønsteret (deterministisk backend + SwiftUI view)

## Oversigt

Ny visual type `short_division` der viser kort division med slikkepindsmetoden — den notation danske folkeskoleelever lærer. Divisor i cirkel øverst, lodret streg, progressive tal til venstre, resultatcifre til højre.

Understøtter hele kæden: hel division → rest → brøk → decimal (kun terminerende decimaler — se edge cases).

Kun encifret divisor. Tocifret divisor hører til lang division (galgemanden) og er ikke i scope.

## Eksempel — 589 ÷ 4 = 147,25

Dette er det kanoniske eksempel igennem hele specen. Det dækker hele kæden: hel division → rest → brøk → terminerende decimal.

```
    (4)        ← divisor i cirkel
     |
  5  | 1       ← 5 ÷ 4 = 1, rest 1
 18  | 4       ← 18 ÷ 4 = 4, rest 2
 29  | 7       ← 29 ÷ 4 = 7, rest 1
_____|_____
              = 147 rest 1
              = 147 1/4
              = 147,25
```

Når en opgave ikke har rest (fx 588 ÷ 4 = 147), stopper flowet efter sidste `process_digit` og går direkte til `reveal` — `show_remainder`, `show_fraction` og `show_decimal` springes over.

## Edge cases

| Case | Eksempel | Håndtering |
|------|----------|------------|
| Første ciffer < divisor | 248 ÷ 4 = 62 | Første ciffer (2) giver quotient_digit 0 — dette er en ledende nul og vises *ikke* i resultatet. Resten (2) bæres videre, næste group bliver 24. Output har `quotient_digit: 0` med `leading: true` som iOS-viewet skjuler |
| Store tal (4-5 cifre) | 12480 ÷ 8 | Flere rækker, samme flow |
| Rest med terminerende decimal | 589 ÷ 4 | Vis rest → brøk → decimal (147,25) |
| Rest med ikke-terminerende decimal | 10 ÷ 3 | Vis rest → brøk (3 1/3) — spring `show_decimal` over. Decimalen terminerer ikke og ville forvirre eleven |
| Nul i kvotienten (midt i tal) | 612 ÷ 6 = 102 | 01 ÷ 6 = 0 rest 1, skriv 0. Nulcifre *midt i* resultatet vises altid — det er kun *ledende* nuller der skjules |

## Routing

Entry point er `backend/app/services/example_generator.py`. Alle divisionsopgaver bruger slikkepindsmetoden — ingen `should_use_stacked()`-lignende logik nødvendig, `topic == "division"` er nok til at route videre til `generate_short_division_example()`.

`pick_example_numbers()` matcher antal cifre i dividend og encifret divisor til elevens opgave.

---

## Backend

### Ny service: `backend/app/services/short_division.py`

Deterministisk Python — ingen LLM til matematik.

#### `compute_steps(dividend: int, divisor: int) → list[dict]`

Algoritme (encifret divisor):
1. Konvertér dividend til ciffer-array
2. Start med `group = 0`
3. For hvert ciffer venstre-til-højre: `group = group * 10 + digit`
   - `quotient_digit = group // divisor`
   - `remainder = group % divisor`
   - `group = remainder` (bæres til næste iteration)
   - Markér `leading: true` hvis alle foregående quotient_digits er 0 og dette også er 0
4. Når alle cifre er behandlet og `group > 0`:
   - Altid: generer `show_remainder` og `show_fraction`
   - Kun hvis decimalen terminerer (dvs. nævneren kun har faktorerne 2 og 5): generer `show_decimal`
   - Ellers: stop ved brøken — eleven ser fx "3 1/3" som slutresultat

Returnerer steps:

```python
[
    {"step": "setup", "dividend": 589, "divisor": 4, "digits": [5, 8, 9]},
    {"step": "process_digit", "position": 0, "group_value": 5,
     "quotient_digit": 1, "remainder": 1, "leading": False,
     "expression": "5 ÷ 4 = 1 rest 1"},
    {"step": "process_digit", "position": 1, "group_value": 18,
     "quotient_digit": 4, "remainder": 2, "leading": False,
     "expression": "18 ÷ 4 = 4 rest 2"},
    {"step": "process_digit", "position": 2, "group_value": 29,
     "quotient_digit": 7, "remainder": 1, "leading": False,
     "expression": "29 ÷ 4 = 7 rest 1"},
    {"step": "show_remainder", "remainder": 1, "divisor": 4},
    {"step": "show_fraction", "whole": 147, "numerator": 1, "denominator": 4},
    {"step": "show_decimal", "decimal_result": "147,25"},
    {"step": "reveal", "result": "147,25"}
]
```

#### `pick_example_numbers(dividend: int, divisor: int) → tuple[int, int]`

- Tager de strukturerede tal direkte (routeren i `example_generator.py` parser fra assignment)
- Sikrer at eksempeltallene er forskellige fra elevens

**"Samme sværhedsgrad"** er defineret eksplicit som alle fire kriterier:
1. Samme antal cifre i dividend (fx 589 → 3-cifret → vælg et andet 3-cifret tal)
2. Samme antal cifre i divisor (altid 1 i denne spec — encifret)
3. Samme antal cifre i kvotienten (fx 589 ÷ 4 = 147 → 3-cifret → eksempel skal også give 3-cifret resultat)
4. Samme rest-status (med rest → med rest, uden rest → uden rest). Hvis elevens opgave har terminerende decimal, skal eksemplet også have det

Dette sikrer at eleven ser et visuelt ensartet eksempel — samme antal rækker i slikkepinden, samme type slutresultat.

#### `generate_text(steps: list[dict]) → list[str]`

Danske templates:
- setup: "Vi skal finde ud af hvad {dividend} divideret med {divisor} giver"
- process_digit (første): "{group} divideret med {divisor} giver {quotient}, rest {remainder}"
- process_digit (følgende): "Resten {prev_remainder} sættes foran {next_digit}, det giver {group}. {group} divideret med {divisor} giver {quotient}, rest {remainder}"
- show_remainder: "Vi har rest {remainder}"
- show_fraction: "Det skriver vi som brøken {num}/{den}"
- show_decimal (kun terminerende): "{decimal} — det er det samme som brøken, bare skrevet med komma"
- reveal (ingen rest): "Svaret er {result}"
- reveal (med terminerende decimal): "Så svaret er {result}"
- reveal (med brøk, ikke-terminerende): "Svaret er {whole} og {num}/{den}"

Reveal-steget kører altid sidst — både som visuelt element (glow-animation på slutresultatet) og som tekstlinje. `show_decimal` står for selve konverterings-bridgen fra brøk til kommatal; reveal-linjen bekræfter sluttallet ovenpå det.

Bemærk at `{decimal}` er det fulde resultat (fx "147,25"), ikke kun brøkdelen. At sige "1/4 er det samme som 147,25" ville være matematisk misvisende — derfor formulerer skabelonen det som "147,25 er det samme som brøken, skrevet med komma", hvilket læser korrekt når eleven lige har set show_fraction-steget ("147 og 1/4").

### Integration i `example_generator.py`

- Ny funktion `should_use_short_division(topic)` → `True` hvis `topic == "division"`
- `generate_example()` router til `generate_short_division_example()`:
  1. Parser dividend og divisor fra assignment (struktureret data)
  2. `pick_example_numbers(dividend, divisor)` → nye eksempeltal
  3. `compute_steps(ex_dividend, ex_divisor)` → deterministiske steps
  4. `generate_text(steps)` → danske tekster
  5. Saml til `ExampleResponse` med `AnimationStep`-liste

### VisualInstruction actions

Type: `"short_division"`

| Action | Flat params |
|--------|-------------|
| `setup` | `dividend: int`, `divisor: int`, `digits: [int]` |
| `process_digit` | `position: int`, `group_value: int`, `quotient_digit: int`, `remainder: int`, `leading: bool`, `expression: str` |
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
   - Divisor (cirkel, 48pt diameter, 3px border). Ciffer inde i cirklen: **Marker Felt 28pt** — efterlader ca. 10pt luft hver side til encifrede divisorer som "9"
   - HStack pr. række:
     - Venstre (60pt bred): group-tal, rest i orange lille skrift foran
     - Lodret streg (3px)
     - Højre: quotient-ciffer i teal. Rækker med `leading: true` fra backend skjules helt (ingen plads reserveres)
   - Aktiv række: teal baggrund 0.1 opacity
   - Vandret streg (3px) i bunden
3. **Rest/brøk/decimal** — under slikkepinden som ekstra tekst-rækker
4. **Resultat** — "= 147,25" med glow

Styling: Marker Felt font 28pt konsekvent (group-tal, quotient-cifre, og ciffer inde i divisor-cirklen), 44pt celler, KvanteTheme.Colors (ink, primary/teal), identisk med stacked arithmetic. 28pt er valgt efter iPad-test — større font overfylder 60pt group-cellen når rest-tallet også skal stå i samme celle.

### State-livscyklus

`cumulativeShortDivisionState` følger samme mønster som `cumulativeGridState` i stacked arithmetic:

- **Nulstilles til `nil`** når `AnimationPlayer` modtager en ny `ExampleResponse` (ny opgave, nyt eksempel, eller retry). Dette sker i view-initialisering/`.onChange(of: response)` — *ikke* ved hver step.
- **Initialiseres** ved første `setup`-visual via `ShortDivisionState.from(visual:)`. `setup` er garanteret det første step i en animation.
- **Muteres** via `apply(visual:)` for hvert efterfølgende step i samme animation.
- **Bevares mellem steps** — det er hele pointen med "cumulative" state: rækker akkumuleres, aktiv række flyttes, brøk/decimal tilføjes oven i.

Hvis et step ankommer uden at state er initialiseret (fx `process_digit` før `setup`), er det en programmeringsfejl og bør logges — ikke silent ignoreres.

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
- Tocifret divisor (fx 864 ÷ 12) — hører til lang division i dansk folkeskole, ikke slikkepindsmetoden
- Multiplikation (kryds/lang) — separat feature
