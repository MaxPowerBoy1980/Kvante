# Pakke 2a — Ark-overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce an "assignment sheet" (ark) screen between Home and Chat — a paper-metaphor-based overview of all assignments in a session. The student sees a grid with status per assignment, scan thumbnails of completed work, and feedback teasers. All session entries (weekly, practice, resume) land on the sheet first. Navigation between sheet and chat is frictionless with perfectly synchronized state via a shared `SessionViewModel`.

**Architecture:** `ContentView` holds `@State activeSession: SessionViewModel?` and `@State activeChatViewModel: ChatViewModel?`. Both are created together in entry-flow functions and survive the full session lifecycle. A `NavigationStack(path: $sessionPath)` with `SessionRoute` enum (.ark, .chat) drives push/pop navigation. `SessionViewModel` is `@Observable` and shared between `AssignmentSheetView` and `ChatView` — mutations in Chat are automatically reflected on the sheet.

**Tech Stack:** FastAPI + Python + pytest (backend TDD), SwiftUI + ImageIO (iOS), SQLAlchemy + SQLite (database)

**Reference:** `docs/superpowers/specs/2026-04-09-pakke-2a-ark-overlay-design.md`

---

## Pre-implementation setup

### Task 0: Create feature branch

**Files:**
- None (git operation)

- [ ] **Step 1: Verify clean working tree**

```bash
cd /Users/olsen/code/Kvante
git status
```

Expected: `working tree clean` (or only known untracked files `docs/design/kvante-plush.jpeg` and `icons/`). If there are uncommitted tracked changes, commit or stash them first.

- [ ] **Step 2: Create and switch to branch**

```bash
cd /Users/olsen/code/Kvante
git checkout main
git pull
git checkout -b feature/pakke-2a-ark-overlay
```

Expected: Branch switched to `feature/pakke-2a-ark-overlay`.

- [ ] **Step 3: Push branch to origin**

```bash
cd /Users/olsen/code/Kvante
git push -u origin feature/pakke-2a-ark-overlay
```

Expected: Branch established on origin as backup.

---

## Phase A — Backend (TDD)

Backend can be developed and tested fully locally via pytest. iOS work in Phase B depends on the backend running on Mac Mini — Task 5 deploys and smoke-tests before iOS work begins.

### Task 1: Pydantic schemas (ArkAssignment, SessionDetailResponse)

**Files:**
- Modify: `backend/app/models/schemas.py`

- [ ] **Step 1: Add Literal import and new models to schemas.py**

Open `backend/app/models/schemas.py`. Find the line:

```python
from pydantic import BaseModel
```

Replace with:

```python
from typing import Literal

from pydantic import BaseModel, field_validator
```

Then at the very end of the file, after the `SessionHistoryResponse` class, add:

```python


# --- Ark Overlay (Pakke 2a) ---

class ArkAssignment(BaseModel):
    id: str
    local_id: str
    text: str
    type: str
    topic: str
    difficulty_estimate: int
    position: int

    ark_status: Literal["not_started", "in_progress", "done"]
    latest_scan_id: str | None = None
    latest_ai_feedback_summary: str | None = None
    teacher_comment: str | None = None

    @field_validator("teacher_comment", mode="before")
    @classmethod
    def normalize_empty_to_none(cls, v: str | None) -> str | None:
        if isinstance(v, str) and v.strip() == "":
            return None
        return v


class SessionDetailResponse(BaseModel):
    session_id: str
    session_name: str
    current_assignment_index: int
    assignments: list[ArkAssignment]
```

- [ ] **Step 2: Verify import works**

```bash
cd /Users/olsen/code/Kvante/backend
python -c "from app.models.schemas import ArkAssignment, SessionDetailResponse; print('OK')"
```

Expected: `OK`

- [ ] **Step 3: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/app/models/schemas.py
git commit -m "$(cat <<'EOF'
feat(backend): add ArkAssignment and SessionDetailResponse Pydantic models

Pakke 2a ark-overlay schemas with ark_status, latest_scan_id,
latest_ai_feedback_summary, and teacher_comment (normalized empty to null).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Fix "complete" vs "completed" status bug

**Files:**
- Modify: `backend/app/routers/practice.py`
- Create: `backend/tests/test_sessions_ark.py` (initial test)

The `submissions.submit_work` endpoint sets `Assignment.status = "complete"` on correct answers (line 123 of `submissions.py`). But `practice.get_session_history` counts `a.status == "completed"` (line 244 of `practice.py`). The strings never match, so `completed_count` is always 0.

**Fix**: Change the counter in `practice.py` to accept both variants. The canonical value set by submissions is `"complete"` — we make the counter defensive.

- [ ] **Step 1: Write test first**

Create `backend/tests/test_sessions_ark.py`:

```python
"""Tests for the extended GET /sessions/{id} endpoint (Pakke 2a ark-overlay)."""

from app.models.db import Assignment, ChatMessage, MathProblem, Session, Submission


def _seed_problem(db, topic="addition", difficulty=2, text="10 + 20", answer="30"):
    """Create a single MathProblem and return it."""
    p = MathProblem(
        topic=topic,
        subtopic="simpel",
        difficulty=difficulty,
        grade_level=4,
        text=text,
        type="calculation",
        correct_answer=answer,
    )
    db.add(p)
    db.commit()
    db.refresh(p)
    return p


def _seed_session_with_assignments(db, count=3, topic="addition"):
    """Create a session with `count` assignments. Returns (session, [assignments])."""
    problems = []
    for i in range(count):
        p = _seed_problem(db, topic=topic, text=f"{10+i} + {20+i}", answer=str(30 + 2 * i))
        problems.append(p)

    session = Session(
        student_id="default",
        mode="practice",
        name=f"Test session",
        topic=topic,
        detected_language="da",
    )
    db.add(session)
    db.flush()

    assignments = []
    for i, problem in enumerate(problems):
        a = Assignment(
            session_id=session.id,
            problem_id=problem.id,
            local_id=str(i + 1),
            text=problem.text,
            type=problem.type,
            topic=problem.topic,
            difficulty_estimate=problem.difficulty,
            correct_answer=problem.correct_answer,
            position=i,
        )
        db.add(a)
        assignments.append(a)

    db.commit()
    for a in assignments:
        db.refresh(a)
    db.refresh(session)
    return session, assignments


# --- Test: status bug fix in session history ---

def test_completed_count_accepts_complete_status(client, test_db):
    """Bug fix: completed_count should count assignments with status='complete'
    (the value set by submissions.submit_work), not just 'completed'."""
    session, assignments = _seed_session_with_assignments(test_db, count=2)

    # Simulate what submissions.py does: set status to "complete"
    assignments[0].status = "complete"
    test_db.commit()

    response = client.get(f"/students/default/sessions")
    assert response.status_code == 200
    data = response.json()
    session_data = next(s for s in data["sessions"] if s["session_id"] == session.id)
    assert session_data["completed_count"] == 1, (
        f"Expected completed_count=1 but got {session_data['completed_count']}. "
        "The counter must accept 'complete' status (set by submissions.py)."
    )
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/test_sessions_ark.py::test_completed_count_accepts_complete_status -v
```

Expected: FAIL — `completed_count` is 0 because the counter only checks `"completed"`.

- [ ] **Step 3: Fix the counter in practice.py**

Open `backend/app/routers/practice.py`. Find line 244:

```python
        completed = sum(1 for a in all_assignments if a.status == "completed")
```

Replace with:

```python
        completed = sum(1 for a in all_assignments if a.status in ("complete", "completed"))
```

- [ ] **Step 4: Run test — expect PASS**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/test_sessions_ark.py::test_completed_count_accepts_complete_status -v
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/app/routers/practice.py backend/tests/test_sessions_ark.py
git commit -m "$(cat <<'EOF'
fix(backend): accept both "complete" and "completed" in session history counter

submissions.py sets status="complete" but the counter only checked "completed",
so completed_count was always 0. Now accepts both variants defensively.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Fix practice session empty `name` bug

**Files:**
- Modify: `backend/app/routers/practice.py`
- Modify: `backend/tests/test_sessions_ark.py`

Practice sessions are created without setting `Session.name`, so the ark header would show a blank title. Weekly sessions already have `name=f"Ugematematik — uge {week_number}"`.

- [ ] **Step 1: Write test**

Append to `backend/tests/test_sessions_ark.py`:

```python


def test_practice_session_has_name(client, test_db):
    """Practice sessions should have a generated name, not empty string."""
    _seed_problem(test_db, topic="addition", difficulty=2)
    response = client.post("/sessions/practice", json={
        "student_id": "default",
        "topic": "addition",
        "difficulty": 2,
        "count": 1,
    })
    assert response.status_code == 200
    data = response.json()

    # Fetch the session to check name in the database
    session_id = data["session_id"]
    get_response = client.get(f"/students/default/sessions")
    session_data = next(
        s for s in get_response.json()["sessions"]
        if s["session_id"] == session_id
    )
    assert session_data["name"], "Practice session name should not be empty"
    assert "addition" in session_data["name"].lower() or "Addition" in session_data["name"]
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/test_sessions_ark.py::test_practice_session_has_name -v
```

Expected: FAIL — name is empty string.

- [ ] **Step 3: Generate name in create_practice_session**

Open `backend/app/routers/practice.py`. Find the block that creates the Session in `create_practice_session` (around line 46):

```python
    session = Session(
        student_id=body.student_id,
        mode="practice",
        topic=body.topic,
        difficulty=body.difficulty,
        detected_language="da",
    )
```

Replace with:

```python
    # Generate a descriptive name for the practice session
    topic_labels = {
        "addition": "Addition",
        "subtraction": "Subtraktion",
        "multiplication": "Multiplikation",
        "division": "Division",
        "geometry": "Geometri",
        "fractions": "Brøker",
    }
    difficulty_labels = {1: "Let", 2: "Medium", 3: "Svær"}
    topic_label = topic_labels.get(body.topic, body.topic.capitalize())
    difficulty_label = difficulty_labels.get(body.difficulty, f"Niveau {body.difficulty}")
    session_name = f"Øvelser — {topic_label} ({difficulty_label})"

    session = Session(
        student_id=body.student_id,
        mode="practice",
        name=session_name,
        topic=body.topic,
        difficulty=body.difficulty,
        detected_language="da",
    )
```

- [ ] **Step 4: Run test — expect PASS**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/test_sessions_ark.py::test_practice_session_has_name -v
```

Expected: PASS

- [ ] **Step 5: Run all existing tests to check for regressions**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/ -v --tb=short 2>&1 | tail -30
```

