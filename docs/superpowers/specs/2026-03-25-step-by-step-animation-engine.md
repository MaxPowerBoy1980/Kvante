# Step-by-Step Animation Engine — Design Spec

**Dato:** 2026-03-25
**Status:** Godkendt

## Maal

Erstat den statiske ExampleView med en animeret, paedagogisk forklaringsmotor. Eleven ser forklaringer udfolde sig trin-for-trin med visuelle animationer — som en laerer ved et whiteboard. Kernevaerdien i Kvante.

## Beslutninger

| Beslutning | Valg | Begrundelse |
|---|---|---|
| Rendering-strategi | Pre-built SwiftUI komponentbibliotek | LLM vaelger komponent + parametre. Forudsigeligt, performant, testbart. Udvidbart med nye typer. |
| Playback-model | Hybrid: auto-advance + tap-to-skip | Foeles som en laerer (auto), men eleven har kontrol (skip). Foregaaende trin forbliver synlige. |
| Paedagogisk progression | Konkret -> semi-konkret -> abstrakt | Haandhaeves i prompt. Hvert trin tagges med `phase`. |
| Audio (TTS) | Ikke i V1 | `audio_cue` felt i schema (fremtidssikret), ignoreres indtil TTS-service implementeres. |
| Backend-aendringer | Prompt + schema opdatering | Ingen nye endpoints. Eksisterende ExampleGeneratorService genbruges. |
| Kardinalregel | Haandhaeves i prompt | Eksempler bruger ALTID andre tal end den faktiske opgave. |
| Visual schema-form | Flade felter (ikke nested `params`) | Simplere for LLM at producere, simplere for Swift Codable. Type-specifik validering sker client-side. |
| Trin-model | Et visuelt action per trin | Multi-action sekvenser (tegn -> kryds ud -> highlight) bliver separate trin. Hvert trin er selvstændigt renderbart. |

## Animation Schema

Gemini returnerer dette JSON-format for hver forklaring. SwiftUI parser og renderer det.

### Top-level struktur

```json
{
  "example_problem": "19 - 6",
  "pedagogy": "concrete-first",
  "note": "Husk: dette eksempel bruger andre tal end din opgave.",
  "steps": [
    {
      "step": 1,
      "phase": "concrete",
      "text": "Vi starter med at tegne 19 cirkler.",
      "visual": {
        "type": "object_collection",
        "action": "draw",
        "object": "circle",
        "count": 19,
        "layout": "rows",
        "rows": 2
      },
      "audio_cue": "Vi starter med at tegne nitten cirkler."
    },
    {
      "step": 2,
      "phase": "concrete",
      "text": "Nu fjerner vi 6 cirkler.",
      "visual": {
        "type": "object_collection",
        "action": "cross_out",
        "count": 6,
        "from": "end"
      },
      "audio_cue": "Nu fjerner vi seks af dem."
    },
    {
      "step": 3,
      "phase": "concrete",
      "text": "Vi kan se, at der er 13 cirkler tilbage.",
      "visual": {
        "type": "object_collection",
        "action": "highlight_remaining",
        "label": "13"
      },
      "audio_cue": "Taeller vi dem, faar vi tretten."
    },
    {
      "step": 4,
      "phase": "abstract",
      "text": "19 - 6 = 13",
      "visual": {
        "type": "equation",
        "action": "reveal",
        "parts": ["19", "-", "6", "=", "13"],
        "highlight": 4
      },
      "audio_cue": "Nitten minus seks er lig med tretten."
    }
  ]
}
```

### Felter

| Felt | Type | Beskrivelse |
|---|---|---|
| `example_problem` | string | Eksempel-opgaven (ALDRIG den faktiske opgave) |
| `pedagogy` | string | Altid `"concrete-first"` i V1 |
| `note` | string | Paamindelse om at eksemplet bruger andre tal. Vises som info-boks efter alle trin. |
| `steps` | array | Ordnet liste af trin |
| `steps[].step` | int | Trin-nummer (1-indexed, unik, sekventiel) |
| `steps[].phase` | enum | `"concrete"`, `"semi-concrete"`, eller `"abstract"` |
| `steps[].text` | string | Tekst der vises til eleven (dansk) |
| `steps[].visual` | object | Visuelt komponent med `type`, `action` og type-specifikke felter (flade, ikke nested) |
| `steps[].audio_cue` | string | Tekst til fremtidig TTS (dansk, naturlig tale) |

### Visual-objekt form

Alle felter er flade paa `visual`-objektet. `type` og `action` er altid til stede. Oevrige felter er type- og action-specifikke:

```json
{
  "type": "number_line",
  "action": "jump_forward",
  "start": 12,
  "jumps": 3,
  "size": 4,
  "min": 10,
  "max": 26
}
```

