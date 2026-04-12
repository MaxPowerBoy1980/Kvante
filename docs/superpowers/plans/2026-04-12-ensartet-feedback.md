# Ensartet Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make single-scan submissions produce the same gear_score + improvement_tip data as bulk-scan, so FeedbackSheet works identically regardless of scan type.

**Architecture:** Backend `POST /submissions/` calls `WorkAnalyzerService.analyze_work()` after `compare_answer()` to get gear_score + improvement_tip, stores them in `submission.analysis`. iOS `SubmissionResponse` gains two new fields. ChatViewModel replaces the broken `getFeedback()` call with inline gear data. FeedbackSheet drops lazy loading.

**Tech Stack:** Python/FastAPI, SwiftUI, pytest, SQLite

**Spec:** `docs/superpowers/specs/2026-04-12-ensartet-feedback-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `backend/app/routers/submissions.py` | Modify | Add work_analyzer call after compare_answer |
| `backend/app/routers/feedback.py` | Modify | Add deprecation comment |
| `backend/tests/test_submission_gear.py` | Create | Tests for gear_score in submissions |
| `ios/Kvante/Kvante/Models/APIResponses.swift` | Modify | Add gearScore + improvementTip to SubmissionResponse |
| `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift` | Modify | Use gear data from submission, remove getFeedback call |
| `ios/Kvante/Kvante/Views/Ark/FeedbackSheet.swift` | Modify | Remove lazy feedback loading, compose feedback from gear data |

**Not changed (already correct):**
- `backend/app/models/schemas.py` — SubmissionResponse already has gear_score + improvement_tip fields (lines 98-99)
- `backend/app/services/work_analyzer.py` — WorkAnalyzerService.analyze_work() already returns gear_score in its JSON output
- `backend/app/routers/practice.py` — `GET /sessions/{id}` already reads gear_score from submission.analysis via `extract_gear_score()` (lines 341-348)
- `ios/.../SessionViewModel.swift` — already populates gearScoreByAssignment from session detail response (lines 126-131)

---

### Task 1: Backend — Add gear_score to single submissions (TDD)

**Files:**
- Create: `backend/tests/test_submission_gear.py`
- Modify: `backend/app/routers/submissions.py`

- [ ] **Step 1: Write failing test — submission returns gear_score for correct answer**

Create `backend/tests/test_submission_gear.py`:

```python
"""Tests for gear_score in single-scan submissions."""

import io
from unittest.mock import MagicMock, patch

import pytest
from PIL import Image


def _make_test_jpeg() -> bytes:
    img = Image.new("RGB", (100, 100), "white")
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def _create_session_with_assignment(client, text="50 + 30", correct_answer="80"):
    """Helper: create a practice session with one known assignment."""
    from app.database import get_db
    from app.main import app
    from app.models.db import Assignment, Session

    # Get the test DB from the dependency override
    db = next(app.dependency_overrides[get_db]())

    session = Session(student_id="default", mode="practice", name="Test", detected_language="da")
    db.add(session)
    db.flush()

    assignment = Assignment(
        session_id=session.id,
        local_id="1",
        text=text,
        type="calculation",
        topic="addition",
        difficulty_estimate=2,
        correct_answer=correct_answer,
        position=0,
    )
    db.add(assignment)
    db.commit()
    return session.id, assignment.id


