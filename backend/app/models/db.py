import uuid
from datetime import datetime, timezone

from sqlalchemy import JSON, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


def _now() -> datetime:
    return datetime.now(timezone.utc)


class Student(Base):
    __tablename__ = "students"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    name: Mapped[str] = mapped_column(String, nullable=False)
    language: Mapped[str] = mapped_column(String, default="da")
    grade_level: Mapped[int] = mapped_column(Integer, default=4)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)


class MathProblem(Base):
    __tablename__ = "math_problems"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    topic: Mapped[str] = mapped_column(String, nullable=False, index=True)
    subtopic: Mapped[str] = mapped_column(String, default="")
    difficulty: Mapped[int] = mapped_column(Integer, nullable=False)
    grade_level: Mapped[int] = mapped_column(Integer, nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    type: Mapped[str] = mapped_column(String, nullable=False)
    correct_answer: Mapped[str] = mapped_column(String, nullable=False)
    solution_steps: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    hints: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    tags: Mapped[str] = mapped_column(String, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)


class ProblemSet(Base):
    __tablename__ = "problem_sets"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    name: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str] = mapped_column(Text, default="")
    topic: Mapped[str] = mapped_column(String, default="")
    difficulty: Mapped[int | None] = mapped_column(Integer, nullable=True)
    problem_ids: Mapped[dict] = mapped_column(JSON, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)


class Session(Base):
    __tablename__ = "sessions"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    student_id: Mapped[str] = mapped_column(String, ForeignKey("students.id"), nullable=False)
    mode: Mapped[str] = mapped_column(String, default="practice")
    topic: Mapped[str | None] = mapped_column(String, nullable=True)
    difficulty: Mapped[int | None] = mapped_column(Integer, nullable=True)
    page_image_path: Mapped[str | None] = mapped_column(String, nullable=True)
    parsed_assignments: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    detected_language: Mapped[str] = mapped_column(String, default="da")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)
    status: Mapped[str] = mapped_column(String, default="active")
    name: Mapped[str] = mapped_column(String, default="")
    completed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class Assignment(Base):
    __tablename__ = "assignments"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    session_id: Mapped[str] = mapped_column(String, ForeignKey("sessions.id"), nullable=False)
    problem_id: Mapped[str | None] = mapped_column(String, ForeignKey("math_problems.id"), nullable=True)
    local_id: Mapped[str] = mapped_column(String, nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    type: Mapped[str] = mapped_column(String, nullable=False)
    topic: Mapped[str] = mapped_column(String, nullable=False)
    difficulty_estimate: Mapped[int] = mapped_column(Integer, default=1)
    correct_answer: Mapped[str | None] = mapped_column(String, nullable=True)
    status: Mapped[str] = mapped_column(String, default="not_started")
    position: Mapped[int] = mapped_column(Integer, default=0)
    feedback_summary: Mapped[str | None] = mapped_column(String, nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class Submission(Base):
    __tablename__ = "submissions"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    session_id: Mapped[str] = mapped_column(String, ForeignKey("sessions.id"), nullable=False)
    assignment_id: Mapped[str] = mapped_column(String, ForeignKey("assignments.id"), nullable=False)
    work_image_path: Mapped[str] = mapped_column(String, nullable=False)
    preprocessed_image_path: Mapped[str | None] = mapped_column(String, nullable=True)
    analysis: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    feedback_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    attempt_number: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    session_id: Mapped[str] = mapped_column(String, ForeignKey("sessions.id"), nullable=False, index=True)
    assignment_id: Mapped[str | None] = mapped_column(String, ForeignKey("assignments.id"), nullable=True)
    sender: Mapped[str] = mapped_column(String, nullable=False)
    content_type: Mapped[str] = mapped_column(String, nullable=False)
    content: Mapped[dict] = mapped_column(JSON, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)
