# Lang multiplikation — visuel metode

**Dato:** 2026-04-07
**Status:** Spec — klar til implementation plan
**Ejer:** Claude + Olsen

## Problem

Kvante's multiplikations-opgaver bruger i dag LLM-genererede prikker (`object_collection` / `array_grid`). Det giver to problemer:

1. **Kardinalreglen brydes.** LLM'en bruger nogle gange samme tal som elevens opgave — fx observeret 2026-04-06: elev har 9 × 7, eksempel viser også 9 × 7 eller tæt på.
2. **Prikker er ulæselige ved store tal.** 9 × 7 = 63 prikker er for meget at tælle, og 14 × 206 er helt absurd. Eleverne kan ikke lære metoden fra noget uoverskueligt.

For division løste vi det med en deterministisk `ShortDivisionService` + ny `ShortDivisionView` (slikkepindsmetoden). Denne spec gør det samme for multiplikation.

## Løsning (overblik)

Byg lang multiplikation (standard opstilling med forskudte delprodukter) som en deterministisk backend-service + ny iOS-view. Samme arkitekturelle mønster som kort division — ingen LLM, ren aritmetik.

**Eksempel:** 14 × 206

```
     ₂                  (mente fra 6×4=24)
     2  0  6
  ×     1  4
  ──────────
     8  2  4            (partial 1: 206 × 4)
  2  0  6  ·            (partial 2: 206 × 1, forskudt én plads)
  ──────────
  2  8  8  4            (sum af delprodukter)
  ══════════
```

## Scope

### In scope (v1)

- Multiplikation hvor mindst én operand har ≥ 2 cifre (7 × 24, 14 × 206, 134 × 245)
- Max 3 cifre × 3 cifre (passer i 8-trin budget)
- Kun heltal
- Routing fra `ExampleGeneratorService.generate_example` når opgaven matcher
- Deterministisk eksempel-nummer-valg der matcher elevens ciffer-sværhedsgrad og aldrig bruger samme tal
- Mentale mellemregninger vises inden i hvert partial_product-trin (mente-cifre, udtryks-kæde, narration)
- "Prøv selv"-trin til sidst med elevens egne tal i tom opstilling

### Out of scope (senere)

- Decimal-multiplikation (3,4 × 2,5) — kommer i senere iteration
- Single × single (9 × 7) — falder stadig til LLM/array_grid-path (disse tal læres gennem gangetabeller, ikke opstilling)
- Multi-cifer × over 3 cifre — bevidst begrænsning, bliver ulæseligt på iPad
- Kryds-multiplikation (metode 1a fra `docs/design/2026-04-06-math-methods-reference.md`) — mindre almindelig i pensum, gemmes til evt. senere
- Automatiserede iOS-tests (Kvante har ingen Swift-test setup endnu)

## Arkitektur

**Ny deterministisk backend-service + ny iOS-view.** Ikke udvidelse af `stacked_arithmetic`.

**Hvorfor ikke udvide `stacked_arithmetic`?**

- `stacked_arithmetic` bygger på kolonner med mente mellem nabokolonner (addition/subtraktion). Multiplikation har et fundamentalt andet begreb: *delprodukter der forskydes*. Det mapper ikke 1:1 til kolonne-modellen.
- `stacked_arithmetic.py` er 234 linjer, `StackedArithmeticView.swift` 396 linjer. Tilføjes multiplikation bliver begge filer >600 linjer og gør to forskellige ting.
- En separat service er lettere at teste isoleret og ændre senere (fx når decimaler skal tilføjes).

### Nye filer

```
backend/app/services/long_multiplication.py
backend/tests/services/test_long_multiplication.py
ios/Kvante/Kvante/Views/VisualComponents/LongMultiplicationView.swift
```

### Eksisterende filer der ændres

```
backend/app/services/example_generator.py
  — tilføj should_use_long_multiplication() router
  — tilføj generate_long_multiplication_example() metode
  — integrér i generate_example() før short_division-branch

ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift
  — route visual.type == "long_multiplication" til LongMultiplicationView

ios/Kvante/Kvante/Models/VisualInstruction.swift
  — tilføj helper til at parse array-of-dict params (mental_steps). Hvis
    VisualInstruction allerede kan returnere [[String: Any]] via eksisterende
    API gøres intet; ellers tilføjes en `dictArrayParam(key:)` metode
```

## Backend service

### Interface

