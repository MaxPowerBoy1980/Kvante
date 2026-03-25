# Step-by-Step Animation Engine — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static ExampleView with an animated step-by-step explanation engine — the core value proposition of Kvante.

**Architecture:** Backend prompt updated to produce a structured animation JSON schema (8 visual component types with phase/action/params). SwiftUI renders each step with pre-built visual components and a hybrid playback model (auto-advance + tap-to-skip). One action per step, cumulative rendering for sequential same-type steps.

**Tech Stack:** Python/FastAPI (backend prompt + schema), SwiftUI/Swift (iOS visual components + playback engine), Gemini/Claude (LLM producing structured animation JSON)

**Spec:** `docs/superpowers/specs/2026-03-25-step-by-step-animation-engine.md`

---

### Task 1: Update Backend Pydantic Schema

**Files:**
- Modify: `backend/app/models/schemas.py:28-39` (replace ExampleStep + ExampleResponse)

- [ ] **Step 1: Update Pydantic models in schemas.py**

Replace the existing `ExampleStep` and `ExampleResponse` classes (lines 28-39) with the new animation schema models:

```python
class VisualInstruction(BaseModel):
    type: str       # object_collection, number_line, array_grid, grouping, pie_chart, bar_model, coordinate_grid, equation
    action: str     # type-specific action (draw, cross_out, jump_forward, etc.)

    model_config = {"extra": "allow"}  # Type-specific flat fields pass through


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

- [ ] **Step 2: Verify backend starts without errors**

Run: `cd /Users/oleserver/Kvante/backend && python -c "from app.models.schemas import ExampleResponse, AnimationStep, VisualInstruction; print('OK')"`

Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add backend/app/models/schemas.py
git commit -m "feat: update Pydantic schema for animation engine"
```

---

### Task 2: Update Backend Prompt

**Files:**
- Modify: `backend/app/prompts/generate_example.txt` (full rewrite)

- [ ] **Step 1: Rewrite the generate_example.txt prompt**

Replace the entire file with:

```text
You are Kvante, a warm and patient math tutor for students aged 9-13.

A student needs help understanding how to solve a math problem. You must create a WORKED EXAMPLE of a SIMILAR but DIFFERENT problem. You are showing them the METHOD, not giving them the answer.

## CRITICAL RULES
- You MUST use DIFFERENT NUMBERS than the student's actual assignment.
- The example problem must be obviously different so it cannot be confused with or copied as the answer.
- Never reveal or hint at the answer to the student's actual assignment.
- Maximum 8 steps per explanation.
- Maximum 30 objects for object_collection visuals. Use number_line instead for larger numbers.

## Pedagogical Progression

ALWAYS follow this order. Never skip backward:

1. **concrete** — Draw real objects the student can count (circles, apples, dots, groups)
2. **semi-concrete** — Use structured representations (number line, arrays, pie charts, bar models, coordinate grids)
3. **abstract** — Show the symbolic equation

Rules:
- Every explanation MUST start with at least one concrete step
- Every explanation MUST end with an abstract step (equation)
- Steps must progress: concrete -> semi-concrete -> abstract (never backward)
- For simple problems, semi-concrete can be skipped

## Visual Component Types

Each step must include a `visual` object. The `type` field determines which visual is rendered. Use ONLY these types:

### Concrete phase:
- `object_collection` — Draw/remove countable objects
  - Actions: `draw` (object, count, layout, rows), `cross_out` (count, from), `highlight_remaining` (label), `add` (object, count)
- `grouping` — Sort objects into equal groups
  - Actions: `place_objects` (count, object), `form_group` (group_index, size), `label_groups` (groups, per_group)

### Semi-concrete phase:
- `number_line` — Horizontal number line with jumps
  - Actions: `jump_forward` (start, jumps, size, min, max), `jump_backward` (start, jumps, size, min, max), `mark_point` (value, label, min, max)
- `array_grid` — Rows x columns of dots for multiplication
  - Actions: `build_row` (rows, columns), `highlight_row` (row_index), `show_total` (total, expression)
- `pie_chart` — Circular fraction diagram
  - Actions: `divide_circle` (parts), `fill_slices` (count, total), `label_fraction` (numerator, denominator)
- `bar_model` — Rectangular bar for fractions/area
  - Actions: `draw_bar` (segments), `split` (count), `fill_segment` (index, label), `label` (text, position)
- `coordinate_grid` — X/Y coordinate system
  - Actions: `draw_axes` (x_range, y_range), `plot_point` (x, y, label), `draw_line` (points)

### Abstract phase:
- `equation` — Symbolic math expression
  - Actions: `reveal` (parts, highlight)

## Output Format

Return ONLY valid JSON. All visual fields are FLAT on the visual object (not nested in a params dict).

{
  "example_problem": "the new problem with different numbers",
  "pedagogy": "concrete-first",
  "note": "reminder that this uses different numbers (in the student's language)",
  "steps": [
    {
      "step": 1,
      "phase": "concrete",
      "text": "explanation text shown to the student",
      "visual": {
        "type": "object_collection",
        "action": "draw",
        "object": "circle",
        "count": 15,
        "layout": "rows",
        "rows": 2
      },
      "audio_cue": "natural speech version of the text"
    }
  ]
}

## Rules for visual fields
- `type` and `action` are ALWAYS present on the visual object
- All other fields are flat siblings of type and action (NOT nested)
- One action per step. Multi-step sequences (draw then cross_out then highlight) become separate steps.
- `phase` must match the visual type (see component list above)

Write ALL text (text, audio_cue, note) in the student's language. If Danish, write in Danish. If English, write in English.
```

- [ ] **Step 2: Verify prompt file is readable**

Run: `cd /Users/oleserver/Kvante/backend && python -c "from app.config import settings; print(len((settings.prompts_dir / 'generate_example.txt').read_text()), 'chars')"`

Expected: Prints char count without error.

- [ ] **Step 3: Commit**

```bash
git add backend/app/prompts/generate_example.txt
git commit -m "feat: rewrite example prompt for animation schema"
```

---

### Task 3: Add Retry Logic to ExampleGeneratorService

**Files:**
- Modify: `backend/app/services/example_generator.py`
- Replace: `backend/tests/test_example_generator.py` (file exists with old-format tests — replace entirely)

- [ ] **Step 1: Write test for retry logic**

Create `backend/tests/test_example_generator.py`:

```python
import json
import pytest
from unittest.mock import patch, MagicMock
from app.services.example_generator import ExampleGeneratorService


VALID_RESPONSE = json.dumps({
    "example_problem": "15 - 3",
    "pedagogy": "concrete-first",
    "note": "Dette eksempel bruger andre tal.",
    "steps": [
        {
            "step": 1,
            "phase": "concrete",
            "text": "Vi tegner 15 cirkler.",
            "visual": {"type": "object_collection", "action": "draw", "object": "circle", "count": 15, "layout": "rows", "rows": 2},
            "audio_cue": "Vi tegner femten cirkler."
        },
        {
            "step": 2,
            "phase": "abstract",
            "text": "15 - 3 = 12",
            "visual": {"type": "equation", "action": "reveal", "parts": ["15", "-", "3", "=", "12"], "highlight": 4},
            "audio_cue": "Femten minus tre er lig med tolv."
        }
    ]
})

INVALID_RESPONSE = "This is not JSON at all"


def make_service_with_mock(responses):
    """Create ExampleGeneratorService with mocked AI client."""
    service = ExampleGeneratorService.__new__(ExampleGeneratorService)
    mock_client = MagicMock()
    mock_client.send_text = MagicMock(side_effect=responses)
    service.client = mock_client
    service._system_prompt = "test prompt"
    return service


def test_valid_response_parses():
    service = make_service_with_mock([VALID_RESPONSE])
    result = service.generate_example("subtraction", "simple subtraction", "17 - 8", "da")
    assert result["example_problem"] == "15 - 3"
    assert len(result["steps"]) == 2
    assert result["steps"][0]["visual"]["type"] == "object_collection"


def test_invalid_then_valid_retries():
    service = make_service_with_mock([INVALID_RESPONSE, VALID_RESPONSE])
    result = service.generate_example("subtraction", "simple subtraction", "17 - 8", "da")
    assert result["example_problem"] == "15 - 3"
    assert service.client.send_text.call_count == 2


def test_two_invalid_raises():
    service = make_service_with_mock([INVALID_RESPONSE, INVALID_RESPONSE])
    with pytest.raises(ValueError, match="Failed to parse"):
        service.generate_example("subtraction", "simple subtraction", "17 - 8", "da")


def test_too_many_steps_retries():
    many_steps = json.loads(VALID_RESPONSE)
    many_steps["steps"] = many_steps["steps"] * 5  # 10 steps, over max of 8
    service = make_service_with_mock([json.dumps(many_steps), VALID_RESPONSE])
    result = service.generate_example("subtraction", "simple subtraction", "17 - 8", "da")
    assert len(result["steps"]) <= 8
    assert service.client.send_text.call_count == 2
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/oleserver/Kvante/backend && python -m pytest tests/test_example_generator.py -v`

Expected: FAIL (current implementation lacks retry logic)

- [ ] **Step 3: Rewrite example_generator.py with retry logic**

Replace `backend/app/services/example_generator.py`:

```python
import json
import logging
import time

from app.config import settings
from app.services.ai_client import get_ai_client

logger = logging.getLogger(__name__)

MAX_STEPS = 8


class ExampleGeneratorService:
    def __init__(self):
        self.client = get_ai_client()
        self._system_prompt = (settings.prompts_dir / "generate_example.txt").read_text()

    def generate_example(
        self,
        assignment_type: str,
        assignment_topic: str,
        assignment_text: str,
        language: str = "da",
    ) -> dict:
        """Generate a worked example with animation instructions.

        Cardinal rule: The example must NEVER use the same numbers as the real assignment.
        Retries once on parse failure with the validation error included.
        """
        logger.info("Generating example for %s: '%s'", assignment_type, assignment_text)
        start = time.time()
        user_message = (
            f"Assignment type: {assignment_type}\n"
            f"Assignment topic: {assignment_topic}\n"
            f"Actual assignment (use DIFFERENT numbers): {assignment_text}\n"
            f"Student's language: {language}\n\n"
            f"Create a worked example with different numbers. Return JSON."
        )

        from pydantic import ValidationError
        from app.models.schemas import ExampleResponse as ExampleResponseModel

        last_error = None
        for attempt in range(2):
            if attempt == 0:
                raw = self.client.send_text(self._system_prompt, user_message)
            else:
                logger.warning("Retry after parse error: %s", last_error)
                correction = (
                    f"Your previous response was not valid. "
                    f"Error: {last_error}\n\n"
                    f"Please try again with valid JSON in the required format."
                )
                raw = self.client.send_text(self._system_prompt, f"{user_message}\n\n{correction}")

            try:
                parsed = self._parse_json(raw)
            except (json.JSONDecodeError, ValueError) as e:
                last_error = str(e)
                continue

            if len(parsed.get("steps", [])) > MAX_STEPS:
                last_error = f"Too many steps ({len(parsed['steps'])}), maximum is {MAX_STEPS}"
                continue

            # Validate against Pydantic schema before returning
            try:
                ExampleResponseModel(**parsed)
            except ValidationError as e:
                last_error = str(e)
                continue

            elapsed = time.time() - start
            logger.info(
                "Generated example for %s in %.1fs (attempt %d): %s",
                assignment_type,
                elapsed,
                attempt + 1,
                parsed.get("example_problem"),
            )
            return parsed

        raise ValueError(f"Failed to parse example after 2 attempts. Last error: {last_error}")

    def _parse_json(self, raw: str) -> dict:
        cleaned = raw.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]
        if cleaned.endswith("```"):
            cleaned = cleaned.rsplit("```", 1)[0]
        return json.loads(cleaned.strip())
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/oleserver/Kvante/backend && python -m pytest tests/test_example_generator.py -v`

Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/example_generator.py backend/tests/test_example_generator.py
git commit -m "feat: add retry logic to ExampleGeneratorService"
```

---

### Task 4: iOS Animation Models (Swift Codable)

**Files:**
- Create: `ios/Kvante/Kvante/Models/AnimationModels.swift`
- Modify: `ios/Kvante/Kvante/Models/APIResponses.swift:42-53` (replace ExampleResponse)
- Delete: `ios/Kvante/Kvante/Models/ExampleStep.swift`

- [ ] **Step 1: Create AnimationModels.swift**

Create `ios/Kvante/Kvante/Models/AnimationModels.swift`:

```swift
import Foundation

// MARK: - Visual Instruction

/// Decoded from the flat JSON visual object. `type` and `action` are always present.
/// All other fields are type-specific and decoded into `params`.
struct VisualInstruction: Codable {
    let type: String
    let action: String
    let params: [String: AnyCodable]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        type = try container.decode(String.self, forKey: DynamicCodingKey(stringValue: "type")!)
        action = try container.decode(String.self, forKey: DynamicCodingKey(stringValue: "action")!)

        var extracted: [String: AnyCodable] = [:]
        for key in container.allKeys where key.stringValue != "type" && key.stringValue != "action" {
            // Bool MUST come before Int — JSON true/false can decode as Int in Swift
            if let boolVal = try? container.decode(Bool.self, forKey: key) {
                extracted[key.stringValue] = AnyCodable(boolVal)
            } else if let intVal = try? container.decode(Int.self, forKey: key) {
                extracted[key.stringValue] = AnyCodable(intVal)
            } else if let doubleVal = try? container.decode(Double.self, forKey: key) {
                extracted[key.stringValue] = AnyCodable(doubleVal)
            } else if let stringVal = try? container.decode(String.self, forKey: key) {
                extracted[key.stringValue] = AnyCodable(stringVal)
            } else if let arrayVal = try? container.decode([AnyCodable].self, forKey: key) {
                extracted[key.stringValue] = AnyCodable(arrayVal)
            }
        }
        params = extracted
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        try container.encode(type, forKey: DynamicCodingKey(stringValue: "type")!)
        try container.encode(action, forKey: DynamicCodingKey(stringValue: "action")!)
        for (key, value) in params {
            if let codingKey = DynamicCodingKey(stringValue: key) {
                try container.encode(value, forKey: codingKey)
            }
        }
    }

    // MARK: - Typed accessors

    func intParam(_ key: String) -> Int? {
        params[key]?.value as? Int
    }

    func stringParam(_ key: String) -> String? {
        params[key]?.value as? String
    }

    func stringArrayParam(_ key: String) -> [String]? {
        if let arr = params[key]?.value as? [AnyCodable] {
            return arr.compactMap { $0.value as? String }
        }
        return nil
    }
}

// MARK: - Animation Step

struct AnimationStep: Identifiable, Codable {
    var id: Int { step }
    let step: Int
    let phase: String
    let text: String
    let visual: VisualInstruction
    let audioCue: String

    enum CodingKeys: String, CodingKey {
        case step, phase, text, visual
        case audioCue = "audio_cue"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        step = try container.decode(Int.self, forKey: .step)
        phase = try container.decode(String.self, forKey: .phase)
        text = try container.decode(String.self, forKey: .text)
        visual = try container.decode(VisualInstruction.self, forKey: .visual)
        audioCue = try container.decodeIfPresent(String.self, forKey: .audioCue) ?? ""
    }
}

// MARK: - Helpers

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.intValue = intValue; self.stringValue = "\(intValue)" }
}

/// Type-erased Codable wrapper for heterogeneous JSON values
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Bool MUST come before Int — JSON true/false can decode as Int(1/0) in Swift
        if let bool = try? container.decode(Bool.self) { value = bool }
        else if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let string = try? container.decode(String.self) { value = string }
        else if let array = try? container.decode([AnyCodable].self) { value = array }
        else if let dict = try? container.decode([String: AnyCodable].self) { value = dict }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let bool = value as? Bool { try container.encode(bool) }
        else if let int = value as? Int { try container.encode(int) }
        else if let double = value as? Double { try container.encode(double) }
        else if let string = value as? String { try container.encode(string) }
        else if let array = value as? [AnyCodable] { try container.encode(array) }
    }
}
```

- [ ] **Step 2: Update ExampleResponse in APIResponses.swift**

Replace lines 42-53 in `ios/Kvante/Kvante/Models/APIResponses.swift`:

Old:
```swift
// MARK: - Example

struct ExampleResponse: Codable {
    let exampleProblem: String
    let steps: [ExampleStep]
    let note: String

    enum CodingKeys: String, CodingKey {
        case exampleProblem = "example_problem"
        case steps, note
    }
}
```

New:
```swift
// MARK: - Example

struct ExampleResponse: Codable {
    let exampleProblem: String
    let pedagogy: String
    let steps: [AnimationStep]
    let note: String

    enum CodingKeys: String, CodingKey {
        case exampleProblem = "example_problem"
        case pedagogy, steps, note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exampleProblem = try container.decode(String.self, forKey: .exampleProblem)
        pedagogy = try container.decodeIfPresent(String.self, forKey: .pedagogy) ?? "concrete-first"
        steps = try container.decode([AnimationStep].self, forKey: .steps)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}
```

- [ ] **Step 3: Keep ExampleStep.swift for now**

Do NOT delete `ExampleStep.swift` yet — `ExampleView.swift` still references it and will cause compile failures through Tasks 5-9. It will be deleted in Task 10 alongside ExampleView.swift.

- [ ] **Step 4: Verify project compiles**

Run: `cd /Users/oleserver/Kvante/ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5`

Expected: `BUILD SUCCEEDED` — ExampleView.swift still compiles because ExampleStep.swift is still present. The old `ExampleResponse` type collision is avoided because we replaced it in APIResponses.swift with the new version (which uses `AnimationStep`). ExampleView.swift will show errors because it references the old `ExampleResponse.steps` type — this is OK, ExampleView gets replaced in Task 10.

Note: If ExampleView causes type errors, temporarily comment out its body or add a `#if false` wrapper. The important thing is that all NEW code compiles.

- [ ] **Step 5: Commit**

```bash
git add ios/Kvante/Kvante/Models/AnimationModels.swift ios/Kvante/Kvante/Models/APIResponses.swift
git commit -m "feat: add Swift animation models, update ExampleResponse"
```

---

### Task 5: EquationView Visual Component

**Files:**
- Create: `ios/Kvante/Kvante/Views/VisualComponents/EquationView.swift`

Start with the simplest component — it's always the final step and validates the rendering pattern.

- [ ] **Step 1: Create EquationView.swift**

Create `ios/Kvante/Kvante/Views/VisualComponents/EquationView.swift`:

```swift
import SwiftUI

struct EquationVisualView: View {
    let visual: VisualInstruction
    let animate: Bool

    private var parts: [String] {
        visual.stringArrayParam("parts") ?? []
    }

    private var highlightIndex: Int? {
        visual.intParam("highlight")
    }

    @State private var visibleCount = 0

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                Text(part)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(partColor(index: index))
                    .shadow(
                        color: isHighlighted(index: index) ? .orange.opacity(0.6) : .clear,
                        radius: isHighlighted(index: index) ? 12 : 0
                    )
                    .opacity(index < visibleCount ? 1 : 0)
                    .scaleEffect(index < visibleCount ? 1 : 0.5)
                    .animation(.spring(duration: 0.4).delay(Double(index) * 0.3), value: visibleCount)
            }
        }
        .padding(20)
        .onAppear {
            if animate {
                visibleCount = parts.count
            }
        }
        .onChange(of: animate) { _, newValue in
            visibleCount = newValue ? parts.count : 0
        }
    }

    private func partColor(index: Int) -> Color {
        isHighlighted(index: index) ? .orange : .primary
    }

    private func isHighlighted(index: Int) -> Bool {
        highlightIndex == index
    }
}
```

- [ ] **Step 2: Verify file added to Xcode project and compiles**

The file should be picked up automatically by Xcode if in the right directory. Verify with a build.

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/VisualComponents/EquationView.swift
git commit -m "feat: add EquationVisualView component"
```

---

### Task 6: ObjectCollectionView Visual Component

**Files:**
- Create: `ios/Kvante/Kvante/Views/VisualComponents/ObjectCollectionView.swift`

- [ ] **Step 1: Create ObjectCollectionView.swift**

Create `ios/Kvante/Kvante/Views/VisualComponents/ObjectCollectionView.swift`:

```swift
import SwiftUI

struct ObjectCollectionVisualView: View {
    let visual: VisualInstruction
    let animate: Bool
    let cumulativeObjects: Int  // Objects from previous draw steps
    let cumulativeCrossedOut: Int  // Objects crossed out in previous steps
    let cumulativeRows: Int  // Row count from the original draw step