Expected: All tests pass. No regressions.

- [ ] **Step 6: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/app/routers/practice.py backend/tests/test_sessions_ark.py
git commit -m "$(cat <<'EOF'
fix(backend): generate name for practice sessions

Practice sessions were created with empty name, which would show blank
in the ark header. Now generates "Øvelser — Topic (Difficulty)" label.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Extend GET /sessions/{id} with ark fields — full TDD

**Files:**
- Modify: `backend/app/routers/practice.py`
- Modify: `backend/tests/test_sessions_ark.py`

This is the main backend task. The `GET /sessions/{session_id}` endpoint is extended to return ark-specific fields: `session_name`, `current_assignment_index`, and per-assignment `ark_status`, `latest_scan_id`, `latest_ai_feedback_summary`, `teacher_comment`.

- [ ] **Step 1: Add all 13 tests to test_sessions_ark.py**

Append the following tests to `backend/tests/test_sessions_ark.py`:

```python


# --- Tests for extended GET /sessions/{id} endpoint ---


def test_get_session_returns_session_name_and_current_index(client, test_db):
    """Extended endpoint returns session_name and current_assignment_index."""
    session, assignments = _seed_session_with_assignments(test_db, count=3)

    response = client.get(f"/sessions/{session.id}")
    assert response.status_code == 200
    data = response.json()

    assert data["session_name"] == "Test session"
    assert data["current_assignment_index"] == 0
    assert data["session_id"] == session.id
    assert len(data["assignments"]) == 3


def test_ark_status_not_started_for_fresh_session(client, test_db):
    """All assignments in a fresh session should have ark_status='not_started'."""
    session, assignments = _seed_session_with_assignments(test_db, count=2)

    response = client.get(f"/sessions/{session.id}")
    data = response.json()

    for a in data["assignments"]:
        assert a["ark_status"] == "not_started"
        assert a["latest_scan_id"] is None
        assert a["latest_ai_feedback_summary"] is None
        assert a["teacher_comment"] is None


def test_ark_status_in_progress_when_submission_exists_but_not_complete(client, test_db):
    """Assignment with a submission but status != 'complete' should be 'in_progress'."""
    session, assignments = _seed_session_with_assignments(test_db, count=2)

    # Create a submission for the first assignment (simulates a wrong answer attempt)
    sub = Submission(
        session_id=session.id,
        assignment_id=assignments[0].id,
        work_image_path="/tmp/test.png",
        feedback_text="Prøv igen, tallet er forkert.",
    )
    test_db.add(sub)
    assignments[0].status = "in_progress"
    test_db.commit()

    response = client.get(f"/sessions/{session.id}")
    data = response.json()

    assert data["assignments"][0]["ark_status"] == "in_progress"
    assert data["assignments"][1]["ark_status"] == "not_started"


def test_ark_status_done_accepts_both_complete_and_completed(client, test_db):
    """ark_status should be 'done' for both 'complete' and 'completed' status values."""
    session, assignments = _seed_session_with_assignments(test_db, count=2)

    assignments[0].status = "complete"
    assignments[1].status = "completed"
    test_db.commit()

    response = client.get(f"/sessions/{session.id}")
    data = response.json()

    assert data["assignments"][0]["ark_status"] == "done"
    assert data["assignments"][1]["ark_status"] == "done"


def test_latest_scan_id_from_chat_message(client, test_db):
    """latest_scan_id should come from the newest scanned_image ChatMessage."""
    session, assignments = _seed_session_with_assignments(test_db, count=1)

    # Simulate chat messages with scanned images (as created by ChatViewModel.scanAnswer)
    msg1 = ChatMessage(
        session_id=session.id,
        assignment_id=assignments[0].id,
        sender="student",
        content_type="scanned_image",
        content={"scan_id": "scan_old"},
    )
    msg2 = ChatMessage(
        session_id=session.id,
        assignment_id=assignments[0].id,
        sender="student",
        content_type="scanned_image",
        content={"scan_id": "scan_newest"},
    )
    test_db.add(msg1)
    test_db.flush()
    test_db.add(msg2)
    test_db.commit()

    response = client.get(f"/sessions/{session.id}")
    data = response.json()

    assert data["assignments"][0]["latest_scan_id"] == "scan_newest"


def test_latest_scan_id_null_when_no_scans(client, test_db):
    """latest_scan_id should be null when there are no scanned_image messages."""
    session, assignments = _seed_session_with_assignments(test_db, count=1)

    response = client.get(f"/sessions/{session.id}")
    data = response.json()

    assert data["assignments"][0]["latest_scan_id"] is None


def test_latest_ai_feedback_summary_from_submission_feedback_text(client, test_db):
    """latest_ai_feedback_summary comes from the latest Submission.feedback_text."""
    session, assignments = _seed_session_with_assignments(test_db, count=1)

    sub = Submission(
        session_id=session.id,
        assignment_id=assignments[0].id,
        work_image_path="/tmp/test.png",
        feedback_text="Flot! Du regnede korrekt med mente.",
    )
    test_db.add(sub)
    test_db.commit()

    response = client.get(f"/sessions/{session.id}")
    data = response.json()

    assert data["assignments"][0]["latest_ai_feedback_summary"] == "Flot! Du regnede korrekt med mente."


def test_latest_ai_feedback_summary_truncated_to_140_chars(client, test_db):
    """Feedback summary should be truncated to ~140 chars at sentence boundary."""
    session, assignments = _seed_session_with_assignments(test_db, count=1)

    long_feedback = (
        "Du har løst opgaven korrekt. "
        "Du brugte mente-metoden til at flytte tiere. "
        "Det er en god strategi for store tal. "
        "Husk at skrive mente-tallet tydeligt over kolonnen. "
        "Næste gang kan du prøve at tjekke svaret bagfra."
    )
    assert len(long_feedback) > 140  # Sanity check

    sub = Submission(
        session_id=session.id,
        assignment_id=assignments[0].id,
        work_image_path="/tmp/test.png",
        feedback_text=long_feedback,
    )
    test_db.add(sub)
    test_db.commit()

    response = client.get(f"/sessions/{session.id}")
    data = response.json()

    summary = data["assignments"][0]["latest_ai_feedback_summary"]
    assert summary is not None
    assert len(summary) <= 143  # 140 + "..." (3 chars)
    assert summary.endswith("...")


def test_teacher_comment_always_null(client, test_db):
    """teacher_comment should always be null in Pakke 2a (contract lock)."""
    session, assignments = _seed_session_with_assignments(test_db, count=2)

    # Even with done assignments, teacher_comment should be null
    assignments[0].status = "complete"
    test_db.commit()

    response = client.get(f"/sessions/{session.id}")
    data = response.json()

    for a in data["assignments"]:
        assert a["teacher_comment"] is None


def test_current_assignment_index_skips_done_assignments(client, test_db):
    """current_assignment_index should be the first non-done assignment's position."""
    session, assignments = _seed_session_with_assignments(test_db, count=3)

    assignments[0].status = "complete"
    test_db.commit()

    response = client.get(f"/sessions/{session.id}")
    data = response.json()

    assert data["current_assignment_index"] == 1


def test_current_assignment_index_returns_count_when_all_done(client, test_db):
    """When all assignments are done, current_assignment_index equals len(assignments)."""
    session, assignments = _seed_session_with_assignments(test_db, count=3)

    for a in assignments:
        a.status = "complete"
    test_db.commit()

    response = client.get(f"/sessions/{session.id}")
    data = response.json()

    assert data["current_assignment_index"] == 3


def test_backward_compat_assignment_fields_preserved(client, test_db):
    """All Pakke 1 assignment fields must still be present in the response."""
    session, assignments = _seed_session_with_assignments(test_db, count=1)

    response = client.get(f"/sessions/{session.id}")
    data = response.json()

    a = data["assignments"][0]
    # Pakke 1 fields
    assert "id" in a
    assert "local_id" in a
    assert "text" in a
    assert "type" in a
    assert "topic" in a
    assert "difficulty_estimate" in a
    assert "position" in a
    # Pakke 2a fields
    assert "ark_status" in a
    assert "latest_scan_id" in a
    assert "latest_ai_feedback_summary" in a
    assert "teacher_comment" in a


def test_empty_session_returns_empty_assignments_list(client, test_db):
    """A session with no assignments returns empty list and index 0."""
    session = Session(
        student_id="default",
        mode="practice",
        name="Empty session",
        detected_language="da",
    )
    test_db.add(session)
    test_db.commit()
    test_db.refresh(session)

    response = client.get(f"/sessions/{session.id}")
    data = response.json()

    assert data["assignments"] == []
    assert data["current_assignment_index"] == 0
    assert data["session_name"] == "Empty session"
```

- [ ] **Step 2: Run all new tests — expect FAIL**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/test_sessions_ark.py -v --tb=short 2>&1 | tail -30
```

Expected: The 2 tests from Task 2/3 PASS. The 13 new tests FAIL (endpoint doesn't return the new fields yet).

- [ ] **Step 3: Implement the extended GET /sessions/{id} endpoint**

Open `backend/app/routers/practice.py`. First, update the imports at the top of the file.

Find:

```python
from app.models.db import Assignment, MathProblem, Session
from app.models.schemas import SessionHistoryResponse, SessionSummary, WeeklyRequest
```

Replace with:

```python
from app.models.db import Assignment, ChatMessage, MathProblem, Session, Submission
from app.models.schemas import (
    ArkAssignment,
    SessionDetailResponse,
    SessionHistoryResponse,
    SessionSummary,
    WeeklyRequest,
)
```

Now replace the entire `get_session` function. Find:

```python
@router.get("/sessions/{session_id}")
def get_session(session_id: str, db: DBSession = Depends(get_db)):
    """Return a session and its assignments — used by iOS to re-enter an
    existing session and reload its chat history."""
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    assignments = (
        db.query(Assignment)
        .filter(Assignment.session_id == session_id)
        .order_by(Assignment.position)
        .all()
    )

    return {
        "session_id": session.id,
        "assignments": [
            {
                "id": a.id,
                "problem_id": a.problem_id,
                "local_id": a.local_id,
                "text": a.text,
                "type": a.type,
                "topic": a.topic,
                "difficulty_estimate": a.difficulty_estimate,
                "position": a.position,
            }
            for a in assignments
        ],
    }
