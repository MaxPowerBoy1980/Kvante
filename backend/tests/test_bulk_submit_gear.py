import pytest
from app.models.schemas import BulkSubmitResult, GearScore


def test_bulk_submit_result_with_gear_score():
    result = BulkSubmitResult(
        assignment_id="a1",
        assignment_text="3 + 4",
        student_answer="7",
        status="correct",
        confidence=0.95,
        gear_score=GearScore(correct_answer=2, visible_method=2, notation=1),
        improvement_tip="Husk mente-streger",
    )
    assert result.gear_score.total == 5
    assert result.improvement_tip == "Husk mente-streger"


def test_bulk_submit_result_without_gear_score():
    result = BulkSubmitResult(
        assignment_id="a1",
        assignment_text="3 + 4",
        student_answer="7",
        status="correct",
        confidence=0.95,
    )
    assert result.gear_score is None
    assert result.improvement_tip is None
