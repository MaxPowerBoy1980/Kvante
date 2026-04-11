# Pakke 4: Bulk-scan + AI fejlanalyse — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let students scan their entire worksheet with 1+ photos and have Kvante automatically match, validate, and error-analyze each answer — updating the ark with ✓/✗/❓ and providing a summary in chat.

**Architecture:** New `POST /sessions/{id}/bulk-submit` endpoint receives multi-page images, sends them to Claude Vision with the session's assignment list, validates answers deterministically with `compare_answer()`, creates Submissions, and returns a structured `BulkSubmitResponse`. iOS adds a "Scan hele arket" button on the ark, uses VisionKit multi-page scanner, displays results with error analysis sheets and re-scan flow.

**Tech Stack:** Python/FastAPI backend, Claude Vision API (multi-image), SQLAlchemy, pytest. SwiftUI iOS app, VisionKit `VNDocumentCameraViewController`.

**Spec:** `docs/superpowers/specs/2026-04-11-pakke-4-bulk-scan-design.md`

---

## File Map

### Backend — New files

| File | Responsibility |
|------|---------------|
| `backend/app/routers/bulk_submit.py` | `POST /sessions/{id}/bulk-submit` endpoint |
| `backend/app/services/bulk_scan_service.py` | AI prompt builder, response parser, validation logic |
| `backend/app/prompts/bulk_scan.txt` | System prompt for Claude Vision bulk-scan |
| `backend/tests/test_bulk_submit.py` | All pytest tests for bulk-scan |

### Backend — Modified files

| File | Change |
|------|--------|
| `backend/app/services/ai_client.py` | Add `send_vision_multi()` method to all 3 clients |
| `backend/app/models/schemas.py` | Add `BulkSubmitResult`, `BulkSubmitSummary`, `BulkSubmitResponse` |
| `backend/app/main.py` | Register `bulk_submit` router |

### iOS — New files

| File | Responsibility |
|------|---------------|
| `ios/Kvante/Kvante/Views/Ark/BulkScanButton.swift` | "Scan hele arket" button |
| `ios/Kvante/Kvante/Views/Ark/ErrorAnalysisSheet.swift` | Bottom sheet for incorrect assignments |
| `ios/Kvante/Kvante/Views/Ark/RescanSheet.swift` | Bottom sheet for uncertain assignments with order tips |
| `ios/Kvante/Kvante/Views/Chat/BulkScanFeedbackCard.swift` | Summary card in chat |

### iOS — Modified files

| File | Change |
|------|--------|
| `ios/Kvante/Kvante/Models/APIResponses.swift` | Add `BulkSubmitResponse`, `BulkSubmitResult`, `BulkSubmitSummary` structs |
| `ios/Kvante/Kvante/Services/APIClient.swift` | Add `bulkSubmit(sessionId:images:)` method |
| `ios/Kvante/Kvante/ViewModels/SessionViewModel.swift` | Add `processBulkResult()`, `errorDescription` dict, `studentAnswer` dict |
| `ios/Kvante/Kvante/Views/Ark/AssignmentSheetView.swift` | Add BulkScanButton, handle bulk result, present error/rescan sheets |
| `ios/Kvante/Kvante/Views/Ark/ArkCell.swift` | Show error type text under incorrect assignments |

---

## Task 1: AI Client — `send_vision_multi()`

**Files:**
- Modify: `backend/app/services/ai_client.py`
- Test: `backend/tests/test_bulk_submit.py` (first test)

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_bulk_submit.py`:

```python
"""Tests for bulk-scan submission (Pakke 4)."""

from unittest.mock import patch, MagicMock
import json

from app.services.ai_client import ClaudeAIClient


def test_send_vision_multi_sends_all_images():
    """send_vision_multi should include all images in the messages content."""
    with patch("app.services.ai_client.ClaudeAIClient.__init__", return_value=None):
        client = ClaudeAIClient()
        client._model = "claude-haiku-4-5-20251001"

        mock_response = MagicMock()
        mock_response.content = [MagicMock(text='{"matches": []}')]
        mock_response.usage = MagicMock(input_tokens=100, output_tokens=50)

        mock_anthropic_client = MagicMock()
        mock_anthropic_client.messages.create.return_value = mock_response
        client._client = mock_anthropic_client

        result = client.send_vision_multi(
            system_prompt="test prompt",
            images=[b"fake_image_1", b"fake_image_2"],
            user_message="test message",
        )

        assert result == '{"matches": []}'

        call_args = mock_anthropic_client.messages.create.call_args
        content_blocks = call_args.kwargs["messages"][0]["content"]

        # 2 image blocks + 1 text block
        image_blocks = [b for b in content_blocks if b["type"] == "image"]
        text_blocks = [b for b in content_blocks if b["type"] == "text"]
        assert len(image_blocks) == 2
        assert len(text_blocks) == 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_bulk_submit.py::test_send_vision_multi_sends_all_images -v`
Expected: FAIL with `AttributeError: 'ClaudeAIClient' object has no attribute 'send_vision_multi'`

- [ ] **Step 3: Add `send_vision_multi()` to `AIClient` base class and `ClaudeAIClient`**

In `backend/app/services/ai_client.py`, add to `AIClient` base class:

```python
def send_vision_multi(
    self,
    system_prompt: str,
    images: list[bytes],
    user_message: str,
    media_types: list[str] | None = None,
) -> str:
    """Send multiple images + text prompt. Returns the text response.
    Default: sends images sequentially and concatenates results.
    """
    # Fallback for providers that don't support multi-image natively
    results = []
    for i, img in enumerate(images):
        mt = media_types[i] if media_types else "image/jpeg"
        r = self.send_vision(system_prompt, img, user_message, mt)
        results.append(r)
    return results[-1] if results else ""
```

Add to `ClaudeAIClient`:

```python
def send_vision_multi(
    self,
    system_prompt: str,
    images: list[bytes],
    user_message: str,
    media_types: list[str] | None = None,
) -> str:
    """Send multiple images in a single Claude API call."""
    logger.debug("Claude send_vision_multi: %d images, prompt: %s", len(images), system_prompt[:200])

    content_blocks = []
    for i, img_bytes in enumerate(images):
        mt = media_types[i] if media_types else "image/jpeg"
        image_b64 = base64.b64encode(img_bytes).decode("utf-8")
        content_blocks.append({
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": mt,
                "data": image_b64,
            },
        })
    content_blocks.append({"type": "text", "text": user_message})

    start = time.time()
    response = self._client.messages.create(
        model=self._model,
        max_tokens=4096,
        system=system_prompt,
        messages=[{"role": "user", "content": content_blocks}],
    )
    elapsed = time.time() - start
    self._log_usage(response.usage, elapsed)
    return response.content[0].text
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && python -m pytest tests/test_bulk_submit.py::test_send_vision_multi_sends_all_images -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/ai_client.py backend/tests/test_bulk_submit.py
git commit -m "feat(backend): add send_vision_multi to AIClient for bulk-scan"
```

---

## Task 2: Pydantic Schemas + Prompt File

**Files:**
- Modify: `backend/app/models/schemas.py`
- Create: `backend/app/prompts/bulk_scan.txt`

- [ ] **Step 1: Add Pydantic schemas to `schemas.py`**

Add at the end of `backend/app/models/schemas.py`, before `StreakResponse`:

```python
# --- Bulk Scan (Pakke 4) ---

