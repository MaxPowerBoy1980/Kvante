import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session as DBSession

from app.database import Base
from app.models.db import Student, Session, Assignment, Submission


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with DBSession(engine) as session:
        yield session


def test_create_student(db):
    student = Student(name="Test Elev", language="da")
    db.add(student)
    db.commit()
    db.refresh(student)
    assert student.id is not None
    assert student.language == "da"


def test_create_session_with_assignments(db):
    student = Student(name="Test", language="da")
    db.add(student)
    db.commit()

    s = Session(
        student_id=student.id,
        page_image_path="uploads/test.jpg",
        detected_language="da",
    )
    db.add(s)
    db.commit()

    a = Assignment(
        session_id=s.id,
        local_id="3a",
        text="347 + 286 =",
        type="addition",
        topic="three-digit addition with carrying",
        difficulty_estimate=2,
    )
    db.add(a)
    db.commit()
    db.refresh(a)
    assert a.status == "not_started"
    assert a.session_id == s.id


def test_create_submission(db):
    student = Student(name="Test", language="da")
    db.add(student)
    db.commit()

    s = Session(student_id=student.id, page_image_path="test.jpg", detected_language="da")
    db.add(s)
    db.commit()

    a = Assignment(
        session_id=s.id, local_id="3a", text="347 + 286 =",
        type="addition", topic="addition", difficulty_estimate=1,
    )
    db.add(a)
    db.commit()

    sub = Submission(
        session_id=s.id,
        assignment_id=a.id,
        work_image_path="uploads/work.jpg",
        preprocessed_image_path="uploads/work_preprocessed.jpg",
        attempt_number=1,
    )
    db.add(sub)
    db.commit()
    db.refresh(sub)
    assert sub.id is not None
    assert sub.attempt_number == 1
    assert sub.feedback_text is None