Ikke:
```json
{
  "type": "number_line",
  "action": "jump_forward",
  "params": { "start": 12, "jumps": 3, "size": 4 }
}
```

I Swift dekodes dette via en custom `Codable` implementation der foerst laeser `type` og `action`, derefter dekoder oevrige felter til en type-specifik enum/struct.

### Trin-model: et action per trin

Hvert trin har praecis en `visual` med en action. Sekvenser der kraever flere actions (f.eks. subtraktion: tegn -> kryds ud -> highlight) bliver separate trin. Hvert trin er selvstaendigt renderbart.

**Cumulative rendering:** Trin der bruger samme `visual.type` i sekvens bygger paa hinanden visuelt. Naar trin 2 siger `cross_out` paa en `object_collection`, renderer iOS det oven paa resultatet af trin 1's `draw`. AnimationPlayer holder styr paa accumuleret tilstand per komponent-type.

**Forventet antal trin:** En typisk forklaring har 3-6 trin. Simple problemer (ren aritmetik) ca. 3-4 trin. Komplekse problemer (broeker, koordinater) ca. 5-6 trin. **Maksimum 8 trin.** Backend afviser (og retrier) responses med flere end 8 trin.

### Paedagogisk progression

Prompt-regler der haandhaeves:

1. Hver forklaring SKAL have mindst et `concrete` trin
2. Sidste trin SKAL vaere `abstract` (equation)
3. Trin SKAL progrediere i raekkefoelge: concrete -> semi-concrete -> abstract (aldrig baglaens)
4. For simple problemer kan `semi-concrete` springes over
5. `visual.type` SKAL matche `phase`:
   - concrete: `object_collection`, `grouping`
   - semi-concrete: `number_line`, `array_grid`, `pie_chart`, `bar_model`, `coordinate_grid`
   - abstract: `equation`

Disse regler haandhaeves i prompten. Backend og iOS validerer dem ikke — ved brud renderes trinene alligevel (graceful degradation).

## Visuelle Komponenter

8 SwiftUI-komponenter, hver med definerede actions og animations.

### 1. ObjectCollectionView

**Phase:** concrete
**Bruges til:** Addition, subtraktion
**Max count:** 30 objekter. Ved hoejere tal bruger LLM'en number_line i stedet.

| Action | Parametre | Animation |
|---|---|---|
| `draw` | `object` (circle/apple/dot), `count`, `layout` (rows/grid), `rows` | Objekter vises et ad gangen, venstre-til-hoejre, top-til-bund |
| `cross_out` | `count`, `from` (end/start) | Roede X tegnes over hvert objekt, et ad gangen, med let rysten |
| `highlight_remaining` | `label` | Tilbagevaerende objekter faar highlight, label vises nedenunder |
| `add` | `object`, `count` | Nye objekter tilfoeles med fade-in (til addition) |

### 2. NumberLineView

**Phase:** semi-concrete
**Bruges til:** Addition, subtraktion, skip-counting

| Action | Parametre | Animation |
|---|---|---|
| `jump_forward` | `start`, `jumps`, `size`, `min`, `max` | Buer animeres en ad gangen, markoer glider langs linjen. `min`/`max` definerer linjens raekkevide. |
| `jump_backward` | `start`, `jumps`, `size`, `min`, `max` | Samme som forward, men mod venstre |
| `mark_point` | `value`, `label`, `min`, `max` | Punkt pulserer ind paa linjen med label. Genbruger `min`/`max` fra foregaaende jump-trin hvis de er i samme sekvens. |

### 3. ArrayGridView

**Phase:** semi-concrete
**Bruges til:** Multiplikation

| Action | Parametre | Animation |
|---|---|---|
| `build_row` | `rows`, `columns` | Raekker vises en ad gangen med loebende total |
| `highlight_row` | `row_index` | Specifik raekke highlightes |
| `show_total` | `total`, `expression` | Total vises nedenunder (f.eks. "4 x 6 = 24") |

### 4. GroupingView

**Phase:** concrete
**Bruges til:** Division

| Action | Parametre | Animation |
|---|---|---|
| `place_objects` | `count`, `object` | Objekter vises i en bunke |
| `form_group` | `group_index`, `size` | De naeste `size` ugrupperede objekter bevaeger sig fra bunke til gruppe (foerst-til-sidst raekkefoelge). Cirkel tegnes rundt om. Cumulative state tracker antal grupperede objekter. |
| `label_groups` | `groups`, `per_group` | Labels vises under hver gruppe |

### 5. PieChartView

**Phase:** semi-concrete
**Bruges til:** Broeker

| Action | Parametre | Animation |
|---|---|---|
| `divide_circle` | `parts` | Cirkel deles med linjer (sweep animation) |
| `fill_slices` | `count`, `total` | Stykker fyldes et ad gangen med sweep |
| `label_fraction` | `numerator`, `denominator` | Broek vises i midten |

