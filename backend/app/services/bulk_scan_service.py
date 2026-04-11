"""Bulk-scan service: build prompts, parse AI responses, validate results."""

import json
import logging
import re

from app.services.answer_reader import compare_answer

logger = logging.getLogger(__name__)


def build_user_message(assignments: list[dict]) -> str:
    """Build the user message listing all assignments for AI matching."""
    lines = ["Eleven skulle løse disse opgaver:\n"]
    for a in assignments:
        idx = a["index"]
        lines.append(f"Opgave {idx + 1} (index {idx}): {a['text']} = {a['correct_answer']}")
    lines.append("\nFind og læs elevens håndskrevne svar for hver opgave.")
    return "\n".join(lines)


def parse_ai_response(ai_text: str) -> list[dict]:
    """Parse AI response JSON, stripping markdown fences if present."""
    text = ai_text.strip()

    # Strip ```json ... ``` wrapper
    fence_match = re.search(r"```(?:json)?\s*\n?(.*?)\n?\s*```", text, re.DOTALL)
    if fence_match:
        text = fence_match.group(1).strip()

    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        raise ValueError(f"Could not parse AI response as JSON: {e}") from e

    if "matches" not in data:
        raise ValueError(f"AI response missing 'matches' key: {list(data.keys())}")

    return data["matches"]


def validate_and_build_results(
    matches: list[dict],
    assignments: list,  # SQLAlchemy Assignment objects
    confidence_threshold: float,
) -> list[dict]:
    """Validate AI matches against session assignments. Returns list of result dicts.

    - Skips already-complete assignments
    - Uses compare_answer() as ground truth
    - Marks low-confidence as uncertain
    - Deduplicates: highest confidence wins
    """
    # Build index → assignment map
    idx_to_assignment = {i: a for i, a in enumerate(assignments)}

    # Deduplicate: keep highest confidence per assignment_index
    best_by_index: dict[int, dict] = {}
    for match in matches:
        idx = match.get("assignment_index")
        if idx is None:
            continue
        confidence = match.get("confidence", 0.0)
        if idx not in best_by_index or confidence > best_by_index[idx].get("confidence", 0):
            best_by_index[idx] = match

    results = []
    for idx, match in sorted(best_by_index.items()):
        assignment = idx_to_assignment.get(idx)
        if assignment is None:
            logger.warning(
                "AI returned assignment_index=%d but session only has %d assignments",
                idx,
                len(assignments),
            )
            continue

        # Skip already-complete assignments
        if assignment.status in ("complete", "completed"):
            logger.info(
                "Skipping already-complete assignment %s (index %d)", assignment.id, idx
            )
            continue

        student_answer = match.get("student_answer")
        confidence = match.get("confidence", 0.0)
        page_index = match.get("page_index", 0)
        error_type = match.get("error_type")
        error_description = match.get("error_description")

        # Determine status
        if confidence < confidence_threshold:
            status = "uncertain"
        elif student_answer and assignment.correct_answer:
            is_correct = compare_answer(student_answer, assignment.correct_answer)
            status = "correct" if is_correct else "incorrect"
        else:
            status = "uncertain"

        # Clear error fields for correct answers
        if status == "correct":
            error_type = None
            error_description = None

        results.append(
            {
                "assignment_id": assignment.id,
                "assignment_index": idx,
                "assignment_text": assignment.text,
                "student_answer": student_answer,
                "status": status,
                "error_type": error_type,
                "error_description": error_description,
                "confidence": confidence,
                "page_index": page_index,
            }
        )

    return results