```python
class LongMultiplicationService:
    @staticmethod
    def compute_steps(multiplicand: int, multiplier: int) -> list[dict]:
        """Produce ordered step dicts: setup, partial_product × N, sum_partials, reveal."""

    @staticmethod
    def pick_example_numbers(multiplicand: int, multiplier: int) -> tuple[int, int]:
        """Pick example numbers of matching digit-count. Never same as student's."""

    @staticmethod
    def generate_text(steps: list[dict]) -> list[dict]:
        """Generate Danish narration text per step. Returns [{text, audio_cue}, ...]."""
```

### Validering i `compute_steps`

- `multiplicand > 0` og `multiplier > 0`
- Mindst ét tal har ≥ 2 cifre (single × single afvises med assertion; scope-valget routes dem ikke hertil)
- Max 3 cifre × 3 cifre (`multiplicand < 1000 and multiplier < 1000`)

### Operand-rækkefølge (større tal øverst)

For pædagogisk læsbarhed skal det **større tal altid stå øverst** i opstillingen (multiplicand-position). `compute_steps` forventer sin første parameter som det der skal stå øverst — kalderen er ansvarlig for at sortere.

`generate_long_multiplication_example` normaliserer før den kalder `compute_steps`:

```python
a, b = sorted([parsed_a, parsed_b], reverse=True)
# a >= b altid
ex_a, ex_b = LongMultiplicationService.pick_example_numbers(a, b)
steps = LongMultiplicationService.compute_steps(ex_a, ex_b)
```

`pick_example_numbers` bevarer denne invariant: returnerer altid `(større, mindre)` og matcher ciffer-antal separat per position.

### Step-strukturer

**`setup`:**
```python
{
    "step": "setup",
    "multiplicand": 206,
    "multiplier": 14,
    "multiplicand_digits": [2, 0, 6],
    "multiplier_digits": [1, 4],      # low-to-high order (ones first)
}
```

**`partial_product`** (ét per multiplier-ciffer, low-to-high). `value` og `digits` er **pre-shift** — den rå produktværdi. `shift` fortæller iOS-view'en hvor mange tomme pladser der skal tilføjes til højre for cifrene ved rendering.

Første delprodukt for 206 × 14 (ones-ciffer):
```python
{
    "step": "partial_product",
    "multiplier_digit": 4,
    "multiplier_position": 0,         # 0 = ones, 1 = tens, 2 = hundreds
    "value": 824,                      # pre-shift raw product (206 × 4)
    "digits": [8, 2, 4],               # pre-shift digits
    "shift": 0,                        # no placeholder cells
    "mental_steps": [
        {"expression": "6×4=24", "digit_written": 4, "carry_in": 0, "carry_out": 2, "column": 0},
        {"expression": "0×4+2=2", "digit_written": 2, "carry_in": 2, "carry_out": 0, "column": 1},
        {"expression": "2×4=8", "digit_written": 8, "carry_in": 0, "carry_out": 0, "column": 2},
    ],
    "expression_chain": "6×4=24 → 0×4+2=2 → 2×4=8",
}
```

Andet delprodukt for 206 × 14 (tens-ciffer) — bemærk `value=206` (pre-shift), ikke 2060:
```python
{
    "step": "partial_product",
    "multiplier_digit": 1,
    "multiplier_position": 1,
    "value": 206,                      # pre-shift (206 × 1)
    "digits": [2, 0, 6],
    "shift": 1,                        # én tom placeholder til højre → rendret som "206·"
    "mental_steps": [
        {"expression": "6×1=6", "digit_written": 6, "carry_in": 0, "carry_out": 0, "column": 0},
        {"expression": "0×1=0", "digit_written": 0, "carry_in": 0, "carry_out": 0, "column": 1},
        {"expression": "2×1=2", "digit_written": 2, "carry_in": 0, "carry_out": 0, "column": 2},
    ],
    "expression_chain": "6×1=6 → 0×1=0 → 2×1=2",
}
```

**`sum_partials`:**
```python
{
    "step": "sum_partials",
    "partials": [824, 2060],          # after shift applied (2060 not 206)
    "total": 2884,
}
```

**`reveal`:**
```python
{
    "step": "reveal",
    "result": 2884,
}
```

**"Prøv selv"-trin (`try_yours`)** — tilføjes IKKE af `compute_steps`, men af `generate_long_multiplication_example` efter `reveal`. Genbruger `setup`-action med elevens egne tal, så iOS-view rendrer den tomme opstilling (ingen partial products, ingen sum, ingen resultat). Strukturen:

```python
{
    "step": "setup",
    "multiplicand": <student's larger>,
    "multiplier": <student's smaller>,
    "multiplicand_digits": [...],
    "multiplier_digits": [...],
}
```

Teksten for dette trin er *"Prøv nu selv med din opgave — stil den op på samme måde!"* (samme som kort division).

### `pick_example_numbers` logik

- Match på ciffer-antal af begge operander (hvis eleven har 206 × 14 → eksempel også 3-cif × 2-cif)
- Afvis samme værdier som eleven
- Afvis trivielle tilfælde: `% 10 == 0` (multiplum af 10), enkelte små tal under 2
- Fallback: deterministiske værdier inden for samme range

### `generate_text` narration

Dansk tekst per trin-type. Eksempel for `partial_product` med `multiplier_digit=4`, `multiplier_position=0`, `value=824`, `mental_steps` som ovenfor:

> "Vi ganger 206 med 4. 6×4 er 24, vi skriver 4 og husker 2. 0×4 er 0 plus 2 er 2. 2×4 er 8. Det giver 824."

For `partial_product` med `multiplier_position=1` forklares forskydningen:

> "Nu ganger vi med tierne, 1. Vi starter én plads til venstre fordi det er tiere — så 206×1=206 bliver til 2060."

For `sum_partials`:

> "Vi lægger delprodukterne sammen: 824 + 2060 = 2884."

For `reveal`:

> "Svaret er 2884."

Alle narrationer returneres som `{"text": ..., "audio_cue": ...}`-dicts — samme format som `ShortDivisionService.generate_text`.

## Routing

### `should_use_long_multiplication` i `example_generator.py`

```python
def should_use_long_multiplication(assignment_type: str, assignment_text: str,
                                   assignment_topic: str = "") -> bool:
    """Route multiplication with at least one multi-digit operand, no decimals,
    and both operands within 3-digit range."""
    if not _is_multiplication(assignment_type, assignment_text, assignment_topic):
        return False
    if re.search(r'\d+[,.]\d+', assignment_text):
        return False  # decimals out of scope in v1
    numbers = [int(n) for n in re.findall(r'\d+', assignment_text)]
    if len(numbers) < 2:
        return False
    # Both operands must fit in 3-digit range (matches compute_steps validation)
    if any(n >= 1000 for n in numbers[:2]):
        return False
    # At least one operand must be multi-digit (scope choice B)
    return any(n >= 10 for n in numbers[:2])

def _is_multiplication(assignment_type: str, assignment_text: str,
                       assignment_topic: str = "") -> bool:
    if assignment_type == "multiplication" or assignment_topic == "multiplication":
        return True
    return bool(re.search(r'\d\s*[×*·]\s*\d', assignment_text)) or "gange" in assignment_text.lower()
```

### Integration i `generate_example`

```python
# Eksisterende
if detected_op and should_use_stacked(...):
    return self.generate_stacked_example(...)

# NY — før short_division check
if should_use_long_multiplication(assignment_type, assignment_text, assignment_topic):
    return self.generate_long_multiplication_example(assignment_text, language)

if should_use_short_division(assignment_topic):
    return self.generate_short_division_example(...)

# Fall through til LLM-path
```

Rækkefølgen er vigtig: multiplikations-check kommer FØR division-check så opgaver med `topic="multiplication"` ikke fejlagtigt routes til slikkepindsmetoden.

### `generate_long_multiplication_example` metode

Parallel til `generate_short_division_example`:

1. Parse elevens `multiplicand` og `multiplier` fra `assignment_text`
2. `LongMultiplicationService.pick_example_numbers(...)` → `ex_mc, ex_mp`
3. `LongMultiplicationService.compute_steps(ex_mc, ex_mp)` → `steps`
4. `LongMultiplicationService.generate_text(steps)` → `texts`
5. Map til `ExampleResponse` schema: hvert step bliver en `anim_steps`-entry med `visual.type="long_multiplication"` og relevante params
6. Tilføj "Prøv selv"-trin med elevens egne tal i en ny `setup`-visual (ingen animation state, kun opstillingen)
7. Returnér `{example_problem, pedagogy, steps, note}`

**Trin-budget worst case (245 × 134, 3×3):**
1. setup
2. partial 245 × 4 = 980 (shift 0)
3. partial 245 × 3 = 735 (shift 1, rendret 7350)
4. partial 245 × 1 = 245 (shift 2, rendret 24500)
5. sum_partials (980 + 7350 + 24500 = 32830)
6. reveal
7. try_yours

