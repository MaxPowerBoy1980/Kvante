# Feedback Sheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace three separate feedback sheets with one unified FeedbackSheet featuring gear-rating, Kvante pixelart, and conversational action buttons.

**Architecture:** Backend-first. Extend the existing `analyze_work.txt` prompt to return `gear_score` + `improvement_tip` alongside existing analysis fields. Add a typed `GearScore` Pydantic model with validation. On iOS, create a single `FeedbackSheet` view that replaces `FeedbackPreviewSheet`, `ErrorAnalysisSheet`, and `AssignmentDetailSheet`. Feedback text is generated lazily on-demand via the existing `POST /feedback/` endpoint.

**Tech Stack:** Python/FastAPI/Pydantic (backend), SwiftUI/Swift (iOS)

**Spec:** `docs/superpowers/specs/2026-04-12-feedback-sheet-design.md`

---

## File Map

### Backend — New/Modified
| File | Action | Responsibility |
|------|--------|----------------|
| `backend/app/models/schemas.py` | Modify | Add `GearScore` model, add fields to `BulkSubmitResult`, `SubmissionResponse`, `ArkAssignment` |
| `backend/app/prompts/analyze_work.txt` | Modify | Add `gear_score` and `improvement_tip` to expected JSON output |
| `backend/app/prompts/give_feedback.txt` | Modify | Update feedback style: ros-first, 2-3 sentences, uformelt dansk |
| `backend/app/services/work_analyzer.py` | Modify | Parse `gear_score` and `improvement_tip` from AI response with validation |
| `backend/app/services/bulk_scan_service.py` | Modify | Pass through `gear_score` and `improvement_tip` in result dicts |
| `backend/app/routers/bulk_submit.py` | Modify | Include new fields in Submission analysis dict |
| `backend/tests/test_gear_score.py` | Create | Tests for GearScore model validation |
| `backend/tests/test_bulk_submit_gear.py` | Create | Tests for gear_score in bulk-submit flow |

### iOS — New
| File | Action | Responsibility |
|------|--------|----------------|
| `ios/Kvante/Kvante/Views/Ark/GearShape.swift` | Create | Custom SwiftUI Shape for tandhjul icon |
| `ios/Kvante/Kvante/Views/Ark/GearRatingView.swift` | Create | HStack of 6 gear icons with fill state |
| `ios/Kvante/Kvante/Views/Ark/FeedbackSheet.swift` | Create | Unified feedback sheet replacing 3 old sheets |

### iOS — Modified
| File | Action | What changes |
|------|--------|-------------|
| `ios/Kvante/Kvante/Models/APIResponses.swift` | Modify | Add `GearScore` struct, add fields to `BulkSubmitResult` and `ArkAssignmentResponse` |
| `ios/Kvante/Kvante/Views/Ark/AssignmentSheetView.swift` | Modify | Replace FeedbackPreviewSheet/ErrorAnalysisSheet sheet bindings with FeedbackSheet |
| `ios/Kvante/Kvante/Views/Notebook/NotebookWeekView.swift` | Modify | Replace AssignmentDetailSheet with FeedbackSheet |
| `ios/Kvante/Kvante/Services/SessionViewModel.swift` | Modify | Add gear_score and improvement_tip dictionaries |

### iOS — Deleted
| File | Action | Why |
|------|--------|-----|
| `ios/Kvante/Kvante/Views/Ark/FeedbackPreviewSheet.swift` | Delete | Replaced by FeedbackSheet |
| `ios/Kvante/Kvante/Views/Ark/ErrorAnalysisSheet.swift` | Delete | Replaced by FeedbackSheet |
| `ios/Kvante/Kvante/Views/Notebook/AssignmentDetailSheet.swift` | Delete | Replaced by FeedbackSheet |

---

## Task 1: Backend — GearScore Pydantic model + schema updates

**Files:**
- Modify: `backend/app/models/schemas.py`
- Create: `backend/tests/test_gear_score.py`

- [ ] **Step 1: Write tests for GearScore validation**

Create `backend/tests/test_gear_score.py`:

```python
import pytest
from app.models.schemas import GearScore


def test_valid_gear_score():
    gs = GearScore(correct_answer=2, visible_method=1, notation=2)
    assert gs.total == 5


def test_gear_score_max():
    gs = GearScore(correct_answer=2, visible_method=2, notation=2)
    assert gs.total == 6


def test_gear_score_zero():
    gs = GearScore(correct_answer=0, visible_method=0, notation=0)
    assert gs.total == 0


def test_correct_answer_binary_clamp():
    """correct_answer=1 should clamp to 2 (generous)."""
    gs = GearScore(correct_answer=1, visible_method=1, notation=1)
    assert gs.correct_answer == 2
    assert gs.total == 4


def test_correct_answer_negative_clamps_to_zero():
    gs = GearScore(correct_answer=-1, visible_method=1, notation=1)
    assert gs.correct_answer == 0


def test_visible_method_clamps():
    gs = GearScore(correct_answer=2, visible_method=5, notation=1)
    assert gs.visible_method == 2


def test_notation_clamps():
    gs = GearScore(correct_answer=0, visible_method=0, notation=-3)
    assert gs.notation == 0


def test_gear_score_serialization():
    gs = GearScore(correct_answer=2, visible_method=1, notation=2)
    data = gs.model_dump()
    assert data == {
        "correct_answer": 2,
        "visible_method": 1,
        "notation": 2,
        "total": 5,
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_gear_score.py -v`
Expected: FAIL — `ImportError: cannot import name 'GearScore' from 'app.models.schemas'`

