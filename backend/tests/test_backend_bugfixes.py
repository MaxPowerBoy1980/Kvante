"""Tests for backend bug fixes: session auto-completion, weekly dedup, feedback removal."""

import io
from unittest.mock import patch, MagicMock

from PIL import Image

from app.models.db import Assignment, MathProblem, Session, Submission


def _jpeg() -> bytes:
    img = Image.new("RGB", (200, 200), "white")
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def _seed_problems(db, count=10):
    topics = ["addition", "subtraction", "multiplication"]
    for i in range(count):
        p = MathProblem(
            topic=topics[i % len(topics)],
            subtopic="simpel",
            difficulty=1,
            grade_level=4,
            text=f"Regn ud: {10 + i} + {20 + i}",
            type="calculation",
            correct_answer=str(30 + 2 * i),
        )
        db.add(p)
    db.commit()


# --- Fix 1: Session auto-completion ---


def test_session_auto_completes_when_all_assignments_done(client, test_db):
    """Session status becomes 'completed' after the last assignment is marked correct."""
    _seed_problems(test_db)
    create = client.post("/sessions/weekly", json={
        "student_id": "default",
        "grade_level": 4,
        "count": 2,
    })
    data = create.json()
    session_id = data["session_id"]
    assignments = data["assignments"]

    mock_analyzer = MagicMock()
    mock_analyzer.send_vision.return_value = '{"gear_score": {"correct_answer": 2, "visible_method": 2, "notation": 2}, "improvement_tip": "Flot!"}'

    with patch("app.services.work_analyzer.get_ai_client", return_value=mock_analyzer), \
         patch("app.services.work_analyzer.preprocess_handwritten_work", side_effect=lambda b: b):

        # Submit correct answer for assignment 1
        resp = client.post(
            "/submissions/",
            data={
                "session_id": session_id,
                "assignment_id": assignments[0]["id"],
                "answer_text": assignments[0]["text"].split(": ")[1].split(" + ")[0],  # wrong answer
            },
            files={"image": ("work.jpg", _jpeg(), "image/jpeg")},
        )

        # Check session is still active (wrong answer)
        session = test_db.query(Session).filter(Session.id == session_id).first()
        assert session.status == "active"

    # Now mark both assignments as correct directly
    for a_data in assignments:
        assignment = test_db.query(Assignment).filter(Assignment.id == a_data["id"]).first()
        assignment.status = "complete"
    test_db.commit()

    # Use the helper directly
    from app.services.session_completion import check_and_complete_session
    result = check_and_complete_session(test_db, session_id)
    assert result is True

    session = test_db.query(Session).filter(Session.id == session_id).first()
    assert session.status == "completed"
    assert session.completed_at is not None


def test_session_not_completed_when_assignments_remain(test_db):
    """Session stays active when some assignments are not yet done."""
    session = Session(student_id="default", mode="weekly", name="Test")
    test_db.add(session)
    test_db.flush()

    a1 = Assignment(session_id=session.id, local_id="1", text="1+1", type="calc", topic="add", status="complete")
    a2 = Assignment(session_id=session.id, local_id="2", text="2+2", type="calc", topic="add", status="not_started")
    test_db.add_all([a1, a2])
    test_db.commit()

    from app.services.session_completion import check_and_complete_session
    result = check_and_complete_session(test_db, session.id)
    assert result is False
    assert session.status == "active"


def test_session_already_completed_is_noop(test_db):
    """Calling check_and_complete on an already completed session returns False."""
    session = Session(student_id="default", mode="weekly", name="Test", status="completed")
    test_db.add(session)
    test_db.flush()

    a1 = Assignment(session_id=session.id, local_id="1", text="1+1", type="calc", topic="add", status="complete")
    test_db.add(a1)
    test_db.commit()

    from app.services.session_completion import check_and_complete_session
    result = check_and_complete_session(test_db, session.id)
    assert result is False


# --- Fix 2: Weekly session deduplication ---


def test_weekly_dedup_returns_existing_session(client, test_db):
    """Second call to /sessions/weekly in the same week returns the same session."""
    _seed_problems(test_db)

    r1 = client.post("/sessions/weekly", json={"student_id": "default", "grade_level": 4, "count": 3})
    r2 = client.post("/sessions/weekly", json={"student_id": "default", "grade_level": 4, "count": 3})

    assert r1.json()["session_id"] == r2.json()["session_id"]
    assert r1.json()["name"] == r2.json()["name"]


def test_weekly_dedup_cleans_empty_sessions(client, test_db):
    """Empty weekly sessions are cleaned up when a new one is created."""
    _seed_problems(test_db)

    # Create an empty session manually (simulating a failed prior call)
    from datetime import datetime, timezone
    week_number = datetime.now(timezone.utc).isocalendar()[1]
    empty = Session(
        student_id="default",
        mode="weekly",
        name=f"Ugematematik — uge {week_number}",
    )
    test_db.add(empty)
    test_db.commit()
    empty_id = empty.id

    # Now call the endpoint — should clean up the empty one and create new
    resp = client.post("/sessions/weekly", json={"student_id": "default", "grade_level": 4, "count": 3})
    assert resp.status_code == 200
    assert resp.json()["session_id"] != empty_id

    # Verify the empty session was deleted
    assert test_db.query(Session).filter(Session.id == empty_id).first() is None


def test_weekly_dedup_different_students_get_own_sessions(client, test_db):
    """Different students each get their own weekly session."""
    _seed_problems(test_db)

    from app.models.db import Student
    test_db.add(Student(id="student2", name="Student 2", language="da"))
    test_db.commit()

    r1 = client.post("/sessions/weekly", json={"student_id": "default", "grade_level": 4, "count": 3})
    r2 = client.post("/sessions/weekly", json={"student_id": "student2", "grade_level": 4, "count": 3})

    assert r1.json()["session_id"] != r2.json()["session_id"]


# --- Fix 3: Feedback endpoint removed ---


def test_feedback_endpoint_removed(client):
    """POST /feedback/ should return 404/405 (endpoint no longer exists)."""
    resp = client.post("/feedback/", json={"submission_id": "fake", "language": "da"})
    assert resp.status_code in (404, 405)


def test_feedback_followup_endpoint_removed(client):
    """POST /feedback/{id}/followup should return 404/405."""
    resp = client.post("/feedback/fake-id/followup", json={"action": "explain_different"})
    assert resp.status_code in (404, 405)
