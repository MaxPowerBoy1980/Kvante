# Single-digit multiplikation — areal-model (design)

**Dato:** 2026-04-07
**Status:** Spec, klar til implementations-plan
**Forudgående arbejde:** `2026-04-07-long-multiplication-visual.md`

## Baggrund og problem

Lang multiplikation (`2026-04-07-long-multiplication-visual.md`) dækker `larger ≥ 10` cases (fx 178 × 23). Single-digit multiplikation (begge operander 1-9, fx 7 × 9) blev bevidst ekskluderet fra det scope fordi den lodrette opstillings-metode ikke giver mening for så små tal.

I dag falder single-digit multiplikation gennem til den eksisterende LLM-fallback path som genererer en `array_grid` visual med spredte cirkler. Resultatet er ulæseligt for elever — 63 cirkler i et 7×9 grid spredt med tilfældige spacings ligner kaos, ikke en multiplikation.

Denne spec specificerer en dedikeret deterministisk pipeline for 2-9 × 2-9, med areal-modellen som den centrale visuelle metafor: hver multiplikation er et rektangel hvor hver celle = 1 enhedsareal.

## Mål

1. Eleven ser `7 × 9` som et rent 7×9 rektangel af kvadrater — ikke spredte objekter.
2. Rektanglet bygges op række for række med skip-counting, så multiplikation læses som "k grupper af n".
3. Hele oplevelsen er deterministisk (ingen LLM, ingen retries) og spejler det eksisterende mønster fra `long_multiplication`, `short_division` og `stacked_arithmetic`.
4. Featuren respekterer kardinalreglen: eksempler bruger ALDRIG samme tal som elevens opgave (heller ikke commutative duplikater som 9×7 for 7×9).

## Eksplicit ude af scope

