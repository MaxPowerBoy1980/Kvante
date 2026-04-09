from datetime import datetime, timezone, timedelta

from sqlalchemy.orm import Session as DbSession

from app.models.db import UserStreak, _uuid, _now
from app.models.schemas import StreakResponse

_DK_OFFSET = timedelta(hours=2)


def _local_date(utc_ts: float):
    try:
        from zoneinfo import ZoneInfo
        dt = datetime.fromtimestamp(utc_ts, tz=ZoneInfo("Europe/Copenhagen"))
    except Exception:
        dt = datetime.fromtimestamp(utc_ts, tz=timezone.utc) + _DK_OFFSET
    return dt.date()


def _today_local():
    try:
        from zoneinfo import ZoneInfo
        return datetime.now(ZoneInfo("Europe/Copenhagen")).date()
    except Exception:
        return (datetime.now(timezone.utc) + _DK_OFFSET).date()


def get_streak(db: DbSession, student_id: str) -> StreakResponse:
    streak = db.query(UserStreak).filter_by(student_id=student_id).first()
    if not streak or streak.last_active_ts == 0:
        return StreakResponse(current_streak=0, longest_streak=0, last_active_date=None)

    return StreakResponse(
        current_streak=streak.current_streak,
        longest_streak=streak.longest_streak,
        last_active_date=_local_date(streak.last_active_ts).isoformat(),
    )


def update_streak(db: DbSession, student_id: str) -> StreakResponse:
    streak = db.query(UserStreak).filter_by(student_id=student_id).first()

    if not streak:
        streak = UserStreak(
            id=_uuid(),
            student_id=student_id,
            current_streak=0,
            last_active_ts=0,
            longest_streak=0,
            created_at=_now(),
        )
        db.add(streak)

    today = _today_local()

    if streak.last_active_ts == 0:
        streak.current_streak = 1
        streak.last_active_ts = datetime.now(timezone.utc).timestamp()
        streak.longest_streak = 1
    else:
        last_date = _local_date(streak.last_active_ts)

        if last_date == today:
            pass
        elif last_date == today - timedelta(days=1):
            streak.current_streak += 1
            streak.last_active_ts = datetime.now(timezone.utc).timestamp()
            if streak.current_streak > streak.longest_streak:
                streak.longest_streak = streak.current_streak
        else:
            streak.current_streak = 1
            streak.last_active_ts = datetime.now(timezone.utc).timestamp()
            if streak.longest_streak == 0:
                streak.longest_streak = 1

    db.commit()

    return StreakResponse(
        current_streak=streak.current_streak,
        longest_streak=streak.longest_streak,
        last_active_date=_local_date(streak.last_active_ts).isoformat(),
    )
