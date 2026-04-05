import logging
import os

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session as DBSession

from app.config import settings
from app.database import get_db
from app.models.db import Assignment, Session, Submission
from app.models.schemas import ErrorResponse, SubmissionResponse
from app.services.answer_reader import read_student_answer, compare_answer

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/submissions/", response_model=SubmissionResponse, responses={422: {"model": ErrorResponse}})
async def submit_work(
    session_id: str = Form(...),
    assignment_id: str = Form(...),
    image: UploadFile = File(...),
    answer_text: str | None = Form(None),
    full_ocr_text: str | None = Form(None),
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

    # === HYBRID APPROACH ===
    # If device already did OCR, use that. Otherwise fall back to LLM vision.
    if answer_text:
        student_answer = answer_text.strip()
        logger.info("Using device OCR answer: '%s' (full text: '%s')", student_answer, full_ocr_text or "")
    else:
        try:
            result = read_student_answer(contents, assignment.text)
        except Exception as e:
            logger.exception("Failed to read student answer")
            raise HTTPException(
                status_code=422,
                detail={
                    "error": "ocr_failed",
                    "message": str(e),
                    "student_message": "Jeg kan ikke helt læse dit svar — prøv at tage et tydeligere billede.",
                },
            )

        if not result["readable"]:
            raise HTTPException(
                status_code=422,
                detail={
                    "error": "unreadable_photo",
                    "message": "Could not read student answer",
                    "student_message": "Jeg kan ikke læse dit svar — prøv at skrive tydeligere og tag et nyt billede.",
                },
            )
        student_answer = result["answer"]

    # Step 2: Compare against ground truth (Python, not AI)
    is_correct = False
    if assignment.correct_answer:
        is_correct = compare_answer(student_answer, assignment.correct_answer)
        logger.info(
            "Answer comparison: student='%s' vs correct='%s' → %s",
            student_answer, assignment.correct_answer, "CORRECT" if is_correct else "INCORRECT",
        )

    # Build analysis dict (compatible with existing schema)
    analysis = {
        "student_answer": student_answer,
        "correct_answer": assignment.correct_answer or "",
        "full_ocr_text": full_ocr_text or "",
        "methodology_sound": is_correct,
        "steps_identified": [],
        "errors": [] if is_correct else ["Svaret er ikke korrekt"],
        "correct_elements": ["Eleven har besvaret opgaven"] if is_correct else [],
        "methodology_assessment": f"Eleven skrev: {full_ocr_text or student_answer}",
        "handwriting_note": "",
        "confidence": 0.95,
    }

    submission.analysis = analysis
    assignment.status = "complete" if is_correct else "in_progress"
    db.commit()

    return SubmissionResponse(
        submission_id=submission.id,
        assignment_id=assignment_id,
        session_id=session_id,
        **{k: v for k, v in analysis.items() if k in SubmissionResponse.model_fields},
    )