= **7 trin**. Under `MAX_STEPS = 8`. Passer.

**Single-partial specialtilfælde:** Når multiplier er enkelt-ciffer (fx 24 × 7), producerer `compute_steps` kun ét `partial_product` og **springer `sum_partials` over** — der er intet at summere. Trin-budget: setup + partial + reveal = 3 trin (+ try_yours = 4). `generate_long_multiplication_example` skal håndtere dette korrekt.

## iOS view

### `LongMultiplicationState` struct

```swift
struct LongMultiplicationState {
    let multiplicand: Int
    let multiplier: Int
    let multiplicandDigits: [Int]
    let multiplierDigits: [Int]

    var partials: [Partial]
    var activePartialIndex: Int?
    var currentExpressionChain: String?
    var currentCarries: [Int?]              // per multiplicand-column carry, nil = ingen
    var showSum: Bool
    var sumTotal: Int?
    var showResult: Bool
    var resultText: String?

    struct Partial {
        let value: Int
        let digits: [Int]
        let shift: Int
    }

    static func from(visual: VisualInstruction) -> LongMultiplicationState
    mutating func apply(visual: VisualInstruction)
}
```

### `apply(visual:)` switch-cases

- `"setup"` — initialiser multiplicand/multiplier, nulstil alt andet (også try_yours bruger denne)
- `"partial_product"` — append til `partials`, sæt `activePartialIndex`, sæt `currentExpressionChain`, byg `currentCarries` fra `mental_steps[*].carry_in` (se nedenfor)
- `"sum_partials"` — sæt `showSum = true`, `sumTotal = total`, clear `currentCarries`, clear `activePartialIndex`, clear `currentExpressionChain`
- `"reveal"` — sæt `showResult = true`, `resultText = String(result)`

**Carry-visning semantik:** På papir skrives en mente altid over *den kolonne hvor den skal bruges i næste beregning*. I vores mental_steps betyder det: hvis `mental_steps[i].carry_in > 0`, vises den værdi som lille ciffer over multiplicand-kolonne `i`. Eksempel for 206 × 4:

```
mental_steps[0] = {column: 0, carry_in: 0, carry_out: 2}  → ingen mente over kol. 0
mental_steps[1] = {column: 1, carry_in: 2, carry_out: 0}  → ₂ vises over kol. 1 (0-cifret)
mental_steps[2] = {column: 2, carry_in: 0, carry_out: 0}  → ingen mente over kol. 2
```

`currentCarries` er derfor et array med længde = antal multiplicand-cifre, hvor hvert element enten er `nil` (ingen mente) eller `Int` (mente-værdien der skal vises).

### Layout

**Monospace grid:**
- `cellSize: CGFloat = 36`
- Hver celle indeholder ét ciffer centreret med `Marker Felt` font
- Alle rækker højre-justerede så kolonner flugter

**Lag fra top til bund:**
1. Mente-række (lille, orange, 18pt): et ciffer over hver multiplicand-kolonne der har `currentCarries[col] != nil`
2. Multiplicand-række (28pt ink)
3. Multiplier-række med `×`-tegn (28pt ink)
4. Streg (3pt ink, fuld bredde)
5. Delprodukt-rækker (28pt ink, én per entry i `partials`). Shift = ekstra tomme celler til højre. Aktiv række har `primary.opacity(0.1)` baggrund
6. Sum-streg (3pt ink, kun når `showSum`)
7. Sum-række (28pt ink, kun når `showSum`)
8. Dobbelt-streg (to parallelle 3pt streger med 3pt gap, kun når `showResult`)

**Udtryks-boble:** Når `currentExpressionChain` er sat, vises den over hele grid'en i en RoundedRectangle med `primary.opacity(0.15)` baggrund og primary foreground — samme pattern som ShortDivisionView's `currentExpression`-label.

### Animationer

- Nye delprodukter: `.transition(.move(edge: .leading).combined(with: .opacity))`
- Cifre inden i et delprodukt falder ind fra højre mod venstre med ~80ms forsinkelse per ciffer (via indekseret `.delay()`)
- Mente-cifre: fader ind/ud med `.opacity`
- Udtryks-bobbel: `.transition(.scale.combined(with: .opacity))`
- Result-tal: spring-animation med scale + teal shadow (kopier fra ShortDivisionView)

### Preview

