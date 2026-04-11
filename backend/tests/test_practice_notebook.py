"""Tests for notebook-related backend changes (Pakke 5)."""
from app.models.db import Assignment, Session, Submission, Student
import json


def _seed_session_with_submission(db):
    """Create a session with one completed assignment and one submission."""
    student = db.query(Student).filter(Student.id == "default").first()
    session = Session(
        id="notebook-test-session",
        student_id=student.id,
        name="Uge 14 — Blandet",
        mode="weekly",
        topic="mixed",
        status="completed",
    )
    db.add(session)
    db.flush()

    assignment = Assignment(
        id="notebook-test-a1",
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
    db.add(assignment)
    db.flush()

    submission = Submission(
        id="notebook-test-sub1",
        session_id=session.id,
        assignment_id=assignment.id,
        work_image_path="/fake/path.jpg",
        analysis=json.dumps({
            "student_answer": "632",
            "correct_answer": "632",
            "methodology_sound": True,
            "errors": [],
            "correct_elements": [],
        }),
        feedback_text="Flot opsætning — du huskede mente fra ener til tier.",
        attempt_number=1,
    )
    db.add(submission)
    db.commit()
    return session.id


def test_session_detail_includes_answer_fields(client, test_db):
    """ArkAssignment should include correct_answer and student_answer."""
    session_id = _seed_session_with_submission(test_db)
    resp = client.get(f"/sessions/{session_id}")
    assert resp.status_code == 200
    data = resp.json()
    a = data["assignments"][0]
    assert a["correct_answer"] == "632"
    assert a["student_answer"] == "632"


def test_session_detail_answer_fields_null_without_submission(client, test_db):
    """Assignments without submissions should have null answer fields."""
    student = test_db.query(Student).filter(Student.id == "default").first()
    session = Session(
        id="notebook-no-sub",
        student_id=student.id,
        name="Empty",
        mode="weekly",
        status="active",
    )
    test_db.add(session)
    test_db.flush()

    assignment = Assignment(
        id="notebook-no-sub-a1",
        session_id=session.id,
        local_id="1",
        text="50 + 30",
        type="addition",
        topic="addition",
        difficulty_estimate=1,
        position=0,
        status="not_started",
        correct_answer="80",
    )
    test_db.add(assignment)
    test_db.commit()

    resp = client.get(f"/sessions/{session.id}")
    assert resp.status_code == 200
    a = resp.json()["assignments"][0]
    assert a["correct_answer"] == "80"
    assert a["student_answer"] is None


def _seed_many_sessions(db, count=25):
    """Create multiple sessions for limit testing."""
    student = db.query(Student).filter(Student.id == "default").first()
    for i in range(count):
        session = Session(
            id=f"limit-test-{i}",
            student_id=student.id,
            name=f"Session {i}",
            mode="weekly",
            status="completed",
        )
        db.add(session)
    db.commit()


def test_session_history_default_limit_20(client, test_db):
    """Default limit should return at most 20 sessions."""
    _seed_many_sessions(test_db, 25)
    resp = client.get("/students/default/sessions")
    assert resp.status_code == 200
    assert len(resp.json()["sessions"]) == 20


def test_session_history_limit_zero_returns_all(client, test_db):
    """limit=0 should return all sessions."""
    _seed_many_sessions(test_db, 25)
    resp = client.get("/students/default/sessions?limit=0")
    assert resp.status_code == 200
    assert len(resp.json()["sessions"]) == 25


def test_session_history_custom_limit(client, test_db):
    """Custom limit should be respected."""
    _seed_many_sessions(test_db, 25)
    resp = client.get("/students/default/sessions?limit=5")
    assert resp.status_code == 200
    assert len(resp.json()["sessions"]) == 5