- [ ] **Step 3: Add GearScore model to schemas.py**

Add to `backend/app/models/schemas.py` after the imports:

```python
from pydantic import BaseModel, SerializeAsAny, field_validator, Field, computed_field
```

Then add the GearScore class (before BulkSubmitResult):

```python
class GearScore(BaseModel):
    correct_answer: int = Field(ge=0, le=2, description="0=forkert, 2=korrekt (binært)")
    visible_method: int = Field(ge=0, le=2, description="0=ingen, 1=noget, 2=alle trin")
    notation: int = Field(ge=0, le=2, description="0=rodet, 1=okay, 2=tydelig")

    @computed_field
    @property
    def total(self) -> int:
        return self.correct_answer + self.visible_method + self.notation

    @field_validator("correct_answer", mode="before")
    @classmethod
    def correct_answer_binary(cls, v: int) -> int:
        if v == 1:
            return 2
        return max(0, min(2, v))

    @field_validator("visible_method", "notation", mode="before")
    @classmethod
    def clamp_0_2(cls, v: int) -> int:
        return max(0, min(2, v))
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_gear_score.py -v`
Expected: All 8 tests PASS

- [ ] **Step 5: Add gear_score fields to BulkSubmitResult, SubmissionResponse, ArkAssignment**

In `backend/app/models/schemas.py`, add to `BulkSubmitResult` (after `bounding_box`):

```python
    gear_score: GearScore | None = None
    improvement_tip: str | None = None
```

Add to `SubmissionResponse` (after `confidence`):

```python
    gear_score: GearScore | None = None
    improvement_tip: str | None = None
```

Add to `ArkAssignment` (after `student_answer`):

```python
    gear_score: GearScore | None = None
    improvement_tip: str | None = None
```

- [ ] **Step 6: Run full test suite to verify no regressions**

