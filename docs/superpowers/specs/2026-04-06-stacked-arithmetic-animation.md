# Stacked Arithmetic Animation — Design Spec

**Dato:** 2026-04-06
**Status:** Under review
**Branch:** feature/animation-engine
**Extends:** 2026-03-25-step-by-step-animation-engine.md

## Mål

Tilføj en ny visuel type `stacked_arithmetic` der animerer den danske kolonneregning-metode (opstilling med lodrette kolonneskel). Dækker addition med tierovergang og subtraktion med lån. Op til 5 cifre.

## Beslutninger

| Beslutning | Valg | Begrundelse |
|---|---|---|
| Scope | Addition + subtraktion MVP | Strukturelt ens (kolonne-for-kolonne med overførsel). Udvidbart til multiplikation/division senere. |
| Ciffer-grænse | Op til 5 cifre (Tt, T, H, Ti, E) | Folkeskole-behov. Grid skalerer naturligt med flere kolonner. |
| Trin-beregning | Deterministisk backend-algoritme | Matematik SKAL være korrekt. LLM kan lave regnefejl. |
| Dansk tekst | LLM skriver tekst til hvert trin | Fleksibel, naturlig formulering. Isolerer sprogkvalitet fra matematik. |
| Layout | Dansk kolonnemethod med lodrette skillelinjer | Sådan lærer danske folkeskoleelever det. Ikke den angelsaksiske stacked-metode. |
| Visuel stil | Håndskrift-font (Marker Felt) | Matcher paper-first filosofi. Føles som en lærer der skriver. |
| Sub-trin gruppering | To beats per kolonne: lån/mente, derefter beregn | Balance mellem for langsomt (mikro-trin) og for hurtigt (alt-på-en-gang). |
| Tekst-visning | Simultant med animation | Tekst synlig med det samme i chat-boblen, grid animerer nedenunder. |
| Rendering | SwiftUI view med ZStack-celler | Følger eksisterende mønster. Canvas er overkill for en tabel med cifre. |
| TTS | Ikke i V1, `audio_cue` felt klar | Samme beslutning som original animation engine spec. |

## Arkitektur

### Overblik

```
┌─────────────────────────────────────────────────────────┐
│ ExampleGeneratorService (eksisterende)                   │
│                                                         │
│  1. LLM vælger eksempel-tal (andre end elevens)         │
│  2. StackedArithmeticService.compute_steps(op, a, b)    │
│     → Deterministiske grupperetrin (ren Python)          │
│  3. LLM tilføjer dansk text + audio_cue per trin         │
│  4. Returnerer ExampleResponse                           │
└──────────────────────────────┬──────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────┐
│ iOS: VisualComponentView router                          │
│  case "stacked_arithmetic" → StackedArithmeticView       │
│  (eksisterende AnimationPlayer håndterer state)          │
└─────────────────────────────────────────────────────────┘
```

### Backend: StackedArithmeticService

**Ny fil:** `backend/app/services/stacked_arithmetic.py`

Ren Python-klasse der tager `(operation, a, b)` og returnerer en liste af grupperede trin.

**Algoritme for subtraktion (83 - 47):**

1. Opdel begge tal i cifre, højrejusteret i kolonner
2. Iterer fra enere mod venstre (højre mod venstre)
3. For hver kolonne:
   - Hvis top-ciffer ≥ bund-ciffer: ren subtraktion → `compute` gruppe
   - Hvis top-ciffer < bund-ciffer: generer `borrow` gruppe (kryds ud, erstat, tilføj mente), derefter `compute` gruppe
   - Håndterer kæde-lån (f.eks. 1000 - 1: lån propagerer over flere kolonner)
4. Afslut med `answer` gruppe

**Algoritme for addition (83 + 47):**

1. Opdel begge tal i cifre, højrejusteret i kolonner
2. Iterer fra enere mod venstre
3. For hver kolonne:
   - Beregn sum + eventuel mente fra forrige kolonne
   - Hvis sum < 10: kun `compute` gruppe (beregn + skriv resultat)
   - Hvis sum ≥ 10: `compute` gruppe (beregn sum, skriv ener-ciffer i svar), derefter `carry` gruppe (ment til næste kolonne)
4. Afslut med `answer` gruppe

**Output-format (grupper):**