class BulkSubmitResult(BaseModel):
    assignment_id: str
    assignment_text: str
    student_answer: str | None
    status: Literal["correct", "incorrect", "uncertain", "not_found"]
    error_type: Literal["procedural", "understanding", "careless"] | None = None
    error_description: str | None = None
    confidence: float
    page_index: int | None = None
    submission_id: str | None = None


class BulkSubmitSummary(BaseModel):
    total: int
    correct: int
    incorrect: int
    uncertain: int
    not_found: int


class BulkSubmitResponse(BaseModel):
    session_id: str
    results: list[BulkSubmitResult]
    summary: BulkSubmitSummary
    scan_ids: list[str]
```

- [ ] **Step 2: Create the bulk scan prompt file**

Create `backend/app/prompts/bulk_scan.txt`:

```
Du er Kvante, en matematikhjælper for folkeskoleelever.

Du modtager foto(s) af en elevs håndskrevne svar på et matematikark, samt en liste over opgaverne eleven skulle løse med korrekte svar.

Din opgave:
1. Find hvert håndskrevet svar i billedet/billederne
2. Match hvert svar til den rigtige opgave via opgavenummer, regnestykke, eller tallene
3. Læs elevens svar omhyggeligt — læs hvad der FAKTISK ER SKREVET, beregn IKKE selv
4. Sammenlign med det korrekte svar og klassificér fejltypen hvis forkert. Beskriv fejlen kort på dansk
5. Vurdér din confidence (0.0–1.0) for hvert svar baseret på læsbarhed

Fejltyper:
- "procedural": Rigtig metode, fejl i udførelsen (mente-fejl, forskydningsfejl, ciferfejl)
- "understanding": Forkert metode (brugte subtraktion i stedet for addition)
- "careless": Eleven kan metoden, lille slip (skrev 3 i stedet for 8)

KRITISK: Beregn ALDRIG svaret selv. Læs kun hvad eleven har skrevet. Hvis du ikke kan læse et svar, sæt confidence lavt.

Returnér KUN valid JSON — ingen markdown, ingen forklaring, ingen kodeblokke.

Format:
{
  "matches": [
    {
      "assignment_index": 0,
      "student_answer": "101",
      "confidence": 0.95,
      "page_index": 0,
      "error_type": null,
      "error_description": null
    }
  ]
}

assignment_index er 0-baseret og refererer til opgave-listen du modtager.
page_index er 0-baseret og refererer til billednummeret.
error_type og error_description er kun udfyldt for forkerte svar.
Svar der ikke kan findes i billedet skal IKKE inkluderes i matches.
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/models/schemas.py backend/app/prompts/bulk_scan.txt
git commit -m "feat(backend): add bulk-scan Pydantic schemas and AI prompt"
```

---

## Task 3: Bulk Scan Service

**Files:**
- Create: `backend/app/services/bulk_scan_service.py`
- Test: `backend/tests/test_bulk_submit.py` (additional tests)

- [ ] **Step 1: Write the failing test for `build_user_message`**

Add to `backend/tests/test_bulk_submit.py`:

```python
from app.services.bulk_scan_service import build_user_message, parse_ai_response


def test_build_user_message_includes_all_assignments():
    """User message should list all assignments with index, text, and correct answer."""
    assignments = [
        {"index": 0, "text": "34 + 67", "correct_answer": "101"},
        {"index": 1, "text": "245 + 378", "correct_answer": "623"},
        {"index": 2, "text": "7 × 8", "correct_answer": "56"},
    ]
    msg = build_user_message(assignments)

    assert "34 + 67" in msg
    assert "245 + 378" in msg
    assert "101" in msg
    assert "623" in msg
    assert "Opgave 1" in msg
    assert "Opgave 3" in msg
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_bulk_submit.py::test_build_user_message_includes_all_assignments -v`
Expected: FAIL with `ModuleNotFoundError` or `ImportError`

- [ ] **Step 3: Write the failing test for `parse_ai_response`**

Add to `backend/tests/test_bulk_submit.py`:

```python
def test_parse_ai_response_valid_json():
    """parse_ai_response should extract matches from valid AI JSON."""
    ai_text = json.dumps({
        "matches": [
            {
                "assignment_index": 0,
                "student_answer": "101",
                "confidence": 0.95,
                "page_index": 0,
                "error_type": None,
                "error_description": None,
            },
            {
                "assignment_index": 2,
                "student_answer": "52",
                "confidence": 0.88,
                "page_index": 0,
                "error_type": "careless",
                "error_description": "Forkert tabel-produkt",
            },
        ]
    })
    matches = parse_ai_response(ai_text)
    assert len(matches) == 2
    assert matches[0]["assignment_index"] == 0
    assert matches[0]["student_answer"] == "101"
    assert matches[1]["error_type"] == "careless"


def test_parse_ai_response_strips_markdown_fences():
    """parse_ai_response should handle AI wrapping JSON in ```json ... ``` blocks."""
    ai_text = '```json\n{"matches": [{"assignment_index": 0, "student_answer": "42", "confidence": 0.9, "page_index": 0, "error_type": null, "error_description": null}]}\n```'
    matches = parse_ai_response(ai_text)
    assert len(matches) == 1
    assert matches[0]["student_answer"] == "42"


def test_parse_ai_response_invalid_json_raises():
    """parse_ai_response should raise ValueError on invalid JSON."""
    import pytest
    with pytest.raises(ValueError, match="parse AI"):
        parse_ai_response("this is not json at all")
```

- [ ] **Step 4: Implement `bulk_scan_service.py`**

Create `backend/app/services/bulk_scan_service.py`:

```python
"""Bulk-scan service: build prompts, parse AI responses, validate results."""

import json
import logging
import re

from app.config import settings
from app.services.answer_reader import compare_answer

logger = logging.getLogger(__name__)


def build_user_message(assignments: list[dict]) -> str:
    """Build the user message listing all assignments for AI matching."""
    lines = ["Eleven skulle løse disse opgaver:\n"]
    for a in assignments:
        idx = a["index"]
        lines.append(f"Opgave {idx + 1} (index {idx}): {a['text']} = {a['correct_answer']}")
    lines.append("\nFind og læs elevens håndskrevne svar for hver opgave.")
    return "\n".join(lines)


def parse_ai_response(ai_text: str) -> list[dict]:
    """Parse AI response JSON, stripping markdown fences if present."""
    text = ai_text.strip()

    # Strip ```json ... ``` wrapper
    fence_match = re.search(r"```(?:json)?\s*\n?(.*?)\n?\s*```", text, re.DOTALL)
    if fence_match:
        text = fence_match.group(1).strip()

    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        raise ValueError(f"Could not parse AI response as JSON: {e}") from e

    if "matches" not in data:
        raise ValueError(f"AI response missing 'matches' key: {list(data.keys())}")

    return data["matches"]