### 6. BarModelView

**Phase:** semi-concrete
**Bruges til:** Broeker, areal-modeller

`draw_bar` tegner en bar allerede delt i segmenter. `split` bruges naar en eksisterende bar (fra et foregaaende trin) skal deles yderligere.

| Action | Parametre | Animation |
|---|---|---|
| `draw_bar` | `segments` | Tom bar med `segments` antal segmenter vises |
| `split` | `count` | Eksisterende bar deles i `count` totale dele (ikke per segment — hele barren faar `count` lige store dele) |
| `fill_segment` | `index`, `label` | Segment fyldes med slide-animation |
| `label` | `text`, `position` (above/below) | Label vises over/under bar |

### 7. CoordinateGridView

**Phase:** semi-concrete
**Bruges til:** Koordinatsystemer

| Action | Parametre | Animation |
|---|---|---|
| `draw_axes` | `x_range` [min, max], `y_range` [min, max] | Akser og gitterlinjer tegnes |
| `plot_point` | `x`, `y`, `label` | Stiplede guide-linjer tegnes foerst (x saa y), punkt pulserer ind |
| `draw_line` | `points` [[x,y], ...] | Linje tegnes mellem punkter |

### 8. EquationView

**Phase:** abstract
**Bruges til:** Altid sidste trin

| Action | Parametre | Animation |
|---|---|---|
| `reveal` | `parts` (array af strings), `highlight` (index i parts-array) | Dele vises venstre-til-hoejre med fade, highlightet del faar glow-effekt |

## Playback-motor (AnimationPlayer)

### Tilstand

```
AnimationPlayer
  currentStep: Int
  isPlaying: Bool
  steps: [AnimationStep]
  cumulativeState: ComponentStateMap  // Typed state per komponent (ikke [String: Any] — dedikeret struct/enum per type)

  play()        // Start auto-advance
  pause()       // Pause
  nextStep()    // Spring til naeste (tap-to-skip)
  previousStep()// Gaa tilbage
  reset()       // Start forfra
```

### Adfaerd

- **Auto-advance:** Naar et trin er faerdigt med at animere, vent en pause baseret paa trin-kompleksitet: 1 sekund for equation, 2 sekunder for simple visuals (mark_point, label), 3 sekunder for komplekse visuals (draw med mange objekter, build_row). I fremtiden styres timing af TTS-varighed.
- **Tap-to-skip:** Eleven kan tappe "Naeste trin" naar som helst. Hvis nuvaerende animation koerer, spring den til completion og gaa videre.
- **Foregaaende trin:** Forbliver synlige ovenover (dimmet), scrollbar. Eleven kan scrolle op og se tidligere trin. Hvert trin vises som selvstaendigt kort med sit endelige visuelt resultat.
- **Cumulative visuals:** Naar flere trin bruger samme komponent-type i sekvens (f.eks. object_collection: draw -> cross_out -> highlight), holder AnimationPlayer styr paa accumuleret tilstand. Det aktive trin viser animationen; foregaaende trin viser snapshot af deres endelige resultat.
- **Kontroller:** "Forrige" og "Naeste trin" knapper i bunden. Auto-advance kan pauses.

### Layout

```
+----------------------------------+
|  Trin 1 (dimmed, completed)      |
|  [Visual snapshot]               |
+----------------------------------+
|  Trin 2 (active, animating)      |  <- auto-scrolls to keep active
|  [Visual animating...]           |     step visible
+----------------------------------+
|  Trin 3, 4 kommer...             |
+----------------------------------+
|  [< Forrige]   [Naeste trin >]   |
+----------------------------------+
|  [info] Husk: andre tal end din  |  <- note fra ExampleResponse
|  opgave.                         |
+----------------------------------+
```

## Fejlhaandtering

### LLM output validering

Det nye schema er IKKE bagudkompatibelt med det gamle ExampleResponse-format (felterne er forskellige). ExampleGeneratorService skal opdateres til at parse det nye format.

**Valideringsstrategi:**

1. **Backend:** Pydantic validerer top-level struktur (`step`, `phase`, `text`, `visual.type`, `visual.action`). Type-specifikke visual-felter valideres IKKE paa backend — de sendes videre som dict.
2. **Retry ved fejl:** Hvis Pydantic validation fejler (LLM returnerer ugyldigt JSON), retry en gang med en correction-prompt der inkluderer den faktiske valideringsfejl: "Dit svar var ikke gyldigt JSON. Fejl: {validation_error}. Proev igen med korrekt format." Hvis retry ogsaa fejler, returner fejl til iOS.
3. **iOS fallback:** Hvis et `visual.type` er ukendt, render kun `text`-feltet for det trin (graceful degradation). Eleven ser stadig forklaringen, bare uden animation.
4. **Phase-komponent validering:** Haandhaeves KUN i prompten. Hverken backend eller iOS afviser trin med forkert phase/type mapping — de renderes alligevel.

