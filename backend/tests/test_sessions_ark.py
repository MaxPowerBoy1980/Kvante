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