Run: `cd backend && python -m pytest -v`
Expected: All existing tests pass (new optional fields don't break anything)

- [ ] **Step 7: Commit**

```bash
git add backend/app/models/schemas.py backend/tests/test_gear_score.py
git commit -m "feat(backend): add GearScore Pydantic model with validation"
```

---

## Task 2: Backend — Update analyze_work.txt prompt

**Files:**
- Modify: `backend/app/prompts/analyze_work.txt`

- [ ] **Step 1: Update analyze_work.txt to include gear_score and improvement_tip**

Add the following to the JSON output format section in `analyze_work.txt`, after the existing fields:

```
  "gear_score": {
    "correct_answer": 0 or 2,
    "visible_method": 0 or 1 or 2,
    "notation": 0 or 1 or 2
  },
  "improvement_tip": "string or null"
```

Add scoring instructions before the JSON format section:

```
## Gear Score — Vurdering af elevens arbejde

Udover analyse af metode, skal du vurdere elevens arbejde på tre kriterier:

1. **correct_answer** (0 eller 2): Er svaret korrekt? 0 = forkert, 2 = korrekt. Kun 0 eller 2 — ingen mellemværdi.

2. **visible_method** (0, 1 eller 2): Viser eleven sin metode?
   - 0: Ingen mellemregning — kun et svar uden arbejde
   - 1: Noget arbejde vist — dele af metoden synlig
   - 2: Alle trin tydeligt vist — fuld mellemregning, overskuelig process

3. **notation** (0, 1 eller 2): Hvor tydelig er opstillingen?
   - 0: Rodet eller ulæseligt — svært at følge
   - 1: Okay — læseligt men kunne være pænere
   - 2: Tydelig opstilling — mente markeret, kolonner på linje, pæn håndskrift

**Scoring-princip:** Vær generøs. Hellere 1 end 0 i tvivlstilfælde. Eleven er 9-13 år.

**improvement_tip**: Ét konkret, venligt forbedringsforslag på dansk. Eksempler:
- "Prøv at sætte små streger over de kolonner hvor du overfører mente"
- "Skriv mellemregningerne ud — så er det lettere at finde fejlen"
- null hvis scoren er 6/6 (perfekt) eller du ikke har et konstruktivt forslag
```

- [ ] **Step 2: Verify the prompt file is valid**

Run: `cd backend && python -c "open('app/prompts/analyze_work.txt').read()"`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add backend/app/prompts/analyze_work.txt
git commit -m "feat(backend): add gear_score and improvement_tip to analyze_work prompt"
```

---

## Task 3: Backend — Parse gear_score in work_analyzer.py

**Files:**
- Modify: `backend/app/services/work_analyzer.py`

- [ ] **Step 1: Write test for gear_score parsing**

Add to `backend/tests/test_gear_score.py`:

```python
from app.services.work_analyzer import extract_gear_score

DEFAULT_GEAR = {"correct_answer": 2, "visible_method": 1, "notation": 1}


def test_extract_gear_score_valid():
    parsed = {
        "gear_score": {"correct_answer": 2, "visible_method": 2, "notation": 1},
        "improvement_tip": "Husk mente-streger",
    }
    gs, tip = extract_gear_score(parsed)
    assert gs.total == 5
    assert tip == "Husk mente-streger"


def test_extract_gear_score_missing():
    parsed = {"student_answer": "42"}
    gs, tip = extract_gear_score(parsed)
    assert gs.total == 4  # generous default
    assert tip is None


def test_extract_gear_score_malformed():
    parsed = {"gear_score": "not a dict"}
    gs, tip = extract_gear_score(parsed)
    assert gs.total == 4  # generous default


def test_extract_gear_score_null_tip():
    parsed = {
        "gear_score": {"correct_answer": 2, "visible_method": 2, "notation": 2},
        "improvement_tip": None,
    }
    gs, tip = extract_gear_score(parsed)
    assert gs.total == 6
    assert tip is None
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_gear_score.py::test_extract_gear_score_valid -v`
Expected: FAIL — `ImportError: cannot import name 'extract_gear_score'`

- [ ] **Step 3: Add extract_gear_score function to work_analyzer.py**

Add to `backend/app/services/work_analyzer.py`:

```python
from app.models.schemas import GearScore

_DEFAULT_GEAR = {"correct_answer": 2, "visible_method": 1, "notation": 1}


def extract_gear_score(parsed: dict) -> tuple[GearScore, str | None]:
    """Extract and validate gear_score from AI response. Returns generous defaults on failure."""
    tip = parsed.get("improvement_tip")
    if isinstance(tip, str) and tip.strip() == "":
        tip = None

    raw = parsed.get("gear_score")
    if not isinstance(raw, dict):
        return GearScore(**_DEFAULT_GEAR), tip

    try:
        return GearScore(**raw), tip
    except Exception:
        return GearScore(**_DEFAULT_GEAR), tip
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_gear_score.py -v`
Expected: All 12 tests PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/work_analyzer.py backend/tests/test_gear_score.py
git commit -m "feat(backend): add extract_gear_score with generous fallback"
```

---

## Task 4: Backend — Wire gear_score through bulk-submit flow

**Files:**
- Modify: `backend/app/services/bulk_scan_service.py`
- Modify: `backend/app/routers/bulk_submit.py`
- Create: `backend/tests/test_bulk_submit_gear.py`

- [ ] **Step 1: Write test for gear_score in bulk-submit results**

Create `backend/tests/test_bulk_submit_gear.py`:

```python
import pytest
from app.models.schemas import BulkSubmitResult, GearScore


def test_bulk_submit_result_with_gear_score():
    result = BulkSubmitResult(
        assignment_id="a1",
        assignment_text="3 + 4",
        student_answer="7",
        status="correct",
        confidence=0.95,
        gear_score=GearScore(correct_answer=2, visible_method=2, notation=1),
        improvement_tip="Husk mente-streger",
    )
    assert result.gear_score.total == 5
    assert result.improvement_tip == "Husk mente-streger"


def test_bulk_submit_result_without_gear_score():
    result = BulkSubmitResult(
        assignment_id="a1",
        assignment_text="3 + 4",
        student_answer="7",
        status="correct",
        confidence=0.95,
    )
    assert result.gear_score is None
    assert result.improvement_tip is None
```

- [ ] **Step 2: Run tests to verify they pass** (schema fields added in Task 1)

Run: `cd backend && python -m pytest tests/test_bulk_submit_gear.py -v`
Expected: PASS

- [ ] **Step 3: Update bulk_scan_service.py to pass through gear_score fields**

In `backend/app/services/bulk_scan_service.py`, in the `validate_and_build_results()` function, add `gear_score` and `improvement_tip` to the result dict (after `bounding_box`):

```python
        "gear_score": match.get("gear_score"),
        "improvement_tip": match.get("improvement_tip"),
```

- [ ] **Step 4: Update bulk_submit.py to include gear_score in analysis dict and result**

In `backend/app/routers/bulk_submit.py`, in the loop that creates Submission records, add to the `analysis` dict (after `"bounding_box"`):

```python
            "gear_score": v.get("gear_score"),
            "improvement_tip": v.get("improvement_tip"),
```

And when building the `BulkSubmitResult` objects to return, add the new fields. Find the line that appends to the results list (where `BulkSubmitResult` is constructed or where a dict is built that maps to it). Add:

```python
            gear_score=gear_score_obj,
            improvement_tip=v.get("improvement_tip"),
```

where `gear_score_obj` is parsed from the analysis:

```python
        from app.services.work_analyzer import extract_gear_score
        gear_score_obj, improvement_tip = extract_gear_score(v)
```

Note: The exact integration depends on how the result list is built. The key requirement is:
1. `gear_score` dict from AI response flows through `validate_and_build_results()` into each result dict
2. `extract_gear_score()` is called to validate/clamp before building `BulkSubmitResult`
3. The validated `GearScore` object and `improvement_tip` string are stored in the analysis dict AND returned in the response

- [ ] **Step 5: Run full test suite**

Run: `cd backend && python -m pytest -v`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/bulk_scan_service.py backend/app/routers/bulk_submit.py backend/tests/test_bulk_submit_gear.py
git commit -m "feat(backend): wire gear_score through bulk-submit flow"
```

---

## Task 5: Backend — Update give_feedback.txt prompt

**Files:**
- Modify: `backend/app/prompts/give_feedback.txt`

- [ ] **Step 1: Update give_feedback.txt for new feedback style**

Rewrite the prompt to emphasize the new tone. Key changes:

1. Reduce from 3-4 sentences to 2-3 sentences max
2. Always start with specific praise ("Flot at du viste alle trin!" not generic "Godt klaret!")
3. Reference visible elements in the student's work (mellemregning, opstilling, mente)
4. Keep the ABSOLUTE RULE about never revealing the answer
5. When errors exist: name the area ("der sneg sig en fejl ind i tierne") not the answer
6. All text in Danish, uformelt, varmt

The existing structure (JSON output with `feedback_text` and `tone`) stays the same — only the tone/content instructions change.

- [ ] **Step 2: Verify prompt file is valid**

Run: `cd backend && python -c "open('app/prompts/give_feedback.txt').read()"`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add backend/app/prompts/give_feedback.txt
git commit -m "feat(backend): update feedback prompt for ros-first uformelt dansk style"
```

---

## Task 6: Backend — Add gear_score to ArkAssignment response

**Files:**
- Modify: `backend/app/routers/assignments.py` (or wherever `ArkAssignment` is populated from DB)

- [ ] **Step 1: Find where ArkAssignment is built from DB data**

Search for where `ArkAssignment` Pydantic objects are constructed from the `Assignment` SQLAlchemy model + `Submission` data. This is likely in the session detail endpoint (`GET /sessions/{id}`). The `gear_score` and `improvement_tip` need to be extracted from the latest submission's `analysis` JSON field.

- [ ] **Step 2: Extract gear_score from Submission.analysis when building ArkAssignment**

In the endpoint that builds `ArkAssignment` responses, after fetching the latest submission for each assignment:

```python
from app.services.work_analyzer import extract_gear_score

# When building ArkAssignment from DB:
gear_score_obj = None
improvement_tip = None
if submission and submission.analysis:
    gear_score_obj, improvement_tip = extract_gear_score(submission.analysis)
```

Pass these to the `ArkAssignment` constructor:

```python
ArkAssignment(
    ...,
    gear_score=gear_score_obj,
    improvement_tip=improvement_tip,
)
```

- [ ] **Step 3: Run existing tests to verify no regressions**

Run: `cd backend && python -m pytest -v`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add backend/app/routers/
git commit -m "feat(backend): include gear_score in ArkAssignment session detail response"
```

---

## Task 7: iOS — GearScore model + API response updates

**Files:**
- Modify: `ios/Kvante/Kvante/Models/APIResponses.swift`

- [ ] **Step 1: Add GearScore struct**

Add to `APIResponses.swift`:

```swift
struct GearScore: Codable {
    let correctAnswer: Int
    let visibleMethod: Int
    let notation: Int
    let total: Int
}
```

- [ ] **Step 2: Add gear_score fields to BulkSubmitResult**

Add to `BulkSubmitResult` struct (after `boundingBox`):

```swift
    let gearScore: GearScore?
    let improvementTip: String?
```

- [ ] **Step 3: Add gear_score fields to ArkAssignmentResponse**

Add to `ArkAssignmentResponse` struct (after `studentAnswer`):

```swift
    let gearScore: GearScore?
    let improvementTip: String?
```

- [ ] **Step 4: Build and verify compilation**

Run: Build in Xcode (Cmd+B)
Expected: Compiles without errors. The new optional fields default to nil when absent from JSON.

- [ ] **Step 5: Commit**

```bash
git add ios/Kvante/Kvante/Models/APIResponses.swift
git commit -m "feat(ios): add GearScore model and response fields"
```

---

## Task 8: iOS — Update SessionViewModel with gear_score data

**Files:**
- Modify: `ios/Kvante/Kvante/Services/SessionViewModel.swift`

- [ ] **Step 1: Add gear_score dictionaries to SessionViewModel**

Add new properties:

```swift
var gearScoreByAssignment: [String: GearScore] = [:]
var improvementTipByAssignment: [String: String] = [:]
var submissionIdByAssignment: [String: String] = [:]
```

- [ ] **Step 2: Populate gear_score in processBulkResult()**

Find the `processBulkResult()` method. In the loop that processes each `BulkSubmitResult`, add:

```swift
if let gearScore = result.gearScore {
    gearScoreByAssignment[result.assignmentId] = gearScore
}
if let tip = result.improvementTip {
    improvementTipByAssignment[result.assignmentId] = tip
}
if let subId = result.submissionId {
    submissionIdByAssignment[result.assignmentId] = subId
}
```

- [ ] **Step 3: Populate gear_score when loading session detail**

Find where `ArkAssignmentResponse` is processed (when session detail is fetched). Add the same pattern:

```swift
if let gearScore = assignment.gearScore {
    gearScoreByAssignment[assignment.id] = gearScore
}
if let tip = assignment.improvementTip {
    improvementTipByAssignment[assignment.id] = tip
}
```

- [ ] **Step 4: Build and verify**

Run: Build in Xcode (Cmd+B)
Expected: Compiles without errors

- [ ] **Step 5: Commit**

```bash
git add ios/Kvante/Kvante/Services/SessionViewModel.swift
git commit -m "feat(ios): store gear_score and improvement_tip in SessionViewModel"
```

---

## Task 9: iOS — Create GearShape and GearRatingView

**Files:**
- Create: `ios/Kvante/Kvante/Views/Ark/GearShape.swift`
- Create: `ios/Kvante/Kvante/Views/Ark/GearRatingView.swift`

- [ ] **Step 1: Create GearShape.swift**

Create `ios/Kvante/Kvante/Views/Ark/GearShape.swift`:

```swift
import SwiftUI

/// A gear/tandhjul shape matching Kvante's collar design.
/// 8-tooth gear with a circular center.
struct GearShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.65
        let toothDepth = outerRadius - innerRadius
        let teethCount = 8
        let anglePerTooth = (2 * .pi) / Double(teethCount)
        let toothWidth = anglePerTooth * 0.4

        var path = Path()

        for i in 0..<teethCount {
            let baseAngle = Double(i) * anglePerTooth - .pi / 2

            // Inner arc (between teeth)
            let innerStart = baseAngle + toothWidth / 2
            let innerEnd = baseAngle + anglePerTooth - toothWidth / 2
            path.addArc(center: center, radius: innerRadius, startAngle: .radians(innerStart), endAngle: .radians(innerEnd), clockwise: false)

            // Outer arc (tooth)
            let outerStart = innerEnd
            let outerEnd = outerStart + toothWidth
            path.addArc(center: center, radius: outerRadius, startAngle: .radians(outerStart), endAngle: .radians(outerEnd), clockwise: false)
        }

        path.closeSubpath()

        // Center hole
        let holeRadius = innerRadius * 0.35
        path.addEllipse(in: CGRect(
            x: center.x - holeRadius,
            y: center.y - holeRadius,
            width: holeRadius * 2,
            height: holeRadius * 2
        ))

        return path
    }
}