```

Replace with:

```python
def _truncate_feedback(text: str | None, max_len: int = 140) -> str | None:
    """Truncate feedback text to ~max_len chars at sentence boundary."""
    if not text:
        return text
    if len(text) <= max_len:
        return text
    # Find last sentence-ending punctuation within max_len
    truncated = text[:max_len]
    for sep in (". ", "! ", "? "):
        last = truncated.rfind(sep)
        if last > 0:
            return text[: last + 1] + "..."
    # No sentence boundary found — truncate at word boundary
    last_space = truncated.rfind(" ")
    if last_space > 0:
        return text[:last_space] + "..."
    return text[:max_len] + "..."


def _compute_ark_status(assignment: Assignment, submissions: list[Submission]) -> str:
    """Compute ark_status from assignment status and submissions."""
    if assignment.status in ("complete", "completed"):
        return "done"
    if submissions:
        return "in_progress"
    return "not_started"


@router.get("/sessions/{session_id}", response_model=SessionDetailResponse)
def get_session(session_id: str, db: DBSession = Depends(get_db)):
    """Return a session and its assignments with ark-overlay fields.

    Used by iOS to enter/re-enter a session. Returns per-assignment status,
    latest scan thumbnail ID, AI feedback summary, and teacher comments.
    """
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    assignments = (
        db.query(Assignment)
        .filter(Assignment.session_id == session_id)
        .order_by(Assignment.position)
        .all()
    )

    # Batch-load all submissions and scan chat messages for this session
    all_submissions = (
        db.query(Submission)
        .filter(Submission.session_id == session_id)
        .order_by(Submission.created_at)
        .all()
    )
    submissions_by_assignment: dict[str, list[Submission]] = defaultdict(list)
    for sub in all_submissions:
        submissions_by_assignment[sub.assignment_id].append(sub)

    # Find latest scanned_image chat messages per assignment
    scan_messages = (
        db.query(ChatMessage)
        .filter(
            ChatMessage.session_id == session_id,
            ChatMessage.content_type == "scanned_image",
        )
        .order_by(ChatMessage.created_at)
        .all()
    )
    latest_scan_by_assignment: dict[str, str | None] = {}
    for msg in scan_messages:
        if msg.assignment_id and isinstance(msg.content, dict):
            scan_id = msg.content.get("scan_id")
            if scan_id:
                latest_scan_by_assignment[msg.assignment_id] = scan_id

    # Compute current_assignment_index (first non-done assignment)
    current_index = len(assignments)  # default: all done
    for i, a in enumerate(assignments):
        if a.status not in ("complete", "completed"):
            current_index = i
            break

    ark_assignments = []
    for a in assignments:
        subs = submissions_by_assignment.get(a.id, [])
        # Latest feedback from the most recent submission
        latest_feedback = None
        if subs:
            latest_sub = subs[-1]
            latest_feedback = _truncate_feedback(latest_sub.feedback_text)

        ark_assignments.append(
            ArkAssignment(
                id=a.id,
                local_id=a.local_id,
                text=a.text,
                type=a.type,
                topic=a.topic,
                difficulty_estimate=a.difficulty_estimate,
                position=a.position,
                ark_status=_compute_ark_status(a, subs),
                latest_scan_id=latest_scan_by_assignment.get(a.id),
                latest_ai_feedback_summary=latest_feedback,
                teacher_comment=None,  # Always null in Pakke 2a
            )
        )

    return SessionDetailResponse(
        session_id=session.id,
        session_name=session.name or "",
        current_assignment_index=current_index,
        assignments=ark_assignments,
    )
```

- [ ] **Step 4: Run all tests — expect PASS**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/test_sessions_ark.py -v
```

Expected: All 15 tests PASS (2 from Task 2/3 + 13 new).

- [ ] **Step 5: Run full test suite for regressions**

```bash
cd /Users/olsen/code/Kvante/backend
python -m pytest tests/ -v --tb=short 2>&1 | tail -40
```

Expected: All tests pass. The `test_get_session_returns_assignments` test in `test_weekly.py` should still pass because the response still contains `session_id` and `assignments` with all original fields. The new fields are additive.

- [ ] **Step 6: Commit**

```bash
cd /Users/olsen/code/Kvante
git add backend/app/routers/practice.py backend/tests/test_sessions_ark.py
git commit -m "$(cat <<'EOF'
feat(backend): extend GET /sessions/{id} with ark-overlay fields

Returns session_name, current_assignment_index, and per-assignment
ark_status, latest_scan_id, latest_ai_feedback_summary, teacher_comment.
Batch-loads submissions and chat messages for efficient queries.
Feedback summary truncated to ~140 chars at sentence boundary.

13 new tests in test_sessions_ark.py cover all computed fields.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Deploy to Mac Mini + smoke test

**Files:**
- None (deployment operation)

- [ ] **Step 1: Deploy via script**

```bash
cd /Users/olsen/code/Kvante
./scripts/deploy.sh
```

Expected: Script pushes to origin, ssh-pulls on Mac Mini, health check passes.

- [ ] **Step 2: Create a test session on Mac Mini**

```bash
curl -s http://192.168.1.60:8000/sessions/practice -X POST \
  -H "Content-Type: application/json" \
  -d '{"student_id":"default","topic":"addition","difficulty":2,"count":2}' | python3 -m json.tool
```

Expected: Response includes `session_id` and 2 assignments.

- [ ] **Step 3: Verify extended endpoint**

Use the session_id from Step 2:

```bash
SESSION_ID=$(curl -s http://192.168.1.60:8000/sessions/practice -X POST \
  -H "Content-Type: application/json" \
  -d '{"student_id":"default","topic":"addition","difficulty":2,"count":2}' | python3 -c "import sys,json; print(json.load(sys.stdin)['session_id'])")

curl -s "http://192.168.1.60:8000/sessions/$SESSION_ID" | python3 -m json.tool
```

Expected: Response includes `session_name` (contains "Addition"), `current_assignment_index` (0), and each assignment has `ark_status` ("not_started"), `latest_scan_id` (null), `latest_ai_feedback_summary` (null), `teacher_comment` (null).

- [ ] **Step 4: No commit needed**

Deploy and smoke test make no code changes.

---

## Phase B — iOS

iOS has no unit test infrastructure for SwiftUI views. Each task ends with `xcodebuild` verification + commit. Final verification is manual QA in Task 16.

### Task 6: Create SessionViewModel.swift

**Files:**
- Create: `ios/Kvante/Kvante/ViewModels/SessionViewModel.swift`

- [ ] **Step 1: Create the file**

Create `ios/Kvante/Kvante/ViewModels/SessionViewModel.swift`:

```swift
import Foundation
import SwiftUI

// MARK: - ArkStatus

enum ArkStatus: String, Equatable {
    case notStarted
    case inProgress
    case done

    init(from apiValue: String) {
        switch apiValue {
        case "done": self = .done
        case "in_progress": self = .inProgress
        default: self = .notStarted
        }
    }
}

// MARK: - SessionViewModel

@Observable
@MainActor
final class SessionViewModel {
    // Identity
    let sessionId: String
    let sessionName: String

    // Frozen after init
    let assignments: [ParsedAssignment]

    // Mutable state
    var currentAssignmentIndex: Int
    var statusByAssignment: [String: ArkStatus]
    var latestScanId: [String: String]
    var feedbackSummary: [String: String]
    var teacherComments: [String: String]  // Always empty in Pakke 2a

    // MARK: - Computed

    var completedCount: Int {
        statusByAssignment.values.filter { $0 == .done }.count
    }

    var currentAssignment: ParsedAssignment {
        guard currentAssignmentIndex < assignments.count else {
            return assignments.last!
        }
        return assignments[currentAssignmentIndex]
    }

    var totalAssignments: Int { assignments.count }

    var isSetComplete: Bool {
        completedCount == assignments.count
    }

    // MARK: - Mutations

    func goToAssignment(_ index: Int) {
        guard index >= 0, index < assignments.count else { return }
        currentAssignmentIndex = index
    }

    func markCompleted(_ assignmentId: String, feedback: String?) {
        statusByAssignment[assignmentId] = .done
        if let feedback {
            feedbackSummary[assignmentId] = feedback
        }
    }

    func recordScan(_ scanId: String, forAssignment assignmentId: String) {
        latestScanId[assignmentId] = scanId
        if statusByAssignment[assignmentId] != .done {
            statusByAssignment[assignmentId] = .inProgress
        }
    }

    // MARK: - Init from API response

    init(from response: SessionDetailResponse) {
        self.sessionId = response.sessionId
        self.sessionName = response.sessionName
        self.assignments = response.assignments.map { ark in
            ParsedAssignment(
                id: ark.id,
                localId: ark.localId,
                text: ark.text,
                type: ark.type,
                topic: ark.topic,
                difficultyEstimate: ark.difficultyEstimate,
                positionOnPage: ""
            )
        }
        self.currentAssignmentIndex = response.currentAssignmentIndex

        var status: [String: ArkStatus] = [:]
        var scans: [String: String] = [:]
        var feedback: [String: String] = [:]
        var comments: [String: String] = [:]

        for ark in response.assignments {
            status[ark.id] = ArkStatus(from: ark.arkStatus)
            if let scanId = ark.latestScanId {
                scans[ark.id] = scanId
            }
            if let summary = ark.latestAiFeedbackSummary {
                feedback[ark.id] = summary
            }
            if let comment = ark.teacherComment {
                comments[ark.id] = comment
            }
        }

        self.statusByAssignment = status
        self.latestScanId = scans
        self.feedbackSummary = feedback
        self.teacherComments = comments
    }
}
```

- [ ] **Step 2: Add file to Xcode project**

The file is in the correct directory (`ViewModels/`) and Xcode should pick it up automatically since the project uses folder references or automatic file discovery. Verify by building.

- [ ] **Step 3: Build verification**

```bash
cd /Users/olsen/code/Kvante/ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | grep -E "BUILD|error:" | tail -10
```

Expected: BUILD SUCCEEDED (will fail because `SessionDetailResponse` doesn't exist in iOS yet — that's OK, Task 7 adds it). If it fails for this reason, proceed to Task 7 and build after both are done.

- [ ] **Step 4: Commit (even if build fails — WIP commit)**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/ViewModels/SessionViewModel.swift
git commit -m "$(cat <<'EOF'
feat(ios): add SessionViewModel for ark-overlay state management

Observable class shared between AssignmentSheetView and ChatView.
Holds assignment status, scan IDs, feedback summaries. Mutations
from Chat are automatically reflected on the sheet via @Observable.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Add iOS response structs + update APIClient

**Files:**
- Modify: `ios/Kvante/Kvante/Models/APIResponses.swift`
- Modify: `ios/Kvante/Kvante/Services/APIClient.swift`

- [ ] **Step 1: Add SessionDetailResponse and ArkAssignmentResponse to APIResponses.swift**

Open `ios/Kvante/Kvante/Models/APIResponses.swift`. Find the comment section:

```swift
// MARK: - Weekly / Session History
```

Immediately BEFORE that line, add:

```swift
// MARK: - Ark Overlay (Pakke 2a)