    private var action: String { visual.action }
    private var count: Int { visual.intParam("count") ?? 0 }
    private var objectShape: String { visual.stringParam("object") ?? "circle" }
    private var rows: Int { visual.intParam("rows") ?? cumulativeRows }  // Fall back to cumulative
    private var fromEnd: Bool { visual.stringParam("from") == "end" }
    private var label: String? { visual.stringParam("label") }

    private var totalObjects: Int {
        switch action {
        case "draw", "add": return cumulativeObjects + count
        default: return cumulativeObjects
        }
    }

    private var columns: Int {
        guard rows > 0 else { return totalObjects }
        return (totalObjects + rows - 1) / rows
    }

    @State private var visibleCount = 0
    @State private var crossedOutCount = 0
    @State private var showHighlight = false
    @State private var showLabel = false

    var body: some View {
        VStack(spacing: 12) {
            // Object grid
            let cols = max(columns, 1)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<cols, id: \.self) { col in
                            let index = row * cols + col
                            if index < totalObjects {
                                objectView(at: index)
                            }
                        }
                    }
                }
            }

            // Label
            if let label, showLabel {
                Text(label)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(16)
        .onAppear { if animate { startAnimation() } }
        .onChange(of: animate) { _, newValue in
            if newValue { startAnimation() }
        }
    }

    @ViewBuilder
    private func objectView(at index: Int) -> some View {
        let isNew = index >= cumulativeObjects
        let isCrossedOut = isCrossed(at: index)
        let isHighlighted = showHighlight && !isCrossed(at: index)

        ZStack {
            Circle()
                .fill(isHighlighted ? Color.green : Color.blue)
                .frame(width: 24, height: 24)
                .opacity(objectOpacity(at: index, isNew: isNew))
                .scaleEffect(isHighlighted ? 1.1 : 1.0)
                .animation(.spring(duration: 0.3), value: isHighlighted)

            if isCrossedOut {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.red)
            }
        }
        .modifier(ShakeModifier(shaking: isCrossedOut))
    }

    private func objectOpacity(at index: Int, isNew: Bool) -> Double {
        if !isNew { return 1.0 }
        return index < (cumulativeObjects + visibleCount) ? 1.0 : 0.0
    }

    private func isCrossed(at index: Int) -> Bool {
        let totalCrossed = cumulativeCrossedOut + crossedOutCount
        if fromEnd {
            return index >= (totalObjects - totalCrossed)
        } else {
            return index < totalCrossed
        }
    }

    private func startAnimation() {
        switch action {
        case "draw", "add":
            for i in 1...count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                    withAnimation(.spring(duration: 0.3)) { visibleCount = i }
                }
            }
        case "cross_out":
            visibleCount = 0 // All already visible
            for i in 1...count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                    withAnimation(.spring(duration: 0.2)) { crossedOutCount = i }
                }
            }
        case "highlight_remaining":
            withAnimation(.easeInOut(duration: 0.5)) { showHighlight = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring) { showLabel = true }
            }
        default: break
        }
    }
}

struct ShakeModifier: ViewModifier {
    let shaking: Bool
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: shaking) { _, isShaking in
                if isShaking {
                    withAnimation(.default.repeatCount(3, autoreverses: true).speed(4)) {
                        offset = 3
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { offset = 0 }
                }
            }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ios/Kvante/Kvante/Views/VisualComponents/ObjectCollectionView.swift
git commit -m "feat: add ObjectCollectionVisualView component"
```

---

### Task 7: NumberLineView, ArrayGridView, GroupingView

**Files:**
- Create: `ios/Kvante/Kvante/Views/VisualComponents/NumberLineView.swift`
- Create: `ios/Kvante/Kvante/Views/VisualComponents/ArrayGridView.swift`
- Create: `ios/Kvante/Kvante/Views/VisualComponents/GroupingView.swift`

These three components follow the same pattern established in Task 5 and 6. Each reads its params from the flat `VisualInstruction`, has an `animate` bool, and uses SwiftUI animations.

- [ ] **Step 1: Create NumberLineView.swift**

Create `ios/Kvante/Kvante/Views/VisualComponents/NumberLineView.swift`:

```swift
import SwiftUI

struct NumberLineVisualView: View {
    let visual: VisualInstruction
    let animate: Bool

    private var action: String { visual.action }
    private var start: Int { visual.intParam("start") ?? 0 }
    private var jumps: Int { visual.intParam("jumps") ?? 1 }
    private var size: Int { visual.intParam("size") ?? 1 }
    private var minVal: Int { visual.intParam("min") ?? 0 }
    private var maxVal: Int { visual.intParam("max") ?? (start + jumps * size + 2) }
    private var pointValue: Int { visual.intParam("value") ?? 0 }
    private var pointLabel: String { visual.stringParam("label") ?? "" }

    private var isForward: Bool { action == "jump_forward" }
    private var range: Int { max(maxVal - minVal, 1) }

    @State private var completedJumps = 0
    @State private var showPoint = false

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width - 40
            ZStack(alignment: .leading) {
                // Base line
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: width, height: 2)
                    .offset(x: 20, y: 60)

                // Tick marks
                ForEach(tickValues, id: \.self) { val in
                    let x = xPosition(for: val, width: width)
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(Color.secondary)
                            .frame(width: 1, height: 10)
                        Text("\(val)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .offset(x: 20 + x - 0.5, y: 55)
                }

                // Jump arcs
                if action == "jump_forward" || action == "jump_backward" {
                    ForEach(0..<completedJumps, id: \.self) { i in
                        let jumpStart = isForward ? start + i * size : start - i * size
                        let jumpEnd = isForward ? jumpStart + size : jumpStart - size
                        jumpArc(from: jumpStart, to: jumpEnd, width: width, label: isForward ? "+\(size)" : "-\(size)")
                    }
                }

                // Point marker
                if action == "mark_point" && showPoint {
                    let x = xPosition(for: pointValue, width: width)
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 12, height: 12)
                        .shadow(color: .orange.opacity(0.6), radius: 6)
                        .offset(x: 20 + x - 6, y: 54)
                        .transition(.scale)

                    Text(pointLabel)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                        .offset(x: 20 + x - 6, y: 38)
                }
            }
        }
        .frame(height: 100)
        .padding(16)
        .onAppear { if animate { startAnimation() } }
        .onChange(of: animate) { _, newValue in
            if newValue { startAnimation() }
        }
    }

    private var tickValues: [Int] {
        var vals: [Int] = [minVal, maxVal]
        if action == "jump_forward" || action == "jump_backward" {
            for i in 0...jumps {
                let val = isForward ? start + i * size : start - i * size
                if !vals.contains(val) { vals.append(val) }
            }
        }
        if action == "mark_point" && !vals.contains(pointValue) {
            vals.append(pointValue)
        }
        return vals.sorted()
    }

    private func xPosition(for value: Int, width: CGFloat) -> CGFloat {
        CGFloat(value - minVal) / CGFloat(range) * width
    }

    @ViewBuilder
    private func jumpArc(from: Int, to: Int, width: CGFloat, label: String) -> some View {
        let x1 = xPosition(for: from, width: width) + 20
        let x2 = xPosition(for: to, width: width) + 20
        let midX = (x1 + x2) / 2

        Path { path in
            path.move(to: CGPoint(x: x1, y: 55))
            path.addQuadCurve(
                to: CGPoint(x: x2, y: 55),
                control: CGPoint(x: midX, y: 20)
            )
        }
        .stroke(Color.blue, lineWidth: 2)

        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.blue)
            .position(x: midX, y: 15)
    }

    private func startAnimation() {
        switch action {
        case "jump_forward", "jump_backward":
            for i in 1...jumps {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
                    withAnimation(.spring(duration: 0.4)) { completedJumps = i }
                }
            }
        case "mark_point":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(duration: 0.4)) { showPoint = true }
            }
        default: break
        }
    }
}
```

- [ ] **Step 2: Create ArrayGridView.swift**

Create `ios/Kvante/Kvante/Views/VisualComponents/ArrayGridView.swift`:

```swift
import SwiftUI

