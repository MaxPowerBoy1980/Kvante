import logging
import os

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.orm import Session as DBSession

from app.config import settings
from app.database import get_db
from app.models.db import Assignment, Session
from app.models.schemas import ErrorResponse, PageScanResponse
from app.services.page_parser import PageParserService

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/pages/scan", response_model=PageScanResponse, responses={422: {"model": ErrorResponse}})
async def scan_page(
    image: UploadFile = File(...),
    db: DBSession = Depends(get_db),
):
    contents = await image.read()
    if len(contents) > settings.max_upload_size:
        raise HTTPException(status_code=400, detail="Image exceeds maximum upload size (10 MB)")

    os.makedirs(settings.upload_dir, exist_ok=True)

    parser = PageParserService()
    try:
        parsed = parser.parse_page(contents)
    except Exception as e:
        logger.exception("Failed to parse page")
        raise HTTPException(
            status_code=422,
            detail={
                "error": "parse_failed",
                "message": str(e),
                "student_message": "Jeg kan ikke l\u00e6se siden \u2014 pr\u00f8v at tage et tydeligere billede.",
            },
        )

    session = Session(
        student_id="default",
        page_image_path=f"{settings.upload_dir}/page_{id(contents)}.jpg",
        parsed_assignments=parsed,
        detected_language=parsed.get("detected_language", "da"),
    )
    db.add(session)
    db.commit()
    db.refresh(session)

    image_path = f"{settings.upload_dir}/{session.id}_page.jpg"
    with open(image_path, "wb") as f:
        f.write(contents)
    session.page_image_path = image_path
    db.commit()

    for a in parsed.get("assignments", []):
        assignment = Assignment(
            session_id=session.id,
            local_id=a["id"],
            text=a["text"],
            type=a["type"],
            topic=a["topic"],
            difficulty_estimate=a.get("difficulty_estimate", 1),
        )
        db.add(assignment)
    db.commit()

    db_assignments = db.query(Assignment).filter(Assignment.session_id == session.id).all()
    response_assignments = []
    for db_a in db_assignments:
        parsed_match = next(
            (pa for pa in parsed["assignments"] if pa["id"] == db_a.local_id),
            {},
        )
        response_assignments.append({
            "id": db_a.id,
            "local_id": db_a.local_id,
            "text": db_a.text,
            "type": db_a.type,
            "topic": db_a.topic,
            "difficulty_estimate": db_a.difficulty_estimate,
            "position_on_page": parsed_match.get("position_on_page", ""),
        })

    return PageScanResponse(
        session_id=session.id,
        assignments=response_assignments,
        page_context=parsed.get("page_context", ""),
        suggested_order=parsed.get("suggested_order", []),
        suggested_start=parsed.get("suggested_start", ""),
        reasoning=parsed.get("reasoning", ""),
        detected_language=session.detected_language,
    )
