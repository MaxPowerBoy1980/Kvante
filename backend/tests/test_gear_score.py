"""Tests for GearScore Pydantic model and extract_gear_score helper."""
import pytest
from app.models.schemas import GearScore
from app.services.work_analyzer import extract_gear_score

DEFAULT_GEAR = {"correct_answer": 2, "visible_method": 1, "notation": 1}


def test_valid_gear_score():
    gs = GearScore(correct_answer=2, visible_method=1, notation=2)
    assert gs.total == 5


def test_gear_score_max():
    gs = GearScore(correct_answer=2, visible_method=2, notation=2)
    assert gs.total == 6


def test_gear_score_zero():
    gs = GearScore(correct_answer=0, visible_method=0, notation=0)
    assert gs.total == 0


def test_correct_answer_binary_clamp():
    gs = GearScore(correct_answer=1, visible_method=1, notation=1)
    assert gs.correct_answer == 2
    assert gs.total == 4


def test_correct_answer_negative_clamps_to_zero():
    gs = GearScore(correct_answer=-1, visible_method=1, notation=1)
    assert gs.correct_answer == 0


def test_visible_method_clamps():
    gs = GearScore(correct_answer=2, visible_method=5, notation=1)
    assert gs.visible_method == 2


def test_notation_clamps():
    gs = GearScore(correct_answer=0, visible_method=0, notation=-3)
    assert gs.notation == 0


def test_gear_score_serialization():
    gs = GearScore(correct_answer=2, visible_method=1, notation=2)
    data = gs.model_dump()
    assert data == {"correct_answer": 2, "visible_method": 1, "notation": 2, "total": 5}


def test_extract_gear_score_valid():
    parsed = {
        "gear_score": {"correct_answer": 2, "visible_method": 2, "notation": 1},
        "improvement_tip": "Husk mente-streger",
    }
    gs, tip = extract_gear_score(parsed)
    assert gs.total == 5
    assert tip == "Husk mente-streger"


def test_extract_gear_score_missing():
    parsed = {"student_answer": "42"}
    gs, tip = extract_gear_score(parsed)
    assert gs.total == 4  # generous default
    assert tip is None


def test_extract_gear_score_malformed():
    parsed = {"gear_score": "not a dict"}
    gs, tip = extract_gear_score(parsed)
    assert gs.total == 4  # generous default


def test_extract_gear_score_null_tip():
    parsed = {
        "gear_score": {"correct_answer": 2, "visible_method": 2, "notation": 2},
        "improvement_tip": None,
    }
    gs, tip = extract_gear_score(parsed)
    assert gs.total == 6
    assert tip is None