def validate_and_build_results(
    matches: list[dict],
    assignments: list,  # SQLAlchemy Assignment objects
    confidence_threshold: float,
) -> list[dict]:
    """Validate AI matches against session assignments. Returns list of result dicts.

    - Skips already-complete assignments
    - Uses compare_answer() as ground truth
    - Marks low-confidence as uncertain
    - Deduplicates: highest confidence wins
    """
    # Build index → assignment map
    idx_to_assignment = {i: a for i, a in enumerate(assignments)}

    # Deduplicate: keep highest confidence per assignment_index
    best_by_index: dict[int, dict] = {}
    for match in matches:
        idx = match.get("assignment_index")
        if idx is None:
            continue
        confidence = match.get("confidence", 0.0)
        if idx not in best_by_index or confidence > best_by_index[idx].get("confidence", 0):
            best_by_index[idx] = match

    results = []
    for idx, match in sorted(best_by_index.items()):
        assignment = idx_to_assignment.get(idx)
        if assignment is None:
            logger.warning("AI returned assignment_index=%d but session only has %d assignments", idx, len(assignments))
            continue

        # Skip already-complete assignments
        if assignment.status in ("complete", "completed"):
            logger.info("Skipping already-complete assignment %s (index %d)", assignment.id, idx)
            continue

        student_answer = match.get("student_answer")
        confidence = match.get("confidence", 0.0)
        page_index = match.get("page_index", 0)
        error_type = match.get("error_type")
        error_description = match.get("error_description")

        # Determine status
        if confidence < confidence_threshold:
            status = "uncertain"
        elif student_answer and assignment.correct_answer:
            is_correct = compare_answer(student_answer, assignment.correct_answer)
            status = "correct" if is_correct else "incorrect"
        else:
            status = "uncertain"

        # Clear error fields for correct answers
        if status == "correct":
            error_type = None
            error_description = None

        results.append({
            "assignment_id": assignment.id,
            "assignment_index": idx,
            "assignment_text": assignment.text,
            "student_answer": student_answer,
            "status": status,
            "error_type": error_type,
            "error_description": error_description,
            "confidence": confidence,
            "page_index": page_index,
        })

    return results
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_bulk_submit.py -v`
Expected: All 5 tests PASS

- [ ] **Step 6: Write the failing test for `validate_and_build_results`**

Add to `backend/tests/test_bulk_submit.py`:

```python
from unittest.mock import MagicMock
from app.services.bulk_scan_service import validate_and_build_results


def _mock_assignment(id="a1", text="34 + 67", correct_answer="101", status="not_started"):
    a = MagicMock()
    a.id = id
    a.text = text
    a.correct_answer = correct_answer
    a.status = status
    return a


def test_validate_correct_answer():
    """Correct student answer should produce status='correct'."""
    assignments = [_mock_assignment(id="a1", text="34 + 67", correct_answer="101")]
    matches = [{"assignment_index": 0, "student_answer": "101", "confidence": 0.95, "page_index": 0, "error_type": None, "error_description": None}]

    results = validate_and_build_results(matches, assignments, confidence_threshold=0.6)
    assert len(results) == 1
    assert results[0]["status"] == "correct"
    assert results[0]["error_type"] is None


def test_validate_incorrect_answer():
    """Wrong answer should produce status='incorrect' with error info preserved."""
    assignments = [_mock_assignment(id="a1", text="245 + 378", correct_answer="623")]
    matches = [{"assignment_index": 0, "student_answer": "613", "confidence": 0.88, "page_index": 0, "error_type": "procedural", "error_description": "Mente-fejl"}]

    results = validate_and_build_results(matches, assignments, confidence_threshold=0.6)
    assert len(results) == 1
    assert results[0]["status"] == "incorrect"
    assert results[0]["error_type"] == "procedural"
    assert results[0]["error_description"] == "Mente-fejl"


def test_validate_low_confidence_is_uncertain():
    """Confidence below threshold should produce status='uncertain'."""
    assignments = [_mock_assignment()]
    matches = [{"assignment_index": 0, "student_answer": "101", "confidence": 0.3, "page_index": 0, "error_type": None, "error_description": None}]

    results = validate_and_build_results(matches, assignments, confidence_threshold=0.6)
    assert len(results) == 1
    assert results[0]["status"] == "uncertain"


def test_validate_skips_complete_assignments():
    """Already-complete assignments should be skipped."""
    assignments = [_mock_assignment(status="complete")]
    matches = [{"assignment_index": 0, "student_answer": "101", "confidence": 0.95, "page_index": 0, "error_type": None, "error_description": None}]

    results = validate_and_build_results(matches, assignments, confidence_threshold=0.6)
    assert len(results) == 0


def test_validate_deduplicates_highest_confidence():
    """When AI returns two matches for the same assignment, keep highest confidence."""
    assignments = [_mock_assignment()]
    matches = [
        {"assignment_index": 0, "student_answer": "100", "confidence": 0.6, "page_index": 0, "error_type": None, "error_description": None},
        {"assignment_index": 0, "student_answer": "101", "confidence": 0.9, "page_index": 1, "error_type": None, "error_description": None},
    ]

    results = validate_and_build_results(matches, assignments, confidence_threshold=0.6)
    assert len(results) == 1
    assert results[0]["student_answer"] == "101"
    assert results[0]["confidence"] == 0.9
```

- [ ] **Step 7: Run all tests**

Run: `cd backend && python -m pytest tests/test_bulk_submit.py -v`
Expected: All tests PASS

- [ ] **Step 8: Commit**

```bash
git add backend/app/services/bulk_scan_service.py backend/tests/test_bulk_submit.py
git commit -m "feat(backend): add bulk_scan_service with prompt builder, parser, validator"
```

---

## Task 4: Bulk Submit Router + Integration Tests

**Files:**
- Create: `backend/app/routers/bulk_submit.py`
- Modify: `backend/app/main.py`
- Test: `backend/tests/test_bulk_submit.py` (integration tests)

- [ ] **Step 1: Write the failing integration test**

Add to `backend/tests/test_bulk_submit.py`:

```python
from app.models.db import Assignment, MathProblem, Session, Submission


def _seed_session_with_assignments(db, count=3):
    """Create a session with assignments for testing. Returns (session, [assignments])."""
    session = Session(
        student_id="default",
        mode="weekly",
        name="Uge 12 matematik",
        topic="mixed",
        detected_language="da",
    )
    db.add(session)
    db.flush()

    problems_data = [
        ("34 + 67", "101", "addition"),
        ("245 + 378", "623", "addition"),
        ("7 × 8", "56", "multiplication"),
        ("156 − 89", "67", "subtraction"),
        ("9 × 6", "54", "multiplication"),
        ("453 − 187", "266", "subtraction"),
    ]

    assignments = []
    for i in range(min(count, len(problems_data))):
        text, answer, topic = problems_data[i]
        p = MathProblem(
            topic=topic, subtopic="test", difficulty=2, grade_level=4,
            text=text, type="calculation", correct_answer=answer,
        )
        db.add(p)
        db.flush()

        a = Assignment(
            session_id=session.id, problem_id=p.id,
            local_id=str(i + 1), text=text, type="calculation",
            topic=topic, difficulty_estimate=2,
            correct_answer=answer, position=i,
        )
        db.add(a)
        assignments.append(a)

    db.commit()
    for a in assignments:
        db.refresh(a)
    db.refresh(session)
    return session, assignments


MOCK_AI_RESPONSE = json.dumps({
    "matches": [
        {"assignment_index": 0, "student_answer": "101", "confidence": 0.95, "page_index": 0, "error_type": None, "error_description": None},
        {"assignment_index": 1, "student_answer": "613", "confidence": 0.88, "page_index": 0, "error_type": "procedural", "error_description": "Mente-fejl i hundrederne"},
        {"assignment_index": 2, "student_answer": "56", "confidence": 0.92, "page_index": 0, "error_type": None, "error_description": None},
    ]
})