```python
@dataclass
class StepAction:
    action: str      # "draw_grid", "write_digit", "cross_out", etc.
    params: dict     # action-specifik data

@dataclass
class StepGroup:
    group: str       # "setup", "borrow", "carry", "compute", "answer"
    column: str | None  # "E", "Ti", "H", etc. (None for setup/answer)
    actions: list[StepAction]
```

**Kolonne-navne:**

| Cifre | Kolonner |
|-------|----------|
| 2 | Ti, E |
| 3 | H, Ti, E |
| 4 | T, H, Ti, E |
| 5 | Tt, T, H, Ti, E |

### Backend: Integration med ExampleGeneratorService

**Ændring i:** `backend/app/services/example_generator.py`

Ny flow for opgaver der passer til stacked arithmetic:

```python
# I generate_example():
if should_use_stacked(assignment_type, assignment_text):
    # 1. LLM vælger eksempel-tal
    example_numbers = await llm.pick_example_numbers(assignment)

    # 2. Deterministisk step-beregning
    groups = StackedArithmeticService.compute_steps(
        operation=assignment_type,
        a=example_numbers.a,
        b=example_numbers.b
    )

    # 3. LLM skriver dansk tekst per gruppe
    steps = await llm.write_step_text(groups, language)

    # 4. Wrap i ExampleResponse
    return ExampleResponse(
        example_problem=f"{a} {op} {b} = ?",
        steps=steps
    )
```

`should_use_stacked()` returnerer `True` for addition/subtraktion med tal > 30 (under 30 er dots/object_collection bedre).

### Backend: Pydantic Schema

**Tilføjelse i:** `backend/app/models/schemas.py`

Ingen nye modeller nødvendige. `VisualInstruction` bruger allerede `extra = "allow"`, så de stacked_arithmetic-specifikke felter passes igennem som flade nøgler.

### iOS: VisualInstruction Format

Hvert `AnimationStep` fra backend bruger `type: "stacked_arithmetic"` med disse actions:

**Setup:**
```json
{
  "type": "stacked_arithmetic",
  "action": "setup",
  "operation": "subtraction",
  "columns": ["Ti", "E"],
  "top": [8, 3],
  "bottom": [4, 7]
}
```

**Borrow (subtraktion):**
```json
{
  "type": "stacked_arithmetic",
  "action": "borrow",
  "column": "E",
  "cross_out_column": "Ti",
  "cross_out_old": 8,
  "replacement_value": 7,
  "carry_value": 1
}
```

**Carry (addition):**
```json
{
  "type": "stacked_arithmetic",
  "action": "carry",
  "from_column": "E",
  "to_column": "Ti",
  "carry_value": 1
}
```

**Compute:**
```json
{
  "type": "stacked_arithmetic",
  "action": "compute",
  "column": "E",
  "expression": "13 - 7 = 6",
  "result_value": 6
}
```

**Answer:**
```json
{
  "type": "stacked_arithmetic",
  "action": "answer",
  "value": 36
}
```

### iOS: StackedArithmeticView

**Ny fil:** `ios/Kvante/Kvante/Views/VisualComponents/StackedArithmeticView.swift`

**Grid-layout:**

```
┌─────┬─────┬─────┬─────┬─────┬─────┐
│     │ Tt  │  T  │  H  │  Ti │  E  │  ← headers (kun nødvendige kolonner)
├─────┼─────┼─────┼─────┼─────┼─────┤
│  −  │     │     │     │  8  │  3  │  ← top tal (højrejusteret)
│     │     │     │     │  4  │  7  │  ← bund tal
├─────┼─────┼─────┼─────┼─────┼─────┤
│     │     │     │     │  3  │  6  │  ← svar-række
└─────┴─────┴─────┴─────┴─────┴─────┘
```

**Celle-struktur (ZStack):**

Hver celle er en `ZStack` med lag:
1. **Baggrund**: Subtil highlight når kolonnen er aktiv (glow)
2. **Hoved-ciffer**: Marker Felt font, ~32pt, animerer ind med spring
3. **Overstregning**: Diagonal linje der animerer hen over cifret (for lån)
4. **Erstatnings-ciffer**: Lille (~16pt), rød, top-venstre i cellen
5. **Mente-ciffer**: Lille (~16pt), teal, top-venstre i nabocellen

**Kumulativ state:**

View'et modtager `currentStep: Int` og renderer alle actions fra step 1 til `currentStep`. Trin ud over `currentStep` er usynlige. Identisk mønster som `ObjectCollectionView`.

**State-model:**