Tilføj `#Preview` der rendrer tre states:
1. Efter setup (tomt grid med 206 × 14)
2. Efter partial 1 (824 skrevet med mente ₂ synlig)
3. Efter reveal (fuld opstilling med sum og dobbeltstreg)

## Test-strategi

### Backend unit tests (`test_long_multiplication.py`)

Skal skrives TDD-style (rød → grøn → refactor) parallelt med service-koden.

**Test cases:**

1. **Compute correctness** — parameteriseret (alle input med større tal først, pr. operand-rækkefølge-invariant):
   - `compute_steps(24, 7) → 168` (single-digit multiplier, 1 partial product)
   - `compute_steps(14, 12) → 168` (2×2)
   - `compute_steps(206, 14) → 2884` (reference-eksempel, 3×2)
   - `compute_steps(245, 134) → 32830` (worst case 3×3)
   - `compute_steps(99, 99) → 9801` (max carries)
   - `compute_steps(100, 100) → 10000` (nuller)
   - Separat test for normalisering: `generate_long_multiplication_example` skal swappe `7 × 24`-input så multiplicand bliver 24, multiplier bliver 7 inden `compute_steps` kaldes

2. **Step structure** — for hvert par:
   - Første step er `setup`
   - Der er præcis ét `partial_product`-step per multiplier-ciffer
   - Der er præcis ét `sum_partials`-step **når der er ≥ 2 delprodukter**; `sum_partials` springes over hvis kun ét delprodukt
   - Sidste step fra `compute_steps` er `reveal`
   - Total step-count fra `compute_steps` ≤ 6 (så der er plads til try_yours tilføjet af `generate_long_multiplication_example`)

3. **Mental steps korrekthed** — for hvert `partial_product`:
   - Simulér cifer-for-cifer med carry
   - Verificér `digit_written`/`carry_out`-kæden
   - Verificér at cifrene kombineret giver `value`
   - Verificér at `mental_steps` er i korrekt rækkefølge (low-to-high column)

4. **Shift-korrekthed:**
   - Multiplier-ciffer i position N har `shift=N`
   - `partials` i `sum_partials` er skaleret korrekt (partial × 10^shift)

5. **`pick_example_numbers` constraints:**
   - Returnerer ALDRIG samme tal som input (kardinalregel — kør 50 iterationer og verificér)
   - Returnerer match på ciffer-antal for begge operander
   - Fallback-branch rammes når alle tilfældige forsøg fejler (tester med en seeded RNG eller monkey-patched `random.randint`)
   - Afviser `% 10 == 0` og under-2 tal

6. **`generate_text` smoke test:**
   - Hver step-type producerer ikke-tom dansk tekst
   - Ingen KeyError på manglende felter
   - Ingen engelske ord (regex check på "the", "and", "times", "plus")
   - Alle `{placeholder}` formatterings-steder er erstattet

### End-to-end test (`test_long_multiplication_e2e.py` eller tilføjet til eksisterende)

Kør `ExampleGeneratorService.generate_example` med en reel multiplikations-opgave. Verificér:

- Response matcher Pydantic `ExampleResponse`-schema
- `example_problem` formatteret som `"Regn ud: X × Y"`
- Hvert step har `visual.type == "long_multiplication"`
- Sidste step er `try_yours` (action=`"setup"`) med elevens egne tal
- Eksempel-tal er aldrig elevens tal

### iOS verifikation

- Ingen automatiserede tests (Kvante har intet Swift-test setup)
- Manuel verifikation via Xcode Preview + simulator
- Manuel verifikation i dev-screenshot flow: kør en opgave, tjek at animationerne fungerer

## Pædagogiske noter

- **Mentale mellemregninger** (mente-cifre + udtryks-kæde + narration) er centralt — eleven skal forstå *hvordan* delproduktet beregnes, ikke bare *at* det er 824
- **Forskydning forklares eksplicit** når multiplier-position > 0 ("vi starter én plads til venstre fordi det er tiere")
- **Kardinalreglen respekteres** fordi al aritmetik er deterministisk og `pick_example_numbers` aldrig returnerer elevens tal
- **"Prøv selv"-trinnet** viser elevens egen opgave i tom opstilling — inviterer til at stille op på papir, ikke at løse på skærm (paper-first-princippet)

## Afhængigheder og rækkefølge

Implementationen er uafhængig af andre åbne features. Kan bygges på sin egen branch og merges direkte til main.

Forslag til branch-navn: `feature/long-multiplication-visual`