struct ArrayGridVisualView: View {
    let visual: VisualInstruction
    let animate: Bool

    private var action: String { visual.action }
    private var rows: Int { visual.intParam("rows") ?? 1 }
    private var columns: Int { visual.intParam("columns") ?? 1 }
    private var highlightRow: Int? { visual.intParam("row_index") }
    private var total: Int? { visual.intParam("total") }
    private var expression: String? { visual.stringParam("expression") }

    @State private var visibleRows = 0
    @State private var showHighlight = false
    @State private var showTotal = false

    var body: some View {
        VStack(spacing: 12) {
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<columns, id: \.self) { _ in
                            Circle()
                                .fill(rowColor(row))
                                .frame(width: 20, height: 20)
                        }
                    }
                    .opacity(row < visibleRows ? 1 : 0)
                    .scaleEffect(row < visibleRows ? 1 : 0.3)
                    .animation(.spring(duration: 0.3).delay(Double(row) * 0.4), value: visibleRows)
                }
            }

            // Running total
            if action == "build_row" && visibleRows > 0 {
                Text("\(columns) x \(visibleRows) = \(columns * visibleRows)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // Show total label
            if let expression, showTotal {
                Text(expression)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(16)
        .onAppear { if animate { startAnimation() } }
        .onChange(of: animate) { _, newValue in
            if newValue { startAnimation() }
        }
    }

    private func rowColor(_ row: Int) -> Color {
        if showHighlight && row == highlightRow { return .orange }
        return .blue
    }

    private func startAnimation() {
        switch action {
        case "build_row":
            visibleRows = rows  // SwiftUI animates each row via delay
        case "highlight_row":
            visibleRows = rows
            withAnimation(.easeInOut(duration: 0.3)) { showHighlight = true }
        case "show_total":
            visibleRows = rows
            withAnimation(.spring) { showTotal = true }
        default: break
        }
    }
}
```

- [ ] **Step 3: Create GroupingView.swift**

Create `ios/Kvante/Kvante/Views/VisualComponents/GroupingView.swift`:

```swift
import SwiftUI

struct GroupingVisualView: View {
    let visual: VisualInstruction
    let animate: Bool
    let cumulativeGrouped: Int  // Objects already grouped in prior steps

    private var action: String { visual.action }
    private var count: Int { visual.intParam("count") ?? 0 }
    private var groupIndex: Int { visual.intParam("group_index") ?? 0 }
    private var groupSize: Int { visual.intParam("size") ?? 1 }
    private var totalGroups: Int { visual.intParam("groups") ?? 1 }
    private var perGroup: Int { visual.intParam("per_group") ?? 1 }

    @State private var placedCount = 0
    @State private var formedGroup = false
    @State private var showLabels = false

    var body: some View {
        VStack(spacing: 16) {
            switch action {
            case "place_objects":
                // Show objects appearing in a cluster
                let cols = min(count, 8)
                let rows = (count + cols - 1) / cols
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(0..<rows, id: \.self) { row in
                        GridRow {
                            ForEach(0..<cols, id: \.self) { col in
                                let idx = row * cols + col
                                if idx < count {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 20, height: 20)
                                        .opacity(idx < placedCount ? 1 : 0)
                                        .animation(.spring(duration: 0.2).delay(Double(idx) * 0.08), value: placedCount)
                                }
                            }
                        }
                    }
                }

            case "form_group":
                // Show a group being formed
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        ForEach(0..<groupSize, id: \.self) { _ in
                            Circle()
                                .fill(formedGroup ? Color.green : Color.blue)
                                .frame(width: 20, height: 20)
                        }
                    }
                    if formedGroup {
                        Text("Gruppe \(groupIndex + 1)")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                }
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(formedGroup ? Color.green : Color.clear, lineWidth: 2)
                )

            case "label_groups":
                // Show all groups with labels
                HStack(spacing: 16) {
                    ForEach(0..<totalGroups, id: \.self) { i in
                        VStack(spacing: 4) {
                            HStack(spacing: 3) {
                                ForEach(0..<perGroup, id: \.self) { _ in
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 16, height: 16)
                                }
                            }
                            if showLabels {
                                Text("Gruppe \(i + 1)")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green, lineWidth: 1.5)
                        )
                    }
                }

            default:
                EmptyView()
            }
        }
        .padding(16)
        .onAppear { if animate { startAnimation() } }
        .onChange(of: animate) { _, newValue in
            if newValue { startAnimation() }
        }
    }

    private func startAnimation() {
        switch action {
        case "place_objects":
            placedCount = count
        case "form_group":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(duration: 0.4)) { formedGroup = true }
            }
        case "label_groups":
            withAnimation(.easeInOut(duration: 0.5).delay(0.2)) { showLabels = true }
        default: break
        }
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add ios/Kvante/Kvante/Views/VisualComponents/NumberLineView.swift \
        ios/Kvante/Kvante/Views/VisualComponents/ArrayGridView.swift \
        ios/Kvante/Kvante/Views/VisualComponents/GroupingView.swift
git commit -m "feat: add NumberLine, ArrayGrid, Grouping visual components"
```

---

### Task 8: PieChartView, BarModelView, CoordinateGridView

**Files:**
- Create: `ios/Kvante/Kvante/Views/VisualComponents/PieChartView.swift`
- Create: `ios/Kvante/Kvante/Views/VisualComponents/BarModelView.swift`
- Create: `ios/Kvante/Kvante/Views/VisualComponents/CoordinateGridView.swift`

- [ ] **Step 1: Create PieChartView.swift**

Create `ios/Kvante/Kvante/Views/VisualComponents/PieChartView.swift`:

```swift
import SwiftUI

struct PieChartVisualView: View {
    let visual: VisualInstruction
    let animate: Bool

    private var action: String { visual.action }
    private var parts: Int { visual.intParam("parts") ?? 4 }
    private var fillCount: Int { visual.intParam("count") ?? 0 }
    private var fillTotal: Int { visual.intParam("total") ?? parts }
    private var numerator: Int { visual.intParam("numerator") ?? fillCount }
    private var denominator: Int { visual.intParam("denominator") ?? fillTotal }