#Preview {
    HStack(spacing: 12) {
        GearShape()
            .fill(Color.orange)
            .frame(width: 28, height: 28)
        GearShape()
            .fill(Color.orange)
            .frame(width: 28, height: 28)
        GearShape()
            .fill(Color(.systemGray5))
            .frame(width: 28, height: 28)
    }
    .padding()
}
```

- [ ] **Step 2: Create GearRatingView.swift**

Create `ios/Kvante/Kvante/Views/Ark/GearRatingView.swift`:

```swift
import SwiftUI

/// Displays 0-6 filled gear icons representing the quality score.
struct GearRatingView: View {
    let score: Int
    let maxScore: Int = 6

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<maxScore, id: \.self) { index in
                GearShape()
                    .fill(index < score ? Color.accentColor : Color(.systemGray5))
                    .frame(width: 28, height: 28)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GearRatingView(score: 6)
        GearRatingView(score: 4)
        GearRatingView(score: 1)
        GearRatingView(score: 0)
    }
    .padding()
}
```

- [ ] **Step 3: Build and verify previews**

Run: Build in Xcode (Cmd+B). Open previews for both files.
Expected: Gear shape renders as an 8-tooth cogwheel. Rating view shows filled/empty gears.

- [ ] **Step 4: Commit**

```bash
git add ios/Kvante/Kvante/Views/Ark/GearShape.swift ios/Kvante/Kvante/Views/Ark/GearRatingView.swift
git commit -m "feat(ios): add GearShape and GearRatingView components"
```

---

## Task 10: iOS — Create FeedbackSheet

**Files:**
- Create: `ios/Kvante/Kvante/Views/Ark/FeedbackSheet.swift`

This is the largest task. The sheet handles both active (ark) and historical (notebook) contexts.

- [ ] **Step 1: Create FeedbackSheet.swift**

Create `ios/Kvante/Kvante/Views/Ark/FeedbackSheet.swift`:

```swift
import SwiftUI