- **Bro til lang multiplikation** (partitioneret areal-model `7 × 12 = 7×10 + 7×2`). Får sin egen brainstorm når vi har set 2-9 × 2-9 i klasseværelset.
- **AI fejlanalyse** ved forkert svar (TODO #3, separat feature).
- **TTS / lyd** — `audio_cue` populeres korrekt, men der findes ikke TTS-infrastruktur i appen endnu.
- **Refaktorering af eksisterende `ArrayGridVisualView`** (LLM-styret cirkel-version). Den bevares uændret som fallback for cases vi ikke fanger (1×N osv.).
- **Sub-step animation inden for én row** (celle-for-celle). Granularitets-niveauet er række, ikke celle.
- **Persistens af elevens svar** (TODO #4, separat feature).

## Centrale designbeslutninger

| # | Beslutning | Valg |
|---|---|---|
| 1 | Cell-stil | Fyldte kvadrater (areal-model) |
| 2 | Buildup-mønster | Række for række, skip-counting |
| 3 | Try-yours | Kun tekst-prompt, ingen grid |
| 4 | Narration-struktur | Trin per række (multi-bobble) |
| 5 | Boble-ordlyd | Hybrid: `8`, `+ 8 = 16`, `+ 8 = 24`, ... |
| 6 | Scope | 2-9 × 2-9, fald gennem ellers |
| 7 | Operand-rækkefølge | Bevares (a = rækker, b = pr. række) |
| 8 | Bro til lang multiplikation | Out of scope |
| 9 | OCR-path | Default Apple OCR (ikke backend Vision) |

Disse beslutninger blev nået gennem trin-for-trin brainstorm med pædagogiske overvejelser; de er ikke vilkårlige. Centrale begrundelser:

- **Fyldte kvadrater (1)** vinder over outline-celler eller cirkler fordi det matcher folkeskole-læseplanens "areal som model" og er den reneste rektangel-metafor.
- **Række for række (2)** vinder over kolonne for kolonne fordi det matcher den intuitive læsning af "k × n" som "k grupper af n", og fordi vi læser top-til-bund i denne kontekst.
- **Kun tekst-prompt for try-yours (3)** vinder over et tomt grid med konturer, fordi outline-celler stadig kan tælles og dermed bryder kardinalreglen i sin ånd.
- **Multi-bobble (4)** vinder over én animeret besked fordi feedback fra første live-test af lang multiplikation viste at tekst-tunge enkeltsteps overvælder eleven. Mange korte bobler er bedre end få lange.
- **Hybrid ordlyd (5)** vinder over alternativer fordi den er kortest mens den stadig viser additionen som en kæde.
- **Bevaret operand-rækkefølge (7)** vinder over normalisering fordi 7×9 og 9×7 så bliver to forskellige visuelle oplevelser — kommutativitet bliver synlig som "samme areal, anden orientering".

## Arkitektur

Spejler det etablerede mønster fra `long_multiplication`, `short_division` og `stacked_arithmetic`:

```
backend/
  app/services/single_digit_multiplication.py     ← NY: deterministisk service
  app/services/example_generator.py               ← MOD: ny routing-gren
  tests/test_single_digit_multiplication.py       ← NY
  tests/test_example_generator_routing.py         ← MOD: tilføj cases

ios/Kvante/Kvante/Views/VisualComponents/
  ArrayGridCleanView.swift                        ← NY: deterministisk render
  VisualComponentView.swift                       ← MOD: routing til ny view
  AnimationPlayer.swift                           ← MOD: cumulative state thread
```

**Kerneprincipper:**
- 100% deterministisk — ingen LLM, ingen JSON-parse, ingen retries
- Backend-service har præcis 3 metoder: `compute_steps()`, `pick_example_numbers()`, `generate_text()` (samme API som søsterservices)
- iOS view er pure: input = `ArrayGridState` struct, ingen netværk, ingen LLM
- Den eksisterende `ArrayGridVisualView` (LLM-styret cirkel-version) bevares **uændret** og bruges stadig af LLM-fallback. Vi rører ikke den. Den nye komponent har et nyt visual `type`-navn (`single_digit_array`) for at undgå konflikt.

## Backend-service

**Fil:** `backend/app/services/single_digit_multiplication.py`

```python
class SingleDigitMultiplicationService:

    @staticmethod
    def compute_steps(a: int, b: int) -> list[dict]:
        """Producer display-order step dicts for a × b.

        Begge operander 2-9. Caller skal IKKE normalisere — vi bevarer
        elevens læseretning: a er antal rækker, b er antal i hver række.
        """
        assert 2 <= a <= 9 and 2 <= b <= 9, "Both operands must be 2-9"

        steps: list[dict] = [{
            "step": "setup",
            "rows": a,
            "cols": b,
        }]

        for i in range(a):
            steps.append({
                "step": "row",
                "row_index": i,
                "row_value": b,
                "cumulative": (i + 1) * b,
            })

        steps.append({
            "step": "reveal",
            "result": a * b,
        })

        return steps

    @staticmethod
    def pick_example_numbers(a: int, b: int) -> tuple[int, int]:
        """Pick (ex_a, ex_b) ≠ (a, b) og ≠ (b, a). Begge 2-9.

        Bevarer (rows, cols)-rolle. Deterministisk fallback hvis 200
        random tries fejler.
        """

    @staticmethod
    def generate_text(steps: list[dict]) -> list[dict]:
        """Generér dansk narration. Returnerer [{text, audio_cue}, ...].

        - setup → "Lad os finde {a} × {b}. Vi bygger {a} rækker med {b} i hver."
        - row, index 0 → "{b}"
        - row, index > 0 → "+ {b} = {cumulative}"
        - reveal → "{a} × {b} = {result}"
        """
```

**Step-tælling per problem-størrelse:**

| Opgave | Steps (uden try-yours) |
|---|---|
| 2 × 2 | 4 (1 setup + 2 row + 1 reveal) |
| 6 × 8 | 8 |
| 9 × 9 | 11 |

`MAX_STEPS=8` håndhæves kun for LLM-genererede examples i `example_generator.py:180`. Deterministiske services bypasser denne grænse allerede (long_mult kan også overskride for større cases). Vi følger samme konvention.

## Visual instructions (JSON-format)

Hvert backend-step bliver til en `ChatMessage` med en `VisualInstruction`. Format:

```json
// Setup
{
  "step": 1,
  "phase": "concrete",
  "text": "Lad os finde 6 × 8. Vi bygger 6 rækker med 8 i hver.",
  "visual": {
    "type": "single_digit_array",
    "action": "setup",
    "rows": 6,
    "cols": 8
  },
  "audio_cue": "6 gange 8"
}

// Row (én per række, 0-indexed)
{
  "step": 3,
  "phase": "concrete",
  "text": "+ 8 = 16",
  "visual": {
    "type": "single_digit_array",
    "action": "row",
    "row_index": 1,
    "row_value": 8,
    "cumulative": 16
  },
  "audio_cue": "16"
}

// Reveal
{
  "step": 8,
  "phase": "concrete",
  "text": "6 × 8 = 48",
  "visual": {
    "type": "single_digit_array",
    "action": "reveal",
    "result": 48
  },
  "audio_cue": "Svaret er 48"
}

// Try-yours (text only — INGEN visual instruction)
{
  "step": 9,
  "phase": "concrete",
  "text": "Nu er det din tur — kan du regne 7 × 9? Skriv svaret på papir og scan.",
  "visual": null,
  "audio_cue": "Prøv selv med 7 gange 9"
}
```

**Vigtig detalje — try-yours uden visual:**
For long_multiplication har try-yours en `setup` visual med elevens egne tal i et tomt grid. Vi besluttede at single-digit IKKE skal vise elevens tal som grid (kardinal-reglen + tællelig outline). Derfor: `visual: null` på try-yours-step.

Dette kræver en **schema-ændring** på begge sider:

**Backend** (`backend/app/models/schemas.py:39`):
```python
visual: VisualInstruction        # FØR
visual: Optional[VisualInstruction] = None    # EFTER
```

**iOS Codable model** (`ios/Kvante/Kvante/Models/AnimationModels.swift`):
- Linje 111: `let visual: VisualInstruction` → `let visual: VisualInstruction?`
- Linje 114-119: opdater init-signatur
- Linje 132: `try container.decode(VisualInstruction.self, forKey: .visual)` → `try container.decodeIfPresent(VisualInstruction.self, forKey: .visual)`

**iOS call-sites der læser `step.visual` (komplet grep-audit, alle skal håndtere optional):**

| Fil | Linje | Brug | Strategi |
|---|---|---|---|
| `Models/AnimationModels.swift` | 111, 114-119, 132 | Type-deklaration + decoder | Type til optional, decodeIfPresent |
| `ViewModels/ChatViewModel.swift` | 265-279 | Bygger cumulative state i loop | Wrap if/else if-kæden i `if let v = s.visual { ... }` |
| `Views/AnimationPlayer.swift` | 87 | `switch step.visual.type` i pauseDuration | Returner default (2.5s) hvis nil — se "pauseDuration når visual er nil" nedenfor |
| `Views/AnimationPlayer.swift` | 90, 94 | `step.visual.intParam(...)` i pauseDuration | N/A når 87 håndteres med early return |
| `Views/AnimationPlayer.swift` | 105 | `let v = step.visual` i updateCumulativeState | `guard let v = step.visual else { return }` i toppen |
| `Views/AnimatedExplanationView.swift` | 137 | `visual: step.visual` til VisualComponentView | `if let visual = step.visual { VisualComponentView(visual: visual, ...) }` — wrap rendering i if-let |
| `Views/Chat/ChatBubble.swift` | 283 | Samme | Samme if-let pattern |
| `Views/Chat/InlineExampleView.swift` | 121 | Samme | Samme if-let pattern |

`VisualComponentView` selv beholder sin non-optional `let visual: VisualInstruction` — den siger "render dette visual"; ansvaret for at håndtere fraværet ligger hos call-sites (try-yours vises som ren tekst-bobble uden visual-pad).

**pauseDuration når visual er nil: 2.5 sekunder.** Samme som default-branch i den eksisterende switch (linje 98). Try-yours er altid sidste step, så `isAtEnd`-vagt i `scheduleAutoAdvance` (linje 72-75) sætter alligevel `isPlaying = false` før denne værdi får praktisk betydning — men 2.5 er et fornuftigt fallback hvis et tekst-only step en dag dukker op midt i en sekvens.

## iOS visual component

**Fil:** `ios/Kvante/Kvante/Views/VisualComponents/ArrayGridCleanView.swift`

```swift
struct ArrayGridState {
    let rows: Int          // a (multiplikand, antal rækker)
    let cols: Int          // b (multiplikator, antal pr. række)

    var revealedRows: Int           // 0...rows
    var currentCumulative: Int?     // running total, nil før første row
    var showResult: Bool
    var resultText: String?

    static func from(visual: VisualInstruction) -> ArrayGridState {
        let rows = visual.intParam("rows") ?? 0
        let cols = visual.intParam("cols") ?? 0
        return ArrayGridState(rows: rows, cols: cols,
                              revealedRows: 0, currentCumulative: nil,
                              showResult: false, resultText: nil)
    }

    mutating func apply(visual: VisualInstruction) {
        switch visual.action {
        case "setup":
            // No-op: AnimationPlayer reassigns via from(visual:)
            break
        case "row":
            revealedRows = (visual.intParam("row_index") ?? 0) + 1
            currentCumulative = visual.intParam("cumulative")
        case "reveal":
            revealedRows = rows
            showResult = true
            if let r = visual.intParam("result") {
                resultText = String(r)
            }
        default: break
        }
    }
}

struct ArrayGridCleanView: View {
    let visual: VisualInstruction
    let animate: Bool
    let state: ArrayGridState

    private let cellSize: CGFloat = 24
    private let cellSpacing: CGFloat = 4

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: cellSpacing) {
                ForEach(0..<state.rows, id: \.self) { row in
                    HStack(spacing: cellSpacing) {
                        ForEach(0..<state.cols, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(KvanteTheme.Colors.primary)
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                    .opacity(row < state.revealedRows ? 1 : 0)
                    .scaleEffect(row < state.revealedRows ? 1 : 0.6)
                    .animation(.spring(duration: 0.35), value: state.revealedRows)
                }
            }

            if let cum = state.currentCumulative, !state.showResult {
                Text("\(cum)")
                    .font(.custom("Marker Felt", size: 22))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .transition(.opacity)
            }

            if state.showResult, let result = state.resultText {
                Text("\(state.rows) × \(state.cols) = \(result)")
                    .font(.custom("Marker Felt", size: 24))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .scaleEffect(1.05)
                    .shadow(color: .teal.opacity(0.6), radius: 8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(16)
    }
}
```

**Notes:**
- Følger samme `_State`-struct + `_View`-struct mønster som `LongMultiplicationView`/`ShortDivisionView`.
- Animation drives af SwiftUI via `.animation(_:value:)` på `revealedRows` — ingen manual `Task.sleep`.
- Cellfarve: `KvanteTheme.Colors.primary` (teal) — matcher "fyldte kvadrater" valgt i brainstorm.
- Cell size: 24pt med 4pt spacing → 9×9 ≈ 256pt bred. Passer i en chat-bobble på iPad.
- Running total under grid'et er en del af visualet — ikke kun en del af tekst-boblen. Lille redundans, men gør grid'et selvforklarende.

## VisualComponentView routing

**Fil:** `ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift`

Tilføj ny case og parameter for cumulative state:

```swift
let cumulativeArrayGridState: ArrayGridState?

// I body switch:
case "single_digit_array":
    if let state = cumulativeArrayGridState {
        ArrayGridCleanView(visual: visual, animate: animate, state: state)
    } else {
        ArrayGridCleanView(visual: visual, animate: animate,
                           state: ArrayGridState.from(visual: visual))
    }
```

## AnimationPlayer ændringer

**Fil:** `ios/Kvante/Kvante/Views/AnimationPlayer.swift`

`AnimationPlayer` skal akkumulere `ArrayGridState` på tværs af steps parallelt med den eksisterende håndtering af `LongMultiplicationState`, `ShortDivisionState`, `GridState`. Konkret:

1. **Property** (linje 17): tilføj `private(set) var cumulativeArrayGridState: ArrayGridState?`
2. **`reset()`** (linje 55-66): tilføj `cumulativeArrayGridState = nil`
3. **`pauseDuration(for:)`** (linje 86-100): refaktorer signatur til at håndtere optional visual først (`guard let visual = step.visual else { return 2.5 }`), derefter tilføj `case "single_digit_array": return 2.0` (rolig tempo til skip-counting)
4. **`updateCumulativeState(for:)`** (linje 104-133): tilføj `guard let v = step.visual else { return }` i toppen, derefter tilføj case for `("single_digit_array", _)` parallelt med long_multiplication-casen — initialiser fra setup, apply ellers
5. **`recalculateCumulativeState()`** (linje 135-145): tilføj `cumulativeArrayGridState = nil` til reset-sektionen

**Note om eksisterende preexisting bug:** `recalculateCumulativeState()` resetter ikke `cumulativeGridState` ved linje 135, hvilket ser ud til at være en bug i eksisterende kode. Det er IKKE i scope for denne spec — vi noterer det og lader det være.

## Routing

**Fil:** `backend/app/services/example_generator.py`

```python
def should_use_single_digit_multiplication(assignment_type: str,
                                           assignment_text: str,
                                           assignment_topic: str = "") -> bool:
    """Route multiplication where both operands are 2-9, no decimals.

    Text er autoritativ — hvis vi ikke kan parse en N × M expression
    returnerer vi False, ligesom should_use_long_multiplication.
    """
    if DECIMAL_PATTERN.search(assignment_text):
        return False
    operands = _parse_multiplication_operands(assignment_text)
    if operands is None:
        return False
    a, b = operands
    return 2 <= a <= 9 and 2 <= b <= 9
```

Routing-rækkefølge i `generate_example()`:

```python
if detected_op and should_use_stacked(...):
    return self.generate_stacked_example(...)

if should_use_single_digit_multiplication(...):       # NY — før long_mult
    return self.generate_single_digit_multiplication_example(...)

if should_use_long_multiplication(...):
    return self.generate_long_multiplication_example(...)

if should_use_short_division(...):
    return self.generate_short_division_example(...)

# fallback til LLM
```

Single-digit står før long_mult i kæden — funktionelt redundant (de er disjunkte), men logisk klarere ("simpler-first").

`generate_single_digit_multiplication_example()` følger samme struktur som `generate_long_multiplication_example()` (linjer 485-562 i nuværende `example_generator.py`): pick numbers → compute steps → generate text → assemble anim_steps → tilføj try-yours step.

**Hvad falder gennem til LLM-fallback?**
- 1 × N, N × 1, 0 × N → eksisterende `ArrayGridVisualView` (cirkler) eller hvad LLM vælger
- 13 × 7 → routes til long_mult (én operand ≥ 10)
- 2,5 × 3 → fallback (decimaler)

## OCR / submission-path

Single-digit submissions går gennem den **eksisterende default OCR-path** — `HandwritingOCR.swift` (Apple Vision-framework, on-device). Ingen ændring i `ChatViewModel.scanAnswer`.

Begrundelse: Eleven skriver bare ét tal (`63`) på papir — ingen kolonner, ingen menter, ingen forskydning. Apple OCR håndterer det fint, hurtigt og gratis. Vi reserverer backend Vision (LLM-baseret) til lang multiplikation hvor den columnar layout faktisk kræver det.

## Edge cases & guard-rails

**Operand-rækkefølge:**
- 7 × 9 → 7 rækker × 9 kolonner (bred rektangel)
- 9 × 7 → 9 rækker × 7 kolonner (høj rektangel)
- Ingen normalisering. Pædagogisk pointe: kommutativitet synlig som "samme areal, anden orientering".

**Eksempel-tal:**
- Hvis student er 7 × 9 må eksempel være hverken 7×9 eller 9×7 (commutative duplikat).
- 200 random tries + deterministisk fallback (samme mønster som `LongMultiplicationService.pick_example_numbers`).
- Begge operander 2-9. Ingen "trivial filter" på ×2 eller ×5 — alle 2-9 er pædagogisk meningsfulde.

**Symmetriske eksempler:**
- 5 × 5 (kvadrat) tilladt visuelt.
- Hvis student er 5 × 5, må eksempel være alt undtagen 5 × 5.

**Step-tæller worst case:**
- 9 × 9 = 11 steps + try-yours = 12. Mange chat-bobler men det var hele pointen med "trin per række".
- 2 × 2 = 5 steps inkl. try-yours, fint kort.

**Tom/bad input:**
- Tekst uden gyldigt `N × M`: `should_use_single_digit_multiplication` returnerer False → router videre. Ingen exceptions.
- `compute_steps(a, b)` asserter `2 <= a <= 9 and 2 <= b <= 9`. Hvis routing er korrekt skal disse aldrig fyre.

**ChatMessage med `visual: null`:**
Try-yours step har ingen visual. Verificer at:
1. Backend-schema (`ExampleResponse.steps[].visual`) tillader `Optional[VisualInstruction]`.
2. iOS `ChatMessage` rendrer text-only beskeder uden grid.

Hvis (1) ikke allerede er sandt, lille schema-justering er en del af implementations-planen.

## Test-strategi

**Backend service-tests** (`backend/tests/test_single_digit_multiplication.py`, ny):

1. `compute_steps(2, 2)` → 4 steps med korrekt struktur
2. `compute_steps(9, 9)` → 11 steps, sidste row har `cumulative=81`, reveal har `result=81`
3. `compute_steps(7, 9)` → 9 steps, alle row_value=9, cumulative 9, 18, ..., 63
4. `compute_steps(3, 8)` ≠ `compute_steps(8, 3)` (forskellige længder, ingen normalisering)
5. `compute_steps(1, 5)` → AssertionError (1 udenfor scope)
6. `compute_steps(10, 5)` → AssertionError
7. `pick_example_numbers(5, 7)` undgår eksakt duplikat (100 iterationer)
8. `pick_example_numbers(5, 7)` undgår commutative duplikat (100 iterationer)
9. `pick_example_numbers` bevarer (rows, cols)-rolle uden normalisering
10. `pick_example_numbers` returnerer altid begge i [2,9]
11. `generate_text` setup-formulering indeholder "{a} × {b}", "{a} rækker", "{b} i hver"
12. `generate_text` første row uden plus: text er bare `"{b}"`
13. `generate_text` efterfølgende rows: text er `"+ {b} = {cumulative}"`
14. `generate_text` reveal: text er `"{a} × {b} = {result}"`

**Routing-tests** (`backend/tests/test_example_generator_routing.py`, eksisterende — tilføj):

15. `should_use_single_digit_multiplication` positive: `"7 × 9"`, `"3 · 4"`, `"5*5"` → True
16. `should_use_single_digit_multiplication` negative: `"1 × 5"`, `"10 × 3"`, `"2,5 × 3"`, `"7 + 9"` → False
17. Routing-prioritet: `"7 × 9"` → single-digit, `"7 × 19"` → long_mult
18. Single-digit fyrer ikke for stacked: `"7 + 9"` → ikke single-digit

**Integration-test** (`backend/tests/test_example_generator.py`, eksisterende — tilføj):

19. `generate_example("6 × 8")` end-to-end:
    - Returnerer `ExampleResponse` med `steps[0].visual.type == "single_digit_array"`
    - Sidste reveal-step har `result=48` eller text indeholder `"= 48"`
    - `example_problem` er IKKE `"Regn ud: 6 × 8"` (forskellige tal end student)
    - Try-yours step har `visual is None` og text refererer til `"6 × 8"`

**iOS:**
- Ingen formelle unit-tests for SwiftUI views i projektet i dag.
- Tilføj `#Preview`-blocks for `ArrayGridCleanView` der dækker:
  - Initial state (rows=6, cols=8, ingen revealed)
  - Mid-state (revealedRows=3, cumulative=24)
  - Final state (showResult=true, resultText="48")
  - Worst case (9×9 fully revealed) — **både iPad-default OG iPhone SE preview** for at fange layout-fejl ved 320pt skærmbredde. iPhone SE er den smalleste konfiguration vi vil tjekke; hvis 9×9 ikke passer dér uden horisontal scroll, skal `cellSize` justeres ned fra 24pt.

**Manuel verifikation:**
- Genstart backend, scan en testopgave med `"7 × 9"`, request example, verificer at examplet bruger andre tal og at chat-bobler kommer i rækkefølge
- Sammenlign 9×9 worst case visuelt på iPad: passer det inden for chat-bobble bredden? Hvis ikke → reducer cellSize fra 24 til 20

## Acceptance criteria

Featuren er færdig når:

- [ ] Backend test suite passes for `SingleDigitMultiplicationService` (alle 14 service-tests + 4 routing-tests + 1 integration test)
- [ ] iOS bygger uden warnings (særligt: ingen Swift 6 concurrency warnings i den nye view)
- [ ] Manuel test: scan en seed-opgave med `"7 × 9"`, request example, verificer:
  - Eksemplet bruger andre tal end 7 × 9 og ikke 9 × 7
  - Setup-bobble har grid med korrekt dimensioner
  - Hver row-bobble viser en ny række med korrekt running total
  - Reveal-bobble viser slutresultatet med celebration treatment
  - Try-yours-bobble er tekst-only og refererer til elevens egne tal
- [ ] Manuel test: scan elevens svar (fx `"63"` på papir) for opgaven 7 × 9. OCR læser tallet, feedback genereres normalt
- [ ] 9 × 9 worst case passer i en chat-bobble på iPad uden horisontal scroll
- [ ] 9 × 9 worst case passer i `#Preview` på iPhone SE (320pt bred) uden horisontal scroll — verificerer mindste-skærms layout selvom appen i dag deployer til iPad
- [ ] Routing-prioritet verificeret: `"7 × 9"` → single-digit, `"7 × 19"` → long_mult