@patch("app.routers.submissions.WorkAnalyzerService")
def test_submission_returns_gear_score(mock_analyzer_cls, client):
    """Single-scan submission should return gear_score + improvement_tip."""
    session_id, assignment_id = _create_session_with_assignment(client)

    mock_analyzer = MagicMock()
    mock_analyzer_cls.return_value = mock_analyzer
    mock_analyzer.analyze_work.return_value = {
        "student_answer": "80",
        "methodology_sound": True,
        "steps_identified": [],
        "errors": [],
        "correct_elements": ["Korrekt svar"],
        "methodology_assessment": "Flot.",
        "handwriting_note": "",
        "confidence": 0.95,
        "gear_score": {"correct_answer": 2, "visible_method": 2, "notation": 1},
        "improvement_tip": "Skriv mellemregningerne tydeligere",
    }

    resp = client.post(
        "/submissions/",
        data={
            "session_id": session_id,
            "assignment_id": assignment_id,
            "answer_text": "80",
            "full_ocr_text": "50 + 30 = 80",
        },
        files={"image": ("work.jpg", _make_test_jpeg(), "image/jpeg")},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["gear_score"]["correct_answer"] == 2
    assert data["gear_score"]["visible_method"] == 2
    assert data["gear_score"]["notation"] == 1
    assert data["gear_score"]["total"] == 5
    assert data["improvement_tip"] == "Skriv mellemregningerne tydeligere"


@patch("app.routers.submissions.WorkAnalyzerService")
def test_submission_gear_score_fallback_on_analyzer_error(mock_analyzer_cls, client):
    """If work_analyzer fails, submission still succeeds with gear_score=None."""
    session_id, assignment_id = _create_session_with_assignment(client)

    mock_analyzer = MagicMock()
    mock_analyzer_cls.return_value = mock_analyzer
    mock_analyzer.analyze_work.side_effect = Exception("AI timeout")

    resp = client.post(
        "/submissions/",
        data={
            "session_id": session_id,
            "assignment_id": assignment_id,
            "answer_text": "80",
            "full_ocr_text": "50 + 30 = 80",
        },
        files={"image": ("work.jpg", _make_test_jpeg(), "image/jpeg")},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["methodology_sound"] is True
    assert data["gear_score"] is None
    assert data["improvement_tip"] is None


@patch("app.routers.submissions.WorkAnalyzerService")
def test_submission_gear_score_stored_in_analysis(mock_analyzer_cls, client):
    """Gear score should be stored in submission.analysis so session detail can read it."""
    session_id, assignment_id = _create_session_with_assignment(client)

    mock_analyzer = MagicMock()
    mock_analyzer_cls.return_value = mock_analyzer
    mock_analyzer.analyze_work.return_value = {
        "student_answer": "80",
        "methodology_sound": True,
        "steps_identified": [],
        "errors": [],
        "correct_elements": [],
        "methodology_assessment": "",
        "handwriting_note": "",
        "confidence": 0.95,
        "gear_score": {"correct_answer": 2, "visible_method": 1, "notation": 2},
        "improvement_tip": "Godt gået",
    }

    # Submit
    client.post(
        "/submissions/",
        data={
            "session_id": session_id,
            "assignment_id": assignment_id,
            "answer_text": "80",
            "full_ocr_text": "50 + 30 = 80",
        },
        files={"image": ("work.jpg", _make_test_jpeg(), "image/jpeg")},
    )

    # Session detail should now include gear_score for this assignment
    detail_resp = client.get(f"/sessions/{session_id}")
    assert detail_resp.status_code == 200
    detail = detail_resp.json()
    ark = detail["assignments"][0]
    assert ark["gear_score"] is not None
    assert ark["gear_score"]["total"] == 5
    assert ark["improvement_tip"] == "Godt gået"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_submission_gear.py -v`

Expected: FAIL — `submissions.py` doesn't import or call WorkAnalyzerService, so the mock is never used and `gear_score` is None in response.

- [ ] **Step 3: Implement — add work_analyzer call to submissions.py**

In `backend/app/routers/submissions.py`, add the import at the top:

```python
from app.services.work_analyzer import WorkAnalyzerService, extract_gear_score
```

Then, after the `analysis = { ... }` dict is built (after line 121) and before `submission.analysis = analysis` (line 123), add the work_analyzer call:

```python
    # Gear score: analyze handwritten work with AI
    gear_score_obj = None
    improvement_tip_val = None
    try:
        analyzer = WorkAnalyzerService()
        ai_analysis = analyzer.analyze_work(
            image_bytes=contents,
            assignment_text=assignment.text,
            assignment_type=assignment.type,
            assignment_topic=assignment.topic,
        )
        gear_score_obj, improvement_tip_val = extract_gear_score(ai_analysis)
        analysis["gear_score"] = gear_score_obj.model_dump() if gear_score_obj else None
        analysis["improvement_tip"] = improvement_tip_val
    except Exception:
        logger.warning("Work analyzer failed for submission %s, continuing without gear_score", submission.id)
        analysis["gear_score"] = None
        analysis["improvement_tip"] = None
```

Then update the return statement (currently line 130-135) to include gear_score:

```python
    return SubmissionResponse(
        submission_id=submission.id,
        assignment_id=assignment_id,
        session_id=session_id,
        gear_score=gear_score_obj,
        improvement_tip=improvement_tip_val,
        **{k: v for k, v in analysis.items() if k in SubmissionResponse.model_fields and k not in ("gear_score", "improvement_tip")},
    )
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_submission_gear.py -v`

Expected: All 3 tests PASS.

- [ ] **Step 5: Run full test suite to check for regressions**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest -x -q`

Expected: All tests pass. The existing `test_submit_work` in `test_routers.py` already mocks WorkAnalyzerService (line 55) so it should still work.

- [ ] **Step 6: Commit**

```bash
git add backend/tests/test_submission_gear.py backend/app/routers/submissions.py
git commit -m "feat(backend): add gear_score to single-scan submissions"
```

---

### Task 2: Backend — Deprecate POST /feedback/ endpoint

**Files:**
- Modify: `backend/app/routers/feedback.py`

- [ ] **Step 1: Add deprecation comment to feedback.py**

At the top of `backend/app/routers/feedback.py`, after the imports (after line 11), add:

```python
# DEPRECATED 2026-04-12: This endpoint is no longer called by iOS.
# gear_score + improvement_tip are now computed at submission time and returned
# inline in SubmissionResponse. The known timeout bug is not being fixed.
# This endpoint will be removed in a future cleanup sprint.
```

- [ ] **Step 2: Run existing tests to verify nothing broke**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest tests/test_feedback_generator.py -v`

Expected: All existing tests pass (we didn't change behavior).

- [ ] **Step 3: Commit**

```bash
git add backend/app/routers/feedback.py
git commit -m "docs(backend): deprecate POST /feedback/ endpoint"
```

---

### Task 3: iOS — Add gear_score + improvement_tip to SubmissionResponse

**Files:**
- Modify: `ios/Kvante/Kvante/Models/APIResponses.swift`

- [ ] **Step 1: Add fields to SubmissionResponse**

In `ios/Kvante/Kvante/Models/APIResponses.swift`, add two optional fields to `SubmissionResponse` (after `confidence` on line 78):

```swift
    let gearScore: GearScore?
    let improvementTip: String?
```

Add the coding keys (inside the existing `CodingKeys` enum, after `case confidence`):

```swift
        case gearScore = "gear_score"
        case improvementTip = "improvement_tip"
```

Also add a custom `init(from:)` so existing responses without these fields decode correctly (the fields may be null or absent):

```swift
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        submissionId = try container.decode(String.self, forKey: .submissionId)
        assignmentId = try container.decode(String.self, forKey: .assignmentId)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        studentAnswer = try container.decode(String.self, forKey: .studentAnswer)
        correctAnswer = try container.decode(String.self, forKey: .correctAnswer)
        methodologySound = try container.decode(Bool.self, forKey: .methodologySound)
        stepsIdentified = try container.decode([AnalysisStep].self, forKey: .stepsIdentified)
        errors = try container.decode([String].self, forKey: .errors)
        correctElements = try container.decode([String].self, forKey: .correctElements)
        methodologyAssessment = try container.decode(String.self, forKey: .methodologyAssessment)
        handwritingNote = try container.decode(String.self, forKey: .handwritingNote)
        confidence = try container.decode(Double.self, forKey: .confidence)
        gearScore = try container.decodeIfPresent(GearScore.self, forKey: .gearScore)
        improvementTip = try container.decodeIfPresent(String.self, forKey: .improvementTip)
    }
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd /Users/olsen/code/Kvante/ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Models/APIResponses.swift
git commit -m "feat(ios): add gearScore + improvementTip to SubmissionResponse"
```

---

### Task 4: iOS — ChatViewModel uses gear data, removes getFeedback call

**Files:**
- Modify: `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift`

This is the largest iOS change. Two locations in ChatViewModel call `apiClient.getFeedback()` after incorrect answers: the Vision OCR path (lines 454-473) and the confirmAnswer path (lines 547-566). Both need to be replaced with inline gear data from the submission response.

- [ ] **Step 1: Replace feedback call in Vision OCR path (scanAnswer)**

In `ChatViewModel.swift`, find the Vision OCR incorrect-answer block (lines 454-473):

```swift
                    // Request feedback for wrong answers
                    if !result.methodologySound {
                        let feedbackLoadingId = addLoading("Kvante kigger på din metode...")
                        do {
                            let feedback = try await apiClient.getFeedback(
                                submissionId: result.submissionId
                            )
                            let chips = feedback.structuredPrompts.map { ActionChipModel.fromPrompt($0) }
                            replaceLoading(feedbackLoadingId, with: ChatMessage(
                                sender: .kvante,
                                content: .feedback(feedback),
                                actions: chips
                            ))
                        } catch {
                            replaceLoading(feedbackLoadingId, with: ChatMessage(
                                sender: .kvante,
                                content: .text("Prøv igen — tryk + for hjælp hvis du sidder fast.")
                            ))
                        }
                    }
```

Replace with:

```swift
                    // Show gear feedback inline for wrong answers
                    if !result.methodologySound {
                        let feedbackMsg = Self.buildGearFeedbackMessage(
                            gearScore: result.gearScore,
                            improvementTip: result.improvementTip
                        )
                        appendMessage(feedbackMsg)
                    }
```

- [ ] **Step 2: Replace feedback call in confirmAnswer path**

In `ChatViewModel.swift`, find the confirmAnswer incorrect-answer block (lines 547-566):

```swift
                // Request feedback for wrong answers
                if !submission.methodologySound {
                    let feedbackLoadingId = addLoading("Kvante kigger på din metode...")
                    do {
                        let feedback = try await apiClient.getFeedback(
                            submissionId: submission.submissionId
                        )
                        let chips = feedback.structuredPrompts.map { ActionChipModel.fromPrompt($0) }
                        replaceLoading(feedbackLoadingId, with: ChatMessage(
                            sender: .kvante,
                            content: .feedback(feedback),
                            actions: chips
                        ))
                    } catch {
                        replaceLoading(feedbackLoadingId, with: ChatMessage(
                            sender: .kvante,
                            content: .text("Prøv igen — tryk + for hjælp hvis du sidder fast.")
                        ))
                    }
                }
```

Replace with:

```swift
                // Show gear feedback inline for wrong answers
                if !submission.methodologySound {
                    let feedbackMsg = Self.buildGearFeedbackMessage(
                        gearScore: submission.gearScore,
                        improvementTip: submission.improvementTip
                    )
                    appendMessage(feedbackMsg)
                }
```

- [ ] **Step 3: Add gear tip for correct but non-perfect answers**

Both the Vision OCR path and confirmAnswer path have the `SubmissionResponse` in scope (`result` and `submission` respectively). Add the gear tip after the existing correct-answer handling in each.

**Vision OCR path:** At the end of the `if result.methodologySound` block (after the existing explanation messages, around line 452), add before the closing brace:

```swift
                        // Gear tip for correct but non-perfect
                        if let gs = result.gearScore, gs.total < 6, let tip = result.improvementTip {
                            appendMessage(ChatMessage(sender: .kvante, content: .text("💡 \(tip)")))
                        }
```

**confirmAnswer path:** After `showAnswerResult(...)` (line 538-545) and before the incorrect-answer check, add:

```swift
                // Gear tip for correct but non-perfect
                if submission.methodologySound,
                   let gs = submission.gearScore, gs.total < 6,
                   let tip = submission.improvementTip {
                    appendMessage(ChatMessage(sender: .kvante, content: .text("💡 \(tip)")))
                }
```

- [ ] **Step 4: Add the static buildGearFeedbackMessage helper**

Add this at the bottom of ChatViewModel, before the closing brace:

```swift
    // MARK: - Gear Feedback

    /// Build a chat message with gear_score feedback for incorrect answers.
    /// Uses improvement_tip from submission instead of calling POST /feedback/.
    static func buildGearFeedbackMessage(
        gearScore: GearScore?,
        improvementTip: String?
    ) -> ChatMessage {
        var parts: [String] = []

        if let gs = gearScore {
            parts.append("⚙ \(gs.total)/6")
        }
        if let tip = improvementTip {
            parts.append(tip)
        }

        let text = parts.isEmpty
            ? "Prøv igen — tryk + for hjælp hvis du sidder fast."
            : parts.joined(separator: " — ")

        return ChatMessage(
            sender: .kvante,
            content: .text(text),
            actions: [
                ActionChipModel(id: "try_again", label: "Prøv igen", icon: "arrow.counterclockwise", isPrimary: false),
                ActionChipModel(id: "another_example", label: "Vis mig eksempel", icon: "lightbulb", isPrimary: true),
            ]
        )
    }
```

- [ ] **Step 5: Build to verify it compiles**

Run: `cd /Users/olsen/code/Kvante/ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add ios/Kvante/Kvante/ViewModels/ChatViewModel.swift
git commit -m "feat(ios): use gear_score from submission, remove getFeedback calls"
```

---

### Task 5: iOS — FeedbackSheet removes lazy loading, composes feedback text

**Files:**
- Modify: `ios/Kvante/Kvante/Views/Ark/FeedbackSheet.swift`

- [ ] **Step 1: Remove lazy feedback loading from loadContent()**

In `FeedbackSheet.swift`, replace the `loadContent()` method (lines 284-311):

```swift
    private func loadContent() async {
        // Load scan image — cropped if bounding box available, otherwise full
        if let sid = scanId {
            isLoadingScan = true
            if let region = cropRegion {
                scanImage = await ScanImageCache.shared.croppedImage(
                    for: sid, region: region, apiClient: apiClient
                )
            } else {
                scanImage = await ScanImageCache.shared.image(
                    for: sid, apiClient: apiClient, maxPixelSize: 800
                )
            }
            isLoadingScan = false
        }
    }
```

This removes the entire `getFeedback` call block (lines 300-310).

- [ ] **Step 2: Remove unused state properties**

Remove these two `@State` properties (lines 23-24):

```swift
    @State private var feedbackText: String?
    @State private var isLoadingFeedback = false
```

- [ ] **Step 3: Update feedbackSection to compose from gear_score**

Replace the `feedbackSection` computed property (lines 155-191):

```swift
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KVANTE SIGER")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KvanteTheme.Colors.textSecondary)
                .textCase(.uppercase)

            let displayText = composedFeedbackText

            if let displayText {
                Text(displayText)
                    .font(.body)
                    .foregroundStyle(KvanteTheme.Colors.ink)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KvanteTheme.Colors.teal.opacity(0.08))
                    )
            }
        }
    }

    /// Compose feedback text from gear_score + improvement_tip.
    /// Falls back to feedbackSummary (from bulk error_description).
    /// Returns nil if no data available — section shows nothing.
    private var composedFeedbackText: String? {
        // Priority 1: gear_score opening line + improvement_tip
        if let gs = gearScore {
            let opening: String
            switch gs.total {
            case 6: opening = "Perfekt!"
            case 4...5: opening = "Godt arbejde!"
            case 2...3: opening = "Tæt på!"
            default: opening = "Lad os prøve igen"
            }
            if let tip = improvementTip {
                return "\(opening) \(tip)"
            }
            return opening
        }

        // Priority 2: feedbackSummary from bulk-scan error description
        if let summary = feedbackSummary {
            return summary
        }

        // No data — show nothing
        return nil
    }
```

- [ ] **Step 4: Build to verify it compiles**

Run: `cd /Users/olsen/code/Kvante/ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add ios/Kvante/Kvante/Views/Ark/FeedbackSheet.swift
git commit -m "feat(ios): FeedbackSheet composes feedback from gear_score, removes lazy loading"
```

---

### Task 6: Integration verification

- [ ] **Step 1: Run full backend test suite**

Run: `cd /Users/olsen/code/Kvante/backend && python -m pytest -x -q`

Expected: All tests pass including the 3 new ones from Task 1.

- [ ] **Step 2: Build iOS for simulator**

Run: `cd /Users/olsen/code/Kvante/ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -10`

Expected: BUILD SUCCEEDED with no new warnings related to our changes.

- [ ] **Step 3: Verify test coverage of session detail path**

The existing test `test_submission_gear_score_stored_in_analysis` (Task 1) already verifies that `GET /sessions/{id}` returns gear_score from single-scan submissions. This confirms the session detail → SessionViewModel → FeedbackSheet data path works end-to-end on the backend.

- [ ] **Step 4: Final commit if any fixups needed**

If integration uncovered issues, commit the fixes:

```bash
git add -A
git commit -m "fix: integration fixups for ensartet feedback"
```
