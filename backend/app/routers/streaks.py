from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as DbSession

from app.database import get_db
from app.models.schemas import StreakResponse
from app.services.streak_service import get_streak

router = APIRouter(tags=["streaks"])


@router.get("/students/{student_id}/streak", response_model=StreakResponse)
def read_streak(student_id: str, db: DbSession = Depends(get_db)):
    return get_streak(db, student_id)
