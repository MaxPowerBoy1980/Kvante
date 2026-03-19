import logging
import os

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session as DBSession

from app.config import settings
from app.database import get_db
from app.models.db import Assignment, Session, Submission
from app.models.schemas import ErrorResponse, SubmissionResponse
from app.services.work_analyzer import WorkAnalyzerService

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/submissions/", response_model=SubmissionResponse, responses={422: {"model": ErrorResponse}})
async def submit_work(
    session_id: str = Form(...),
    assignment_id: str = Form(...),
    image: UploadFile = File(...),
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
        raise HTTPException(status_code=404, detail="Assignment not found in this session")

    contents = await image.read()
    if len(contents) > settings.max_upload_size:
        raise HTTPException(status_code=400, detail="Image exceeds maximum upload size (10 MB)")

    os.makedirs(settings.upload_dir, exist_ok=True)

    attempt_count = (
        db.query(Submission)
        .filter(
            Submission.session_id == session_id,
            Submission.assignment_id == assignment_id,
        )
        .count()
    ) + 1

    submission = Submission(
        session_id=session_id,
        assignment_id=assignment_id,
        work_image_path="",
        attempt_number=attempt_count,
    )
    db.add(submission)
    db.commit()
    db.refresh(submission)

    image_path = f"{settings.upload_dir}/{submission.id}_work.jpg"
    with open(image_path, "wb") as f:
        f.write(contents)
    submission.work_image_path = image_path
    db.commit()

    analyzer = WorkAnalyzerService()
    try:
        analysis = analyzer.analyze_work(
            image_bytes=contents,
            assignment_text=assignment.text,
            assignment_type=assignment.type,
            assignment_topic=assignment.topic,
        )
    except Exception as e:
        logger.exception("Failed to analyze work")
        raise HTTPException(
            status_code=422,
            detail={
                "error": "analysis_failed",
                "message": str(e),
                "student_message": "Jeg kan ikke helt l\u00e6se dit svar \u2014 pr\u00f8v at tage et tydeligere billede.",
            },
        )

    if analysis.get("confidence", 0) < settings.confidence_threshold:
        raise HTTPException(
            status_code=422,
            detail={
                "error": "unreadable_photo",
                "message": "Confidence below threshold",
                "student_message": "Jeg kan ikke helt l\u00e6se dit arbejde \u2014 kan du pr\u00f8ve at tage et tydeligere billede? S\u00f8rg for godt lys og hold iPad'en rolig.",
            },
        )

    submission.analysis = analysis
    assignment.status = "in_progress"
    db.commit()

    return SubmissionResponse(
        submission_id=submission.id,
        assignment_id=assignment_id,
        session_id=session_id,
        **{k: v for k, v in analysis.items() if k in SubmissionResponse.model_fields},
    )