```swift
struct GridState {
    let columns: [String]
    let topDigits: [Int?]        // nil = tom celle
    let bottomDigits: [Int?]
    var answerDigits: [Int?]
    var crossedOut: [String: Bool]       // kolonne → er overstreget
    var replacements: [String: Int]      // kolonne → erstatnings-ciffer
    var carries: [String: Int]           // kolonne → mente-ciffer
    var activeColumn: String?
    var showAnswer: Bool
}
```

View'et bygger `GridState` ved at replay alle actions op til `currentStep`.

**Animation timing:**

| Action | Animation | Varighed |
|--------|-----------|----------|
| `setup` | Cifre stagger ind (0.1s per ciffer) | ~1.5s |
| `borrow` | Highlight kolonne (0.3s) → overstregning (0.3s) → erstatning fade-in (0.3s) → mente fade-in (0.3s) | ~1.5s |
| `carry` | Mente-ciffer springer op til næste kolonne (spring animation) | ~0.8s |
| `compute` | Mini-ligning pulser → svar-ciffer skriver ind | ~1.2s |
| `answer` | Alle svar-cifre pulser sammen med glow | ~1.0s |

**Mini-ligning callout:**

Ved `compute` trin vises en lille fremhævet boks mellem teksten og grid'et:

```
  ┌─────────────────────┐
  │  13 − 7 = 6         │  ← teal baggrund, afrundede hjørner
  └─────────────────────┘
```

### iOS: VisualComponentView Router

**Ændring i:** `ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift`

Tilføj case:

```swift
case "stacked_arithmetic":
    StackedArithmeticView(
        steps: steps,
        currentStep: currentStep,
        animate: animate
    )
```

### iOS: AnimationPlayer

**Ændring i:** `ios/Kvante/Kvante/Views/AnimationPlayer.swift`

Tilføj pause-varighed:

```swift
case "stacked_arithmetic": return 2.5  // sekunder per beat
```

### Chat-integration

Ingen ændringer nødvendige i `ChatBubble` eller `ChatViewModel`. Det eksisterende flow håndterer allerede:

1. `ExampleResponse` med `steps[]` → gemmes i `pendingExampleSteps`
2. Hvert trin vises som chat-besked med tekst + visuelt komponent
3. `VisualComponentView` router sender `stacked_arithmetic` til den nye view
4. `AnimationPlayer` håndterer kumulativ state

## Filændringer

### Nye filer
| Fil | Beskrivelse |
|-----|-------------|
| `backend/app/services/stacked_arithmetic.py` | Deterministisk step-engine for addition/subtraktion |
| `ios/Kvante/Kvante/Views/VisualComponents/StackedArithmeticView.swift` | SwiftUI grid-animation view |

### Ændrede filer
| Fil | Ændring |
|-----|---------|
| `backend/app/services/example_generator.py` | Kald `StackedArithmeticService` for passende opgaver |
| `backend/app/prompts/generate_example.txt` | Tilføj `stacked_arithmetic` type-dokumentation + regler for hvornår den bruges |
| `ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift` | Tilføj router case |
| `ios/Kvante/Kvante/Views/AnimationPlayer.swift` | Tilføj pause-varighed |
| `ios/Kvante/Kvante/Models/AnimationModels.swift` | Eventuelle typed accessors for nye params |

## Afgrænsning

**Ikke i scope:**
- Multiplikation, division, brøker (senere udvidelse)
- TTS/audio (feltet er klar, implementering senere)
- Canvas-baseret rendering (SwiftUI er nok)
- Tal > 5 cifre
- Decimaltal

**Beslutninger udskudt:**
- Præcis threshold for hvornår `stacked_arithmetic` vælges over `object_collection` (starter med > 30)
- Mulighed for at eleven kan vælge mellem visuelt eksempel og stacked arithmetic

## Test-strategi

### Backend
- Unit tests for `StackedArithmeticService`: korrekte trin for alle edge cases
  - Simpel subtraktion uden lån (85 - 42)
  - Subtraktion med enkelt lån (83 - 47)
  - Subtraktion med kæde-lån (1000 - 1)
  - Simpel addition uden mente (23 + 14)
  - Addition med mente (67 + 85)
  - Addition med kæde-mente (999 + 1)
  - 5-cifret tal (12345 + 67890)
  - Edge: 0'er i top-tal (10000 - 1)

### iOS
- Preview med hardcoded steps for visuelt tjek
- Manuel test af kumulativ state (trin 1, 2, 3... viser korrekt akkumuleret grid)
- Test i chat-flow med backend
