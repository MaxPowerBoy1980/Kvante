"""Practice session endpoint — create a session from the assignment library."""

import random

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session as DBSession

from app.database import get_db
from app.models.db import Assignment, MathProblem, Session

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
    for i, problem in enumerate(selected, 1):
        assignment = Assignment(
            session_id=session.id,
            problem_id=problem.id,
            local_id=str(i),
            text=problem.text,
            type=problem.type,
            topic=problem.topic,
            difficulty_estimate=problem.difficulty,
            correct_answer=problem.correct_answer,
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
            }
            for a in assignments
        ],
    }
