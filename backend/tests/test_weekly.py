from app.models.db import MathProblem


def _seed_problems(db, count=10):
    topics = ["addition", "subtraktion", "multiplikation"]
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


def test_create_weekly_session(client, test_db):
    _seed_problems(test_db)
    response = client.post("/sessions/weekly", json={
        "student_id": "default",
        "grade_level": 4,
        "count": 5,
    })
    assert response.status_code == 200
    data = response.json()
    assert "session_id" in data
    assert "Ugematematik" in data["name"]
    assert len(data["assignments"]) == 5
    topics = {a["topic"] for a in data["assignments"]}
    assert len(topics) > 1


def test_create_weekly_no_problems(client, test_db):
    response = client.post("/sessions/weekly", json={
        "student_id": "default",
        "grade_level": 4,
    })
    assert response.status_code == 404


def test_session_history(client, test_db):
    _seed_problems(test_db)
    client.post("/sessions/weekly", json={
        "student_id": "default",
        "grade_level": 4,
        "count": 3,
    })
    response = client.get("/students/default/sessions")
    assert response.status_code == 200
    data = response.json()
    assert len(data["sessions"]) >= 1
    assert data["sessions"][0]["assignment_count"] == 3


def test_complete_session(client, test_db):
    _seed_problems(test_db)
    create = client.post("/sessions/weekly", json={
        "student_id": "default",
        "grade_level": 4,
        "count": 3,
    })
    session_id = create.json()["session_id"]
    response = client.post(f"/sessions/{session_id}/complete")
    assert response.status_code == 200
    assert response.json()["status"] == "completed"


def test_complete_session_not_found(client, test_db):
    response = client.post("/sessions/nonexistent/complete")
    assert response.status_code == 404
