"""Assignment library endpoints — browse topics and problems."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.db import MathProblem
from app.seed_data import TOPIC_META

router = APIRouter(prefix="/library", tags=["library"])


@router.get("/topics")
def list_topics(db: Session = Depends(get_db)):
    """List available topics with problem counts and metadata."""
    rows = (
        db.query(
            MathProblem.topic,
            func.count(MathProblem.id).label("count"),
            func.group_concat(MathProblem.difficulty.distinct()).label("difficulties"),
            func.group_concat(MathProblem.grade_level.distinct()).label("grade_levels"),
        )
        .group_by(MathProblem.topic)
        .all()
    )

    topics = []
    for row in rows:
        meta = TOPIC_META.get(row.topic, {"name": row.topic.capitalize(), "icon": "questionmark.circle"})
        difficulties = sorted(set(int(d) for d in row.difficulties.split(","))) if row.difficulties else []
        grade_levels = sorted(set(int(g) for g in row.grade_levels.split(","))) if row.grade_levels else []
        topics.append({
            "topic": row.topic,
            "name": meta["name"],
            "icon": meta["icon"],
            "problem_count": row.count,
            "difficulties": difficulties,
            "grade_levels": grade_levels,
        })

    return {"topics": sorted(topics, key=lambda t: t["name"])}


@router.get("/problems")
def list_problems(
    topic: str | None = Query(None),
    difficulty: int | None = Query(None),
    grade_level: int | None = Query(None),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    """Browse problems with optional filters. Never returns correct_answer."""
    query = db.query(MathProblem)
    if topic:
        query = query.filter(MathProblem.topic == topic)
    if difficulty:
        query = query.filter(MathProblem.difficulty == difficulty)
    if grade_level:
        query = query.filter(MathProblem.grade_level == grade_level)

    total = query.count()
    problems = query.offset(offset).limit(limit).all()

    return {
        "problems": [
            {
                "id": p.id,
                "text": p.text,
                "topic": p.topic,
                "subtopic": p.subtopic,
                "difficulty": p.difficulty,
                "grade_level": p.grade_level,
                "type": p.type,
            }
            for p in problems
        ],
        "total": total,
    }