    @State private var filledSlices = 0
    @State private var showDivisions = false
    @State private var showFraction = false

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                .frame(width: 150, height: 150)

            // Filled slices
            ForEach(0..<filledSlices, id: \.self) { i in
                PieSlice(
                    startAngle: .degrees(Double(i) * 360.0 / Double(parts) - 90),
                    endAngle: .degrees(Double(i + 1) * 360.0 / Double(parts) - 90)
                )
                .fill(i == filledSlices - 1 ? Color.green : Color.blue)
                .frame(width: 150, height: 150)
                .transition(.opacity)
            }

            // Division lines
            if showDivisions {
                ForEach(0..<parts, id: \.self) { i in
                    let angle = Double(i) * 360.0 / Double(parts) - 90
                    Rectangle()
                        .fill(Color.secondary)
                        .frame(width: 1, height: 75)
                        .offset(y: -37.5)
                        .rotationEffect(.degrees(angle))
                }
            }

            // Fraction label
            if showFraction {
                Text("\(numerator)/\(denominator)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
        }
        .padding(16)
        .onAppear { if animate { startAnimation() } }
        .onChange(of: animate) { _, newValue in
            if newValue { startAnimation() }
        }
    }

    private func startAnimation() {
        switch action {
        case "divide_circle":
            withAnimation(.easeInOut(duration: 0.5)) { showDivisions = true }
        case "fill_slices":
            showDivisions = true
            for i in 1...fillCount {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4) {
                    withAnimation(.easeInOut(duration: 0.3)) { filledSlices = i }
                }
            }
        case "label_fraction":
            showDivisions = true
            filledSlices = numerator
            withAnimation(.spring.delay(0.2)) { showFraction = true }
        default: break
        }
    }
}

struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}
```

- [ ] **Step 2: Create BarModelView.swift**

Create `ios/Kvante/Kvante/Views/VisualComponents/BarModelView.swift`:

```swift
import SwiftUI

struct BarModelVisualView: View {
    let visual: VisualInstruction
    let animate: Bool

    private var action: String { visual.action }
    private var segments: Int { visual.intParam("segments") ?? visual.intParam("count") ?? 4 }
    private var fillIndex: Int { visual.intParam("index") ?? 0 }
    private var fillLabel: String { visual.stringParam("label") ?? "" }
    private var labelText: String { visual.stringParam("text") ?? "" }
    private var labelPosition: String { visual.stringParam("position") ?? "below" }

    @State private var visibleSegments = 0
    @State private var filledIndex: Int? = nil
    @State private var showLabel = false

    var body: some View {
        VStack(spacing: 8) {
            if showLabel && labelPosition == "above" {
                Text(labelText)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            }

            HStack(spacing: 0) {
                ForEach(0..<segments, id: \.self) { i in
                    Rectangle()
                        .fill(segmentColor(i))
                        .frame(height: 50)
                        .overlay(
                            Rectangle()
                                .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                        )
                        .overlay(
                            Group {
                                if i == filledIndex {
                                    Text(fillLabel)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                }
                            }
                        )
                        .opacity(i < visibleSegments ? 1 : 0.2)
                        .animation(.easeInOut(duration: 0.3).delay(Double(i) * 0.15), value: visibleSegments)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary, lineWidth: 2)
            )

            if showLabel && labelPosition != "above" {
                Text(labelText)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            }
        }
        .padding(16)
        .onAppear { if animate { startAnimation() } }
        .onChange(of: animate) { _, newValue in
            if newValue { startAnimation() }
        }
    }

    private func segmentColor(_ index: Int) -> Color {
        if index == filledIndex { return .blue }
        return Color.secondary.opacity(0.1)
    }

    private func startAnimation() {
        switch action {
        case "draw_bar", "split":
            visibleSegments = segments
        case "fill_segment":
            visibleSegments = segments
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.4)) { filledIndex = fillIndex }
            }
        case "label":
            visibleSegments = segments
            withAnimation(.spring.delay(0.2)) { showLabel = true }
        default: break
        }
    }
}
```

- [ ] **Step 3: Create CoordinateGridView.swift**

Create `ios/Kvante/Kvante/Views/VisualComponents/CoordinateGridView.swift`:

```swift
import SwiftUI

struct CoordinateGridVisualView: View {
    let visual: VisualInstruction
    let animate: Bool

    private var action: String { visual.action }
    private var xVal: Int { visual.intParam("x") ?? 0 }
    private var yVal: Int { visual.intParam("y") ?? 0 }
    private var pointLabel: String { visual.stringParam("label") ?? "(\(xVal), \(yVal))" }

    // Ranges default to 0-10
    private var xRange: [Int] { rangeParam("x_range") }
    private var yRange: [Int] { rangeParam("y_range") }
    private var xMin: Int { xRange.first ?? 0 }
    private var xMax: Int { xRange.last ?? 10 }
    private var yMin: Int { yRange.first ?? 0 }
    private var yMax: Int { yRange.last ?? 10 }

    private func rangeParam(_ key: String) -> [Int] {
        guard let anyCodable = visual.params[key],
              let array = anyCodable.value as? [AnyCodable] else { return [0, 10] }
        return array.compactMap { $0.value as? Int }
    }

    @State private var showGuideX = false
    @State private var showGuideY = false
    @State private var showPoint = false
    @State private var showAxes = false

    private let gridSize: CGFloat = 200

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Grid background
            Canvas { context, size in
                let stepX = size.width / CGFloat(xMax - xMin)
                let stepY = size.height / CGFloat(yMax - yMin)

                // Grid lines
                for i in 0...(xMax - xMin) {
                    let x = CGFloat(i) * stepX
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(.secondary.opacity(0.15)), lineWidth: 1)
                }
                for i in 0...(yMax - yMin) {
                    let y = size.height - CGFloat(i) * stepY
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(.secondary.opacity(0.15)), lineWidth: 1)
                }
            }
            .frame(width: gridSize, height: gridSize)
            .opacity(showAxes ? 1 : 0)

            // Axes
            if showAxes {
                // Y axis
                Rectangle()
                    .fill(Color.secondary)
                    .frame(width: 2, height: gridSize)
                // X axis
                Rectangle()
                    .fill(Color.secondary)
                    .frame(width: gridSize, height: 2)
                    .offset(y: gridSize - 2)
            }

            // Guide lines for plot_point
            if action == "plot_point" {
                let px = CGFloat(xVal - xMin) / CGFloat(xMax - xMin) * gridSize
                let py = gridSize - CGFloat(yVal - yMin) / CGFloat(yMax - yMin) * gridSize

                if showGuideX {
                    Path { path in
                        path.move(to: CGPoint(x: px, y: gridSize))
                        path.addLine(to: CGPoint(x: px, y: py))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.orange)
                }

                if showGuideY {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: py))
                        path.addLine(to: CGPoint(x: px, y: py))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.orange)
                }

                if showPoint {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 12, height: 12)
                        .shadow(color: .orange.opacity(0.6), radius: 6)
                        .offset(x: px - 6, y: py - 6)

                    Text(pointLabel)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                        .offset(x: px + 8, y: py - 16)
                }
            }
        }
        .frame(width: gridSize, height: gridSize)
        .padding(24)
        .onAppear { if animate { startAnimation() } }
        .onChange(of: animate) { _, newValue in
            if newValue { startAnimation() }
        }
    }

    private func startAnimation() {
        switch action {
        case "draw_axes":
            withAnimation(.easeInOut(duration: 0.5)) { showAxes = true }
        case "plot_point":
            showAxes = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.3)) { showGuideX = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeInOut(duration: 0.3)) { showGuideY = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                withAnimation(.spring(duration: 0.3)) { showPoint = true }
            }
        case "draw_line":
            showAxes = true
            // TODO: animate line drawing between points
        default: break
        }
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add ios/Kvante/Kvante/Views/VisualComponents/PieChartView.swift \
        ios/Kvante/Kvante/Views/VisualComponents/BarModelView.swift \
        ios/Kvante/Kvante/Views/VisualComponents/CoordinateGridView.swift
