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
