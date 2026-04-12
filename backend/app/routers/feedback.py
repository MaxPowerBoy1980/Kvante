from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from app.database import get_db
from app.models.db import Assignment, Submission
from app.models.schemas import FeedbackRequest, FeedbackResponse, FollowupRequest
from app.services.feedback_generator import FeedbackGeneratorService

import logging

# DEPRECATED 2026-04-12: This endpoint is no longer called by iOS.
# gear_score + improvement_tip are now computed at submission time and returned
# inline in SubmissionResponse. The known timeout bug is not being fixed.
# This endpoint will be removed in a future cleanup sprint.

logger = logging.getLogger(__name__)

router = APIRouter()

VALID_ACTIONS = {"explain_different", "another_example", "show_first_step", "what_did_well", "try_again", "explain_task"}


@router.post("/feedback/", response_model=FeedbackResponse)
async def generate_feedback(
    request: FeedbackRequest,
    db: DBSession = Depends(get_db),
):
    submission = db.query(Submission).filter(Submission.id == request.submission_id).first()
    if not submission:
        raise HTTPException(status_code=404, detail="Submission not found")

    assignment = db.query(Assignment).filter(Assignment.id == submission.assignment_id).first()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    if not submission.analysis:
        raise HTTPException(status_code=400, detail="Submission has not been analyzed yet")

    logger.info("Generating feedback for submission %s", request.submission_id)

    generator = FeedbackGeneratorService()
    result = generator.generate_feedback(
        assignment_text=assignment.text,
        analysis=submission.analysis,
        language=request.language,
    )

    submission.feedback_text = result["feedback_text"]
    db.commit()

    return FeedbackResponse(**result)


@router.post("/feedback/{submission_id}/followup", response_model=FeedbackResponse)
async def followup(
    submission_id: str,
    request: FollowupRequest,
    db: DBSession = Depends(get_db),
):
    if request.action not in VALID_ACTIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid action '{request.action}'. Valid: {', '.join(sorted(VALID_ACTIONS))}",
        )

    logger.info("Followup action='%s' for submission %s", request.action, submission_id)

    submission = db.query(Submission).filter(Submission.id == submission_id).first()
    if not submission:
        raise HTTPException(status_code=404, detail="Submission not found")

    assignment = db.query(Assignment).filter(Assignment.id == submission.assignment_id).first()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    from app.models.db import Session
    session = db.query(Session).filter(Session.id == submission.session_id).first()
    language = session.detected_language if session else "da"

    # Route "another_example" to ExampleGeneratorService
    if request.action == "another_example":
        from app.services.example_generator import ExampleGeneratorService
        gen = ExampleGeneratorService()
        example = gen.generate_example(
            assignment_type=assignment.type,
            assignment_topic=assignment.topic,
            assignment_text=assignment.text,
            language=language,
        )
        return FeedbackResponse(
            feedback_text=example.get("note", ""),
            tone="encouraging",
            structured_prompts=FeedbackGeneratorService()._get_prompts(language),
        )

    generator = FeedbackGeneratorService()
    result = generator.generate_followup(
        assignment_text=assignment.text,
        previous_feedback=submission.feedback_text or "",
        action=request.action,
        language=language,
    )

    return FeedbackResponse(**result)
