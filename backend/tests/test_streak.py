"""Tests for streak_service (Pakke 2b PR2)."""
from datetime import datetime, timezone, timedelta

import pytest
from app.services.streak_service import update_streak, get_streak


@pytest.fixture
def student_id(test_db):
    """Create a test student and return its id."""
    from app.models.db import Student
    s = Student(name="TestElev", language="da", grade_level=4)
    test_db.add(s)
    test_db.commit()
    return s.id


def test_first_correct_answer_starts_streak(test_db, student_id):
    result = update_streak(test_db, student_id)
    assert result.current_streak == 1
    assert result.longest_streak == 1


def test_second_answer_same_day_no_change(test_db, student_id):
    update_streak(test_db, student_id)
    result = update_streak(test_db, student_id)
    assert result.current_streak == 1


def test_consecutive_day_increments(test_db, student_id):
    from app.models.db import UserStreak
    update_streak(test_db, student_id)
    streak = test_db.query(UserStreak).filter_by(student_id=student_id).first()
    yesterday = datetime.now(timezone.utc) - timedelta(days=1)
    streak.last_active_ts = yesterday.timestamp()
    test_db.commit()

    result = update_streak(test_db, student_id)
    assert result.current_streak == 2
    assert result.longest_streak == 2


def test_gap_resets_streak(test_db, student_id):
    from app.models.db import UserStreak
    update_streak(test_db, student_id)
    streak = test_db.query(UserStreak).filter_by(student_id=student_id).first()
    three_days_ago = datetime.now(timezone.utc) - timedelta(days=3)
    streak.last_active_ts = three_days_ago.timestamp()
    streak.current_streak = 5
    streak.longest_streak = 5
    test_db.commit()

    result = update_streak(test_db, student_id)
    assert result.current_streak == 1
    assert result.longest_streak == 5


def test_get_streak_new_student(test_db, student_id):
    result = get_streak(test_db, student_id)
    assert result.current_streak == 0
    assert result.longest_streak == 0
    assert result.last_active_date is None
