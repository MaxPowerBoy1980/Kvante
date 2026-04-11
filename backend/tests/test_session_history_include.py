"""Tests for GET /students/{id}/sessions?include=assignments."""
import json

from app.models.db import Assignment, Session, Submission, Student


def _seed_session_with_assignments(db):
    """Create a session with 2 assignments, one with a submission."""
    student = db.query(Student).filter(Student.id == "default").first()
    session = Session(
        id="include-test-session",
        student_id=student.id,
        name="Ugematematik — uge 15",
        mode="weekly",
        topic="mixed",
        status="active",
    )
    db.add(session)
    db.flush()

    a1 = Assignment(
        id="include-a1",
        session_id=session.id,
        local_id="1",
        text="347 + 285",
        type="addition",
        topic="addition",
        difficulty_estimate=2,
        position=0,
        status="completed",
        correct_answer="632",
    )
    a2 = Assignment(
        id="include-a2",
        session_id=session.id,
        local_id="2",
        text="500 - 123",
        type="subtraction",
        topic="subtraction",
        difficulty_estimate=2,
        position=1,
        status="not_started",
        correct_answer="377",
    )
    db.add_all([a1, a2])
    db.flush()

    sub = Submission(
        id="include-sub1",
        session_id=session.id,
        assignment_id=a1.id,
        work_image_path="/fake/path.jpg",
        analysis=json.dumps({"student_answer": "632"}),
        feedback_text="Flot! Du huskede mente fra ener til tier.",
        attempt_number=1,
    )
    db.add(sub)
    db.commit()
    return session.id


def test_include_assignments_returns_ark_assignments(client, test_db):
    """include=assignments should return ArkAssignment objects inline."""
    _seed_session_with_assignments(test_db)
    resp = client.get("/students/default/sessions?limit=0&include=assignments")
    assert resp.status_code == 200
    data = resp.json()
    sessions = data["sessions"]
    assert len(sessions) >= 1

    s = next(s for s in sessions if s["session_id"] == "include-test-session")
    assert "assignments" in s
    assert "current_assignment_index" in s
    assert len(s["assignments"]) == 2

    a1 = next(a for a in s["assignments"] if a["id"] == "include-a1")
    assert a1["ark_status"] == "done"
    assert a1["correct_answer"] == "632"
    assert a1["student_answer"] == "632"
    assert a1["latest_ai_feedback_summary"] is not None

    a2 = next(a for a in s["assignments"] if a["id"] == "include-a2")
    assert a2["ark_status"] == "not_started"
    assert a2["student_answer"] is None


def test_without_include_has_no_assignments(client, test_db):
    """Without include param, response should NOT have assignments field."""
    _seed_session_with_assignments(test_db)
    resp = client.get("/students/default/sessions?limit=0")
    assert resp.status_code == 200
    sessions = resp.json()["sessions"]
    s = next(s for s in sessions if s["session_id"] == "include-test-session")
    assert "assignments" not in s


def test_include_assignments_counts_are_correct(client, test_db):
    """assignment_count and completed_count should match inline assignments."""
    _seed_session_with_assignments(test_db)
    resp = client.get("/students/default/sessions?limit=0&include=assignments")
    assert resp.status_code == 200
    s = next(
        s for s in resp.json()["sessions"]
        if s["session_id"] == "include-test-session"
    )
    assert s["assignment_count"] == 2
    assert s["completed_count"] == 1


def test_include_current_assignment_index(client, test_db):
    """current_assignment_index should be the first non-done assignment."""
    _seed_session_with_assignments(test_db)
    resp = client.get("/students/default/sessions?limit=0&include=assignments")
    assert resp.status_code == 200
    s = next(
        s for s in resp.json()["sessions"]
        if s["session_id"] == "include-test-session"
    )
    assert s["current_assignment_index"] == 1
