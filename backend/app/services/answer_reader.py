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

READER_PROMPT = """You are an OCR system. Read the student's handwritten answer from the photo.

Rules:
- Return ONLY the final answer the student wrote (the number, fraction, or text)
- Do NOT explain, analyze, or comment
- Do NOT solve the problem yourself
- If you can read the answer clearly, reply with just the answer
- If you cannot read it, reply with: UNREADABLE

Examples of good responses:
- 79
- 3/4
- 26 cm
- 14 rest 2
- UNREADABLE"""


def read_student_answer(image_bytes: bytes, assignment_text: str) -> dict:
    """Read the student's handwritten answer. Returns {answer, readable}."""
    logger.info("Reading answer for '%s' (%d bytes)", assignment_text, len(image_bytes))
    start = time.time()

    client = get_ai_client()

    # Send original image — no preprocessing. The CLAHE/grayscale pipeline
    # was designed for heavy analysis, but for simple OCR the raw image works better.
    raw = client.send_vision(
        READER_PROMPT,
        image_bytes,
        f"The assignment is: {assignment_text}\nWhat answer did the student write?",
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
