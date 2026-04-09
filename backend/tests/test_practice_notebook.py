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