git commit -m "feat: add PieChart, BarModel, CoordinateGrid visual components"
```

---

### Task 9: VisualComponentView Router + AnimationPlayer

**Files:**
- Create: `ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift`
- Create: `ios/Kvante/Kvante/Views/AnimationPlayer.swift`

- [ ] **Step 1: Create VisualComponentView.swift**

Create `ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift`:

```swift
import SwiftUI

/// Routes a VisualInstruction to the correct visual component.
/// Falls back to plain text for unknown types.
struct VisualComponentView: View {
    let visual: VisualInstruction
    let animate: Bool
    let cumulativeObjects: Int
    let cumulativeCrossedOut: Int
    let cumulativeRows: Int
    let cumulativeGrouped: Int

    init(visual: VisualInstruction, animate: Bool,
         cumulativeObjects: Int = 0, cumulativeCrossedOut: Int = 0,
         cumulativeRows: Int = 2, cumulativeGrouped: Int = 0) {
        self.visual = visual
        self.animate = animate
        self.cumulativeObjects = cumulativeObjects
        self.cumulativeCrossedOut = cumulativeCrossedOut
        self.cumulativeRows = cumulativeRows
        self.cumulativeGrouped = cumulativeGrouped
    }

    var body: some View {
        switch visual.type {
        case "equation":
            EquationVisualView(visual: visual, animate: animate)
        case "object_collection":
            ObjectCollectionVisualView(
                visual: visual, animate: animate,
                cumulativeObjects: cumulativeObjects,
                cumulativeCrossedOut: cumulativeCrossedOut,
                cumulativeRows: cumulativeRows
            )
        case "number_line":
            NumberLineVisualView(visual: visual, animate: animate)
        case "array_grid":
            ArrayGridVisualView(visual: visual, animate: animate)
        case "grouping":
            GroupingVisualView(visual: visual, animate: animate, cumulativeGrouped: cumulativeGrouped)
        case "pie_chart":
            PieChartVisualView(visual: visual, animate: animate)
        case "bar_model":
            BarModelVisualView(visual: visual, animate: animate)
        case "coordinate_grid":
            CoordinateGridVisualView(visual: visual, animate: animate)
        default:
            // Fallback: unknown visual type — show nothing (text is shown by parent)
            EmptyView()
        }
    }
}
```

- [ ] **Step 2: Create AnimationPlayer.swift**

Create `ios/Kvante/Kvante/Views/AnimationPlayer.swift`:

```swift
import SwiftUI

@Observable
class AnimationPlayer {
    let steps: [AnimationStep]
    private(set) var currentStepIndex: Int = 0
    private(set) var isPlaying: Bool = false
    private var autoAdvanceTask: Task<Void, Never>?

    // Cumulative state for ObjectCollection
    private(set) var cumulativeObjects: Int = 0
    private(set) var cumulativeCrossedOut: Int = 0
    private(set) var cumulativeRows: Int = 2
    private(set) var cumulativeGrouped: Int = 0

    var currentStep: AnimationStep? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }

    var isAtEnd: Bool { currentStepIndex >= steps.count - 1 }
    var isAtStart: Bool { currentStepIndex <= 0 }

    init(steps: [AnimationStep]) {
        self.steps = steps
    }

    func play() {
        isPlaying = true
        scheduleAutoAdvance()
    }

    func pause() {
        isPlaying = false
        autoAdvanceTask?.cancel()
    }

    func nextStep() {
        guard !isAtEnd else { return }
        updateCumulativeState(for: steps[currentStepIndex])
        currentStepIndex += 1
        if isPlaying { scheduleAutoAdvance() }
    }

    func previousStep() {
        guard !isAtStart else { return }
        currentStepIndex -= 1
        recalculateCumulativeState()
        if isPlaying { scheduleAutoAdvance() }
    }

    func reset() {
        currentStepIndex = 0
        cumulativeObjects = 0
        cumulativeCrossedOut = 0
        cumulativeRows = 2
        cumulativeGrouped = 0
        isPlaying = false
        autoAdvanceTask?.cancel()
    }

    // MARK: - Auto-advance

    private func scheduleAutoAdvance() {
        autoAdvanceTask?.cancel()
        guard !isAtEnd else {
            isPlaying = false
            return
        }

        let delay = pauseDuration(for: steps[currentStepIndex])
        autoAdvanceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            if !Task.isCancelled && isPlaying {
                nextStep()
            }
        }
    }

    private func pauseDuration(for step: AnimationStep) -> Double {
        switch step.visual.type {
        case "equation": return 1.5
        case "object_collection":
            let count = step.visual.intParam("count") ?? 0
            return count > 10 ? 3.5 : 2.5
        case "array_grid": return 3.5
        case "number_line":
            let jumps = step.visual.intParam("jumps") ?? 1
            return 2.0 + Double(jumps) * 0.5
        default: return 2.5
        }
    }

    // MARK: - Cumulative state

    private func updateCumulativeState(for step: AnimationStep) {
        let v = step.visual
        switch (v.type, v.action) {
        case ("object_collection", "draw"), ("object_collection", "add"):
            cumulativeObjects += v.intParam("count") ?? 0
            if let rows = v.intParam("rows") { cumulativeRows = rows }
        case ("object_collection", "cross_out"):
            cumulativeCrossedOut += v.intParam("count") ?? 0
        case ("grouping", "place_objects"):
            break // Just placing, not grouping
        case ("grouping", "form_group"):
            cumulativeGrouped += v.intParam("size") ?? 0
        default: break
        }
    }

    private func recalculateCumulativeState() {
        cumulativeObjects = 0
        cumulativeCrossedOut = 0
        cumulativeRows = 2
        cumulativeGrouped = 0
        for i in 0..<currentStepIndex {
            updateCumulativeState(for: steps[i])
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/VisualComponents/VisualComponentView.swift \
        ios/Kvante/Kvante/Views/AnimationPlayer.swift
git commit -m "feat: add VisualComponentView router and AnimationPlayer"
```

---

### Task 10: AnimatedExplanationView + Wire Up

**Files:**
- Create: `ios/Kvante/Kvante/Views/AnimatedExplanationView.swift`
- Modify: `ios/Kvante/Kvante/Views/WorkingView.swift`
- Modify: `ios/Kvante/Kvante/Views/FeedbackView.swift`
- Delete: `ios/Kvante/Kvante/Views/ExampleView.swift`
- Delete: `ios/Kvante/Kvante/Models/ExampleStep.swift`

- [ ] **Step 1: Create AnimatedExplanationView.swift**

Create `ios/Kvante/Kvante/Views/AnimatedExplanationView.swift`:

```swift
import SwiftUI

struct AnimatedExplanationView: View {
    let example: ExampleResponse

    @State private var player: AnimationPlayer

    init(example: ExampleResponse) {
        self.example = example
        self._player = State(initialValue: AnimationPlayer(steps: example.steps))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Example problem header
            Text(example.exampleProblem)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.top, 16)

            // Steps
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(example.steps.enumerated()), id: \.element.id) { index, step in
                            StepCardView(
                                step: step,
                                isActive: index == player.currentStepIndex,
                                isCompleted: index < player.currentStepIndex,
                                animate: index == player.currentStepIndex,
                                cumulativeObjects: player.cumulativeObjects,
                                cumulativeCrossedOut: player.cumulativeCrossedOut,
                                cumulativeRows: player.cumulativeRows,
                                cumulativeGrouped: player.cumulativeGrouped
                            )
                            .id(step.step)
                            .opacity(index <= player.currentStepIndex ? 1 : 0.3)
                        }

                        // Note
                        if !example.note.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.blue)
                                Text(example.note)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 16)
                }
                .onChange(of: player.currentStepIndex) { _, newIndex in
                    let stepNum = example.steps[min(newIndex, example.steps.count - 1)].step
                    withAnimation { proxy.scrollTo(stepNum, anchor: .center) }
                }
            }

            // Controls
            HStack(spacing: 24) {
                Button {
                    player.previousStep()
                } label: {
                    Label("Forrige", systemImage: "chevron.left")
                        .font(.callout)
                }
                .disabled(player.isAtStart)

                Button {
                    if player.isPlaying {
                        player.pause()
                    } else {
                        player.play()
                    }
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }

                Button {
                    player.nextStep()
                } label: {
                    Label("Naeste trin", systemImage: "chevron.right")
                        .font(.callout)
                }
                .disabled(player.isAtEnd)
            }
            .padding(16)
            .background(.ultraThinMaterial)
        }
        .navigationTitle("Eksempel")
        .onAppear { player.play() }
    }
}