/// Unified feedback sheet replacing FeedbackPreviewSheet, ErrorAnalysisSheet, and AssignmentDetailSheet.
/// Shows Kvante pixelart, gear rating, scan image, feedback text, and action buttons.
struct FeedbackSheet: View {
    let assignmentId: String
    let assignmentText: String
    let assignmentIndex: Int
    let status: String // "correct", "incorrect", "uncertain", "done", "in_progress"
    let errorType: String? // "procedural", "understanding", "careless"
    let studentAnswer: String?
    let scanId: String?
    let cropRegion: CropRegion?
    let gearScore: GearScore?
    let improvementTip: String?
    let feedbackSummary: String?
    let submissionId: String?
    let isHistorical: Bool
    let apiClient: APIClient

    var onRetry: (() -> Void)?
    var onShowExample: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText: String?
    @State private var isLoadingFeedback = false
    @State private var scanImage: UIImage?
    @State private var isLoadingScan = false

    // MARK: - Computed

    private var isCorrect: Bool {
        status == "correct" || status == "done"
    }

    private var pixelartName: String {
        if let gs = gearScore, gs.total == 6 {
            return "rob2_surprised"
        }
        if isCorrect {
            return "rob2_happy"
        }
        switch errorType {
        case "understanding":
            return "rob2_sad"
        default:
            return "rob2"
        }
    }

