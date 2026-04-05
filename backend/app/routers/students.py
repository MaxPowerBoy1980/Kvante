"""Student registration endpoint."""

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.db import Student

router = APIRouter(prefix="/students", tags=["students"])


class RegisterRequest(BaseModel):
    name: str
    grade_level: int = 4


@router.post("/register")
def register_student(body: RegisterRequest, db: Session = Depends(get_db)):
    """Register a new student or return existing."""
    student = Student(
        name=body.name,
        grade_level=body.grade_level,
        language="da",
    )
    db.add(student)
    db.commit()
    db.refresh(student)
    return {
        "student_id": student.id,
        "name": student.name,
        "grade_level": student.grade_level,
    }