struct ArkAssignmentResponse: Codable {
    let id: String
    let localId: String
    let text: String
    let type: String
    let topic: String
    let difficultyEstimate: Int
    let position: Int

    let arkStatus: String
    let latestScanId: String?
    let latestAiFeedbackSummary: String?
    let teacherComment: String?

    enum CodingKeys: String, CodingKey {
        case id, text, type, topic, position
        case localId = "local_id"
        case difficultyEstimate = "difficulty_estimate"
        case arkStatus = "ark_status"
        case latestScanId = "latest_scan_id"
        case latestAiFeedbackSummary = "latest_ai_feedback_summary"
        case teacherComment = "teacher_comment"
    }
}

struct SessionDetailResponse: Codable {
    let sessionId: String
    let sessionName: String
    let currentAssignmentIndex: Int
    let assignments: [ArkAssignmentResponse]

    enum CodingKeys: String, CodingKey {
        case assignments
        case sessionId = "session_id"
        case sessionName = "session_name"
        case currentAssignmentIndex = "current_assignment_index"
    }
}

```

- [ ] **Step 2: Update APIClient.getSession return type**

Open `ios/Kvante/Kvante/Services/APIClient.swift`. Find the `getSession` method:

```swift
    /// Fetch an existing session and its assignments — used to re-enter a
    /// session from the history list and reload its persisted chat.
    func getSession(sessionId: String) async throws -> PracticeSessionResponse {
        let url = baseURL.appendingPathComponent("sessions/\(sessionId)")
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(PracticeSessionResponse.self, from: data)
    }
```

Replace with:

```swift
    /// Fetch an existing session and its assignments with ark-overlay fields.
    /// Used to enter/re-enter a session from the history list.
    func getSession(sessionId: String) async throws -> SessionDetailResponse {
        let url = baseURL.appendingPathComponent("sessions/\(sessionId)")
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(SessionDetailResponse.self, from: data)
    }
```

- [ ] **Step 3: Build verification**

```bash
cd /Users/olsen/code/Kvante/ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | grep -E "BUILD|error:" | tail -10
```

Expected: Build will fail because `ContentView.resumeSession` uses the old `PracticeSessionResponse` return type. This is expected — Task 13 fixes ContentView. For now, verify that the new types parse correctly by checking for errors related to the new structs specifically. If the only errors are type mismatches in `ContentView.swift`, that's correct.

- [ ] **Step 4: Commit (WIP — type mismatch in ContentView expected)**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Models/APIResponses.swift ios/Kvante/Kvante/Services/APIClient.swift
git commit -m "$(cat <<'EOF'
feat(ios): add ArkAssignmentResponse + SessionDetailResponse structs

Update APIClient.getSession to return SessionDetailResponse with
ark-overlay fields. ContentView call-site updated in Task 13.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Create ScanImageCache + extend ScannedImageView

**Files:**
- Create: `ios/Kvante/Kvante/Services/ScanImageCache.swift`
- Modify: `ios/Kvante/Kvante/Views/Chat/ScannedImageView.swift`

- [ ] **Step 1: Create ScanImageCache.swift**

Create `ios/Kvante/Kvante/Services/ScanImageCache.swift`:

```swift
import Foundation
import UIKit
import ImageIO

/// Cache for downsampled scan thumbnails. Uses NSCache for OS-managed eviction
/// under memory pressure. Scans are immutable so no invalidation is needed.
@MainActor
final class ScanImageCache {
    static let shared = ScanImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        // Limit to ~30 thumbnails in memory (each ~400px, roughly 200KB)
        cache.countLimit = 30
    }

    /// Load a scan image, downsampled to maxPixelSize, from cache or network.
    func image(for scanId: String, apiClient: APIClient, maxPixelSize: Int = 400) async -> UIImage? {
        let key = "\(scanId)_\(maxPixelSize)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        do {
            let url = apiClient.scanImageURL(scanId: scanId)
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                return nil
            }

            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceShouldCacheImmediately: true,
            ]

            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }

            let image = UIImage(cgImage: cgImage)
            cache.setObject(image, forKey: key)
            return image
        } catch {
            return nil
        }
    }
}
```

- [ ] **Step 2: Extend ScannedImageView with maxPixelSize parameter**

Open `ios/Kvante/Kvante/Views/Chat/ScannedImageView.swift`. Replace the entire file content:

```swift
import SwiftUI

/// Viser et scannet billede enten fra in-memory Data (lige scannet) eller
/// via AsyncImage fra backendens /scans/{id}/image (loadet fra historik).
/// Med maxPixelSize bruger den ScanImageCache for effektiv thumbnail-rendering.
struct ScannedImageView: View {
    let data: Data?
    let scanId: String?
    let apiClient: APIClient
    var maxPixelSize: Int? = nil

    @State private var cachedImage: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let data, let uiImage = UIImage(data: data) {
                imageFrame(uiImage: uiImage)
            } else if let cachedImage {
                imageFrame(uiImage: cachedImage)
            } else if let scanId, maxPixelSize == nil {
                // Full-resolution path (existing behavior)
                AsyncImage(url: apiClient.scanImageURL(scanId: scanId)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 220, height: 180)
                    case .success(let img):
                        imageFrameFromSwiftUIImage(img)
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else if failed {
                placeholder
            } else {
                ProgressView()
                    .frame(width: maxPixelSize != nil ? 160 : 220,
                           height: maxPixelSize != nil ? 100 : 180)
            }
        }
        .task(id: scanId) {
            guard let scanId, let maxPixelSize, data == nil else { return }
            cachedImage = await ScanImageCache.shared.image(
                for: scanId, apiClient: apiClient, maxPixelSize: maxPixelSize
            )
            if cachedImage == nil { failed = true }
        }
    }

    private func imageFrame(uiImage: UIImage) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: maxPixelSize != nil ? 160 : 220,
                       maxHeight: maxPixelSize != nil ? 100 : 180)
                .clipShape(RoundedRectangle(cornerRadius: maxPixelSize != nil ? 8 : 14))
        }
    }

    private func imageFrameFromSwiftUIImage(_ img: Image) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            img
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220, maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var placeholder: some View {
        Text("Billedet kunne ikke hentes")
            .font(.caption)
            .foregroundStyle(KvanteTheme.Colors.textMuted)
            .frame(width: maxPixelSize != nil ? 160 : 220,
                   height: maxPixelSize != nil ? 40 : 60)
    }
}
```

- [ ] **Step 3: Build verification**

```bash
cd /Users/olsen/code/Kvante/ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | grep -E "BUILD|error:" | tail -10
```

Expected: May still fail due to ContentView type mismatch from Task 7, but no new errors from ScanImageCache or ScannedImageView.

- [ ] **Step 4: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Services/ScanImageCache.swift ios/Kvante/Kvante/Views/Chat/ScannedImageView.swift
git commit -m "$(cat <<'EOF'
feat(ios): add ScanImageCache + extend ScannedImageView with maxPixelSize

NSCache-based singleton for downsampled scan thumbnails via ImageIO.
ScannedImageView now accepts optional maxPixelSize parameter for
efficient thumbnail rendering in ark cells.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Create AssignmentSheetView.swift

**Files:**
- Create: `ios/Kvante/Kvante/Views/Ark/AssignmentSheetView.swift`

- [ ] **Step 1: Create the Ark directory**

```bash
mkdir -p /Users/olsen/code/Kvante/ios/Kvante/Kvante/Views/Ark
```

- [ ] **Step 2: Create AssignmentSheetView.swift**

Create `ios/Kvante/Kvante/Views/Ark/AssignmentSheetView.swift`:

```swift
import SwiftUI

// MARK: - ArkFeedbackItem (wrapper for sheet binding)

struct ArkFeedbackItem: Identifiable {
    let id: String
    let assignment: ParsedAssignment
    let index: Int
}

// MARK: - AssignmentSheetView

struct AssignmentSheetView: View {
    let session: SessionViewModel
    let apiClient: APIClient
    let onSelectAssignment: (Int) -> Void

