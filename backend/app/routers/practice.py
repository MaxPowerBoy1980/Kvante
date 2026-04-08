"""Practice session endpoint — create a session from the assignment library."""

import random
from collections import defaultdict
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session as DBSession

from app.database import get_db
from app.models.db import Assignment, MathProblem, Session
from app.models.schemas import SessionHistoryResponse, SessionSummary, WeeklyRequest

router = APIRouter(tags=["practice"])


class PracticeRequest(BaseModel):
    student_id: str
    topic: str
    difficulty: int = 2
    count: int = 5


@router.post("/sessions/practice")
def create_practice_session(body: PracticeRequest, db: DBSession = Depends(get_db)):
    """Create a practice session with random problems from the library."""
    problems = (
        db.query(MathProblem)
        .filter(MathProblem.topic == body.topic, MathProblem.difficulty == body.difficulty)
        .all()
    )

    if not problems:
        raise HTTPException(
            status_code=404,
            detail={
                "error": "no_problems",
                "message": f"No problems found for topic={body.topic}, difficulty={body.difficulty}",
                "student_message": "Der er ingen opgaver med de valgte indstillinger. Prøv et andet emne.",
            },
        )

    selected = random.sample(problems, min(body.count, len(problems)))

    session = Session(
        student_id=body.student_id,
        mode="practice",
        topic=body.topic,
        difficulty=body.difficulty,
        detected_language="da",
    )
    db.add(session)
    db.flush()

    assignments = []
    for i, problem in enumerate(selected):
        assignment = Assignment(
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
        db.add(assignment)
        assignments.append(assignment)

    db.commit()

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


@router.post("/sessions/weekly")
def create_weekly_session(body: WeeklyRequest, db: DBSession = Depends(get_db)):
    """Create a mixed-topic weekly session from the assignment library."""
    problems = (
        db.query(MathProblem)
        .filter(MathProblem.grade_level <= body.grade_level)
        .all()
    )

    if not problems:
        raise HTTPException(
            status_code=404,
            detail={
                "error": "no_problems",
                "message": f"No problems found for grade_level<={body.grade_level}",
                "student_message": "Der er ingen opgaver klar til ugematematik. Prøv igen senere.",
            },
        )

    # Group by topic, then round-robin pick to get a good mix
    by_topic: dict[str, list] = defaultdict(list)
    for p in problems:
        by_topic[p.topic].append(p)

    # Shuffle within each topic for variety
    for topic_list in by_topic.values():
        random.shuffle(topic_list)

    # Round-robin across topics until we have enough
    selected = []
    topic_iters = {topic: iter(lst) for topic, lst in by_topic.items()}
    topic_keys = list(topic_iters.keys())
    idx = 0
    while len(selected) < body.count:
        key = topic_keys[idx % len(topic_keys)]
        try:
            selected.append(next(topic_iters[key]))
        except StopIteration:
            # This topic is exhausted; remove it
            topic_keys.pop(idx % len(topic_keys))
            if not topic_keys:
                break
            continue
        idx += 1

    if not selected:
        raise HTTPException(
            status_code=404,
            detail={
                "error": "no_problems",
                "message": "Could not select any problems",
                "student_message": "Der er ingen opgaver klar til ugematematik. Prøv igen senere.",
            },
        )

    # Determine ISO week number for the session name
    week_number = datetime.now(timezone.utc).isocalendar()[1]

    session = Session(
        student_id=body.student_id,
        mode="weekly",
        name=f"Ugematematik — uge {week_number}",
        detected_language="da",
    )
    db.add(session)
    db.flush()

    assignments = []
    for i, problem in enumerate(selected):
        assignment = Assignment(
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
        db.add(assignment)
        assignments.append(assignment)

    db.commit()

    return {
        "session_id": session.id,
        "name": session.name,
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


@router.get("/students/{student_id}/sessions", response_model=SessionHistoryResponse)
def get_session_history(student_id: str, db: DBSession = Depends(get_db)):
    """Return session history for a student, most recent first."""
    sessions = (
        db.query(Session)
        .filter(Session.student_id == student_id)
        .order_by(Session.created_at.desc())
        .limit(20)
        .all()
    )

    summaries = []
    for s in sessions:
        all_assignments = db.query(Assignment).filter(Assignment.session_id == s.id).all()
        total = len(all_assignments)
        completed = sum(1 for a in all_assignments if a.status == "completed")
        summaries.append(
            SessionSummary(
                session_id=s.id,
                name=s.name,
                mode=s.mode,
                topic=s.topic,
                status=s.status,
                assignment_count=total,
                completed_count=completed,
                created_at=s.created_at.isoformat(),
                completed_at=s.completed_at.isoformat() if s.completed_at else None,
            )
        )

    return SessionHistoryResponse(sessions=summaries)


@router.post("/sessions/{session_id}/complete")
def complete_session(session_id: str, db: DBSession = Depends(get_db)):
    """Mark a session as completed."""
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        raise HTTPException(
            status_code=404,
            detail={
                "error": "session_not_found",
                "message": f"Session {session_id} not found",
                "student_message": "Sessionen blev ikke fundet.",
            },
        )

    session.status = "completed"
    session.completed_at = datetime.now(timezone.utc)
    db.commit()

    return {"session_id": session.id, "status": session.status}
