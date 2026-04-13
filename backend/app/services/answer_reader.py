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

The photo shows a student's handwritten columnar arithmetic (stacked vertically).
Read EACH DIGIT of the answer carefully, one at a time, left to right.

Rules:
- The answer is the bottom number, below the horizontal line
- Read ONLY that final answer — just the number, nothing else
- Read what is ACTUALLY WRITTEN, do NOT calculate the answer yourself
- Do NOT explain or comment — return ONLY the number
- If you cannot read it, reply with: UNREADABLE

## Digit confusion — read carefully:
These handwritten digits are often confused. Look at stroke shape, not what you expect:
- 5 vs 6: 5 has a flat top + angled stroke; 6 has a curved top loop
- 3 vs 8: 3 is open on the left; 8 is fully closed
- 1 vs 7: 1 is a straight vertical; 7 has a horizontal top bar
- 4 vs 9: 4 has an angular top; 9 has a round top loop
- 0 vs 6: 0 is a closed oval; 6 has a descending stroke

## ANTI-BIAS RULE (critical):
You know the assignment the student was solving. Do NOT let that bias your reading.
If a digit is ambiguous, prefer the reading that does NOT produce the mathematically correct answer.
The student may have made a mistake — your job is to read what they WROTE, not what they SHOULD have written.
A reading that matches the correct answer is MORE likely to be a misread when the digit is unclear.

Examples:
- Photo shows "50 + 30 = 80" → respond: 80
- Photo shows "347 + 286 = 633" → respond: 633
- Photo shows messy scribble → respond: UNREADABLE"""


def read_student_answer(image_bytes: bytes, assignment_text: str) -> dict:
    """Read the student's handwritten answer. Returns {answer, readable}."""
    logger.info("Reading answer for '%s' (%d bytes)", assignment_text, len(image_bytes))
    start = time.time()

    client = get_ai_client()

    raw = client.send_vision(
        READER_PROMPT,
        image_bytes,
        f"The student is solving: {assignment_text}\n"
        f"Read the handwritten answer below the line. What number did the student write? "
        f"Read each digit carefully.",
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