    @State private var presentedFeedback: ArkFeedbackItem?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ZStack {
            paperBackground

            VStack(spacing: 0) {
                arkHeader

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(session.assignments.enumerated()), id: \.element.id) { index, assignment in
                            ArkCell(
                                assignment: assignment,
                                index: index,
                                status: session.statusByAssignment[assignment.id] ?? .notStarted,
                                scanId: session.latestScanId[assignment.id],
                                feedbackSummary: session.feedbackSummary[assignment.id],
                                isCurrent: session.currentAssignmentIndex == index,
                                apiClient: apiClient,
                                onTap: {
                                    onSelectAssignment(index)
                                },
                                onFeedbackTap: {
                                    presentedFeedback = ArkFeedbackItem(
                                        id: assignment.id,
                                        assignment: assignment,
                                        index: index
                                    )
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $presentedFeedback) { item in
            FeedbackPreviewSheet(
                assignment: item.assignment,
                session: session,
                apiClient: apiClient,
                onOpenChat: {
                    presentedFeedback = nil
                    onSelectAssignment(item.index)
                }
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Header

    private var arkHeader: some View {
        VStack(spacing: 8) {
            // Drag handle (decorative, paper metaphor)
            RoundedRectangle(cornerRadius: 2)
                .fill(KvanteTheme.Colors.inkSubtle)
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            Text("Mit ark")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(KvanteTheme.Colors.ink)

            Text("\(session.sessionName) — \(session.completedCount) af \(session.totalAssignments) løst")
                .font(.subheadline)
                .foregroundStyle(KvanteTheme.Colors.textSecondary)

            // Back button
            HStack {
                Button {
                    // Pop back to home — handled by NavigationStack
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Hjem")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(KvanteTheme.Colors.ink)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
        .background(
            Color.white.opacity(0.8)
                .overlay(
                    Rectangle()
                        .fill(KvanteTheme.Colors.inkSubtle)
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }

    // MARK: - Paper Background

    private var paperBackground: some View {
        ZStack {
            KvanteTheme.Colors.cream
            Canvas { context, size in
                // Sparse pixel-noise for paper texture
                var rng = SeededRandomNumberGenerator(seed: 42)
                let dotCount = Int(size.width * size.height / 200)
                for _ in 0..<dotCount {
                    let x = CGFloat.random(in: 0..<size.width, using: &rng)
                    let y = CGFloat.random(in: 0..<size.height, using: &rng)
                    let gray = CGFloat.random(in: 0.3...0.7, using: &rng)
                    context.fill(
                        Path(CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(Color(white: gray))
                    )
                }
            }
            .opacity(0.04)
            .blendMode(.multiply)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Seeded RNG for consistent paper texture

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
```

- [ ] **Step 3: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Views/Ark/AssignmentSheetView.swift
git commit -m "$(cat <<'EOF'
feat(ios): create AssignmentSheetView with paper background and grid

Shows all session assignments in a 2-column LazyVGrid with paper texture.
Header displays session name and completion count. Supports feedback
preview sheet via ArkFeedbackItem wrapper.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: Create ArkCell.swift

**Files:**
- Create: `ios/Kvante/Kvante/Views/Ark/ArkCell.swift`

- [ ] **Step 1: Create ArkCell.swift**

Create `ios/Kvante/Kvante/Views/Ark/ArkCell.swift`:

```swift
import SwiftUI

struct ArkCell: View {
    let assignment: ParsedAssignment
    let index: Int
    let status: ArkStatus
    let scanId: String?
    let feedbackSummary: String?
    let isCurrent: Bool
    let apiClient: APIClient
    let onTap: () -> Void
    let onFeedbackTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Cell head
                cellHead
                    .padding(.horizontal, 10)
                    .padding(.top, 10)

                Divider()
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                // Visual slot
                visualSlot
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 70)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)

                // Cell foot
                cellFoot
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 160)
            .background(cellBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(cellBorder)
            .overlay(currentOverlay)
            .shadow(
                color: isCurrent ? KvanteTheme.Colors.primary.opacity(0.20) : .clear,
                radius: isCurrent ? 6 : 0,
                y: isCurrent ? 2 : 0
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cell Head

    private var cellHead: some View {
        HStack {
            Text("OPG \(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(KvanteTheme.Colors.textMuted)

            Spacer()

            Text(assignment.text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(KvanteTheme.Colors.ink)
                .lineLimit(1)
        }
    }

    // MARK: - Visual Slot

    @ViewBuilder
    private var visualSlot: some View {
        switch status {
        case .done:
            if let scanId {
                ScannedImageView(
                    data: nil,
                    scanId: scanId,
                    apiClient: apiClient,
                    maxPixelSize: 400
                )
            } else {
                statusPlaceholder(icon: "checkmark.circle.fill", text: "Løst", color: KvanteTheme.Colors.success)
            }

        case .inProgress:
            if let scanId {
                ZStack {
                    ScannedImageView(
                        data: nil,
                        scanId: scanId,
                        apiClient: apiClient,
                        maxPixelSize: 400
                    )
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("I gang")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(KvanteTheme.Colors.primary)
                                )
                            Spacer()
                        }
                    }
                }
            } else {
                statusPlaceholder(icon: "pencil.circle", text: "Du arbejder på den...", color: KvanteTheme.Colors.primary)
            }

        case .notStarted:
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundStyle(KvanteTheme.Colors.inkSubtle)
                .overlay(
                    Text("Tryk for at løse")
                        .font(.caption)
                        .foregroundStyle(KvanteTheme.Colors.textMuted)
                )
        }
    }

    private func statusPlaceholder(icon: String, text: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(KvanteTheme.Colors.textMuted)
        }
    }

    // MARK: - Cell Foot

    private var cellFoot: some View {
        HStack(spacing: 6) {
            // Status badge
            switch status {
            case .done:
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                    Text("løst")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(KvanteTheme.Colors.success)

            case .inProgress:
                HStack(spacing: 3) {
                    Image(systemName: "pencil")
                        .font(.caption2.weight(.bold))
                    Text("i gang")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(KvanteTheme.Colors.primary)

            case .notStarted:
                EmptyView()
            }

            // Feedback teaser
            if let feedbackSummary {
                Text(feedbackSummary)
                    .font(.caption2.italic())
                    .foregroundStyle(KvanteTheme.Colors.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            // Info button (feedback preview)
            if feedbackSummary != nil {
                Button(action: onFeedbackTap) {
                    Image(systemName: "info.circle.fill")
                        .font(.body)
                        .foregroundStyle(KvanteTheme.Colors.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Styling

    private var cellBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(backgroundFill)
    }

    private var backgroundFill: Color {
        switch status {
        case .notStarted: return KvanteTheme.Colors.cream
        case .inProgress: return KvanteTheme.Colors.primary.opacity(0.08)
        case .done: return KvanteTheme.Colors.success.opacity(0.08)
        }
    }

    private var cellBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(borderColor, lineWidth: borderWidth)
    }

    private var borderColor: Color {
        switch status {
        case .notStarted: return KvanteTheme.Colors.inkSubtle
        case .inProgress: return KvanteTheme.Colors.primary
        case .done: return KvanteTheme.Colors.success
        }
    }

    private var borderWidth: CGFloat {
        switch status {
        case .notStarted: return 1
        case .inProgress: return 2
        case .done: return 1.5
        }
    }

    @ViewBuilder
    private var currentOverlay: some View {
        if isCurrent {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(KvanteTheme.Colors.primary, lineWidth: 2)
                    .padding(-2)

                // Current indicator dot
                Circle()
                    .fill(KvanteTheme.Colors.primary)
                    .frame(width: 8, height: 8)
                    .offset(x: 6, y: 6)
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Views/Ark/ArkCell.swift
git commit -m "$(cat <<'EOF'
feat(ios): create ArkCell with status coloring and scan thumbnails

Grid cell showing assignment head, visual slot (scan thumb/placeholder),
status badge, feedback teaser, and info button. isCurrent cells get
primary border ring + drop shadow + indicator dot.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Create FeedbackPreviewSheet.swift

**Files:**
- Create: `ios/Kvante/Kvante/Views/Ark/FeedbackPreviewSheet.swift`

- [ ] **Step 1: Create FeedbackPreviewSheet.swift**

Create `ios/Kvante/Kvante/Views/Ark/FeedbackPreviewSheet.swift`:

```swift
import SwiftUI

struct FeedbackPreviewSheet: View {
    let assignment: ParsedAssignment
    let session: SessionViewModel
    let apiClient: APIClient
    let onOpenChat: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var scanId: String? {
        session.latestScanId[assignment.id]
    }

    private var aiFeedback: String? {
        session.feedbackSummary[assignment.id]
    }

    private var teacherComment: String? {
        session.teacherComments[assignment.id]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header: assignment number + text
                    Text("Opgave \(assignment.localId) — \(assignment.text)")
                        .font(.headline)
                        .foregroundStyle(KvanteTheme.Colors.ink)

                    // Large scan thumbnail (full-width)
                    if let scanId {
                        ScannedImageView(
                            data: nil,
                            scanId: scanId,
                            apiClient: apiClient,
                            maxPixelSize: 800
                        )
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Kvante section
                    if let aiFeedback {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Kvante", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(KvanteTheme.Colors.ink)

                            Text(aiFeedback)
                                .font(.body)
                                .foregroundStyle(KvanteTheme.Colors.ink)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(KvanteTheme.Colors.cream)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // Teacher section — hidden when empty (always in Pakke 2a)
                    if let teacherComment, !teacherComment.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Fra laerer", systemImage: "person.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(KvanteTheme.Colors.ink)

                            Text(teacherComment)
                                .font(.body)
                                .foregroundStyle(KvanteTheme.Colors.ink)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(KvanteTheme.Colors.cream)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // Open full chat button
                    Button(action: onOpenChat) {
                        Text("Abn fuld chat")
                            .font(KvanteTheme.Fonts.buttonLabel)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(KvanteTheme.TactileButtonStyle.primary)
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Luk") { dismiss() }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Views/Ark/FeedbackPreviewSheet.swift
git commit -m "$(cat <<'EOF'
feat(ios): create FeedbackPreviewSheet for ark cell feedback preview

Shows assignment header, large scan thumbnail, AI feedback summary,
and teacher comment (always hidden in Pakke 2a). "Open full chat"
button navigates from sheet to chat view.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: Refactor ChatViewModel — remove assignment ownership

**Files:**
- Modify: `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift`

This is the most delicate refactor. ChatViewModel loses its own `allAssignments`, `currentAssignmentIndex`, and `completedAssignmentIds` — these are now owned by `SessionViewModel`. ChatViewModel gets a `let session: SessionViewModel` reference instead.

- [ ] **Step 1: Replace the state section and init**

Open `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift`.

Find the entire MARK: State section and Context section (lines 1-84):

```swift
import Foundation
import SwiftUI

@Observable
class ChatViewModel {
    // MARK: - State

    var messages: [ChatMessage] = []
    var isLoading = false
    var isLoadingHistory = true
    var showScanner = false
    var inputText = ""

    private var syncedMessageIds: Set<UUID> = []
    private var isSyncing = false
    private var pendingSync = false

    // MARK: - Context

    // Multi-assignment state
    private(set) var allAssignments: [ParsedAssignment]
    var currentAssignmentIndex: Int = 0
    var completedAssignmentIds: Set<String> = []
    var attemptCounts: [String: Int] = [:]

    var currentAssignment: ParsedAssignment {
        allAssignments[currentAssignmentIndex]
    }

    var totalAssignments: Int { allAssignments.count }
    var completedCount: Int { completedAssignmentIds.count }
    var isSetComplete: Bool { completedAssignmentIds.count == allAssignments.count }

    let sessionId: String
    let apiClient: APIClient

    // Track submission for follow-ups
    private var currentSubmissionId: String?

    /// Whether current assignment uses stacked arithmetic (numbers > 30)
    private var isStackedArithmetic: Bool {
        let text = currentAssignment.text
        let topic = currentAssignment.topic
        let isAddSub = topic == "addition" || topic == "subtraction"
            || text.contains("+") || text.contains("-")
        let numbers = text.matches(of: /\d+/).compactMap { Int(String($0.output)) }
        return isAddSub && numbers.contains(where: { $0 > 30 })
    }

    /// Whether current assignment is multiplication (×, ·, or *)
    private var isMultiplicationAssignment: Bool {
        let text = currentAssignment.text
        let topic = currentAssignment.topic
        if topic == "multiplication" { return true }
        // Match × (U+00D7) or middle dot. Skip ASCII '*' since it's also used
        // as a bullet/wildcard in non-math text — multiplication tasks always
        // use × in our seed data and parsed pages.
        return text.contains("×") || text.contains("·")
    }

    /// Whether the current assignment's handwritten work needs Vision OCR.
    /// Apple OCR can't read columnar layouts (stacked addition/subtraction
    /// or long multiplication with mente notation).
    private var needsVisionOCR: Bool {
        isStackedArithmetic || isMultiplicationAssignment
    }

    var onSetComplete: (() -> Void)?

    // MARK: - Init

    init(assignments: [ParsedAssignment], sessionId: String, apiClient: APIClient) {
        self.allAssignments = assignments
        self.sessionId = sessionId
        self.apiClient = apiClient

        Task { @MainActor in
            await loadExistingMessages()
            if messages.isEmpty {
                sendWelcome()
            }
            isLoadingHistory = false
        }
    }
```

Replace with:

```swift
import Foundation
import SwiftUI

@Observable
class ChatViewModel {
    // MARK: - State

    var messages: [ChatMessage] = []
    var isLoading = false
    var isLoadingHistory = true
    var showScanner = false
    var inputText = ""

    private var syncedMessageIds: Set<UUID> = []
    private var isSyncing = false
    private var pendingSync = false

    // MARK: - Context

    // Session state — owned by SessionViewModel, shared with AssignmentSheetView
    let session: SessionViewModel
    var attemptCounts: [String: Int] = [:]

    // Convenience accessors that delegate to session
    var allAssignments: [ParsedAssignment] { session.assignments }
    var currentAssignmentIndex: Int { session.currentAssignmentIndex }
    var currentAssignment: ParsedAssignment { session.currentAssignment }
    var totalAssignments: Int { session.totalAssignments }
    var completedCount: Int { session.completedCount }
    var isSetComplete: Bool { session.isSetComplete }

    var sessionId: String { session.sessionId }
    let apiClient: APIClient

    // Track submission for follow-ups
    private var currentSubmissionId: String?

    /// Whether current assignment uses stacked arithmetic (numbers > 30)
    private var isStackedArithmetic: Bool {
        let text = currentAssignment.text
        let topic = currentAssignment.topic
        let isAddSub = topic == "addition" || topic == "subtraction"
            || text.contains("+") || text.contains("-")
        let numbers = text.matches(of: /\d+/).compactMap { Int(String($0.output)) }
        return isAddSub && numbers.contains(where: { $0 > 30 })
    }

    /// Whether current assignment is multiplication (x, ., or *)
    private var isMultiplicationAssignment: Bool {
        let text = currentAssignment.text
        let topic = currentAssignment.topic
        if topic == "multiplication" { return true }
        return text.contains("\u{00D7}") || text.contains("\u{00B7}")
    }

    /// Whether the current assignment's handwritten work needs Vision OCR.
    private var needsVisionOCR: Bool {
        isStackedArithmetic || isMultiplicationAssignment
    }

    var onSetComplete: (() -> Void)?

    // MARK: - Init

    init(session: SessionViewModel, apiClient: APIClient) {
        self.session = session
        self.apiClient = apiClient

        Task { @MainActor in
            await loadExistingMessages()
            if messages.isEmpty {
                sendWelcome()
            }
            isLoadingHistory = false
        }
    }
```

- [ ] **Step 2: Update advanceToNextAssignment to use session**

Find:

```swift
    func advanceToNextAssignment() {
        completedAssignmentIds.insert(currentAssignment.id)

        if isSetComplete {
            let celebration = ChatMessage(
                sender: .kvante,
                content: .celebration(.setComplete)
            )
            appendMessage(celebration)
            onSetComplete?()
            return
        }

        // Move to next unfinished assignment
        if currentAssignmentIndex < allAssignments.count - 1 {
            currentAssignmentIndex += 1
        }

        // Reset submission tracking for new assignment
        currentSubmissionId = nil

        // Introduce next assignment in chat
        let intro = ChatMessage(
            sender: .kvante,
            content: .assignmentIntro(currentAssignment)
        )
        appendMessage(intro)

        let prompt = ChatMessage(
            sender: .kvante,
            content: .text("Her er din næste opgave. Brug + knappen for at scanne dit svar eller bede om hjælp.")
        )
        appendMessage(prompt)
    }
```

Replace with:

```swift
    func advanceToNextAssignment() {
        session.markCompleted(currentAssignment.id, feedback: nil)

        if isSetComplete {
            let celebration = ChatMessage(
                sender: .kvante,
                content: .celebration(.setComplete)
            )
            appendMessage(celebration)
            onSetComplete?()
            return
        }

        // Move to next unfinished assignment
        if currentAssignmentIndex < allAssignments.count - 1 {
            session.goToAssignment(currentAssignmentIndex + 1)
        }

        // Reset submission tracking for new assignment
        currentSubmissionId = nil

        // Introduce next assignment in chat
        let intro = ChatMessage(
            sender: .kvante,
            content: .assignmentIntro(currentAssignment)
        )
        appendMessage(intro)

        let prompt = ChatMessage(
            sender: .kvante,
            content: .text("Her er din næste opgave. Brug + knappen for at scanne dit svar eller bede om hjælp.")
        )
        appendMessage(prompt)
    }
```

- [ ] **Step 3: Update jumpToAssignment to use session**

Find:

```swift
    func jumpToAssignment(_ index: Int) {
        guard index >= 0 && index < allAssignments.count else { return }
        currentAssignmentIndex = index
        currentSubmissionId = nil
```

Replace with:

```swift
    func jumpToAssignment(_ index: Int) {
        guard index >= 0 && index < allAssignments.count else { return }
        session.goToAssignment(index)
        currentSubmissionId = nil
```

- [ ] **Step 4: Update scanAnswer to record scan on session**

In the `scanAnswer` method, find the block that handles successful scan upload (around line 332-346):

```swift
        // Parallel upload til backend så billedet kan genfetches ved reload
        Task { @MainActor in
            do {
                let response = try await self.apiClient.uploadScan(imageData: imageData)
                if let idx = self.messages.firstIndex(where: { $0.id == scanMessageId }) {
                    let old = self.messages[idx]
                    self.messages[idx] = ChatMessage(
                        id: scanMessageId,                              // ← samme UUID
                        sender: old.sender,
                        content: .scannedImage(imageData, scanId: response.scanId),
                        timestamp: old.timestamp,
                        actions: old.actions,
                        assignmentId: old.assignmentId
                    )
                    self.syncUnsavedMessages()
                }
            } catch {
                // Upload fejlede — beskeden beholder scanId: nil og persisteres aldrig
                print("[ChatViewModel] scan upload failed: \(error)")
            }
        }
```

Replace with:

```swift
        // Parallel upload til backend så billedet kan genfetches ved reload
        Task { @MainActor in
            do {
                let response = try await self.apiClient.uploadScan(imageData: imageData)
                if let idx = self.messages.firstIndex(where: { $0.id == scanMessageId }) {
                    let old = self.messages[idx]
                    self.messages[idx] = ChatMessage(
                        id: scanMessageId,                              // ← samme UUID
                        sender: old.sender,
                        content: .scannedImage(imageData, scanId: response.scanId),
                        timestamp: old.timestamp,
                        actions: old.actions,
                        assignmentId: old.assignmentId
                    )
                    self.syncUnsavedMessages()
                }
                // Record scan on session for ark thumbnail
                self.session.recordScan(response.scanId, forAssignment: self.session.currentAssignment.id)
            } catch {
                // Upload fejlede — beskeden beholder scanId: nil og persisteres aldrig
                print("[ChatViewModel] scan upload failed: \(error)")
            }
        }
```

- [ ] **Step 5: Update showAnswerResult to mark completed on session**

In the `showAnswerResult` method, find:

```swift
        // Add celebration for correct answers
        if isCorrect {
            let attempts = attemptCounts[currentAssignment.id, default: 1]
            let tier: CelebrationTier = attempts >= 2 ? .persevered : .routine
            appendMessage(ChatMessage(
                sender: .kvante,
                content: .celebration(tier),
                actions: [ActionChipModel(id: "next_assignment", label: "Næste opgave", icon: "arrow.right.circle.fill", isPrimary: true)]
            ))
        }
```

Replace with:

```swift
        // Add celebration for correct answers
        if isCorrect {
            // Update session state for ark overlay
            session.markCompleted(currentAssignment.id, feedback: studentAnswer)

            let attempts = attemptCounts[currentAssignment.id, default: 1]
            let tier: CelebrationTier = attempts >= 2 ? .persevered : .routine
            appendMessage(ChatMessage(
                sender: .kvante,
                content: .celebration(tier),
                actions: [ActionChipModel(id: "next_assignment", label: "Næste opgave", icon: "arrow.right.circle.fill", isPrimary: true)]
            ))
        }
```

- [ ] **Step 6: Update loadExistingMessages to use session.assignments**

In the `loadExistingMessages` method, find:

```swift
            let byId = Dictionary(uniqueKeysWithValues: allAssignments.map { ($0.id, $0) })
```

This line should still work because `allAssignments` is now a computed property delegating to `session.assignments`. No change needed here.

- [ ] **Step 7: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/ViewModels/ChatViewModel.swift
git commit -m "$(cat <<'EOF'
refactor(ios): thin ChatViewModel — delegate assignment state to SessionViewModel

Remove allAssignments, currentAssignmentIndex, completedAssignmentIds
ownership. ChatViewModel now holds a SessionViewModel reference and
delegates all assignment state. Mutations (markCompleted, recordScan,
goToAssignment) update session state directly, which is automatically
reflected on the ark view via @Observable.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 13: Refactor ContentView — NavigationStack with SessionRoute

**Files:**
- Modify: `ios/Kvante/Kvante/ContentView.swift`

This is the structural refactor that wires everything together. ContentView switches from the current conditional-view approach to a `NavigationStack(path:)` approach with `SessionRoute` enum.

- [ ] **Step 1: Replace the entire ContentView.swift**

Open `ios/Kvante/Kvante/ContentView.swift` and replace the entire file content:

```swift
import SwiftUI
import SwiftData

// MARK: - SessionRoute

enum SessionRoute: Hashable {
    case ark
    case chat
}

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [StudentProfile]
    @State private var serverDiscovery = ServerDiscovery()
    @State private var isLoading = false
    @State private var loadingMessage = ""
    @State private var errorMessage: String?

    // Navigation state — pre-session
    @State private var showPractice = false
    @State private var selectedTopic: TopicInfo?
    @State private var sessionHistory: [SessionSummary] = []

    // Navigation state — session (NavigationStack path)
    @State private var sessionPath: [SessionRoute] = []
    @State private var activeSession: SessionViewModel?
    @State private var activeChatViewModel: ChatViewModel?

    private var profile: StudentProfile? { profiles.first }

    private var apiClient: APIClient? {
        guard let url = serverDiscovery.serverURL else { return nil }
        return APIClient(baseURL: url)
    }

    var body: some View {
        NavigationStack(path: $sessionPath) {
            ZStack {
                KvanteTheme.Colors.background.ignoresSafeArea()

                Group {
                    if isLoading {
                        LoadingView(message: loadingMessage)
                    } else if profile == nil {
                        ChatOnboardingView(apiClient: apiClient) {}
                    } else if let topic = selectedTopic {
                        DifficultyPickerView(topic: topic) { difficulty in
                            startPracticeSession(topic: topic.topic, difficulty: difficulty)
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button { selectedTopic = nil } label: {
                                    Label("Tilbage", systemImage: "chevron.left")
                                }
                            }
                        }
                    } else if showPractice, let client = apiClient {
                        TopicPickerView(apiClient: client) { topic in
                            selectedTopic = topic
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button { showPractice = false } label: {
                                    Label("Hjem", systemImage: "chevron.left")
                                }
                            }
                        }
                    } else if let p = profile {
                        NewHomeView(
                            profile: p,
                            serverDiscovery: serverDiscovery,
                            onPractice: { showPractice = true },
                            onWeekly: { startWeeklySession() },
                            sessionHistory: sessionHistory,
                            onTapSession: { summary in
                                resumeSession(summary)
                            }
                        )
                        .task(id: serverDiscovery.serverURL) { await loadSessionHistory() }
                    }
                }
            }
            .navigationDestination(for: SessionRoute.self) { route in
                switch route {
                case .ark:
                    if let session = activeSession, let client = apiClient {
                        AssignmentSheetView(
                            session: session,
                            apiClient: client,
                            onSelectAssignment: { index in
                                session.goToAssignment(index)
                                sessionPath.append(.chat)
                            }
                        )
                    }
                case .chat:
                    if let vm = activeChatViewModel {
                        ChatView(
                            viewModel: vm,
                            onBack: { sessionPath.removeLast() },
                            onShowArk: { sessionPath.removeLast() }
                        )
                    }
                }
            }
        }
        .onChange(of: sessionPath) { _, newValue in
            if newValue.isEmpty {
                activeSession = nil
                activeChatViewModel = nil
                // Refresh session history when returning to home
                Task { await loadSessionHistory() }
            }
        }
        .alert("Fejl", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            serverDiscovery.startSearching()
        }
        .devCaptureButton(apiClient: apiClient)
    }

    // MARK: - Session Entry Flows

    private func startPracticeSession(topic: String, difficulty: Int) {
        guard let client = apiClient, let p = profile else { return }

        isLoading = true
        loadingMessage = "Kvante finder opgaver..."

        Task {
            do {
                let studentId = p.backendStudentId ?? "default"
                let practiceResponse = try await client.createPracticeSession(
                    studentId: studentId,
                    topic: topic,
                    difficulty: difficulty
                )
                // Fetch the full session detail with ark fields
                let response = try await client.getSession(sessionId: practiceResponse.sessionId)
                let session = SessionViewModel(from: response)
                activeSession = session
                activeChatViewModel = ChatViewModel(session: session, apiClient: client)
                selectedTopic = nil
                showPractice = false
                sessionPath = [.ark]
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func startWeeklySession() {
        guard let client = apiClient, let p = profile else { return }
        isLoading = true
        loadingMessage = "Kvante laver ugematematik..."

        Task {
            do {
                let studentId = p.backendStudentId ?? "default"
                let weekly = try await client.createWeeklySession(
                    studentId: studentId,
                    gradeLevel: p.gradeLevel
                )
                // Fetch the full session detail with ark fields
                let response = try await client.getSession(sessionId: weekly.sessionId)
                let session = SessionViewModel(from: response)
                activeSession = session
                activeChatViewModel = ChatViewModel(session: session, apiClient: client)
                sessionPath = [.ark]
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func resumeSession(_ summary: SessionSummary) {
        guard let client = apiClient else { return }
        isLoading = true
        loadingMessage = "Henter session..."

        Task {
            do {
                let response = try await client.getSession(sessionId: summary.sessionId)
                let session = SessionViewModel(from: response)
                activeSession = session
                activeChatViewModel = ChatViewModel(session: session, apiClient: client)
                sessionPath = [.ark]
            } catch {
                errorMessage = "Kunne ikke abne session: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    private func loadSessionHistory() async {
        guard let client = apiClient, let p = profile else { return }
        let studentId = p.backendStudentId ?? "default"
        if let history = try? await client.getSessionHistory(studentId: studentId) {
            sessionHistory = history.sessions
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [StudentProfile.self], inMemory: true)
}
```

- [ ] **Step 2: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/ContentView.swift
git commit -m "$(cat <<'EOF'
refactor(ios): ContentView uses NavigationStack with SessionRoute path

Replace conditional view switching with NavigationStack(path:).
SessionRoute enum (.ark, .chat) drives navigation. Both SessionViewModel
and ChatViewModel created together in entry flows and survive the full
session lifecycle as @State on ContentView.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 14: Refactor ChatView — remove ProgressPillView, add "Mit ark" button

**Files:**
- Modify: `ios/Kvante/Kvante/Views/Chat/ChatView.swift`

- [ ] **Step 1: Update ChatView struct signature and header**

Open `ios/Kvante/Kvante/Views/Chat/ChatView.swift`. Replace the entire file content:

```swift
import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    var onBack: (() -> Void)?
    var onShowArk: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            chatHeader

            if viewModel.isLoadingHistory {
                Spacer()
                ProgressView()
                    .scaleEffect(1.4)
                Spacer()
            } else {
                chatContent
            }
        }
        .background(KvanteTheme.Colors.cream)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $viewModel.showScanner) {
            DocumentScannerView(
                onScan: { imageData in
                    viewModel.showScanner = false
                    viewModel.scanAnswer(imageData)
                },
                onCancel: {
                    viewModel.showScanner = false
                }
            )
        }
    }

    @ViewBuilder
    private var chatContent: some View {
        // Sticky assignment bar (ProgressPillView removed — replaced by ark)
        HStack(spacing: 8) {
            Text(viewModel.currentAssignment.text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KvanteTheme.Colors.ink)
                .lineLimit(1)
            Spacer()
            Text("Opgave \(viewModel.currentAssignment.localId)")
                .font(.caption.weight(.medium))
                .foregroundStyle(KvanteTheme.Colors.textMuted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(KvanteTheme.Colors.cream)
        .overlay(
            Rectangle()
                .fill(KvanteTheme.Colors.inkSubtle)
                .frame(height: 1),
            alignment: .bottom
        )

        // Messages
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        ChatBubble(
                            message: message,
                            apiClient: viewModel.apiClient,
                            onChip: { chip in
                                viewModel.handleChip(chip)
                            },
                            onConfirmAnswer: { answer in
                                viewModel.confirmAnswer(answer)
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(KvanteTheme.Colors.cream)
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }

        // Input bar
        ChatInputBar(
            text: $viewModel.inputText,
            onSend: { viewModel.sendMessage() },
            onCamera: { viewModel.showScanner = true },
            onHelp: { viewModel.requestHelp() },
            onExplainDifferent: { viewModel.requestExplainDifferent() },
            onSkip: { viewModel.advanceToNextAssignment() }
        )
    }

    // MARK: - Chat Header

    private var chatHeader: some View {
        ZStack {
            // Back button (leading)
            HStack {
                Button {
                    onBack?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Tilbage")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(KvanteTheme.Colors.ink)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16)

            // Centered avatar + name + status
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: KvanteTheme.Shapes.avatarRadius)
                            .fill(KvanteTheme.Colors.kvanteAvatar)
                            .frame(width: 32, height: 32)
                        Text("\u{1F916}")
                            .font(.system(size: 16))
                    }
                    Text("Kvante")
                        .font(.headline)
                        .foregroundStyle(KvanteTheme.Colors.ink)
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(KvanteTheme.Colors.success)
                        .frame(width: 6, height: 6)
                    Text("Online")
                        .font(.caption)
                        .foregroundStyle(KvanteTheme.Colors.success)
                }
            }

            // "Mit ark" button (trailing) — NEW
            HStack {
                Spacer()
                Button {
                    onShowArk?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Mit ark")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(KvanteTheme.Colors.ink)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(
            Color.white
                .overlay(
                    Rectangle()
                        .fill(KvanteTheme.Colors.inkSubtle)
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }
}
```

- [ ] **Step 2: Commit**

```bash
cd /Users/olsen/code/Kvante
git add ios/Kvante/Kvante/Views/Chat/ChatView.swift
git commit -m "$(cat <<'EOF'
refactor(ios): remove ProgressPillView from ChatView, add "Mit ark" button

ChatView header now has "Tilbage" (left), Kvante avatar (center),
and "Mit ark" (right). ProgressPillView is removed — its function
is replaced by the full ark-overlay screen. onShowArk callback pops
back to ark via sessionPath.removeLast().

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 15: Delete ProgressPillView.swift and SessionDashboardView.swift

**Files:**
- Delete: `ios/Kvante/Kvante/Views/Chat/ProgressPillView.swift`
- Delete: `ios/Kvante/Kvante/Views/Dashboard/SessionDashboardView.swift`

- [ ] **Step 1: Delete the files**

```bash
rm /Users/olsen/code/Kvante/ios/Kvante/Kvante/Views/Chat/ProgressPillView.swift
rm /Users/olsen/code/Kvante/ios/Kvante/Kvante/Views/Dashboard/SessionDashboardView.swift
```

- [ ] **Step 2: Check for remaining references**

```bash
cd /Users/olsen/code/Kvante
grep -r "ProgressPillView" ios/ --include="*.swift" || echo "No references to ProgressPillView"
grep -r "SessionDashboardView" ios/ --include="*.swift" || echo "No references to SessionDashboardView"
```

Expected: No references found (ChatView no longer imports ProgressPillView, ContentView no longer uses SessionDashboardView).

- [ ] **Step 3: Check for PracticeSessionView references**

```bash
cd /Users/olsen/code/Kvante
grep -r "PracticeSessionView" ios/ --include="*.swift"
```

If `PracticeSessionView` is referenced anywhere other than its own file, it should also be removed or updated. ContentView no longer uses it (replaced by the NavigationStack approach). If `PracticeSessionView.swift` is only self-contained, leave it for now — it can be cleaned up later.

- [ ] **Step 4: Commit**

```bash
cd /Users/olsen/code/Kvante
git add -u ios/Kvante/Kvante/Views/Chat/ProgressPillView.swift ios/Kvante/Kvante/Views/Dashboard/SessionDashboardView.swift
git commit -m "$(cat <<'EOF'
chore(ios): delete ProgressPillView and SessionDashboardView

ProgressPillView replaced by full ark-overlay screen.
SessionDashboardView replaced by ark-first entry flow with
session metadata in ark header.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 16: Build verification + deploy + manual QA

**Files:**
- None (verification only)

- [ ] **Step 1: Build Debug**

```bash
cd /Users/olsen/code/Kvante/ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | grep -E "BUILD|error:" | tail -20
```

Expected: BUILD SUCCEEDED. If there are compilation errors, fix them before proceeding. Common issues:
- Missing `onShowArk` parameter in call sites to `ChatView` — check all call sites
- `PracticeSessionView` still referencing old `ChatViewModel` init signature — update or remove
- Type mismatches from `PracticeSessionResponse` vs `SessionDetailResponse`

- [ ] **Step 2: Fix any remaining compilation errors**

If `PracticeSessionView.swift` has compile errors because `ChatViewModel` init changed, update it. The file at `ios/Kvante/Kvante/Views/Practice/PracticeSessionView.swift` creates a `ChatViewModel` on line ~70 with the old signature.

Find in PracticeSessionView.swift:

```swift
    private func setupSession() {
        let parsed = assignments.map { ParsedAssignment(from: $0) }
        chatViewModel = ChatViewModel(assignments: parsed, sessionId: sessionId, apiClient: apiClient)
```

This view is no longer used by ContentView (replaced by NavigationStack + SessionRoute flow), but it still needs to compile. Either delete the file or update the init call. Since PracticeSessionView is no longer referenced by ContentView, delete it:

```bash
rm /Users/olsen/code/Kvante/ios/Kvante/Kvante/Views/Practice/PracticeSessionView.swift
```

Then check for references:

```bash
grep -r "PracticeSessionView" ios/ --include="*.swift" || echo "No references"
```

If no references remain, proceed. If other files reference it, update those too.

- [ ] **Step 3: Build Release**

```bash
cd /Users/olsen/code/Kvante/ios/Kvante && xcodebuild -scheme Kvante -configuration Release -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | grep -E "BUILD|error:" | tail -20
```

Expected: BUILD SUCCEEDED. No DEBUG-only dependencies leaked into production.

- [ ] **Step 4: Deploy backend to Mac Mini**

```bash
cd /Users/olsen/code/Kvante
./scripts/deploy.sh
```

Expected: Deploy succeeds, health check passes.

- [ ] **Step 5: Manual QA checklist**

Run through this checklist on the iPad simulator or device:

1. [ ] Start ny weekly session — lander pa arket (ikke Chat)
2. [ ] Grid viser alle ugens opgaver med korrekt status pr. opgave
3. [ ] Tap opgave — abner Chat for den opgave
4. [ ] "Tilbage" i Chat — tilbage til Ark (ikke Home)
5. [ ] "Tilbage" i Ark — Home
6. [ ] "Mit ark"-knap i chat-header — Ark
7. [ ] Los opgave i Chat — Ark viser nu done med feedback-teaser og "i"-ikon
8. [ ] Scan-thumbnail vises pa done-celler efter async load
9. [ ] Tap "i"-ikon — FeedbackPreviewSheet uden at forlade arket
10. [ ] "Abn fuld chat"-knap fra sheet — Chat for den opgave
11. [ ] Fortsæt eksisterende session fra Seneste — Ark med korrekt state
12. [ ] Force-quit midt i session — reopen — Home — tap Seneste — Ark med korrekt state
13. [ ] Release-build kompilerer (ingen utilsigtede DEBUG-afhængigheder)
14. [ ] Ark med 0 loste opgaver renderer (ingen i-ikoner, ingen teasers)
15. [ ] Ark med alle loste opgaver renderer (alle gronne, alle med teaser)
16. [ ] Scan-thumb fejl-fallback: "billede ikke tilgængeligt" uden crash
17. [ ] Practice session har nu et name pa arket (bug fix verified)
18. [ ] `completed_count` pa Seneste-liste matcher faktiske loste opgaver (bug fix verified)

- [ ] **Step 6: Commit any fixes from QA**

```bash
cd /Users/olsen/code/Kvante
git add -A
git status
# Only commit if there are changes
git commit -m "$(cat <<'EOF'
fix(ios): QA fixes for pakke 2a ark-overlay

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 17: Merge branch to main + update TODO.md + memory

**Files:**
- Modify: `TODO.md`
- Modify: `~/.claude/projects/-Users-olsen-code-Kvante/memory/project_next_features.md`

- [ ] **Step 1: Merge to main**

```bash
cd /Users/olsen/code/Kvante
git checkout main
git pull
git merge feature/pakke-2a-ark-overlay
```

Expected: Fast-forward or clean merge. No conflicts expected since this is the only active branch.

- [ ] **Step 2: Update TODO.md**

Move "Pakke 2a — Ark-overlay" from the "Næste" section to "Gennemfort" in `TODO.md`. The exact edit depends on the current TODO.md content — read it first.

```bash
cd /Users/olsen/code/Kvante
cat TODO.md
```

Then make the appropriate edit to move the pakke 2a item.

- [ ] **Step 3: Update memory file**

Read and update `~/.claude/projects/-Users-olsen-code-Kvante/memory/project_next_features.md` to reflect that Pakke 2a is complete. Add observations about what was learned during implementation.

- [ ] **Step 4: Commit updates**

```bash
cd /Users/olsen/code/Kvante
git add TODO.md
git commit -m "$(cat <<'EOF'
docs: mark Pakke 2a ark-overlay as complete in TODO.md

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 5: Push to origin**

```bash
cd /Users/olsen/code/Kvante
git push
```

- [ ] **Step 6: Delete feature branch**

```bash
cd /Users/olsen/code/Kvante
git branch -d feature/pakke-2a-ark-overlay
git push origin --delete feature/pakke-2a-ark-overlay
```

- [ ] **Step 7: Deploy final version to Mac Mini**

```bash
cd /Users/olsen/code/Kvante
./scripts/deploy.sh
```

---

## Self-review checklist

**Spec coverage (design spec section references):**

- [x] Backend `ArkAssignment` Pydantic model with all 4 new fields (section 3) — Task 1
- [x] Backend `SessionDetailResponse` model (section 3) — Task 1
- [x] Backend `teacher_comment` normalized empty to null via field_validator (section 3, review point 6) — Task 1
- [x] Bug fix: "complete" vs "completed" status mismatch (section 9, Bug 1) — Task 2
- [x] Bug fix: Practice sessions get generated name (section 9, Bug 2) — Task 3
- [x] Backend `_compute_ark_status` accepts both "complete" and "completed" (section 3) — Task 4
- [x] Backend `latest_scan_id` from ChatMessage content_type=scanned_image (section 3) — Task 4
- [x] Backend `latest_ai_feedback_summary` from Submission.feedback_text, truncated to ~140 chars (section 3) — Task 4
- [x] Backend `current_assignment_index` = first non-done, or len(assignments) (section 3) — Task 4
- [x] Backend 13 tests in test_sessions_ark.py (section 3, tests list) — Task 4
- [x] Deploy to Mac Mini + smoke test (section 12) — Task 5
- [x] iOS `SessionViewModel` @Observable with all properties from spec (section 4) — Task 6
- [x] iOS `ArkAssignmentResponse` and `SessionDetailResponse` structs (section 3) — Task 7
- [x] iOS `APIClient.getSession` returns `SessionDetailResponse` (section 11) — Task 7
- [x] iOS `ScanImageCache` singleton with NSCache (section 8, review point 3) — Task 8
- [x] iOS `ScannedImageView` extended with `maxPixelSize` parameter (section 8) — Task 8
- [x] iOS `AssignmentSheetView` with paper background, header, LazyVGrid (section 6) — Task 9
- [x] iOS `ArkFeedbackItem` wrapper for sheet binding (section 6, review point 2) — Task 9
- [x] iOS `ArkCell` with status coloring, visual-slot, feedback teaser, "i" button (section 6) — Task 10
- [x] iOS `isCurrent` overlay: primary border ring + drop shadow + indicator dot (section 6, review point 4) — Task 10
- [x] iOS `FeedbackPreviewSheet` with scan thumb, AI feedback, teacher comment, "open chat" (section 6) — Task 11
- [x] iOS ChatViewModel refactored: `let session: SessionViewModel` reference (section 5) — Task 12
- [x] iOS ChatViewModel.confirmAnswer calls `session.markCompleted` (section 5) — Task 12
- [x] iOS ChatViewModel.scanAnswer calls `session.recordScan` (section 5) — Task 12
- [x] iOS ContentView: `SessionRoute` enum, `sessionPath`, `activeSession`, `activeChatViewModel` (section 7) — Task 13
- [x] iOS ChatViewModel + SessionViewModel created together in entry flows, NOT in navigationDestination (section 7, review point 1) — Task 13
- [x] iOS `onChange(of: sessionPath)` cleanup when empty (section 7) — Task 13
- [x] iOS ChatView: ProgressPillView removed, "Mit ark" button in header (section 7) — Task 14
- [x] iOS ProgressPillView.swift deleted (section 7) — Task 15
- [x] iOS SessionDashboardView.swift deleted (section 7) — Task 15
- [x] Build verification Debug + Release (section 12) — Task 16
- [x] Manual QA checklist (section 12, 18 items) — Task 16
- [x] Staggered animation marked as optional polish (section 6, review point 5) — Not implemented, acceptable per spec
- [x] Merge to main + TODO.md + memory update — Task 17

**Architectural invariants:**

- [x] `activeChatViewModel` created at ContentView level, not in navigationDestination closure
- [x] `SessionViewModel` is `@Observable` class, not struct — shared between Ark and Chat
- [x] `assignments` array is immutable after init on SessionViewModel
- [x] All status mutations go through SessionViewModel methods
- [x] Backend endpoint is backwards-compatible (all Pakke 1 fields preserved)
- [x] `teacher_comment` always null in Pakke 2a (contract lock test)

**Files touched:**

- Backend: `schemas.py` (modified), `practice.py` (modified), `test_sessions_ark.py` (created)
- iOS created: `SessionViewModel.swift`, `AssignmentSheetView.swift`, `ArkCell.swift`, `FeedbackPreviewSheet.swift`, `ScanImageCache.swift`
- iOS modified: `ContentView.swift`, `ChatViewModel.swift`, `ChatView.swift`, `ScannedImageView.swift`, `APIResponses.swift`, `APIClient.swift`
- iOS deleted: `ProgressPillView.swift`, `SessionDashboardView.swift`, `PracticeSessionView.swift` (if no other references)
