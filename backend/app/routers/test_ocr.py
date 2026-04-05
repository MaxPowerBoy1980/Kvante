"""Test endpoint for quick OCR debugging — not for production."""

import logging

from fastapi import APIRouter, File, Form, UploadFile

from app.services.answer_reader import read_student_answer, compare_answer

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/test", tags=["test"])


@router.post("/ocr")
async def test_ocr(
    image: UploadFile = File(...),
    assignment_text: str = Form("50 + 30"),
    correct_answer: str = Form("80"),
):
    """Quick test: upload a photo, see what the OCR reads and if it matches."""
    contents = await image.read()
    result = read_student_answer(contents, assignment_text)

    is_correct = False
    if result["readable"]:
        is_correct = compare_answer(result["answer"], correct_answer)

    return {
        "student_answer": result["answer"],
        "readable": result["readable"],
        "correct_answer": correct_answer,
        "is_correct": is_correct,
        "elapsed_seconds": round(result["elapsed"], 1),
    }