@patch("app.routers.bulk_submit.get_ai_client")
def test_bulk_submit_returns_correct_response(mock_get_client, client, test_db):
    """Full integration: bulk-submit with mock AI returns correct BulkSubmitResponse."""
    session, assignments = _seed_session_with_assignments(test_db, count=3)

    mock_client = MagicMock()
    mock_client.send_vision_multi.return_value = MOCK_AI_RESPONSE
    mock_get_client.return_value = mock_client

    # Create a minimal JPEG-like image
    fake_image = b"\xff\xd8\xff\xe0" + b"\x00" * 100

    response = client.post(
        f"/sessions/{session.id}/bulk-submit",
        files=[("images", ("page1.jpg", fake_image, "image/jpeg"))],
    )
    assert response.status_code == 200
    data = response.json()

    assert data["session_id"] == session.id
    assert len(data["results"]) == 3
    assert data["summary"]["correct"] == 2  # 101 and 56
    assert data["summary"]["incorrect"] == 1  # 613 != 623
    assert data["summary"]["total"] == 3
    assert len(data["scan_ids"]) == 1

    # Check individual results
    correct_result = next(r for r in data["results"] if r["assignment_id"] == assignments[0].id)
    assert correct_result["status"] == "correct"
    assert correct_result["student_answer"] == "101"

    incorrect_result = next(r for r in data["results"] if r["assignment_id"] == assignments[1].id)
    assert incorrect_result["status"] == "incorrect"
    assert incorrect_result["error_type"] == "procedural"


@patch("app.routers.bulk_submit.get_ai_client")
def test_bulk_submit_creates_submissions(mock_get_client, client, test_db):
    """Bulk submit should create one Submission per matched assignment."""
    session, assignments = _seed_session_with_assignments(test_db, count=3)

    mock_client = MagicMock()
    mock_client.send_vision_multi.return_value = MOCK_AI_RESPONSE
    mock_get_client.return_value = mock_client

    fake_image = b"\xff\xd8\xff\xe0" + b"\x00" * 100
    client.post(
        f"/sessions/{session.id}/bulk-submit",
        files=[("images", ("page1.jpg", fake_image, "image/jpeg"))],
    )

    submissions = test_db.query(Submission).filter(Submission.session_id == session.id).all()
    assert len(submissions) == 3


@patch("app.routers.bulk_submit.get_ai_client")
def test_bulk_submit_updates_assignment_status(mock_get_client, client, test_db):
    """Bulk submit should set status='complete' for correct, 'in_progress' for incorrect."""
    session, assignments = _seed_session_with_assignments(test_db, count=3)

    mock_client = MagicMock()
    mock_client.send_vision_multi.return_value = MOCK_AI_RESPONSE
    mock_get_client.return_value = mock_client

    fake_image = b"\xff\xd8\xff\xe0" + b"\x00" * 100
    client.post(
        f"/sessions/{session.id}/bulk-submit",
        files=[("images", ("page1.jpg", fake_image, "image/jpeg"))],
    )

    test_db.expire_all()
    assert assignments[0].status == "complete"   # 101 correct
    assert assignments[1].status == "in_progress" # 613 incorrect
    assert assignments[2].status == "complete"    # 56 correct


@patch("app.routers.bulk_submit.get_ai_client")
def test_bulk_submit_skips_already_complete(mock_get_client, client, test_db):
    """Assignments already marked complete should be skipped in results."""
    session, assignments = _seed_session_with_assignments(test_db, count=3)
    assignments[0].status = "complete"
    test_db.commit()

    mock_client = MagicMock()
    mock_client.send_vision_multi.return_value = MOCK_AI_RESPONSE
    mock_get_client.return_value = mock_client

    fake_image = b"\xff\xd8\xff\xe0" + b"\x00" * 100
    response = client.post(
        f"/sessions/{session.id}/bulk-submit",
        files=[("images", ("page1.jpg", fake_image, "image/jpeg"))],
    )
    data = response.json()

    # Assignment 0 was already complete, so only 2 results
    assert len(data["results"]) == 2
    assert all(r["assignment_id"] != assignments[0].id for r in data["results"])


def test_bulk_submit_404_for_nonexistent_session(client, test_db):
    """Should return 404 for non-existent session."""
    fake_image = b"\xff\xd8\xff\xe0" + b"\x00" * 100
    response = client.post(
        "/sessions/nonexistent-id/bulk-submit",
        files=[("images", ("page1.jpg", fake_image, "image/jpeg"))],
    )
    assert response.status_code == 404


@patch("app.routers.bulk_submit.get_ai_client")
def test_bulk_submit_handles_no_matches(mock_get_client, client, test_db):
    """When AI returns no matches, results should be empty with appropriate summary."""
    session, assignments = _seed_session_with_assignments(test_db, count=3)

    mock_client = MagicMock()
    mock_client.send_vision_multi.return_value = '{"matches": []}'
    mock_get_client.return_value = mock_client

    fake_image = b"\xff\xd8\xff\xe0" + b"\x00" * 100
    response = client.post(
        f"/sessions/{session.id}/bulk-submit",
        files=[("images", ("page1.jpg", fake_image, "image/jpeg"))],
    )
    data = response.json()

    assert data["summary"]["correct"] == 0
    assert data["summary"]["incorrect"] == 0
    assert data["summary"]["not_found"] == 3
    assert data["summary"]["total"] == 3
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_bulk_submit.py::test_bulk_submit_returns_correct_response -v`
Expected: FAIL (router doesn't exist)

- [ ] **Step 3: Implement the router**

Create `backend/app/routers/bulk_submit.py`:

```python
"""Bulk-scan endpoint: submit multiple photos of a student's completed worksheet."""

import logging
import os

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.orm import Session as DBSession

from app.config import settings
from app.database import get_db
from app.models.db import Assignment, Scan, Session, Submission
from app.models.schemas import BulkSubmitResponse, BulkSubmitResult, BulkSubmitSummary
from app.services.ai_client import get_ai_client
from app.services.bulk_scan_service import build_user_message, parse_ai_response, validate_and_build_results
from app.services.streak_service import update_streak

logger = logging.getLogger(__name__)
router = APIRouter()

_scans_dir = os.path.join(settings.upload_dir, "scans")
os.makedirs(_scans_dir, exist_ok=True)


