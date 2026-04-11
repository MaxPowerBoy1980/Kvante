"""Bulk-scan endpoint: submit multiple photos of a student's completed worksheet."""

import logging
import os

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.orm import Session as DBSession

from app.config import settings
from app.database import get_db
from app.models.db import Assignment, Scan, Session, Submission
from app.models.schemas import BulkSubmitResponse, BulkSubmitResult, BulkSubmitSummary
from app.services.ai_client import get_ai_client
from app.services.bulk_scan_service import build_user_message, parse_ai_response, validate_and_build_results
from app.services.streak_service import update_streak

logger = logging.getLogger(__name__)
router = APIRouter()

_scans_dir = os.path.join(settings.upload_dir, "scans")
os.makedirs(_scans_dir, exist_ok=True)


@router.post(
    "/sessions/{session_id}/bulk-submit",
    response_model=BulkSubmitResponse,
)
async def bulk_submit(
    session_id: str,
    images: list[UploadFile] = File(...),
    db: DBSession = Depends(get_db),
):
    """Accept 1+ photos of a student's worksheet, match answers to assignments via AI Vision."""
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    assignments = (
        db.query(Assignment)
        .filter(Assignment.session_id == session_id)
        .order_by(Assignment.position)
        .all()
    )
    if not assignments:
        raise HTTPException(status_code=400, detail="Session has no assignments")

    # Read all images and save as Scan records
    image_bytes_list = []
    scan_ids = []
    for img_file in images:
        contents = await img_file.read()
        if len(contents) > settings.max_upload_size:
            raise HTTPException(status_code=400, detail="Image exceeds maximum upload size (10 MB)")

        scan = Scan(image_path="")
        db.add(scan)
        db.commit()
        db.refresh(scan)

        image_path = os.path.join(_scans_dir, f"scan_{scan.id}.jpg")
        with open(image_path, "wb") as f:
            f.write(contents)
        scan.image_path = image_path
        db.commit()

        image_bytes_list.append(contents)
        scan_ids.append(scan.id)

    # Build assignment list for AI prompt
    assignment_list = [
        {"index": i, "text": a.text, "correct_answer": a.correct_answer or ""}
        for i, a in enumerate(assignments)
    ]

    # Load system prompt
    prompt_path = settings.prompts_dir / "bulk_scan.txt"
    system_prompt = prompt_path.read_text(encoding="utf-8")

    user_message = build_user_message(assignment_list)

    # Call AI Vision
    ai_client = get_ai_client()
    try:
        ai_response = ai_client.send_vision_multi(
            system_prompt=system_prompt,
            images=image_bytes_list,
            user_message=user_message,
        )
    except Exception as e:
        logger.exception("AI bulk-scan call failed")
        raise HTTPException(
            status_code=502,
            detail={"error": "ai_failed", "message": str(e),
                    "student_message": "Kvante kunne ikke læse dit ark — prøv igen."},
        )

    # Parse AI response
    try:
        matches = parse_ai_response(ai_response)
    except ValueError as e:
        logger.error("Failed to parse AI response: %s. Raw: %s", e, ai_response[:500])
        raise HTTPException(
            status_code=502,
            detail={"error": "ai_parse_failed", "message": str(e),
                    "student_message": "Kvante kunne ikke forstå resultaterne — prøv igen."},
        )

    # Validate and build results
    validated = validate_and_build_results(
        matches, assignments, settings.confidence_threshold,
    )

    # Create Submissions and update Assignment status
    results: list[BulkSubmitResult] = []
    correct_count = 0
    incorrect_count = 0
    uncertain_count = 0

    for v in validated:
        assignment = next(a for a in assignments if a.id == v["assignment_id"])

        # Build analysis dict (same shape as single submission)
        analysis = {
            "student_answer": v["student_answer"] or "",
            "correct_answer": assignment.correct_answer or "",
            "full_ocr_text": "",
            "methodology_sound": v["status"] == "correct",
            "steps_identified": [],
            "errors": [v["error_description"]] if v["error_description"] else [],
            "correct_elements": [],
            "methodology_assessment": v["error_description"] or "",
            "handwriting_note": "",
            "confidence": v["confidence"],
            "page_index": v["page_index"],
            "bulk_scan": True,
            "error_type": v["error_type"],
        }

        # Determine attempt number
        attempt_count = (
            db.query(Submission)
            .filter(Submission.assignment_id == assignment.id)
            .count()
        ) + 1

        submission = Submission(
            session_id=session_id,
            assignment_id=assignment.id,
            work_image_path=scan_ids[v["page_index"]] if v["page_index"] < len(scan_ids) else scan_ids[0],
            analysis=analysis,
            attempt_number=attempt_count,
        )
        db.add(submission)
        db.commit()
        db.refresh(submission)

        # Update assignment status
        if v["status"] == "correct":
            assignment.status = "complete"
            correct_count += 1
        elif v["status"] == "incorrect":
            assignment.status = "in_progress"
            assignment.feedback_summary = v["error_description"]
            incorrect_count += 1
        elif v["status"] == "uncertain":
            uncertain_count += 1
        db.commit()

        # Streak update for correct answers
        if v["status"] == "correct":
            update_streak(db, session.student_id)

        results.append(BulkSubmitResult(
            assignment_id=v["assignment_id"],
            assignment_text=v["assignment_text"],
            student_answer=v["student_answer"],
            status=v["status"],
            error_type=v["error_type"],
            error_description=v["error_description"],
            confidence=v["confidence"],
            page_index=v["page_index"],
            submission_id=submission.id,
        ))

    # Add not_found entries for unmatched assignments
    matched_ids = {r.assignment_id for r in results}
    not_found_count = 0
    for a in assignments:
        if a.id not in matched_ids and a.status not in ("complete", "completed"):
            not_found_count += 1
            results.append(BulkSubmitResult(
                assignment_id=a.id,
                assignment_text=a.text,
                student_answer=None,
                status="not_found",
                confidence=0.0,
                submission_id=None,
            ))

    # Calculate total: all non-previously-complete assignments
    previously_complete_not_matched = sum(
        1 for a in assignments
        if a.status in ("complete", "completed") and a.id not in matched_ids
    )
    summary = BulkSubmitSummary(
        total=len(assignments) - previously_complete_not_matched,
        correct=correct_count,
        incorrect=incorrect_count,
        uncertain=uncertain_count,
        not_found=not_found_count,
    )

    return BulkSubmitResponse(
        session_id=session_id,
        results=results,
        summary=summary,
        scan_ids=scan_ids,
    )