    private var headlineText: String {
        if isCorrect { return "Rigtigt!" }
        switch errorType {
        case "careless", "procedural":
            return "Tæt på!"
        default:
            return "Ikke helt"
        }
    }

    private var headlineColor: Color {
        isCorrect ? .green : .accentColor
    }

    private var questionText: String? {
        guard !isHistorical, !isCorrect else { return nil }
        switch errorType {
        case "procedural":
            return "Vil du prøve igen, eller skal jeg vise dig et eksempel med andre tal?"
        case "understanding":
            return "Skal jeg vise dig hvordan man løser den slags opgaver?"
        case "careless":
            return "Det var bare en lille glider — vil du prøve igen?"
        default:
            return "Vil du prøve igen, eller skal jeg vise dig et eksempel med andre tal?"
        }
    }

    private var showHelpButton: Bool {
        !isHistorical && !isCorrect && errorType != "careless"
    }

    private var showRetryButton: Bool {
        !isHistorical && !isCorrect
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                kvantHeader
                scanSection
                Divider()
                feedbackSection
                if isCorrect {
                    tipSection
                }
                if !isHistorical && !isCorrect {
                    actionSection
                }
            }
            .padding(20)
        }
        .background(Color("Cream"))
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await loadContent() }
    }

    // MARK: - Sections

    private var kvantHeader: some View {
        VStack(spacing: 8) {
            Image(pixelartName)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 64, height: 64)

            Text(headlineText)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(headlineColor)

            Text("\(assignmentText) — Opgave \(assignmentIndex + 1)")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            if let gs = gearScore {
                GearRatingView(score: gs.total)
                    .padding(.top, 4)
            }
        }
    }

    private var scanSection: some View {
        Group {
            if isLoadingScan {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(minHeight: 120, maxHeight: 200)
                    .overlay {
                        ProgressView()
                    }
            } else if let image = scanImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(minHeight: 120, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .overlay {
                        if let region = cropRegion {
                            BoundingBoxOverlay(region: region)
                        }
                    }
            } else if scanId != nil {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(minHeight: 120, maxHeight: 200)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: "camera")
                                .font(.title2)
                            Text("Kunne ikke hente billede")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
            }
        }
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KVANTE SIGER")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            if isLoadingFeedback {
                HStack(spacing: 10) {
                    Image("rob2_thinking")
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                    Text("Kvante kigger på dit arbejde...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .italic()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.teal.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let text = feedbackText ?? feedbackSummary {
                Text(text)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.teal.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @ViewBuilder
    private var tipSection: some View {
        if let tip = improvementTip, gearScore?.total != 6 {
            VStack(alignment: .leading, spacing: 8) {
                Text("TIP FRA KVANTE")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.accentColor)
                    .tracking(0.5)

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 3)
                    Text(tip)
                        .font(.system(size: 14))
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .background(Color(red: 1.0, green: 0.97, blue: 0.93))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            if let question = questionText {
                Text(question)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 4)
            }

            HStack(spacing: 10) {
                if showRetryButton {
                    Button {
                        dismiss()
                        onRetry?()
                    } label: {
                        Text("Jeg prøver igen")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .foregroundStyle(.accentColor)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.accentColor, lineWidth: 2)
                            )
                    }
                }

                if showHelpButton {
                    Button {
                        dismiss()
                        onShowExample?()
                    } label: {
                        Text("Ja, vis mig!")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .foregroundStyle(.white)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    // MARK: - Loading

    private func loadContent() async {
        // Load scan image
        if let sid = scanId {
            isLoadingScan = true
            scanImage = await ScanImageCache.shared.image(
                for: sid,
                apiClient: apiClient,
                maxPixelSize: 800
            )
            isLoadingScan = false
        }

        // Load feedback text lazily if not already cached
        if feedbackText == nil, feedbackSummary == nil, let subId = submissionId {
            isLoadingFeedback = true
            do {
                let response = try await apiClient.getFeedback(submissionId: subId)
                feedbackText = response.feedbackText
            } catch {
                // Fallback: show nothing rather than crash
            }
            isLoadingFeedback = false
        }
    }
}
```

**Note:** The `loadContent()` method's feedback-loading logic needs to be wired to the actual `apiClient.getFeedback()` call. This depends on having the `submissionId` available, which comes from `SessionViewModel`. The exact wiring is determined during implementation based on how the sheet is presented (see Task 11).

- [ ] **Step 2: Add pixelart images to asset catalog**

Copy the 5 existing pixelart PNGs from `icons/Kvante/Pixelart/` into the Xcode asset catalog so they can be referenced by `Image("rob2_happy")` etc. The filenames have a quirk — `rob2_happy .png` has a trailing space. Rename in the asset catalog to `rob2_happy`.

- [ ] **Step 3: Build and verify**

Run: Build in Xcode (Cmd+B)
Expected: Compiles without errors

- [ ] **Step 4: Commit**

```bash
git add ios/Kvante/Kvante/Views/Ark/FeedbackSheet.swift
git commit -m "feat(ios): create unified FeedbackSheet view"
```

---

## Task 11: iOS — Replace old sheets in AssignmentSheetView

**Files:**
- Modify: `ios/Kvante/Kvante/Views/Ark/AssignmentSheetView.swift`

- [ ] **Step 1: Replace FeedbackPreviewSheet and ErrorAnalysisSheet with FeedbackSheet**

In `AssignmentSheetView.swift`:

1. Remove `@State private var presentedFeedback: ArkFeedbackItem?`
2. Remove `@State private var presentedError: ArkFeedbackItem?`
3. Add `@State private var presentedFeedbackSheet: ArkFeedbackItem?`

4. Replace the tap handler logic (around lines 51-68). Both `onFeedbackTap` and the done-state `onTap` now set `presentedFeedbackSheet`:

```swift
onTap: {
    let status = session.statusByAssignment[assignment.id] ?? .notStarted
    if status == .done {
        presentedFeedbackSheet = ArkFeedbackItem(id: assignment.id, assignment: assignment, index: index)
    } else {
        onSelectAssignment(index)
    }
},
onFeedbackTap: {
    presentedFeedbackSheet = ArkFeedbackItem(id: assignment.id, assignment: assignment, index: index)
}
```

5. Replace the two `.sheet` modifiers (FeedbackPreviewSheet at lines 112-123 and ErrorAnalysisSheet at lines 124-147) with one:

```swift
.sheet(item: $presentedFeedbackSheet) { item in
    let assignmentId = item.assignment.id
    FeedbackSheet(
        assignmentId: assignmentId,
        assignmentText: item.assignment.text,
        assignmentIndex: item.index,
        status: session.statusByAssignment[assignmentId]?.rawValue ?? "not_started",
        errorType: session.errorType[assignmentId],
        studentAnswer: session.studentAnswer[assignmentId],
        scanId: session.latestScanId[assignmentId],
        cropRegion: session.boundingBoxByAssignment[assignmentId],
        gearScore: session.gearScoreByAssignment[assignmentId],
        improvementTip: session.improvementTipByAssignment[assignmentId],
        feedbackSummary: session.feedbackSummary[assignmentId],
        submissionId: session.submissionIdByAssignment[assignmentId],
        isHistorical: false,
        apiClient: apiClient,
        onRetry: {
            presentedFeedbackSheet = nil
            // Return to assignment for re-scanning
        },
        onShowExample: {
            presentedFeedbackSheet = nil
            onSelectAssignment(item.index)
            // This navigates to chat which triggers example generation
        }
    )
}
```

6. Keep the ConfirmAnswerSheet `.sheet` modifier unchanged — it handles OCR correction, not feedback.

- [ ] **Step 2: Remove import/reference to FeedbackPreviewSheet and ErrorAnalysisSheet**

Search `AssignmentSheetView.swift` for any remaining references to the old sheets and remove them.

- [ ] **Step 3: Build and verify**

Run: Build in Xcode (Cmd+B)
Expected: Compiles. Both old sheet types now route through FeedbackSheet.

- [ ] **Step 4: Commit**

```bash
git add ios/Kvante/Kvante/Views/Ark/AssignmentSheetView.swift
git commit -m "refactor(ios): replace FeedbackPreviewSheet and ErrorAnalysisSheet with FeedbackSheet"
```

---

## Task 12: iOS — Replace AssignmentDetailSheet in NotebookWeekView

**Files:**
- Modify: `ios/Kvante/Kvante/Views/Notebook/NotebookWeekView.swift`

- [ ] **Step 1: Replace AssignmentDetailSheet with FeedbackSheet**

In `NotebookWeekView.swift`, replace the `.sheet(item: $selectedAssignment)` modifier (lines 68-72):

```swift
.sheet(item: $selectedAssignment) { assignment in
    FeedbackSheet(
        assignmentId: assignment.id,
        assignmentText: assignment.text,
        assignmentIndex: assignment.position,
        status: assignment.arkStatus,
        errorType: nil,  // Not available in historical view
        studentAnswer: assignment.studentAnswer,
        scanId: assignment.scanId,
        cropRegion: nil,  // Notebook doesn't have crop regions currently
        gearScore: assignment.gearScore,
        improvementTip: assignment.improvementTip,
        feedbackSummary: assignment.feedbackSummary,
        submissionId: nil,  // Historical view — feedback already cached as summary
        isHistorical: true,
        apiClient: apiClient
    )
}
```

**Note:** The `NotebookAssignment` model may need `gearScore` and `improvementTip` properties. Check if `NotebookAssignment` is a separate model from `ArkAssignmentResponse` — if so, add the fields there too.

- [ ] **Step 2: Build and verify**

Run: Build in Xcode (Cmd+B)
Expected: Compiles without errors

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/Notebook/NotebookWeekView.swift
git commit -m "refactor(ios): replace AssignmentDetailSheet with FeedbackSheet in notebook"
```

---

## Task 13: iOS — Delete old sheets + verify all entry points

**Files:**
- Delete: `ios/Kvante/Kvante/Views/Ark/FeedbackPreviewSheet.swift`
- Delete: `ios/Kvante/Kvante/Views/Ark/ErrorAnalysisSheet.swift`
- Delete: `ios/Kvante/Kvante/Views/Notebook/AssignmentDetailSheet.swift`

- [ ] **Step 1: Search for any remaining references to old sheets**

Search the entire iOS codebase for:
- `FeedbackPreviewSheet`
- `ErrorAnalysisSheet`
- `AssignmentDetailSheet`

All references should have been replaced in Tasks 11 and 12. If any remain, update them.

- [ ] **Step 2: Delete the old sheet files**

```bash
rm ios/Kvante/Kvante/Views/Ark/FeedbackPreviewSheet.swift
rm ios/Kvante/Kvante/Views/Ark/ErrorAnalysisSheet.swift
rm ios/Kvante/Kvante/Views/Notebook/AssignmentDetailSheet.swift
```

- [ ] **Step 3: Build to verify clean compilation**

Run: Build in Xcode (Cmd+B)
Expected: Compiles without errors. No references to deleted files.

- [ ] **Step 4: Manual verification checklist**

Test on simulator or device:
- [ ] Tap on a **done** assignment in the ark → FeedbackSheet opens with gear rating, scan, feedback
- [ ] Tap on an **incorrect** assignment info button in the ark → FeedbackSheet opens with error feedback, action buttons
- [ ] Tap on an **uncertain** assignment in the ark → FeedbackSheet opens appropriately
- [ ] Tap "Jeg prøver igen" → sheet closes, returns to assignment
- [ ] Tap "Ja, vis mig!" → sheet closes, navigates to chat with example
- [ ] Open matematikbogen → tap on a historical assignment → FeedbackSheet opens in historical mode (no action buttons, no question text)
- [ ] Verify ConfirmAnswerSheet still works for OCR corrections

- [ ] **Step 5: Commit**

```bash
git rm ios/Kvante/Kvante/Views/Ark/FeedbackPreviewSheet.swift
git rm ios/Kvante/Kvante/Views/Ark/ErrorAnalysisSheet.swift
git rm ios/Kvante/Kvante/Views/Notebook/AssignmentDetailSheet.swift
git commit -m "refactor(ios): delete old FeedbackPreviewSheet, ErrorAnalysisSheet, AssignmentDetailSheet"
```

---

## Task 14: Deploy and end-to-end test

**Files:** None — deployment and testing

- [ ] **Step 1: Deploy backend to Mac Mini**

```bash
./scripts/deploy.sh
```

Expected: Deploy succeeds, health check passes.

- [ ] **Step 2: Run backend test suite on Mac Mini**

```bash
ssh oleserver@macmini4 "cd ~/Kvante/backend && python -m pytest -v"
```

Expected: All tests pass including new gear_score tests.

- [ ] **Step 3: Build and run iOS app on iPad**

Build in Xcode, deploy to physical iPad.

- [ ] **Step 4: End-to-end test**

1. Create a new ugematematik session
2. Solve a few assignments on paper
3. Bulk-scan the sheet
4. Verify gear scores appear on FeedbackSheet
5. Verify feedback text loads (with loading state)
6. Verify "Ja, vis mig!" navigates to chat
7. Check matematikbogen shows historical feedback correctly

- [ ] **Step 5: Final commit with any fixes**

```bash
git add -A
git commit -m "fix(ios): end-to-end fixes for feedback sheet"
```