@router.post(
    "/sessions/{session_id}/bulk-submit",
    response_model=BulkSubmitResponse,
)
async def bulk_submit(
    session_id: str,
    images: list[UploadFile] = File(...),
    db: DBSession = Depends(get_db),
):
    """Accept 1+ photos of a student's worksheet, match answers to assignments via AI Vision."""
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    assignments = (
        db.query(Assignment)
        .filter(Assignment.session_id == session_id)
        .order_by(Assignment.position)
        .all()
    )
    if not assignments:
        raise HTTPException(status_code=400, detail="Session has no assignments")

    # Read all images and save as Scan records
    image_bytes_list = []
    scan_ids = []
    for img_file in images:
        contents = await img_file.read()
        if len(contents) > settings.max_upload_size:
            raise HTTPException(status_code=400, detail="Image exceeds maximum upload size (10 MB)")

        scan = Scan(image_path="")
        db.add(scan)
        db.commit()
        db.refresh(scan)

        image_path = os.path.join(_scans_dir, f"scan_{scan.id}.jpg")
        with open(image_path, "wb") as f:
            f.write(contents)
        scan.image_path = image_path
        db.commit()

        image_bytes_list.append(contents)
        scan_ids.append(scan.id)

    # Build assignment list for AI prompt
    assignment_list = [
        {"index": i, "text": a.text, "correct_answer": a.correct_answer or ""}
        for i, a in enumerate(assignments)
    ]

    # Load system prompt
    prompt_path = settings.prompts_dir / "bulk_scan.txt"
    system_prompt = prompt_path.read_text(encoding="utf-8")

    user_message = build_user_message(assignment_list)

    # Call AI Vision
    ai_client = get_ai_client()
    try:
        ai_response = ai_client.send_vision_multi(
            system_prompt=system_prompt,
            images=image_bytes_list,
            user_message=user_message,
        )
    except Exception as e:
        logger.exception("AI bulk-scan call failed")
        raise HTTPException(
            status_code=502,
            detail={"error": "ai_failed", "message": str(e),
                    "student_message": "Kvante kunne ikke læse dit ark — prøv igen."},
        )

    # Parse AI response
    try:
        matches = parse_ai_response(ai_response)
    except ValueError as e:
        logger.error("Failed to parse AI response: %s. Raw: %s", e, ai_response[:500])
        raise HTTPException(
            status_code=502,
            detail={"error": "ai_parse_failed", "message": str(e),
                    "student_message": "Kvante kunne ikke forstå resultaterne — prøv igen."},
        )

    # Validate and build results
    validated = validate_and_build_results(
        matches, assignments, settings.confidence_threshold,
    )

    # Create Submissions and update Assignment status
    results: list[BulkSubmitResult] = []
    correct_count = 0
    incorrect_count = 0
    uncertain_count = 0

    for v in validated:
        assignment = next(a for a in assignments if a.id == v["assignment_id"])

        # Build analysis dict (same shape as single submission)
        analysis = {
            "student_answer": v["student_answer"] or "",
            "correct_answer": assignment.correct_answer or "",
            "full_ocr_text": "",
            "methodology_sound": v["status"] == "correct",
            "steps_identified": [],
            "errors": [v["error_description"]] if v["error_description"] else [],
            "correct_elements": [],
            "methodology_assessment": v["error_description"] or "",
            "handwriting_note": "",
            "confidence": v["confidence"],
            "page_index": v["page_index"],
            "bulk_scan": True,
            "error_type": v["error_type"],
        }

        # Determine attempt number
        attempt_count = (
            db.query(Submission)
            .filter(Submission.assignment_id == assignment.id)
            .count()
        ) + 1

        submission = Submission(
            session_id=session_id,
            assignment_id=assignment.id,
            work_image_path=scan_ids[v["page_index"]] if v["page_index"] < len(scan_ids) else scan_ids[0],
            analysis=analysis,
            attempt_number=attempt_count,
        )
        db.add(submission)
        db.commit()
        db.refresh(submission)

        # Update assignment status
        if v["status"] == "correct":
            assignment.status = "complete"
            correct_count += 1
        elif v["status"] == "incorrect":
            assignment.status = "in_progress"
            assignment.feedback_summary = v["error_description"]
            incorrect_count += 1
        elif v["status"] == "uncertain":
            uncertain_count += 1
        db.commit()

        # Streak update for correct answers
        if v["status"] == "correct":
            update_streak(db, session.student_id)

        results.append(BulkSubmitResult(
            assignment_id=v["assignment_id"],
            assignment_text=v["assignment_text"],
            student_answer=v["student_answer"],
            status=v["status"],
            error_type=v["error_type"],
            error_description=v["error_description"],
            confidence=v["confidence"],
            page_index=v["page_index"],
            submission_id=submission.id,
        ))

    # Add not_found entries for unmatched assignments
    matched_ids = {r.assignment_id for r in results}
    not_found_count = 0
    for a in assignments:
        if a.id not in matched_ids and a.status not in ("complete", "completed"):
            not_found_count += 1
            results.append(BulkSubmitResult(
                assignment_id=a.id,
                assignment_text=a.text,
                student_answer=None,
                status="not_found",
                confidence=0.0,
                submission_id=None,
            ))

    summary = BulkSubmitSummary(
        total=len(assignments) - sum(1 for a in assignments if a.status in ("complete", "completed") and a.id not in matched_ids),
        correct=correct_count,
        incorrect=incorrect_count,
        uncertain=uncertain_count,
        not_found=not_found_count,
    )

    return BulkSubmitResponse(
        session_id=session_id,
        results=results,
        summary=summary,
        scan_ids=scan_ids,
    )
```

- [ ] **Step 4: Register the router in `main.py`**

In `backend/app/main.py`, add import and include:

```python
from app.routers import assignments, bulk_submit, chat, dev_screenshots, dev_todos, feedback, health, library, pages, practice, scans, streaks, students, submissions, test_ocr
```

And add after `app.include_router(scans.router)`:

```python
app.include_router(bulk_submit.router)
```

- [ ] **Step 5: Run all tests**

Run: `cd backend && python -m pytest tests/test_bulk_submit.py -v`
Expected: All tests PASS

- [ ] **Step 6: Run full test suite to check for regressions**

Run: `cd backend && python -m pytest --tb=short -q`
Expected: All existing tests still pass

- [ ] **Step 7: Commit**

```bash
git add backend/app/routers/bulk_submit.py backend/app/main.py backend/tests/test_bulk_submit.py
git commit -m "feat(backend): add POST /sessions/{id}/bulk-submit endpoint with TDD tests"
```

---

## Task 5: iOS — `BulkSubmitResponse` Model + `APIClient.bulkSubmit()`

**Files:**
- Modify: `ios/Kvante/Kvante/Models/APIResponses.swift`
- Modify: `ios/Kvante/Kvante/Services/APIClient.swift`

- [ ] **Step 1: Add Swift response models**

Add to `ios/Kvante/Kvante/Models/APIResponses.swift` before the `// MARK: - Health` section:

```swift
// MARK: - Bulk Scan (Pakke 4)

struct BulkSubmitResult: Codable, Identifiable {
    let assignmentId: String
    let assignmentText: String
    let studentAnswer: String?
    let status: String  // correct, incorrect, uncertain, not_found
    let errorType: String?
    let errorDescription: String?
    let confidence: Double
    let pageIndex: Int?
    let submissionId: String?

    var id: String { assignmentId }

    enum CodingKeys: String, CodingKey {
        case assignmentText = "assignment_text"
        case assignmentId = "assignment_id"
        case studentAnswer = "student_answer"
        case status
        case errorType = "error_type"
        case errorDescription = "error_description"
        case confidence
        case pageIndex = "page_index"
        case submissionId = "submission_id"
    }
}

struct BulkSubmitSummary: Codable {
    let total: Int
    let correct: Int
    let incorrect: Int
    let uncertain: Int
    let notFound: Int

    enum CodingKeys: String, CodingKey {
        case total, correct, incorrect, uncertain
        case notFound = "not_found"
    }
}

struct BulkSubmitResponse: Codable {
    let sessionId: String
    let results: [BulkSubmitResult]
    let summary: BulkSubmitSummary
    let scanIds: [String]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case results, summary
        case scanIds = "scan_ids"
    }
}
```

- [ ] **Step 2: Add `bulkSubmit()` to `APIClient.swift`**

Add before `// MARK: - Dev Screenshot`:

```swift
// MARK: - Bulk Scan

func bulkSubmit(sessionId: String, images: [Data]) async throws -> BulkSubmitResponse {
    let url = baseURL.appendingPathComponent("sessions/\(sessionId)/bulk-submit")
    var request = URLRequest(url: url, timeoutInterval: 60)  // 60s for multi-image AI
    request.httpMethod = "POST"

    let boundary = UUID().uuidString
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var body = Data()
    for (i, imageData) in images.enumerated() {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"images\"; filename=\"page\(i).jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n")
    }
    body.append("--\(boundary)--\r\n")
    request.httpBody = body

    let (data, response) = try await session.data(for: request)
    try checkResponse(response, data: data)
    return try decoder.decode(BulkSubmitResponse.self, from: data)
}
```

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Models/APIResponses.swift ios/Kvante/Kvante/Services/APIClient.swift
git commit -m "feat(ios): add BulkSubmitResponse model and APIClient.bulkSubmit()"
```

---

## Task 6: iOS — `SessionViewModel` Bulk Result Processing

**Files:**
- Modify: `ios/Kvante/Kvante/ViewModels/SessionViewModel.swift`

- [ ] **Step 1: Add bulk-scan state and processing method**

Add new stored properties and method to `SessionViewModel`:

```swift
// Add to stored properties section:
var errorDescription: [String: String]  // assignment_id → error description
var studentAnswer: [String: String]     // assignment_id → student's answer
var errorType: [String: String]         // assignment_id → error type
var bulkScanIds: [String]              // scan IDs from last bulk scan
var pageIndexByAssignment: [String: Int] // assignment_id → page_index

