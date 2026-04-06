from app.models.db import Assignment, Session


def _create_session_with_assignments(db, count=3):
    session = Session(student_id="default", mode="practice", topic="addition")
    db.add(session)
    db.flush()

    assignments = []
    for i in range(count):
        a = Assignment(
            session_id=session.id,
            local_id=str(i + 1),
            text=f"Regn ud: {10 + i} + {20 + i}",
            type="calculation",
            topic="addition",
            position=i,
        )
        db.add(a)
        assignments.append(a)
    db.commit()
    return session, assignments


def test_save_messages(client, test_db):
    session, assignments = _create_session_with_assignments(test_db)
    response = client.post("/chat/messages/save", json={
        "session_id": session.id,
        "messages": [
            {"sender": "kvante", "content_type": "assignment_intro", "content": {"text": "Regn ud: 10 + 20"}, "assignment_id": assignments[0].id},
            {"sender": "student", "content_type": "text", "content": {"text": "30"}, "assignment_id": assignments[0].id},
        ],
    })
    assert response.status_code == 200
    assert response.json()["saved_count"] == 2


def test_load_messages(client, test_db):
    session, _ = _create_session_with_assignments(test_db)
    client.post("/chat/messages/save", json={
        "session_id": session.id,
        "messages": [
            {"sender": "kvante", "content_type": "text", "content": {"text": "Hej!"}},
            {"sender": "student", "content_type": "text", "content": {"text": "Hej Kvante!"}},
        ],
    })
    response = client.get(f"/chat/messages/{session.id}")
    assert response.status_code == 200
    data = response.json()
    assert len(data["messages"]) == 2
    assert data["messages"][0]["content"]["text"] == "Hej!"


def test_load_messages_empty(client, test_db):
    session, _ = _create_session_with_assignments(test_db)
    response = client.get(f"/chat/messages/{session.id}")
    assert response.status_code == 200
    assert len(response.json()["messages"]) == 0


def test_load_messages_not_found(client, test_db):
    response = client.get("/chat/messages/nonexistent")
    assert response.status_code == 404


def test_save_messages_not_found(client, test_db):
    response = client.post("/chat/messages/save", json={
        "session_id": "nonexistent",
        "messages": [{"sender": "kvante", "content_type": "text", "content": {"text": "hi"}}],
    })
    assert response.status_code == 404
