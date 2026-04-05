"""Simple OCR: read the student's handwritten answer using vision model.

No math reasoning, no methodology analysis — just read what they wrote.
"""

import logging
import re
import time

from app.config import settings
from app.services.ai_client import get_ai_client
from app.services.image_preprocessor import preprocess_handwritten_work  # noqa: F401

logger = logging.getLogger(__name__)

READER_PROMPT = """You are an OCR system. Read the student's handwritten FINAL ANSWER from the photo.

Rules:
- Look for the number or value written AFTER the equals sign (=)
- Return ONLY that final answer — just the number
- Do NOT include the calculation, only the result
- Do NOT explain or comment
- Do NOT solve the problem yourself
- If you cannot read it, reply with: UNREADABLE

Examples:
- Photo shows "50 + 30 = 80" → respond: 80
- Photo shows "3/4 + 1/4 = 1" → respond: 1
- Photo shows "347 + 286 = 633" → respond: 633
- Photo shows messy scribble → respond: UNREADABLE"""


def read_student_answer(image_bytes: bytes, assignment_text: str) -> dict:
    """Read the student's handwritten answer. Returns {answer, readable}."""
    logger.info("Reading answer for '%s' (%d bytes)", assignment_text, len(image_bytes))
    start = time.time()

    client = get_ai_client()

    # Send original image — no preprocessing. The CLAHE/grayscale pipeline
    # was designed for heavy analysis, but for simple OCR the raw image works better.
    # IMPORTANT: Do NOT include the assignment text — the model will
    # calculate the answer instead of reading the handwriting.
    raw = client.send_vision(
        READER_PROMPT,
        image_bytes,
        "Read the handwritten answer from the photo. What number is written after the equals sign?",
    )

    elapsed = time.time() - start
    answer = raw.strip().strip('"').strip("'").strip()

    # Clean up common OCR artifacts
    answer = re.sub(r"\s+", " ", answer)

    readable = answer.upper() != "UNREADABLE" and len(answer) > 0
    logger.info("Read answer in %.1fs: '%s' (readable=%s)", elapsed, answer, readable)

    return {"answer": answer, "readable": readable, "elapsed": elapsed}


def compare_answer(student_answer: str, correct_answer: str) -> bool:
    """Compare student answer against ground truth, with normalization."""
    def normalize(s: str) -> str:
        s = s.strip().lower()
        s = s.replace(",", ".")     # Danish decimal comma → dot
        s = s.replace(" ", "")      # Remove spaces
        s = re.sub(r"\.0+$", "", s) # Remove trailing .0
        s = s.rstrip(".")           # Remove trailing dot
        # Remove units for comparison (cm, cm², m, etc.)
        s = re.sub(r"\s*(cm[²³]?|m[²³]?|kr\.?|%)\s*$", "", s)
        return s

    return normalize(student_answer) == normalize(correct_answer)