// Add to init, after teacherComments initialization:
self.errorDescription = [:]
self.studentAnswer = [:]
self.errorType = [:]
self.bulkScanIds = []
self.pageIndexByAssignment = [:]
```

Add method:

```swift
/// Process bulk-scan results: update status, store error info, scan IDs.
func processBulkResult(_ response: BulkSubmitResponse) {
    bulkScanIds = response.scanIds

    for result in response.results {
        let id = result.assignmentId

        switch result.status {
        case "correct":
            statusByAssignment[id] = .done
        case "incorrect":
            statusByAssignment[id] = .inProgress
        case "uncertain":
            // Keep existing status or set inProgress
            if statusByAssignment[id] == .notStarted {
                statusByAssignment[id] = .inProgress
            }
        default:
            break  // not_found — leave unchanged
        }

        if let answer = result.studentAnswer {
            studentAnswer[id] = answer
        }
        if let desc = result.errorDescription {
            errorDescription[id] = desc
        }
        if let type = result.errorType {
            errorType[id] = type
        }
        if let feedback = result.errorDescription {
            feedbackSummary[id] = feedback
        }
        if let pageIdx = result.pageIndex {
            pageIndexByAssignment[id] = pageIdx
        }
        if let subId = result.submissionId {
            // Store submission ID for feedback generation later
            latestScanId[id] = response.scanIds.indices.contains(result.pageIndex ?? 0)
                ? response.scanIds[result.pageIndex ?? 0] : response.scanIds.first ?? ""
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ios/Kvante/Kvante/ViewModels/SessionViewModel.swift
git commit -m "feat(ios): add bulk-scan result processing to SessionViewModel"
```

---

## Task 7: iOS — BulkScanButton + VisionKit Scanner Integration

**Files:**
- Create: `ios/Kvante/Kvante/Views/Ark/BulkScanButton.swift`
- Modify: `ios/Kvante/Kvante/Views/Ark/AssignmentSheetView.swift`

- [ ] **Step 1: Create BulkScanButton**

Create `ios/Kvante/Kvante/Views/Ark/BulkScanButton.swift`:

```swift
import SwiftUI
import VisionKit

// MARK: - Image Downscaling

private func downscaleToJPEG(_ image: UIImage, maxDimension: CGFloat = 2048, quality: CGFloat = 0.8) -> Data {
    let size = image.size
    let scale: CGFloat
    if max(size.width, size.height) > maxDimension {
        scale = maxDimension / max(size.width, size.height)
    } else {
        scale = 1.0
    }

    let newSize = CGSize(width: size.width * scale, height: size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    let scaled = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
    return scaled.jpegData(compressionQuality: quality) ?? Data()
}

// MARK: - BulkScanButton

struct BulkScanButton: View {
    let hasIncompleteAssignments: Bool
    let onScanComplete: ([Data]) -> Void

    @State private var showScanner = false

    var body: some View {
        if hasIncompleteAssignments {
            Button {
                showScanner = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Scan hele arket")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(KvanteTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScannerView { images in
                    showScanner = false
                    let jpegData = images.map { downscaleToJPEG($0) }
                    onScanComplete(jpegData)
                } onCancel: {
                    showScanner = false
                }
            }
        }
    }
}

// MARK: - DocumentScannerView (VisionKit wrapper)

struct DocumentScannerView: UIViewControllerRepresentable {
    let onComplete: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onComplete: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onComplete: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            onComplete(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onCancel()
        }
    }
}
```

- [ ] **Step 2: Integrate BulkScanButton into AssignmentSheetView**

In `ios/Kvante/Kvante/Views/Ark/AssignmentSheetView.swift`, add state and bulk scan handling:

Add to struct properties:

```swift
@State private var isBulkScanning = false
@State private var bulkScanError: String?
@State private var presentedError: ArkFeedbackItem?
@State private var presentedRescan: ArkFeedbackItem?
```

Add BulkScanButton after the ScrollView, inside the VStack, before the closing `}`:

```swift
// Bulk scan button
if !isBulkScanning {
    BulkScanButton(
        hasIncompleteAssignments: session.completedCount < session.totalAssignments
    ) { imageDataList in
        Task {
            await performBulkScan(imageDataList)
        }
    }
    .padding(.bottom, 16)
}

// Loading state
if isBulkScanning {
    VStack(spacing: 8) {
        ProgressView()
            .tint(KvanteTheme.Colors.primary)
        Text("Kvante læser dit ark...")
            .font(.subheadline)
            .foregroundStyle(KvanteTheme.Colors.textSecondary)
    }
    .padding(.vertical, 16)
}

// Error message
if let error = bulkScanError {
    VStack(spacing: 8) {
        Text(error)
            .font(.subheadline)
            .foregroundStyle(KvanteTheme.Colors.error)
            .multilineTextAlignment(.center)
        Button("Prøv igen") {
            bulkScanError = nil
        }
        .font(.subheadline.weight(.medium))
    }
    .padding(16)
}
```

Add the method:

```swift
@MainActor
private func performBulkScan(_ images: [Data]) async {
    isBulkScanning = true
    bulkScanError = nil

    do {
        let response = try await apiClient.bulkSubmit(
            sessionId: session.sessionId,
            images: images
        )
        session.processBulkResult(response)
    } catch {
        bulkScanError = error.localizedDescription
    }

    isBulkScanning = false
}
```

- [ ] **Step 3: Build and verify in Xcode**

Build the project in Xcode (Cmd+B) to verify no compilation errors.

- [ ] **Step 4: Commit**

```bash
git add ios/Kvante/Kvante/Views/Ark/BulkScanButton.swift ios/Kvante/Kvante/Views/Ark/AssignmentSheetView.swift
git commit -m "feat(ios): add BulkScanButton with VisionKit multi-page scanner"
```

---

## Task 8: iOS — ArkCell Error Display

**Files:**
- Modify: `ios/Kvante/Kvante/Views/Ark/ArkCell.swift`

- [ ] **Step 1: Read current ArkCell implementation**

Read `ios/Kvante/Kvante/Views/Ark/ArkCell.swift` to understand the current structure before modifying.

- [ ] **Step 2: Add error description parameter and display**

Add `errorDescription: String?` parameter to `ArkCell`. Show it under the assignment text when the status is `inProgress` and an error description exists:

```swift
// Add parameter:
let errorDescription: String?

// In the body, after the assignment text display, add:
if status != .done, let errorDesc = errorDescription {
    Text(errorDesc)
        .font(.caption)
        .foregroundStyle(KvanteTheme.Colors.primary)
        .lineLimit(2)
}
```

- [ ] **Step 3: Update ArkCell call site in AssignmentSheetView**

In `AssignmentSheetView.swift`, update the `ArkCell` initializer to pass `errorDescription`:

```swift
ArkCell(
    assignment: assignment,
    index: index,
    status: session.statusByAssignment[assignment.id] ?? .notStarted,
    scanId: session.latestScanId[assignment.id],
    feedbackSummary: session.feedbackSummary[assignment.id],
    errorDescription: session.errorDescription[assignment.id],
    isCurrent: session.currentAssignmentIndex == index,
    apiClient: apiClient,
    onTap: { onSelectAssignment(index) },
    onFeedbackTap: {
        presentedFeedback = ArkFeedbackItem(
            id: assignment.id,
            assignment: assignment,
            index: index
        )
    }
)
```

- [ ] **Step 4: Build and verify**

Build in Xcode (Cmd+B).

- [ ] **Step 5: Commit**

```bash
git add ios/Kvante/Kvante/Views/Ark/ArkCell.swift ios/Kvante/Kvante/Views/Ark/AssignmentSheetView.swift
git commit -m "feat(ios): show error description in ArkCell for incorrect bulk-scan results"
```

---

## Task 9: iOS — ErrorAnalysisSheet (Bottom Sheet for Incorrect Assignments)

**Files:**
- Create: `ios/Kvante/Kvante/Views/Ark/ErrorAnalysisSheet.swift`
- Modify: `ios/Kvante/Kvante/Views/Ark/AssignmentSheetView.swift`

- [ ] **Step 1: Create ErrorAnalysisSheet**

Create `ios/Kvante/Kvante/Views/Ark/ErrorAnalysisSheet.swift`:

```swift
import SwiftUI

struct ErrorAnalysisSheet: View {
    let assignment: ParsedAssignment
    let studentAnswer: String
    let errorDescription: String
    let scanId: String?
    let apiClient: APIClient
    let onOpenChat: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Opgave \(assignment.localId)")
                .font(.headline)
                .foregroundStyle(KvanteTheme.Colors.ink)

            Text(assignment.text)
                .font(.title3.weight(.semibold))
                .foregroundStyle(KvanteTheme.Colors.ink)

            // Scan image
            if let scanId {
                AsyncImage(url: apiClient.scanImageURL(scanId: scanId)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(KvanteTheme.Colors.cream)
                        .frame(height: 120)
                        .overlay {
                            ProgressView()
                        }
                }
            }

            // What Kvante read
            HStack(spacing: 8) {
                Image(systemName: "text.magnifyingglass")
                    .foregroundStyle(KvanteTheme.Colors.primary)
                Text("Du skrev: \(studentAnswer)")
                    .font(.body.weight(.medium))
            }

            // Error explanation
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(KvanteTheme.Colors.primary)
                Text(errorDescription)
                    .font(.body)
                    .foregroundStyle(KvanteTheme.Colors.ink)
            }
            .padding(12)
            .background(KvanteTheme.Colors.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            Spacer()

            // Get help button
            Button {
                onOpenChat()
            } label: {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("Få hjælp i chatten")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(KvanteTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }
}
```

- [ ] **Step 2: Wire up ErrorAnalysisSheet in AssignmentSheetView**

Add a `.sheet` modifier for error analysis. When an `inProgress` assignment with an `errorDescription` is tapped, show this sheet instead of navigating to chat directly.

In `AssignmentSheetView`, the `onFeedbackTap` closure on `ArkCell` already presents a `FeedbackPreviewSheet`. For bulk-scan results with error descriptions, we present the `ErrorAnalysisSheet` instead. Modify the `onFeedbackTap`:

```swift
onFeedbackTap: {
    if session.errorDescription[assignment.id] != nil {
        presentedError = ArkFeedbackItem(
            id: assignment.id,
            assignment: assignment,
            index: index
        )
    } else {
        presentedFeedback = ArkFeedbackItem(
            id: assignment.id,
            assignment: assignment,
            index: index
        )
    }
}
```

Add sheet modifier after the existing `FeedbackPreviewSheet` sheet:

```swift
.sheet(item: $presentedError) { item in
    ErrorAnalysisSheet(
        assignment: item.assignment,
        studentAnswer: session.studentAnswer[item.assignment.id] ?? "?",
        errorDescription: session.errorDescription[item.assignment.id] ?? "",
        scanId: session.latestScanId[item.assignment.id],
        apiClient: apiClient,
        onOpenChat: {
            presentedError = nil
            onSelectAssignment(item.index)
        }
    )
    .presentationDetents([.medium, .large])
}
```

- [ ] **Step 3: Build and verify**

Build in Xcode (Cmd+B).

- [ ] **Step 4: Commit**

```bash
git add ios/Kvante/Kvante/Views/Ark/ErrorAnalysisSheet.swift ios/Kvante/Kvante/Views/Ark/AssignmentSheetView.swift
git commit -m "feat(ios): add ErrorAnalysisSheet for bulk-scan incorrect assignments"
```

---

## Task 10: iOS — RescanSheet (Bottom Sheet for Uncertain Assignments)

**Files:**
- Create: `ios/Kvante/Kvante/Views/Ark/RescanSheet.swift`
- Modify: `ios/Kvante/Kvante/Views/Ark/AssignmentSheetView.swift`

- [ ] **Step 1: Create RescanSheet**

Create `ios/Kvante/Kvante/Views/Ark/RescanSheet.swift`:

```swift
import SwiftUI
import VisionKit

struct RescanSheet: View {
    let assignment: ParsedAssignment
    let sessionId: String
    let apiClient: APIClient
    let onResult: (SubmissionResponse) -> Void
    let onDismiss: () -> Void

    @State private var typedAnswer = ""
    @State private var showScanner = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var showOrderTips: Bool {
        !UserDefaults.standard.bool(forKey: "hasSeenOrderTips_\(sessionId)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Opgave \(assignment.localId)")
                .font(.headline)
                .foregroundStyle(KvanteTheme.Colors.ink)

            Text("Kvante kan ikke læse dit svar til denne opgave.")
                .font(.body)
                .foregroundStyle(KvanteTheme.Colors.ink)

            // Option A: Scan again
            Button {
                showScanner = true
            } label: {
                HStack {
                    Image(systemName: "camera")
                    Text("Scan igen")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(KvanteTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            // Option B: Type answer
            VStack(alignment: .leading, spacing: 8) {
                Text("Eller skriv dit svar:")
                    .font(.subheadline)
                    .foregroundStyle(KvanteTheme.Colors.textSecondary)

                HStack {
                    TextField("Dit svar...", text: $typedAnswer)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)

                    Button {
                        Task { await submitTypedAnswer() }
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(KvanteTheme.Colors.primary)
                    }
                    .disabled(typedAnswer.isEmpty || isSubmitting)
                }
            }

            if isSubmitting {
                ProgressView("Sender...")
                    .font(.subheadline)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(KvanteTheme.Colors.error)
            }

            // Order tips (shown once per session)
            if showOrderTips {
                orderTipsView
            }

            Spacer()
        }
        .padding(20)
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView { images in
                showScanner = false
                if let first = images.first {
                    Task { await submitRescan(first) }
                }
            } onCancel: {
                showScanner = false
            }
        }
    }

    private var orderTipsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tips til pæn orden", systemImage: "lightbulb")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KvanteTheme.Colors.primary)

            VStack(alignment: .leading, spacing: 4) {
                tipRow("Skriv tydeligt med sort eller blå pen")
                tipRow("Brug linjer eller tern-papir")
                tipRow("Giv god plads mellem opgaverne")
                tipRow("Skriv opgavenummeret ved hvert svar")
            }
        }
        .padding(12)
        .background(KvanteTheme.Colors.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .onAppear {
            UserDefaults.standard.set(true, forKey: "hasSeenOrderTips_\(sessionId)")
        }
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(KvanteTheme.Colors.textSecondary)
    }

    @MainActor
    private func submitTypedAnswer() async {
        isSubmitting = true
        errorMessage = nil
        do {
            let imageData = Data()  // Empty — no image for typed answer
            let response = try await apiClient.submitAnswer(
                sessionId: sessionId,
                assignmentId: assignment.id,
                answerText: typedAnswer,
                fullOcrText: typedAnswer,
                imageData: imageData
            )
            onResult(response)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    @MainActor
    private func submitRescan(_ image: UIImage) async {
        isSubmitting = true
        errorMessage = nil
        let jpegData = downscaleToJPEG(image)
        do {
            let response = try await apiClient.submitWork(
                sessionId: sessionId,
                assignmentId: assignment.id,
                imageData: jpegData
            )
            onResult(response)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}

private func downscaleToJPEG(_ image: UIImage, maxDimension: CGFloat = 2048, quality: CGFloat = 0.8) -> Data {
    let size = image.size
    let scale: CGFloat = max(size.width, size.height) > maxDimension
        ? maxDimension / max(size.width, size.height) : 1.0
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    let scaled = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    return scaled.jpegData(compressionQuality: quality) ?? Data()
}
```

- [ ] **Step 2: Wire up RescanSheet in AssignmentSheetView**

For uncertain (❓) assignments, tapping shows RescanSheet. Modify the `onTap` closure in ArkCell to check for uncertain status:

In `AssignmentSheetView`, update the `onTap` for assignments with uncertain status:

```swift
onTap: {
    let status = session.statusByAssignment[assignment.id] ?? .notStarted
    if status == .inProgress && session.errorDescription[assignment.id] == nil && session.studentAnswer[assignment.id] == nil {
        // Uncertain — show rescan sheet
        presentedRescan = ArkFeedbackItem(
            id: assignment.id,
            assignment: assignment,
            index: index
        )
    } else {
        onSelectAssignment(index)
    }
},
```

Add sheet modifier:

```swift
.sheet(item: $presentedRescan) { item in
    RescanSheet(
        assignment: item.assignment,
        sessionId: session.sessionId,
        apiClient: apiClient,
        onResult: { response in
            presentedRescan = nil
            let isCorrect = response.methodologySound
            if isCorrect {
                session.markCompleted(item.assignment.id, feedback: nil)
            }
        },
        onDismiss: {
            presentedRescan = nil
        }
    )
    .presentationDetents([.medium, .large])
}
```

- [ ] **Step 3: Build and verify**

Build in Xcode (Cmd+B).

- [ ] **Step 4: Commit**

```bash
git add ios/Kvante/Kvante/Views/Ark/RescanSheet.swift ios/Kvante/Kvante/Views/Ark/AssignmentSheetView.swift
git commit -m "feat(ios): add RescanSheet for uncertain bulk-scan results with order tips"
```

---

## Task 11: iOS — BulkScanFeedbackCard in Chat

**Files:**
- Create: `ios/Kvante/Kvante/Views/Chat/BulkScanFeedbackCard.swift`

- [ ] **Step 1: Create the feedback card view**

Create `ios/Kvante/Kvante/Views/Chat/BulkScanFeedbackCard.swift`:

```swift
import SwiftUI

struct BulkScanFeedbackCard: View {
    let results: [BulkSubmitResult]
    let summary: BulkSubmitSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(KvanteTheme.Colors.primary)
                Text("Kvante har tjekket dit ark")
                    .font(.headline)
                    .foregroundStyle(KvanteTheme.Colors.ink)
            }

            // Results list
            VStack(alignment: .leading, spacing: 6) {
                ForEach(results) { result in
                    HStack(spacing: 8) {
                        statusIcon(for: result.status)
                        Text(resultText(for: result))
                            .font(.subheadline)
                            .foregroundStyle(resultColor(for: result.status))
                    }
                }
            }

            // Summary
            Divider()

            Text(summaryText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(KvanteTheme.Colors.ink)

            if summary.incorrect > 0 || summary.uncertain > 0 {
                Text("Tap på en opgave på arket for at se mere")
                    .font(.caption)
                    .foregroundStyle(KvanteTheme.Colors.textSecondary)
            }
        }
        .padding(16)
        .background(KvanteTheme.Colors.cream, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(KvanteTheme.Colors.inkSubtle, lineWidth: 1)
        )
    }

    private func statusIcon(for status: String) -> some View {
        switch status {
        case "correct":
            return Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(KvanteTheme.Colors.success)
        case "incorrect":
            return Image(systemName: "xmark.circle.fill")
                .foregroundStyle(KvanteTheme.Colors.primary)
        case "uncertain":
            return Image(systemName: "questionmark.circle.fill")
                .foregroundStyle(KvanteTheme.Colors.info)
        default:
            return Image(systemName: "minus.circle")
                .foregroundStyle(KvanteTheme.Colors.textSecondary)
        }
    }

    private func resultText(for result: BulkSubmitResult) -> String {
        let base = "Opgave: \(result.assignmentText)"
        switch result.status {
        case "correct":
            return "\(base) = \(result.studentAnswer ?? "?")"
        case "incorrect":
            return "\(base) — \(result.errorDescription ?? "forkert")"
        case "uncertain":
            return "\(base) — kan ikke læse"
        default:
            return "\(base) — ikke fundet"
        }
    }

    private func resultColor(for status: String) -> Color {
        switch status {
        case "correct": return KvanteTheme.Colors.ink
        case "incorrect": return KvanteTheme.Colors.primary
        case "uncertain": return KvanteTheme.Colors.info
        default: return KvanteTheme.Colors.textSecondary
        }
    }

    private var summaryText: String {
        if summary.correct == summary.total {
            return "Alle \(summary.total) rigtige!"
        }
        return "\(summary.correct) af \(summary.total) rigtige"
    }
}
```

- [ ] **Step 2: Build and verify**

Build in Xcode (Cmd+B).

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/Chat/BulkScanFeedbackCard.swift
git commit -m "feat(ios): add BulkScanFeedbackCard for chat summary display"
```

---

## Task 12: Deploy + End-to-End Test

**Files:** No new files. Deploy and test.

- [ ] **Step 1: Run backend tests**

Run: `cd backend && python -m pytest --tb=short -q`
Expected: All tests pass, including new bulk_submit tests.

- [ ] **Step 2: Deploy backend to Mac Mini**

```bash
./scripts/deploy.sh
```

- [ ] **Step 3: Build iOS app on device/simulator**

Build and run in Xcode on iPad simulator or physical device.

- [ ] **Step 4: Manual QA checklist**

1. Create a weekly session with 6 assignments
2. Open the ark — verify "Scan hele arket" button is visible
3. Tap "Scan hele arket" — VisionKit scanner opens
4. Scan a test page (or cancel to verify cancel works)
5. After scan: verify loading state shows
6. After analysis: verify ark shows ✓/✗/❓ correctly
7. Verify error descriptions show under incorrect assignments
8. Tap an incorrect assignment — ErrorAnalysisSheet shows
9. Tap "Få hjælp i chatten" — navigates to chat
10. Verify order tips show once (dismiss, tap another ❓ — tips should not show again)

- [ ] **Step 5: Commit any fixes from QA**

```bash
git add -A
git commit -m "fix(ios): QA fixes for bulk-scan flow"
```