### HTTP fejl

Eksisterende fejlhaandtering i `routers/assignments.py` daeekker dette. 500-fejl ved uparserbart LLM-output fanges af retry-logikken ovenfor.

## Integration med eksisterende kode

### Backend

**Filer der aendres:**

1. `backend/app/prompts/generate_example.txt` — Omskriv prompt til at kraeve det nye animation-schema med `phase`, `visual`, `audio_cue`. Specificer komponent-typer og tilladte actions. Haandhaev paedagogisk progression. Specificer max 30 objekter for object_collection.

2. `backend/app/models/schemas.py` — Opdater `ExampleStep` og `ExampleResponse`:
   ```python
   class VisualInstruction(BaseModel):
       type: str       # object_collection, number_line, etc.
       action: str     # draw, cross_out, jump_forward, etc.

       model_config = {"extra": "allow"}  # Type-specifikke felter tillades

   class AnimationStep(BaseModel):
       step: int
       phase: str          # concrete, semi-concrete, abstract
       text: str
       visual: VisualInstruction
       audio_cue: str = ""

   class ExampleResponse(BaseModel):
       example_problem: str
       pedagogy: str = "concrete-first"
       steps: list[AnimationStep]
       note: str = ""
   ```

3. `backend/app/services/example_generator.py` — Tilfoej retry-logik: hvis JSON parsing fejler, send correction-prompt og proev igen (max 1 retry).

**Filer der IKKE aendres:**
- `main.py`, `ai_client.py`, `routers/assignments.py` — endpoint og service-kald er uaendrede.

### iOS

**Nye filer:**

1. `Views/AnimatedExplanationView.swift` — Erstatter ExampleView. Container for playback med step-liste, kontroller og note-visning.
2. `Views/AnimationPlayer.swift` — Playback state machine (currentStep, isPlaying, auto-advance, cumulativeState).
3. `Views/VisualComponents/ObjectCollectionView.swift`
4. `Views/VisualComponents/NumberLineView.swift`
5. `Views/VisualComponents/ArrayGridView.swift`
6. `Views/VisualComponents/GroupingView.swift`
7. `Views/VisualComponents/PieChartView.swift`
8. `Views/VisualComponents/BarModelView.swift`
9. `Views/VisualComponents/CoordinateGridView.swift`
10. `Views/VisualComponents/EquationView.swift`
11. `Views/VisualComponents/VisualComponentView.swift` — Switch paa `visual.type`, renderer den rigtige komponent. Ukendte typer falder tilbage til ren tekst-visning.
12. `Models/AnimationModels.swift` — Swift structs med custom Codable: dekod `type` og `action` foerst, derefter type-specifik enum for oevrige felter.

**Filer der aendres:**

1. `Views/WorkingView.swift` — Aendr `showExample` sheet til at bruge `AnimatedExplanationView` i stedet for `ExampleView`.
2. `Views/FeedbackView.swift` — Samme aendring for "Vis mig et andet eksempel".
3. `Models/ExampleStep.swift` — Erstattes af `AnimationModels.swift`.
4. `Models/APIResponses.swift` — Opdater `ExampleResponse` decoding.

**Filer der kan slettes:**
- `Views/ExampleView.swift` — Erstattes fuldt af AnimatedExplanationView.

## Fremtidige udvidelser (ikke i V1)

- **TTS integration:** `audio_cue` aflaeses via Plapre/anden TTS-service. Audio-varighed styrer auto-advance timing i stedet for faste pauser.
- **Nye komponent-typer:** Schema er udvidbart — tilfoej nye `visual.type` vaerdier (f.eks. `long_division`, `lollipop_method`) uden at aendre eksisterende kode.
- **Interaktive trin:** Eleven kan manipulere visuals (traek objekter, placer punkter) som en fremtidig udvidelse.
- **Chat-integration:** Naar chat-UI bygges (Phase 1), vises animerede forklaringer inline i chatten.

## Test-strategi

1. **Backend prompt-test:** Test at Gemini returnerer valid animation-schema for hvert opgavetype (addition, subtraktion, multiplikation, division, broeker, koordinater). Verificer paedagogisk progression. Test retry-logik med bevidst ugyldigt output.
2. **iOS komponenter:** Byg hvert visuelt komponent med hardcoded test-data foerst. Verificer animationer foer integration med backend.
3. **End-to-end:** Scan reel opgave -> generer animeret forklaring -> verificer det giver mening paedagogisk.
4. **Fallback-test:** Test at ukendte visual.type renderes som ren tekst. Test at manglende felter ikke crasher appen.
