from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from app.database import get_db
from app.models.db import Assignment, Session
from app.models.schemas import ExampleResponse, FeedbackResponse
from app.services.example_generator import ExampleGeneratorService

router = APIRouter()


@router.post(
    "/sessions/{session_id}/assignments/{assignment_id}/example",
    response_model=ExampleResponse,
)
async def generate_example(
    session_id: str,
    assignment_id: str,
    db: DBSession = Depends(get_db),
):
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    assignment = (
        db.query(Assignment)
        .filter(Assignment.id == assignment_id, Assignment.session_id == session_id)
        .first()
    )
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    generator = ExampleGeneratorService()
    result = generator.generate_example(
        assignment_type=assignment.type,
        assignment_topic=assignment.topic,
        assignment_text=assignment.text,
        language=session.detected_language,
    )
    return ExampleResponse(**result)


@router.post(
    "/sessions/{session_id}/assignments/{assignment_id}/explain",
    response_model=FeedbackResponse,
)
async def explain_task(
    session_id: str,
    assignment_id: str,
    db: DBSession = Depends(get_db),
):
    """Re-explain what an assignment is asking in simpler terms.

    Used when student taps "I don't understand the task" (pre-submission).
    """
    from app.services.feedback_generator import FeedbackGeneratorService

    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    assignment = (
        db.query(Assignment)
        .filter(Assignment.id == assignment_id, Assignment.session_id == session_id)
        .first()
    )
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    generator = FeedbackGeneratorService()
    result = generator.generate_followup(
        assignment_text=assignment.text,
        previous_feedback="",
        action="explain_task",
        language=session.detected_language,
    )
    return FeedbackResponse(**result)