struct StepCardView: View {
    let step: AnimationStep
    let isActive: Bool
    let isCompleted: Bool
    let animate: Bool
    let cumulativeObjects: Int
    let cumulativeCrossedOut: Int
    let cumulativeRows: Int
    let cumulativeGrouped: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Step header
            HStack {
                Text("Trin \(step.step)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.orange, in: Capsule())

                Text(step.text)
                    .font(.subheadline)
                    .fontWeight(isActive ? .medium : .regular)

                Spacer()

                if isActive {
                    Text("Afspiller")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            // Visual component
            VisualComponentView(
                visual: step.visual,
                animate: animate,
                cumulativeObjects: cumulativeObjects,
                cumulativeCrossedOut: cumulativeCrossedOut,
                cumulativeRows: cumulativeRows,
                cumulativeGrouped: cumulativeGrouped
            )
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? Color.primary.opacity(0.05) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .opacity(isCompleted ? 0.6 : 1)
        .padding(.horizontal, 20)
    }
}
```

- [ ] **Step 2: Update WorkingView.swift — replace ExampleView with AnimatedExplanationView**

In `ios/Kvante/Kvante/Views/WorkingView.swift`, replace the `.sheet(isPresented: $showExample)` block (lines 44-53):

Old:
```swift
        .sheet(isPresented: $showExample) {
            if let example = exampleResponse {
                NavigationStack {
                    ExampleView(example: example)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Luk") { showExample = false }
                            }
                        }
                }
            }
        }
```

New:
```swift
        .sheet(isPresented: $showExample) {
            if let example = exampleResponse {
                NavigationStack {
                    AnimatedExplanationView(example: example)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Luk") { showExample = false }
                            }
                        }
                }
            }
        }
```

- [ ] **Step 3: Update FeedbackView.swift — same replacement**

In `ios/Kvante/Kvante/Views/FeedbackView.swift`, replace the `.sheet(isPresented: $showExample)` block (lines 52-62):

Old:
```swift
        .sheet(isPresented: $showExample) {
            if let example = exampleResponse {
                NavigationStack {
                    ExampleView(example: example)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Luk") { showExample = false }
                            }
                        }
                }
            }
        }
```

New:
```swift
        .sheet(isPresented: $showExample) {
            if let example = exampleResponse {
                NavigationStack {
                    AnimatedExplanationView(example: example)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Luk") { showExample = false }
                            }
                        }
                }
            }
        }
```

- [ ] **Step 4: Delete ExampleView.swift and ExampleStep.swift**

Delete `ios/Kvante/Kvante/Views/ExampleView.swift` and `ios/Kvante/Kvante/Models/ExampleStep.swift`.

- [ ] **Step 5: Verify full project compiles**

Run: `cd /Users/oleserver/Kvante/ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: Commit**

```bash
git add ios/Kvante/Kvante/Views/AnimatedExplanationView.swift
git add ios/Kvante/Kvante/Views/WorkingView.swift
git add ios/Kvante/Kvante/Views/FeedbackView.swift
git rm ios/Kvante/Kvante/Views/ExampleView.swift ios/Kvante/Kvante/Models/ExampleStep.swift
git commit -m "feat: wire up AnimatedExplanationView, replace static ExampleView"
```

---

### Task 11: End-to-End Verification

**Files:** None (testing only)

- [ ] **Step 1: Start backend and verify example endpoint returns new schema**

Run: `cd /Users/oleserver/Kvante/backend && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000`

Then in another terminal, test with curl (requires a valid session and assignment ID from a prior scan):

```bash
# First check health
curl http://localhost:8000/health

# If you have a session, test example generation:
# curl -X POST http://localhost:8000/sessions/{session_id}/assignments/{assignment_id}/example
```

Verify the response contains `pedagogy`, `phase`, `visual.type`, `visual.action` fields.

- [ ] **Step 2: Run backend tests**

Run: `cd /Users/oleserver/Kvante/backend && python -m pytest tests/ -v`

Expected: All tests pass.

- [ ] **Step 3: Test iOS in simulator**

Build and run in Xcode on iPad simulator. Scan a page, select an assignment, tap "Vis mig et eksempel". Verify:
- Steps appear one at a time with animations
- Visual components render correctly
- Playback controls work (pause, next, previous)
- Note appears at the bottom
- Tap-to-skip advances to next step

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: end-to-end verification fixes for animation engine"
```
