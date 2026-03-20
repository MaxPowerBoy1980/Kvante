import os
import tempfile

os.environ["KVANTE_TESTING"] = "1"
os.environ.setdefault("KVANTE_ANTHROPIC_API_KEY", "sk-test-placeholder")
os.environ.setdefault("KVANTE_LOG_DIR", os.path.join(tempfile.gettempdir(), "kvante-test-logs"))

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session as DBSession, sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models.db import Student


@pytest.fixture
def test_db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    TestingSession = sessionmaker(bind=engine)
    db = TestingSession()

    # Create default student for MVP
    student = Student(id="default", name="Default Student", language="da")
    db.add(student)
    db.commit()

    yield db
    db.close()


@pytest.fixture
def client(test_db):
    def override_get_db():
        yield test_db

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
