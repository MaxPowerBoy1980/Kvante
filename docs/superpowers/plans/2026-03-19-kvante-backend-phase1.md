# Kvante Backend — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete Kvante backend — a FastAPI server that parses textbook page photos into assignments, analyzes handwritten student work, generates worked examples of similar problems, and produces kid-friendly method-focused feedback. All via Claude Vision API.

**Architecture:** FastAPI app with 4 routers (pages, assignments, submissions, feedback) backed by 5 services (page_parser, work_analyzer, example_generator, feedback_generator, image_preprocessor). SQLite database via SQLAlchemy stores sessions, assignments, submissions. Claude Vision API (`claude-sonnet-4-20250514`) handles all image analysis and text generation. System prompts stored as `.txt` files define the pedagogical behavior.

**Tech Stack:** Python 3.11+, FastAPI, uvicorn, anthropic SDK, SQLAlchemy + SQLite, Pillow, opencv-python-headless, zeroconf, python-dotenv, pytest

**Spec:** `docs/superpowers/specs/2026-03-19-kvante-design.md`

---

## File Structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py                    # FastAPI app, CORS, lifespan (Bonjour registration)
│   ├── config.py                  # Settings via pydantic-settings, loads .env
│   ├── database.py                # SQLAlchemy engine, session factory, Base
│   ├── routers/
│   │   ├── __init__.py
│   │   ├── health.py              # GET /health
│   │   ├── pages.py               # POST /pages/scan
│   │   ├── assignments.py         # POST /sessions/{session_id}/assignments/{assignment_id}/example
│   │   ├── submissions.py         # POST /submissions/
│   │   └── feedback.py            # POST /feedback/, POST /feedback/{submission_id}/followup
│   ├── services/
│   │   ├── __init__.py
│   │   ├── claude_client.py       # Shared Anthropic client wrapper (vision + text calls)
│   │   ├── image_preprocessor.py  # Pillow/OpenCV preprocessing pipeline
│   │   ├── page_parser.py         # Parse textbook page → assignment list
│   │   ├── example_generator.py   # Generate similar worked examples
│   │   ├── work_analyzer.py       # Analyze handwritten student work
│   │   └── feedback_generator.py  # Kid-friendly method-focused feedback + followup
│   ├── models/
│   │   ├── __init__.py
│   │   ├── db.py                  # All SQLAlchemy ORM models (Session, Assignment, Submission, Student)
│   │   └── schemas.py             # Pydantic request/response schemas for all endpoints
│   └── prompts/
│       ├── parse_page.txt
│       ├── generate_example.txt
│       ├── analyze_work.txt
│       ├── give_feedback.txt
│       └── explain_method.txt
├── tests/
│   ├── __init__.py
│   ├── conftest.py                # Shared fixtures: test client, test DB, mock Claude
│   ├── test_image_preprocessor.py
│   ├── test_page_parser.py
│   ├── test_work_analyzer.py
│   ├── test_example_generator.py
│   ├── test_feedback_generator.py
│   ├── test_routers.py            # Integration tests for all endpoints
│   └── sample_photos/             # Real test images (added manually)
├── requirements.txt
├── .env.example
└── .gitignore
```

**Key design decisions:**
- All SQLAlchemy models in one file (`models/db.py`) — 4 small models, no reason to split
- All Pydantic schemas in one file (`models/schemas.py`) — keeps request/response contracts in one place
- `claude_client.py` wraps the Anthropic SDK — single place to configure model, handle errors, log token usage
- Prompts loaded from `.txt` files at service init, not hardcoded in Python

---

### Task 1: Project Scaffolding

**Files:**
- Create: `backend/requirements.txt`
- Create: `backend/.env.example`
- Create: `backend/.gitignore`
- Create: `backend/app/__init__.py`
- Create: `backend/app/config.py`

- [ ] **Step 1: Create requirements.txt**

```
fastapi==0.115.6
uvicorn[standard]==0.34.0
anthropic==0.42.0
sqlalchemy==2.0.36
pillow==11.1.0
opencv-python-headless==4.10.0.84
zeroconf==0.136.2
python-dotenv==1.0.1
pydantic-settings==2.7.1
pytest==8.3.4
httpx==0.28.1
pytest-asyncio==0.25.0
```

- [ ] **Step 2: Create .env.example**

```
ANTHROPIC_API_KEY=sk-ant-your-key-here
KVANTE_DB_PATH=kvante.db
KVANTE_HOST=0.0.0.0
KVANTE_PORT=8000
KVANTE_CONFIDENCE_THRESHOLD=0.6
KVANTE_CLAUDE_MODEL=claude-sonnet-4-20250514
KVANTE_UPLOAD_DIR=uploads
```

- [ ] **Step 3: Create .gitignore**

```
__pycache__/
*.pyc
.env
kvante.db
uploads/
.pytest_cache/
```

- [ ] **Step 4: Create app/__init__.py**

Empty file.

- [ ] **Step 5: Create app/config.py**

```python
from pathlib import Path
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    anthropic_api_key: str
    db_path: str = "kvante.db"
    host: str = "0.0.0.0"
    port: int = 8000
    confidence_threshold: float = 0.6
    claude_model: str = "claude-sonnet-4-20250514"
    upload_dir: str = "uploads"
    max_upload_size: int = 10 * 1024 * 1024  # 10 MB
    prompts_dir: Path = Path(__file__).parent / "prompts"

    model_config = {"env_prefix": "KVANTE_", "env_file": ".env"}


settings = Settings()
```

- [ ] **Step 6: Create directory structure and install dependencies**

Run:
```bash
cd backend
mkdir -p app/routers app/services app/models app/prompts tests/sample_photos uploads
touch app/__init__.py app/routers/__init__.py app/services/__init__.py app/models/__init__.py tests/__init__.py
python -m pip install -r requirements.txt
```

- [ ] **Step 7: Commit**

```bash
git add backend/
git commit -m "feat: scaffold backend project with dependencies and config"
```

---

### Task 2: Database Models and Setup

**Files:**
- Create: `backend/app/database.py`
- Create: `backend/app/models/db.py`
- Create: `backend/app/models/schemas.py`

- [ ] **Step 1: Write the test for database models**

Create `backend/tests/test_models.py`:

```python
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
    assert sub.feedback_text is None  # populated later by POST /feedback/
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_models.py -v`
Expected: FAIL — modules not found

- [ ] **Step 3: Create database.py**

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.config import settings


class Base(DeclarativeBase):
    pass


engine = create_engine(f"sqlite:///{settings.db_path}", echo=False)
SessionLocal = sessionmaker(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

- [ ] **Step 4: Create models/db.py**

```python
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
    language: Mapped[str] = mapped_column(String, default="da")  # "da" or "en"
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)


class Session(Base):
    __tablename__ = "sessions"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    student_id: Mapped[str] = mapped_column(String, ForeignKey("students.id"), nullable=False)
    page_image_path: Mapped[str] = mapped_column(String, nullable=False)
    parsed_assignments: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    detected_language: Mapped[str] = mapped_column(String, default="da")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)
    status: Mapped[str] = mapped_column(String, default="active")  # "active" | "completed"


class Assignment(Base):
    __tablename__ = "assignments"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    session_id: Mapped[str] = mapped_column(String, ForeignKey("sessions.id"), nullable=False)
    local_id: Mapped[str] = mapped_column(String, nullable=False)  # "3a", "3b"
    text: Mapped[str] = mapped_column(Text, nullable=False)
    type: Mapped[str] = mapped_column(String, nullable=False)  # "addition", "subtraction", etc.
    topic: Mapped[str] = mapped_column(String, nullable=False)
    difficulty_estimate: Mapped[int] = mapped_column(Integer, default=1)
    status: Mapped[str] = mapped_column(String, default="not_started")  # "not_started" | "in_progress" | "completed"


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
```

- [ ] **Step 5: Create models/schemas.py**

```python
from pydantic import BaseModel


# --- Page Scan ---

class ParsedAssignment(BaseModel):
    id: str
    text: str
    type: str
    topic: str
    difficulty_estimate: int
    position_on_page: str


class PageScanResponse(BaseModel):
    session_id: str
    assignments: list[ParsedAssignment]
    page_context: str
    suggested_order: list[str]
    suggested_start: str
    reasoning: str
    detected_language: str


# --- Example Generator ---

class ExampleStep(BaseModel):
    step: int
    instruction: str
    visual: str
    explanation: str


class ExampleResponse(BaseModel):
    example_problem: str
    steps: list[ExampleStep]
    note: str


# --- Work Analyzer (Submission) ---

class AnalysisStep(BaseModel):
    step: int
    description: str
    correct: bool


class SubmissionResponse(BaseModel):
    submission_id: str
    assignment_id: str
    session_id: str
    student_answer: str
    methodology_sound: bool
    steps_identified: list[AnalysisStep]
    errors: list[str]
    correct_elements: list[str]
    methodology_assessment: str
    handwriting_note: str = ""
    confidence: float


# --- Feedback ---

class StructuredPrompt(BaseModel):
    id: str
    label: str


class FeedbackResponse(BaseModel):
    feedback_text: str
    tone: str
    structured_prompts: list[StructuredPrompt]


class FeedbackRequest(BaseModel):
    submission_id: str
    language: str = "da"


class FollowupRequest(BaseModel):
    action: str  # explain_different | another_example | show_first_step | what_did_well | try_again


# --- Health ---

class HealthResponse(BaseModel):
    status: str
    version: str


# --- Errors ---

class ErrorResponse(BaseModel):
    error: str
    message: str
    student_message: str = ""
    detail: str = ""
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_models.py -v`
Expected: All 3 tests PASS

- [ ] **Step 7: Commit**

```bash
git add backend/
git commit -m "feat: add database models and Pydantic schemas"
```

---

### Task 3: Image Preprocessor

**Files:**
- Create: `backend/app/services/image_preprocessor.py`
- Create: `backend/tests/test_image_preprocessor.py`

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_image_preprocessor.py`:

```python
import io
from PIL import Image
import pytest

from app.services.image_preprocessor import preprocess_textbook_page, preprocess_handwritten_work


def _make_test_image(width: int = 3000, height: int = 4000, mode: str = "RGB") -> bytes:
    """Create a test image as bytes."""
    img = Image.new(mode, (width, height), color="white")
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_textbook_page_resizes_to_max_1568():
    raw = _make_test_image(3000, 4000)
    result = preprocess_textbook_page(raw)
    img = Image.open(io.BytesIO(result))
    assert max(img.size) <= 1568


def test_textbook_page_returns_jpeg():
    raw = _make_test_image()
    result = preprocess_textbook_page(raw)
    img = Image.open(io.BytesIO(result))
    assert img.format == "JPEG"


def test_handwritten_work_converts_to_grayscale():
    raw = _make_test_image(mode="RGB")
    result = preprocess_handwritten_work(raw)
    img = Image.open(io.BytesIO(result))
    assert img.mode == "L"


def test_handwritten_work_resizes():
    raw = _make_test_image(3000, 4000)
    result = preprocess_handwritten_work(raw)
    img = Image.open(io.BytesIO(result))
    assert max(img.size) <= 1568


def test_small_image_not_upscaled():
    raw = _make_test_image(800, 600)
    result = preprocess_textbook_page(raw)
    img = Image.open(io.BytesIO(result))
    assert max(img.size) <= 800


def test_rejects_oversized_input():
    # Create a ~12 MB image (exceeds 10 MB limit)
    huge = _make_test_image(8000, 8000)
    if len(huge) <= 10 * 1024 * 1024:
        pytest.skip("Test image not large enough to exceed limit")
    with pytest.raises(ValueError, match="exceeds maximum"):
        preprocess_textbook_page(huge)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_image_preprocessor.py -v`
Expected: FAIL — module not found

- [ ] **Step 3: Implement image_preprocessor.py**

```python
import io

import cv2
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

from app.config import settings

MAX_DIMENSION = 1568


def _validate_size(image_bytes: bytes) -> None:
    if len(image_bytes) > settings.max_upload_size:
        raise ValueError(
            f"Image size ({len(image_bytes)} bytes) exceeds maximum "
            f"({settings.max_upload_size} bytes)"
        )


def _resize_if_needed(img: Image.Image) -> Image.Image:
    w, h = img.size
    if max(w, h) <= MAX_DIMENSION:
        return img
    scale = MAX_DIMENSION / max(w, h)
    new_w, new_h = int(w * scale), int(h * scale)
    return img.resize((new_w, new_h), Image.LANCZOS)


def _to_jpeg_bytes(img: Image.Image) -> bytes:
    if img.mode == "RGBA":
        img = img.convert("RGB")
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return buf.getvalue()


def preprocess_textbook_page(image_bytes: bytes) -> bytes:
    """Light preprocessing for printed textbook pages.

    Resize to max 1568px, light contrast enhancement.
    """
    _validate_size(image_bytes)
    img = Image.open(io.BytesIO(image_bytes))
    img = _resize_if_needed(img)
    img = ImageEnhance.Contrast(img).enhance(1.2)
    return _to_jpeg_bytes(img)


def preprocess_handwritten_work(image_bytes: bytes) -> bytes:
    """Aggressive preprocessing for pencil-on-paper handwritten work.

    Grayscale -> CLAHE -> sharpen -> resize.
    Critical for faint pencil marks.
    """
    _validate_size(image_bytes)
    img = Image.open(io.BytesIO(image_bytes))
    img = _resize_if_needed(img)
    img = img.convert("L")

    # CLAHE via OpenCV for better pencil contrast
    arr = np.array(img)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    arr = clahe.apply(arr)
    img = Image.fromarray(arr)

    # Light sharpening
    img = img.filter(ImageFilter.UnsharpMask(radius=1.5, percent=50, threshold=3))

    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return buf.getvalue()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_image_preprocessor.py -v`
Expected: PASS (the oversized test may skip if the synthetic image compresses below 10 MB — that's fine)

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/image_preprocessor.py backend/tests/test_image_preprocessor.py
git commit -m "feat: add image preprocessor with CLAHE for pencil-on-paper"
```

---

### Task 4: Claude Client Wrapper

**Files:**
- Create: `backend/app/services/claude_client.py`
- Create: `backend/tests/test_claude_client.py`

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_claude_client.py`:

```python
import pytest
from unittest.mock import MagicMock, patch

from app.services.claude_client import ClaudeClient


@pytest.fixture
def client():
    with patch("app.services.claude_client.anthropic.Anthropic") as mock_cls:
        mock_instance = MagicMock()
        mock_cls.return_value = mock_instance
        c = ClaudeClient()
        c._client = mock_instance
        yield c, mock_instance


def test_send_text_prompt(client):
    c, mock = client
    mock.messages.create.return_value = MagicMock(
        content=[MagicMock(text='{"result": "ok"}')],
        usage=MagicMock(input_tokens=100, output_tokens=50),
    )
    result = c.send_text("system prompt", "user message")
    assert result == '{"result": "ok"}'
    mock.messages.create.assert_called_once()


def test_send_vision_prompt(client):
    c, mock = client
    mock.messages.create.return_value = MagicMock(
        content=[MagicMock(text='{"assignments": []}')],
        usage=MagicMock(input_tokens=200, output_tokens=100),
    )
    result = c.send_vision("system prompt", b"fake-image-bytes", "What do you see?")
    assert '"assignments"' in result
    call_args = mock.messages.create.call_args
    # Verify image content block was included
    messages = call_args.kwargs["messages"]
    assert any(
        isinstance(block, dict) and block.get("type") == "image"
        for msg in messages
        for block in (msg["content"] if isinstance(msg["content"], list) else [])
    )
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_claude_client.py -v`
Expected: FAIL — module not found

- [ ] **Step 3: Implement claude_client.py**

```python
import base64
import logging

import anthropic

from app.config import settings

logger = logging.getLogger(__name__)


class ClaudeClient:
    def __init__(self):
        self._client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        self._model = settings.claude_model

    def send_text(self, system_prompt: str, user_message: str) -> str:
        """Send a text-only prompt to Claude. Returns the text response."""
        response = self._client.messages.create(
            model=self._model,
            max_tokens=4096,
            system=system_prompt,
            messages=[{"role": "user", "content": user_message}],
        )
        self._log_usage(response.usage)
        return response.content[0].text

    def send_vision(
        self,
        system_prompt: str,
        image_bytes: bytes,
        user_message: str,
        media_type: str = "image/jpeg",
    ) -> str:
        """Send an image + text prompt to Claude Vision. Returns the text response."""
        image_b64 = base64.b64encode(image_bytes).decode("utf-8")
        response = self._client.messages.create(
            model=self._model,
            max_tokens=4096,
            system=system_prompt,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": media_type,
                                "data": image_b64,
                            },
                        },
                        {"type": "text", "text": user_message},
                    ],
                }
            ],
        )
        self._log_usage(response.usage)
        return response.content[0].text

    def _log_usage(self, usage) -> None:
        logger.info(
            "Claude API usage: input_tokens=%d, output_tokens=%d",
            usage.input_tokens,
            usage.output_tokens,
        )
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_claude_client.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/claude_client.py backend/tests/test_claude_client.py
git commit -m "feat: add Claude client wrapper with vision and text support"
```

---

### Task 5: System Prompts

**Files:**
- Create: `backend/app/prompts/parse_page.txt`
- Create: `backend/app/prompts/generate_example.txt`
- Create: `backend/app/prompts/analyze_work.txt`
- Create: `backend/app/prompts/give_feedback.txt`
- Create: `backend/app/prompts/explain_method.txt`

These are the most critical deliverable. They define the product's pedagogical behavior.

- [ ] **Step 1: Write parse_page.txt**

```
You are Kvante, a math learning assistant for primary school students aged 9–13.

You are looking at a photo of a page from a math textbook. Your job is to identify every individual assignment or exercise on this page and return them as structured JSON.

## Instructions

1. Examine the entire page carefully.
2. Identify every individual assignment or exercise. These are typically numbered (e.g., "3a", "3b", "4", "5a").
3. For each assignment, extract:
   - The assignment ID (e.g., "3a", "4", "12b")
   - The full text of the assignment (e.g., "347 + 286 =")
   - The type: addition, subtraction, multiplication, division, fractions, geometry, word_problem, mixed, or other
   - The topic: a brief description (e.g., "three-digit addition with carrying")
   - A difficulty estimate from 1 (easiest) to 5 (hardest), relative to the OTHER assignments on this page
   - Position on the page: top-left, top-right, middle-left, middle-right, bottom-left, bottom-right

4. Determine the page context (e.g., "Chapter 4: Addition and subtraction with large numbers").
5. Suggest a pedagogically sound order to work through the assignments. Typically: start with the easiest as a warm-up, then build to harder ones.
6. Suggest which assignment to start with and explain why briefly.
7. Detect the language of the textbook (Danish "da" or English "en").

## What to IGNORE
- Page numbers
- Chapter headers and section titles (capture them as page_context, but they are not assignments)
- Illustrations and decorative images
- Instructional text explaining concepts (not assignments)
- Example solutions already shown on the page

## Output Format

Return ONLY valid JSON matching this exact schema. No markdown, no explanation, just JSON:

{
  "assignments": [
    {
      "id": "string",
      "text": "string",
      "type": "string",
      "topic": "string",
      "difficulty_estimate": number,
      "position_on_page": "string"
    }
  ],
  "page_context": "string",
  "suggested_order": ["id1", "id2", ...],
  "suggested_start": "string",
  "reasoning": "string",
  "detected_language": "da" or "en"
}
```

- [ ] **Step 2: Write generate_example.txt**

```
You are Kvante, a warm and patient math tutor for students aged 9–13.

A student needs help understanding how to solve a math problem. You must create a WORKED EXAMPLE of a SIMILAR but DIFFERENT problem. You are showing them the METHOD, not giving them the answer to their assignment.

## CRITICAL RULES
- You MUST use DIFFERENT NUMBERS than the student's actual assignment.
- The example problem must be obviously different so it cannot be confused with or copied as the answer.
- Never reveal or hint at the answer to the student's actual assignment.

## Instructions

You will receive:
- The assignment type (e.g., "addition")
- The assignment topic (e.g., "three-digit addition with carrying")
- The actual assignment text (so you know what to make DIFFERENT from)
- The student's language ("da" for Danish, "en" for English)

Create a new problem of similar difficulty with different numbers. Then solve it step-by-step.

## How to write each step
- Use simple language a 9–13 year old can understand
- Make each step visual and concrete
- Show the work visually (lined up numbers, carry marks, etc.)
- Explain WHY you do each step, not just WHAT you do
- Use encouraging language

## Output Format

Return ONLY valid JSON:

{
  "example_problem": "string (the new problem, e.g., '523 + 389 =')",
  "steps": [
    {
      "step": number,
      "instruction": "string (what to do in this step)",
      "visual": "string (visual representation of the work, use \\n for line breaks)",
      "explanation": "string (why we do it this way)"
    }
  ],
  "note": "string (remind the student this uses different numbers — write in the student's language)"
}

Write all text in the student's language. If Danish, write in Danish. If English, write in English.
```

- [ ] **Step 3: Write analyze_work.txt**

```
You are Kvante, a math learning assistant analyzing a student's handwritten work.

You will receive:
- The original assignment (what the student was asked to solve)
- A photo of the student's handwritten work on paper

Your job is to carefully read their handwriting and analyze their METHODOLOGY — how they approached the problem, step by step.

## CRITICAL RULES
- NEVER include the correct answer in your response.
- If you cannot read the handwriting clearly, say so honestly. Do NOT guess.
- Focus on the PROCESS, not just whether the final answer is right or wrong.
- Always find something positive the student did.

## Analysis Instructions

1. Read the handwritten numbers and operations carefully.
2. Trace the student's step-by-step methodology.
3. For each step, determine if it was executed correctly.
4. Classify any errors:
   - "understanding" — wrong method entirely (e.g., subtracted instead of added)
   - "procedural" — right method, execution error (e.g., carried wrong, miscounted)
   - "careless" — clearly knows the method, small slip (e.g., wrote 3 instead of 8)
5. Note what the student did correctly — there is always something.
6. Assess handwriting clarity.

## Confidence

Rate your confidence from 0.0 to 1.0:
- 0.0–0.3: Cannot read the work, image too unclear
- 0.4–0.6: Can partially read, some guessing required
- 0.7–0.9: Can read most of it clearly
- 1.0: Perfectly clear

If confidence is below 0.4, set methodology_sound to false and add "unclear_image" to errors. Do NOT attempt to analyze work you cannot read.

## Output Format

Return ONLY valid JSON:

{
  "student_answer": "string (what the student wrote as their answer)",
  "methodology_sound": boolean,
  "steps_identified": [
    {"step": number, "description": "string", "correct": boolean}
  ],
  "errors": ["string (error descriptions, or 'unclear_image')"],
  "correct_elements": ["string (things the student did well)"],
  "methodology_assessment": "string (brief overall assessment of their approach)",
  "handwriting_note": "string (comment on handwriting clarity)",
  "confidence": number
}
```

- [ ] **Step 4: Write give_feedback.txt**

```
You are Kvante, a warm and patient math tutor for students aged 9–13.

You are giving feedback on a student's work. You have already received a structured analysis of what the student did.

## ABSOLUTE RULE — READ THIS FIRST
You must NEVER, under any circumstances, reveal the correct answer to the assignment. Not directly, not indirectly, not "the answer is close to..." — NEVER. The student must arrive at the answer themselves, on paper.

## Feedback Guidelines

1. ALWAYS start with something positive. Find what the student did well and praise it genuinely.
2. If there are errors, explain them through METHODOLOGY:
   - NOT: "8 + 7 is not 14"
   - YES: "When you added the ones column, try counting again carefully — you're so close!"
3. Keep feedback to 3–4 sentences maximum. Kids lose attention with walls of text.
4. If everything is correct: celebrate! Note what was done well methodologically. Encourage moving to the next assignment.
5. Use analogies and concrete language when helpful.
6. Tone: warm, patient, encouraging. Like a favorite tutor. Never condescending. Never robotic.

## Input

You will receive:
- The assignment text
- The structured analysis (steps identified, errors, correct elements)
- The student's language ("da" or "en")

## Output Format

Return ONLY valid JSON:

{
  "feedback_text": "string (3-4 sentences, in the student's language)",
  "tone": "celebratory" | "encouraging" | "supportive"
}

- "celebratory" — everything correct, great work!
- "encouraging" — some errors but good effort, keep trying
- "supportive" — significant errors, but find the positive and guide gently

Write the feedback_text entirely in the student's language.
```

- [ ] **Step 5: Write explain_method.txt**

```
You are Kvante, a warm and patient math tutor for students aged 9–13.

A student has already received feedback on their work and is asking you to explain the concept in a DIFFERENT way. They didn't fully understand the first explanation.

## ABSOLUTE RULE
NEVER reveal the correct answer to the assignment. Not directly, not indirectly. The student must arrive at the answer themselves.

## Instructions

You will receive:
- The assignment text
- The previous feedback that was given
- The student's language ("da" or "en")
- The action requested (one of: "explain_different", "show_first_step", "what_did_well")

## For "explain_different":
- Re-explain using a DIFFERENT approach than the previous feedback
- If the previous explanation was abstract → make it concrete (use objects, counting, real-world examples)
- If the previous explanation was concrete → try a visual/spatial approach
- Keep it to 2–3 sentences, then ask if that helps

## For "show_first_step":
- Show ONLY the very first step of the methodology
- Do NOT outline the full solution path
- Example: "Start by lining up the numbers so the ones, tens, and hundreds are in columns."
- Keep it to 1–2 sentences

## For "what_did_well":
- Focus entirely on what the student did correctly
- Be specific and genuine
- Reinforce the correct methodology they used
- Keep it to 2–3 sentences

## Output Format

Return ONLY valid JSON:

{
  "feedback_text": "string (in the student's language)",
  "tone": "encouraging" | "supportive" | "celebratory"
}
```

- [ ] **Step 6: Write test to verify prompts load correctly**

Create `backend/tests/test_prompts.py`:

```python
from pathlib import Path

import pytest

PROMPTS_DIR = Path(__file__).parent.parent / "app" / "prompts"

REQUIRED_PROMPTS = [
    "parse_page.txt",
    "generate_example.txt",
    "analyze_work.txt",
    "give_feedback.txt",
    "explain_method.txt",
]


@pytest.mark.parametrize("filename", REQUIRED_PROMPTS)
def test_prompt_file_exists_and_nonempty(filename):
    path = PROMPTS_DIR / filename
    assert path.exists(), f"Prompt file {filename} not found"
    content = path.read_text()
    assert len(content) > 100, f"Prompt file {filename} seems too short ({len(content)} chars)"


@pytest.mark.parametrize("filename", REQUIRED_PROMPTS)
def test_prompt_mentions_never_reveal_answer(filename):
    """Every prompt except parse_page must contain the 'never reveal answer' instruction."""
    if filename == "parse_page.txt":
        pytest.skip("parse_page doesn't analyze student work")
    content = (PROMPTS_DIR / filename).read_text().lower()
    assert "never" in content and "answer" in content, (
        f"Prompt {filename} must contain the 'never reveal answer' instruction"
    )
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_prompts.py -v`
Expected: All PASS

- [ ] **Step 8: Commit**

```bash
git add backend/app/prompts/ backend/tests/test_prompts.py
git commit -m "feat: add all system prompts — pedagogical core of Kvante"
```

---

### Task 6: Page Parser Service

**Files:**
- Create: `backend/app/services/page_parser.py`
- Create: `backend/tests/test_page_parser.py`

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_page_parser.py`:

```python
import json
from unittest.mock import MagicMock, patch

import pytest

from app.services.page_parser import PageParserService


MOCK_CLAUDE_RESPONSE = json.dumps({
    "assignments": [
        {
            "id": "3a",
            "text": "347 + 286 =",
            "type": "addition",
            "topic": "three-digit addition with carrying",
            "difficulty_estimate": 2,
            "position_on_page": "top-left",
        },
        {
            "id": "3b",
            "text": "1.203 - 847 =",
            "type": "subtraction",
            "topic": "four-digit subtraction with borrowing",
            "difficulty_estimate": 3,
            "position_on_page": "top-right",
        },
    ],
    "page_context": "Chapter 4: Addition and subtraction",
    "suggested_order": ["3a", "3b"],
    "suggested_start": "3a",
    "reasoning": "3a is simpler.",
    "detected_language": "da",
})


@pytest.fixture
def service():
    with patch("app.services.page_parser.ClaudeClient") as mock_cls:
        mock_client = MagicMock()
        mock_cls.return_value = mock_client
        mock_client.send_vision.return_value = MOCK_CLAUDE_RESPONSE
        svc = PageParserService()
        svc.claude = mock_client
        yield svc


def test_parse_page_returns_assignments(service):
    result = service.parse_page(b"fake-image-bytes")
    assert len(result["assignments"]) == 2
    assert result["assignments"][0]["id"] == "3a"
    assert result["assignments"][1]["type"] == "subtraction"


def test_parse_page_includes_suggestion(service):
    result = service.parse_page(b"fake-image-bytes")
    assert result["suggested_start"] == "3a"
    assert result["detected_language"] == "da"


def test_parse_page_sends_image_to_claude(service):
    service.parse_page(b"test-image")
    service.claude.send_vision.assert_called_once()
    call_args = service.claude.send_vision.call_args
    assert b"test-image" in call_args.args or b"test-image" == call_args.args[1]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_page_parser.py -v`
Expected: FAIL — module not found

- [ ] **Step 3: Implement page_parser.py**

```python
import json
import logging

from app.config import settings
from app.services.claude_client import ClaudeClient
from app.services.image_preprocessor import preprocess_textbook_page

logger = logging.getLogger(__name__)


class PageParserService:
    def __init__(self):
        self.claude = ClaudeClient()
        self._system_prompt = (settings.prompts_dir / "parse_page.txt").read_text()

    def parse_page(self, image_bytes: bytes) -> dict:
        """Parse a textbook page photo into a list of assignments.

        Args:
            image_bytes: Raw image bytes from the uploaded photo.

        Returns:
            Dict matching the PageScanResponse schema.
        """
        preprocessed = preprocess_textbook_page(image_bytes)
        raw_response = self.claude.send_vision(
            self._system_prompt,
            preprocessed,
            "Please identify all assignments on this textbook page and return structured JSON.",
        )
        # Strip markdown code fences if Claude wraps the response
        cleaned = raw_response.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]
        if cleaned.endswith("```"):
            cleaned = cleaned.rsplit("```", 1)[0]
        cleaned = cleaned.strip()

        parsed = json.loads(cleaned)
        logger.info("Parsed %d assignments from page", len(parsed.get("assignments", [])))
        return parsed
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_page_parser.py -v`
Expected: All 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/page_parser.py backend/tests/test_page_parser.py
git commit -m "feat: add page parser service with Claude Vision"
```

---

### Task 7: Example Generator Service

**Files:**
- Create: `backend/app/services/example_generator.py`
- Create: `backend/tests/test_example_generator.py`

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_example_generator.py`:

```python
import json
from unittest.mock import MagicMock, patch

import pytest

from app.services.example_generator import ExampleGeneratorService


MOCK_RESPONSE = json.dumps({
    "example_problem": "523 + 389 =",
    "steps": [
        {
            "step": 1,
            "instruction": "Stil tallene op efter pladsværdi",
            "visual": "  523\n+ 389\n-----",
            "explanation": "Vi skriver tallene så enerne er under enerne.",
        },
    ],
    "note": "Bemærk at dette er et andet regnestykke end dit — prøv den samme metode med dine tal!",
})


@pytest.fixture
def service():
    with patch("app.services.example_generator.ClaudeClient") as mock_cls:
        mock_client = MagicMock()
        mock_cls.return_value = mock_client
        mock_client.send_text.return_value = MOCK_RESPONSE
        svc = ExampleGeneratorService()
        svc.claude = mock_client
        yield svc


def test_generate_example_returns_steps(service):
    result = service.generate_example(
        assignment_type="addition",
        assignment_topic="three-digit addition with carrying",
        assignment_text="347 + 286 =",
        language="da",
    )
    assert result["example_problem"] == "523 + 389 ="
    assert len(result["steps"]) >= 1
    assert result["steps"][0]["step"] == 1


def test_generate_example_uses_different_numbers(service):
    result = service.generate_example(
        assignment_type="addition",
        assignment_topic="three-digit addition",
        assignment_text="347 + 286 =",
        language="da",
    )
    assert "347" not in result["example_problem"]
    assert "286" not in result["example_problem"]


def test_generate_example_includes_note(service):
    result = service.generate_example(
        assignment_type="addition",
        assignment_topic="addition",
        assignment_text="1 + 1 =",
        language="da",
    )
    assert "note" in result
    assert len(result["note"]) > 0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_example_generator.py -v`
Expected: FAIL — module not found

- [ ] **Step 3: Implement example_generator.py**

```python
import json
import logging

from app.config import settings
from app.services.claude_client import ClaudeClient

logger = logging.getLogger(__name__)


class ExampleGeneratorService:
    def __init__(self):
        self.claude = ClaudeClient()
        self._system_prompt = (settings.prompts_dir / "generate_example.txt").read_text()

    def generate_example(
        self,
        assignment_type: str,
        assignment_topic: str,
        assignment_text: str,
        language: str = "da",
    ) -> dict:
        """Generate a worked example of a similar but different problem.

        Cardinal rule: The example must NEVER use the same numbers as the real assignment.
        """
        user_message = (
            f"Assignment type: {assignment_type}\n"
            f"Assignment topic: {assignment_topic}\n"
            f"Actual assignment (use DIFFERENT numbers): {assignment_text}\n"
            f"Student's language: {language}\n\n"
            f"Create a worked example with different numbers. Return JSON."
        )
        raw = self.claude.send_text(self._system_prompt, user_message)

        cleaned = raw.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]
        if cleaned.endswith("```"):
            cleaned = cleaned.rsplit("```", 1)[0]
        cleaned = cleaned.strip()

        parsed = json.loads(cleaned)
        logger.info("Generated example for %s: %s", assignment_type, parsed.get("example_problem"))
        return parsed
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_example_generator.py -v`
Expected: All 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/example_generator.py backend/tests/test_example_generator.py
git commit -m "feat: add example generator — similar problems, different numbers"
```

---

### Task 8: Work Analyzer Service

**Files:**
- Create: `backend/app/services/work_analyzer.py`
- Create: `backend/tests/test_work_analyzer.py`

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_work_analyzer.py`:

```python
import json
from unittest.mock import MagicMock, patch

import pytest

from app.services.work_analyzer import WorkAnalyzerService


MOCK_ANALYSIS = json.dumps({
    "student_answer": "633",
    "methodology_sound": True,
    "steps_identified": [
        {"step": 1, "description": "Added ones: 7+6=13, wrote 3, carried 1", "correct": True},
        {"step": 2, "description": "Added tens: 4+8+1=13, wrote 3, carried 1", "correct": True},
        {"step": 3, "description": "Added hundreds: 3+2+1=6", "correct": True},
    ],
    "errors": [],
    "correct_elements": ["Carrying technique", "Place value alignment"],
    "methodology_assessment": "Clean, systematic approach.",
    "handwriting_note": "Numbers are well-formed.",
    "confidence": 0.95,
})

MOCK_UNCLEAR = json.dumps({
    "student_answer": "",
    "methodology_sound": False,
    "steps_identified": [],
    "errors": ["unclear_image"],
    "correct_elements": [],
    "methodology_assessment": "Cannot read the handwritten work.",
    "handwriting_note": "Image is too blurry to analyze.",
    "confidence": 0.2,
})


@pytest.fixture
def service():
    with patch("app.services.work_analyzer.ClaudeClient") as mock_cls:
        mock_client = MagicMock()
        mock_cls.return_value = mock_client
        mock_client.send_vision.return_value = MOCK_ANALYSIS
        svc = WorkAnalyzerService()
        svc.claude = mock_client
        yield svc, mock_client


def test_analyze_work_returns_structured_analysis(service):
    svc, _ = service
    result = svc.analyze_work(b"image-bytes", "347 + 286 =", "addition", "three-digit addition")
    assert result["methodology_sound"] is True
    assert result["student_answer"] == "633"
    assert len(result["steps_identified"]) == 3


def test_analyze_work_respects_confidence_threshold(service):
    svc, mock_client = service
    mock_client.send_vision.return_value = MOCK_UNCLEAR
    result = svc.analyze_work(b"blurry-image", "347 + 286 =", "addition", "addition")
    assert result["confidence"] < 0.6
    assert "unclear_image" in result["errors"]


def test_analyze_work_never_includes_correct_answer(service):
    svc, _ = service
    result = svc.analyze_work(b"image", "347 + 286 =", "addition", "addition")
    # The response must NOT have a "correct_answer" field
    assert "correct_answer" not in result
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_work_analyzer.py -v`
Expected: FAIL — module not found

- [ ] **Step 3: Implement work_analyzer.py**

```python
import json
import logging

from app.config import settings
from app.services.claude_client import ClaudeClient
from app.services.image_preprocessor import preprocess_handwritten_work

logger = logging.getLogger(__name__)


class WorkAnalyzerService:
    def __init__(self):
        self.claude = ClaudeClient()
        self._system_prompt = (settings.prompts_dir / "analyze_work.txt").read_text()

    def analyze_work(
        self,
        image_bytes: bytes,
        assignment_text: str,
        assignment_type: str,
        assignment_topic: str,
    ) -> dict:
        """Analyze a photo of handwritten student work.

        Returns structured analysis. Never includes the correct answer.
        """
        preprocessed = preprocess_handwritten_work(image_bytes)
        user_message = (
            f"Assignment: {assignment_text}\n"
            f"Type: {assignment_type}\n"
            f"Topic: {assignment_topic}\n\n"
            f"Please analyze the student's handwritten work in the photo. Return JSON."
        )
        raw = self.claude.send_vision(self._system_prompt, preprocessed, user_message)

        cleaned = raw.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]
        if cleaned.endswith("```"):
            cleaned = cleaned.rsplit("```", 1)[0]
        cleaned = cleaned.strip()

        parsed = json.loads(cleaned)

        # Safety: ensure correct_answer is NEVER in the response
        parsed.pop("correct_answer", None)

        logger.info(
            "Analyzed work for '%s': confidence=%.2f, methodology_sound=%s",
            assignment_text,
            parsed.get("confidence", 0),
            parsed.get("methodology_sound"),
        )
        return parsed
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_work_analyzer.py -v`
Expected: All 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/work_analyzer.py backend/tests/test_work_analyzer.py
git commit -m "feat: add work analyzer — methodology-focused handwriting analysis"
```

---

### Task 9: Feedback Generator Service

**Files:**
- Create: `backend/app/services/feedback_generator.py`
- Create: `backend/tests/test_feedback_generator.py`

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_feedback_generator.py`:

```python
import json
from unittest.mock import MagicMock, patch

import pytest

from app.services.feedback_generator import FeedbackGeneratorService


MOCK_FEEDBACK = json.dumps({
    "feedback_text": "Flot arbejde! Du har stillet tallene pænt op.",
    "tone": "celebratory",
})

MOCK_FOLLOWUP = json.dumps({
    "feedback_text": "Prøv at tænke på det sådan her: hvis du har 347 bolde...",
    "tone": "encouraging",
})

ANALYSIS = {
    "student_answer": "633",
    "methodology_sound": True,
    "steps_identified": [{"step": 1, "description": "Added ones", "correct": True}],
    "errors": [],
    "correct_elements": ["Carrying technique"],
    "methodology_assessment": "Good approach.",
    "confidence": 0.95,
}


@pytest.fixture
def service():
    with patch("app.services.feedback_generator.ClaudeClient") as mock_cls:
        mock_client = MagicMock()
        mock_cls.return_value = mock_client
        mock_client.send_text.return_value = MOCK_FEEDBACK
        svc = FeedbackGeneratorService()
        svc.claude = mock_client
        yield svc, mock_client


def test_generate_feedback_returns_text_and_tone(service):
    svc, _ = service
    result = svc.generate_feedback(
        assignment_text="347 + 286 =",
        analysis=ANALYSIS,
        language="da",
    )
    assert "feedback_text" in result
    assert result["tone"] in ("celebratory", "encouraging", "supportive")


def test_generate_feedback_includes_structured_prompts(service):
    svc, _ = service
    result = svc.generate_feedback(
        assignment_text="347 + 286 =",
        analysis=ANALYSIS,
        language="da",
    )
    assert "structured_prompts" in result
    prompt_ids = [p["id"] for p in result["structured_prompts"]]
    assert "explain_different" in prompt_ids
    assert "try_again" in prompt_ids
    assert "next_assignment" in prompt_ids


def test_generate_followup(service):
    svc, mock_client = service
    mock_client.send_text.return_value = MOCK_FOLLOWUP
    result = svc.generate_followup(
        assignment_text="347 + 286 =",
        previous_feedback="Flot arbejde!",
        action="explain_different",
        language="da",
    )
    assert "feedback_text" in result
    assert len(result["feedback_text"]) > 0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python -m pytest tests/test_feedback_generator.py -v`
Expected: FAIL — module not found

- [ ] **Step 3: Implement feedback_generator.py**

```python
import json
import logging

from app.config import settings
from app.services.claude_client import ClaudeClient

logger = logging.getLogger(__name__)

# Structured prompts for the "work submitted" state.
# Labels are keyed by language. The iOS app renders these as buttons.
STRUCTURED_PROMPTS = {
    "da": [
        {"id": "explain_different", "label": "Forklar på en anden måde"},
        {"id": "another_example", "label": "Vis mig et andet eksempel"},
        {"id": "show_first_step", "label": "Jeg sidder fast — vis mig første skridt"},
        {"id": "what_did_well", "label": "Hvad gjorde jeg godt?"},
        {"id": "try_again", "label": "Jeg vil prøve igen"},
        {"id": "next_assignment", "label": "Næste opgave"},
    ],
    "en": [
        {"id": "explain_different", "label": "Explain in a different way"},
        {"id": "another_example", "label": "Give me another example"},
        {"id": "show_first_step", "label": "I'm stuck — show me the first step"},
        {"id": "what_did_well", "label": "What did I do well?"},
        {"id": "try_again", "label": "I want to try again"},
        {"id": "next_assignment", "label": "Next assignment"},
    ],
}


class FeedbackGeneratorService:
    def __init__(self):
        self.claude = ClaudeClient()
        self._feedback_prompt = (settings.prompts_dir / "give_feedback.txt").read_text()
        self._explain_prompt = (settings.prompts_dir / "explain_method.txt").read_text()

    def generate_feedback(
        self,
        assignment_text: str,
        analysis: dict,
        language: str = "da",
    ) -> dict:
        """Generate kid-friendly, method-focused feedback.

        Never reveals the correct answer.
        """
        user_message = (
            f"Assignment: {assignment_text}\n"
            f"Student's language: {language}\n\n"
            f"Analysis:\n{json.dumps(analysis, indent=2)}\n\n"
            f"Generate warm, method-focused feedback. Return JSON."
        )
        raw = self.claude.send_text(self._feedback_prompt, user_message)
        parsed = self._parse_json(raw)

        # Attach structured prompts for the iOS button bar
        prompts = STRUCTURED_PROMPTS.get(language, STRUCTURED_PROMPTS["en"])
        parsed["structured_prompts"] = prompts

        return parsed

    def generate_followup(
        self,
        assignment_text: str,
        previous_feedback: str,
        action: str,
        language: str = "da",
    ) -> dict:
        """Handle a structured follow-up action.

        Actions: explain_different, another_example, show_first_step, what_did_well, try_again
        """
        user_message = (
            f"Assignment: {assignment_text}\n"
            f"Previous feedback: {previous_feedback}\n"
            f"Student's language: {language}\n"
            f"Action requested: {action}\n\n"
            f"Respond according to the action. Return JSON."
        )
        raw = self.claude.send_text(self._explain_prompt, user_message)
        parsed = self._parse_json(raw)

        prompts = STRUCTURED_PROMPTS.get(language, STRUCTURED_PROMPTS["en"])
        parsed["structured_prompts"] = prompts

        return parsed

    def _parse_json(self, raw: str) -> dict:
        cleaned = raw.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]
        if cleaned.endswith("```"):
            cleaned = cleaned.rsplit("```", 1)[0]
        return json.loads(cleaned.strip())
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_feedback_generator.py -v`
Expected: All 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/feedback_generator.py backend/tests/test_feedback_generator.py
git commit -m "feat: add feedback generator with localized structured prompts"
```

---

### Task 10: API Routers

**Files:**
- Create: `backend/app/routers/health.py`
- Create: `backend/app/routers/pages.py`
- Create: `backend/app/routers/assignments.py`
- Create: `backend/app/routers/submissions.py`
- Create: `backend/app/routers/feedback.py`
- Create: `backend/tests/conftest.py`
- Create: `backend/tests/test_routers.py`

- [ ] **Step 1: Write test fixtures**

Create `backend/tests/conftest.py`:

```python
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session as DBSession, sessionmaker

from app.database import Base, get_db
from app.main import app
from app.models.db import Student


@pytest.fixture
def test_db():
    engine = create_engine("sqlite:///:memory:")
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
```

- [ ] **Step 2: Write router tests**

Create `backend/tests/test_routers.py`:

```python
import json
from unittest.mock import patch, MagicMock
import io
from PIL import Image

import pytest


def _make_test_jpeg() -> bytes:
    img = Image.new("RGB", (100, 100), "white")
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "ok"
    assert "version" in data


@patch("app.routers.pages.PageParserService")
def test_page_scan(mock_parser_cls, client):
    mock_parser = MagicMock()
    mock_parser_cls.return_value = mock_parser
    mock_parser.parse_page.return_value = {
        "assignments": [
            {"id": "1a", "text": "2+3=", "type": "addition",
             "topic": "simple addition", "difficulty_estimate": 1,
             "position_on_page": "top-left"}
        ],
        "page_context": "Chapter 1",
        "suggested_order": ["1a"],
        "suggested_start": "1a",
        "reasoning": "Only one assignment.",
        "detected_language": "da",
    }
    jpeg = _make_test_jpeg()
    resp = client.post("/pages/scan", files={"image": ("page.jpg", jpeg, "image/jpeg")})
    assert resp.status_code == 200
    data = resp.json()
    assert "session_id" in data
    assert len(data["assignments"]) == 1


@patch("app.routers.assignments.ExampleGeneratorService")
def test_get_example_404_for_missing_session(mock_gen_cls, client):
    resp = client.post("/sessions/nonexistent/assignments/1a/example")
    assert resp.status_code == 404


@patch("app.routers.submissions.WorkAnalyzerService")
def test_submit_work(mock_analyzer_cls, client):
    # First create a session by scanning a page
    with patch("app.routers.pages.PageParserService") as mock_parser_cls:
        mock_parser = MagicMock()
        mock_parser_cls.return_value = mock_parser
        mock_parser.parse_page.return_value = {
            "assignments": [
                {"id": "1a", "text": "2+3=", "type": "addition",
                 "topic": "addition", "difficulty_estimate": 1,
                 "position_on_page": "top"}
            ],
            "page_context": "Ch 1",
            "suggested_order": ["1a"],
            "suggested_start": "1a",
            "reasoning": "Simple.",
            "detected_language": "da",
        }
        scan_resp = client.post(
            "/pages/scan", files={"image": ("page.jpg", _make_test_jpeg(), "image/jpeg")}
        )
    session_id = scan_resp.json()["session_id"]
    assignments = scan_resp.json()["assignments"]
    assignment_id = assignments[0]["id"]

    mock_analyzer = MagicMock()
    mock_analyzer_cls.return_value = mock_analyzer
    mock_analyzer.analyze_work.return_value = {
        "student_answer": "5",
        "methodology_sound": True,
        "steps_identified": [{"step": 1, "description": "Added 2+3=5", "correct": True}],
        "errors": [],
        "correct_elements": ["Basic addition"],
        "methodology_assessment": "Correct.",
        "handwriting_note": "Clear.",
        "confidence": 0.95,
    }

    resp = client.post(
        "/submissions/",
        data={"session_id": session_id, "assignment_id": assignment_id},
        files={"image": ("work.jpg", _make_test_jpeg(), "image/jpeg")},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["methodology_sound"] is True
    assert "submission_id" in data
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_routers.py -v`
Expected: FAIL — routers/main not yet created

- [ ] **Step 4: Implement health.py router**

```python
from fastapi import APIRouter

from app.models.schemas import HealthResponse

router = APIRouter()


@router.get("/health", response_model=HealthResponse)
async def health():
    return HealthResponse(status="ok", version="0.1.0")
```

- [ ] **Step 5: Implement pages.py router**

```python
import logging
import os

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.orm import Session as DBSession

from app.config import settings
from app.database import get_db
from app.models.db import Assignment, Session
from app.models.schemas import ErrorResponse, PageScanResponse
from app.services.page_parser import PageParserService

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/pages/scan", response_model=PageScanResponse, responses={422: {"model": ErrorResponse}})
async def scan_page(
    image: UploadFile = File(...),
    db: DBSession = Depends(get_db),
):
    contents = await image.read()
    if len(contents) > settings.max_upload_size:
        raise HTTPException(status_code=400, detail="Image exceeds maximum upload size (10 MB)")

    # Save original image
    os.makedirs(settings.upload_dir, exist_ok=True)

    parser = PageParserService()
    try:
        parsed = parser.parse_page(contents)
    except Exception as e:
        logger.exception("Failed to parse page")
        raise HTTPException(
            status_code=422,
            detail={
                "error": "parse_failed",
                "message": str(e),
                "student_message": "Jeg kan ikke læse siden — prøv at tage et tydeligere billede.",
            },
        )

    # Create session
    session = Session(
        student_id="default",
        page_image_path=f"{settings.upload_dir}/page_{id(contents)}.jpg",
        parsed_assignments=parsed,
        detected_language=parsed.get("detected_language", "da"),
    )
    db.add(session)
    db.commit()
    db.refresh(session)

    # Save original image with session ID
    image_path = f"{settings.upload_dir}/{session.id}_page.jpg"
    with open(image_path, "wb") as f:
        f.write(contents)
    session.page_image_path = image_path
    db.commit()

    # Create assignment records
    for a in parsed.get("assignments", []):
        assignment = Assignment(
            session_id=session.id,
            local_id=a["id"],
            text=a["text"],
            type=a["type"],
            topic=a["topic"],
            difficulty_estimate=a.get("difficulty_estimate", 1),
        )
        db.add(assignment)
    db.commit()

    # Build response — use DB-generated assignment IDs
    db_assignments = db.query(Assignment).filter(Assignment.session_id == session.id).all()
    response_assignments = []
    for db_a in db_assignments:
        # Find matching parsed assignment for position_on_page
        parsed_match = next(
            (pa for pa in parsed["assignments"] if pa["id"] == db_a.local_id),
            {},
        )
        response_assignments.append({
            "id": db_a.id,
            "text": db_a.text,
            "type": db_a.type,
            "topic": db_a.topic,
            "difficulty_estimate": db_a.difficulty_estimate,
            "position_on_page": parsed_match.get("position_on_page", ""),
        })

    return PageScanResponse(
        session_id=session.id,
        assignments=response_assignments,
        page_context=parsed.get("page_context", ""),
        suggested_order=parsed.get("suggested_order", []),
        suggested_start=parsed.get("suggested_start", ""),
        reasoning=parsed.get("reasoning", ""),
        detected_language=session.detected_language,
    )
```

- [ ] **Step 6: Implement assignments.py router**

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from app.database import get_db
from app.models.db import Assignment, Session
from app.models.schemas import ExampleResponse
from app.services.example_generator import ExampleGeneratorService

router = APIRouter()


@router.post(
    "/sessions/{session_id}/assignments/{assignment_id}/example",
    response_model=ExampleResponse,
)
async def generate_example(
    session_id: str,
    assignment_id: str,
    db: DBSession = Depends(get_db),
):
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    assignment = (
        db.query(Assignment)
        .filter(Assignment.id == assignment_id, Assignment.session_id == session_id)
        .first()
    )
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    generator = ExampleGeneratorService()
    result = generator.generate_example(
        assignment_type=assignment.type,
        assignment_topic=assignment.topic,
        assignment_text=assignment.text,
        language=session.detected_language,
    )
    return ExampleResponse(**result)
```

- [ ] **Step 7: Implement submissions.py router**

```python
import logging
import os

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session as DBSession

from app.config import settings
from app.database import get_db
from app.models.db import Assignment, Session, Submission
from app.models.schemas import ErrorResponse, SubmissionResponse
from app.services.work_analyzer import WorkAnalyzerService

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/submissions/", response_model=SubmissionResponse, responses={422: {"model": ErrorResponse}})
async def submit_work(
    session_id: str = Form(...),
    assignment_id: str = Form(...),
    image: UploadFile = File(...),
    db: DBSession = Depends(get_db),
):
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    assignment = (
        db.query(Assignment)
        .filter(Assignment.id == assignment_id, Assignment.session_id == session_id)
        .first()
    )
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found in this session")

    contents = await image.read()
    if len(contents) > settings.max_upload_size:
        raise HTTPException(status_code=400, detail="Image exceeds maximum upload size (10 MB)")

    # Save original image
    os.makedirs(settings.upload_dir, exist_ok=True)

    # Count attempts for this assignment
    attempt_count = (
        db.query(Submission)
        .filter(
            Submission.session_id == session_id,
            Submission.assignment_id == assignment_id,
        )
        .count()
    ) + 1

    # Create submission record
    submission = Submission(
        session_id=session_id,
        assignment_id=assignment_id,
        work_image_path="",  # updated below
        attempt_number=attempt_count,
    )
    db.add(submission)
    db.commit()
    db.refresh(submission)

    image_path = f"{settings.upload_dir}/{submission.id}_work.jpg"
    with open(image_path, "wb") as f:
        f.write(contents)
    submission.work_image_path = image_path
    db.commit()

    # Analyze the work
    analyzer = WorkAnalyzerService()
    try:
        analysis = analyzer.analyze_work(
            image_bytes=contents,
            assignment_text=assignment.text,
            assignment_type=assignment.type,
            assignment_topic=assignment.topic,
        )
    except Exception as e:
        logger.exception("Failed to analyze work")
        raise HTTPException(
            status_code=422,
            detail={
                "error": "analysis_failed",
                "message": str(e),
                "student_message": "Jeg kan ikke helt læse dit svar — prøv at tage et tydeligere billede.",
            },
        )

    # Check confidence threshold
    if analysis.get("confidence", 0) < settings.confidence_threshold:
        raise HTTPException(
            status_code=422,
            detail={
                "error": "unreadable_photo",
                "message": "Confidence below threshold",
                "student_message": "Jeg kan ikke helt læse dit arbejde — kan du prøve at tage et tydeligere billede? Sørg for godt lys og hold iPad'en rolig.",
            },
        )

    # Store analysis
    submission.analysis = analysis
    assignment.status = "in_progress"
    db.commit()

    return SubmissionResponse(
        submission_id=submission.id,
        assignment_id=assignment_id,
        session_id=session_id,
        **{k: v for k, v in analysis.items() if k in SubmissionResponse.model_fields},
    )
```

- [ ] **Step 8: Implement feedback.py router**

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from app.database import get_db
from app.models.db import Assignment, Submission
from app.models.schemas import FeedbackRequest, FeedbackResponse, FollowupRequest
from app.services.feedback_generator import FeedbackGeneratorService

router = APIRouter()

VALID_ACTIONS = {"explain_different", "another_example", "show_first_step", "what_did_well", "try_again"}


@router.post("/feedback/", response_model=FeedbackResponse)
async def generate_feedback(
    request: FeedbackRequest,
    db: DBSession = Depends(get_db),
):
    submission = db.query(Submission).filter(Submission.id == request.submission_id).first()
    if not submission:
        raise HTTPException(status_code=404, detail="Submission not found")

    assignment = db.query(Assignment).filter(Assignment.id == submission.assignment_id).first()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    if not submission.analysis:
        raise HTTPException(status_code=400, detail="Submission has not been analyzed yet")

    generator = FeedbackGeneratorService()
    result = generator.generate_feedback(
        assignment_text=assignment.text,
        analysis=submission.analysis,
        language=request.language,
    )

    # Store feedback text on submission record
    submission.feedback_text = result["feedback_text"]
    db.commit()

    return FeedbackResponse(**result)


@router.post("/feedback/{submission_id}/followup", response_model=FeedbackResponse)
async def followup(
    submission_id: str,
    request: FollowupRequest,
    db: DBSession = Depends(get_db),
):
    if request.action not in VALID_ACTIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid action '{request.action}'. Valid: {', '.join(sorted(VALID_ACTIONS))}",
        )

    submission = db.query(Submission).filter(Submission.id == submission_id).first()
    if not submission:
        raise HTTPException(status_code=404, detail="Submission not found")

    assignment = db.query(Assignment).filter(Assignment.id == submission.assignment_id).first()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    # Determine language from session
    from app.models.db import Session
    session = db.query(Session).filter(Session.id == submission.session_id).first()
    language = session.detected_language if session else "da"

    generator = FeedbackGeneratorService()
    result = generator.generate_followup(
        assignment_text=assignment.text,
        previous_feedback=submission.feedback_text or "",
        action=request.action,
        language=language,
    )

    return FeedbackResponse(**result)
```

- [ ] **Step 9: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_routers.py -v`
Expected: All 4 tests PASS

- [ ] **Step 10: Commit**

```bash
git add backend/app/routers/ backend/tests/conftest.py backend/tests/test_routers.py
git commit -m "feat: add all API routers — pages, assignments, submissions, feedback"
```

---

### Task 11: FastAPI App and Bonjour

**Files:**
- Create: `backend/app/main.py`

- [ ] **Step 1: Implement main.py**

```python
import logging
import socket
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import Base, engine
from app.routers import assignments, feedback, health, pages, submissions

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup: create tables, register Bonjour. Shutdown: unregister."""
    # Create database tables
    Base.metadata.create_all(bind=engine)
    logger.info("Database tables created")

    # Create default student for MVP
    from sqlalchemy.orm import Session as DBSession
    from app.models.db import Student
    with DBSession(engine) as db:
        if not db.query(Student).filter(Student.id == "default").first():
            db.add(Student(id="default", name="Default Student", language="da"))
            db.commit()
            logger.info("Created default student")

    # Register Bonjour/mDNS service
    zeroconf = None
    try:
        from zeroconf import ServiceInfo, Zeroconf

        hostname = socket.gethostname()
        local_ip = socket.gethostbyname(hostname)
        info = ServiceInfo(
            "_kvante._tcp.local.",
            f"Kvante Math Assistant._kvante._tcp.local.",
            addresses=[socket.inet_aton(local_ip)],
            port=settings.port,
            properties={"version": "0.1.0"},
        )
        zeroconf = Zeroconf()
        zeroconf.register_service(info)
        logger.info("Bonjour service registered: _kvante._tcp on port %d", settings.port)
    except Exception as e:
        logger.warning("Bonjour registration failed (non-fatal): %s", e)

    yield

    # Shutdown
    if zeroconf:
        zeroconf.unregister_all_services()
        zeroconf.close()
        logger.info("Bonjour service unregistered")


app = FastAPI(
    title="Kvante",
    description="Math learning assistant for primary school students",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS — allow all origins for MVP (local network only)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(health.router)
app.include_router(pages.router)
app.include_router(assignments.router)
app.include_router(submissions.router)
app.include_router(feedback.router)
```

- [ ] **Step 2: Verify the app starts**

Run:
```bash
cd backend
echo "KVANTE_ANTHROPIC_API_KEY=sk-test-placeholder" > .env
python -c "from app.main import app; print('App created successfully:', app.title)"
```
Expected: `App created successfully: Kvante`

- [ ] **Step 3: Run ALL tests**

Run: `cd backend && python -m pytest tests/ -v --tb=short`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add backend/app/main.py backend/.env
git commit -m "feat: add FastAPI app with CORS and Bonjour registration"
```

Note: Do NOT commit the `.env` file with a real API key. The placeholder is fine for testing. Add the real key manually.

---

### Task 12: Full Integration Smoke Test

**Files:**
- Create: `backend/tests/test_integration.py`

This test verifies the complete flow with mocked Claude responses: scan page → pick assignment → get example → submit work → get feedback → followup.

- [ ] **Step 1: Write integration test**

Create `backend/tests/test_integration.py`:

```python
"""Full flow integration test with mocked Claude API.

Workflow: scan page → pick assignment → get example → submit work → get feedback → followup
"""
import io
import json
from unittest.mock import patch, MagicMock

from PIL import Image
import pytest

from app.main import app


def _jpeg() -> bytes:
    img = Image.new("RGB", (200, 200), "white")
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


PARSED_PAGE = json.dumps({
    "assignments": [
        {"id": "1a", "text": "25 + 17 =", "type": "addition",
         "topic": "two-digit addition with carrying", "difficulty_estimate": 1,
         "position_on_page": "top-left"},
        {"id": "1b", "text": "43 - 28 =", "type": "subtraction",
         "topic": "two-digit subtraction with borrowing", "difficulty_estimate": 2,
         "position_on_page": "top-right"},
    ],
    "page_context": "Chapter 1: Addition and subtraction",
    "suggested_order": ["1a", "1b"],
    "suggested_start": "1a",
    "reasoning": "1a is simpler.",
    "detected_language": "da",
})

EXAMPLE = json.dumps({
    "example_problem": "38 + 24 =",
    "steps": [
        {"step": 1, "instruction": "Stil tallene op", "visual": " 38\n+24\n---",
         "explanation": "Enerne under enerne."},
    ],
    "note": "Bemærk: dette er andre tal end din opgave!",
})

ANALYSIS = json.dumps({
    "student_answer": "42",
    "methodology_sound": True,
    "steps_identified": [
        {"step": 1, "description": "Added ones: 5+7=12, wrote 2, carried 1", "correct": True},
        {"step": 2, "description": "Added tens: 2+1+1=4", "correct": True},
    ],
    "errors": [],
    "correct_elements": ["Carrying", "Place value"],
    "methodology_assessment": "Perfect method.",
    "handwriting_note": "Clear.",
    "confidence": 0.95,
})

FEEDBACK = json.dumps({
    "feedback_text": "Fantastisk arbejde! Du har mestret mente-teknikken perfekt.",
    "tone": "celebratory",
})

FOLLOWUP = json.dumps({
    "feedback_text": "Du stillede tallene flot op og huskede at gemme mente — det er det vigtigste!",
    "tone": "celebratory",
})


def test_full_workflow(client):
    """Test the complete Kvante workflow end-to-end."""

    # Mock all Claude calls
    with patch("app.services.page_parser.ClaudeClient") as mock_parser_client, \
         patch("app.services.example_generator.ClaudeClient") as mock_example_client, \
         patch("app.services.work_analyzer.ClaudeClient") as mock_analyzer_client, \
         patch("app.services.feedback_generator.ClaudeClient") as mock_feedback_client:

        # Configure mock returns
        mock_parser_client.return_value.send_vision.return_value = PARSED_PAGE
        mock_example_client.return_value.send_text.return_value = EXAMPLE
        mock_analyzer_client.return_value.send_vision.return_value = ANALYSIS
        mock_feedback_client.return_value.send_text.return_value = FEEDBACK

        # 1. Scan page
        resp = client.post("/pages/scan", files={"image": ("page.jpg", _jpeg(), "image/jpeg")})
        assert resp.status_code == 200, resp.text
        page_data = resp.json()
        session_id = page_data["session_id"]
        assert len(page_data["assignments"]) == 2
        assignment_id = page_data["assignments"][0]["id"]

        # 2. Get example for first assignment
        resp = client.post(f"/sessions/{session_id}/assignments/{assignment_id}/example")
        assert resp.status_code == 200, resp.text
        example_data = resp.json()
        assert example_data["example_problem"] == "38 + 24 ="
        assert len(example_data["steps"]) >= 1

        # 3. Submit handwritten work
        resp = client.post(
            "/submissions/",
            data={"session_id": session_id, "assignment_id": assignment_id},
            files={"image": ("work.jpg", _jpeg(), "image/jpeg")},
        )
        assert resp.status_code == 200, resp.text
        submission_data = resp.json()
        submission_id = submission_data["submission_id"]
        assert submission_data["methodology_sound"] is True

        # 4. Get feedback
        resp = client.post("/feedback/", json={"submission_id": submission_id, "language": "da"})
        assert resp.status_code == 200, resp.text
        feedback_data = resp.json()
        assert "Fantastisk" in feedback_data["feedback_text"]
        assert len(feedback_data["structured_prompts"]) == 6
        prompt_ids = [p["id"] for p in feedback_data["structured_prompts"]]
        assert "explain_different" in prompt_ids
        assert "next_assignment" in prompt_ids

        # 5. Followup — "What did I do well?"
        mock_feedback_client.return_value.send_text.return_value = FOLLOWUP
        resp = client.post(
            f"/feedback/{submission_id}/followup",
            json={"action": "what_did_well"},
        )
        assert resp.status_code == 200, resp.text
        followup_data = resp.json()
        assert len(followup_data["feedback_text"]) > 0

    # 6. Health check
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"
```

- [ ] **Step 2: Run integration test**

Run: `cd backend && python -m pytest tests/test_integration.py -v`
Expected: PASS — full workflow completes

- [ ] **Step 3: Run ALL tests to verify nothing broke**

Run: `cd backend && python -m pytest tests/ -v --tb=short`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add backend/tests/test_integration.py
git commit -m "feat: add full workflow integration test — page scan to feedback"
```

---

### Task 13: Final Cleanup and Documentation

**Files:**
- Modify: `backend/requirements.txt` (if any missing deps discovered during testing)
- Create: `backend/.env.example` (already exists, verify)

- [ ] **Step 1: Verify the server starts with real config**

Run:
```bash
cd backend
# Copy .env.example and add real API key
cp .env.example .env
# Edit .env with real KVANTE_ANTHROPIC_API_KEY
uvicorn app.main:app --host 0.0.0.0 --port 8000
```
Expected: Server starts, logs "Bonjour service registered", accessible at `http://localhost:8000/health`

- [ ] **Step 2: Test health endpoint manually**

Run: `curl http://localhost:8000/health`
Expected: `{"status":"ok","version":"0.1.0"}`

- [ ] **Step 3: Run final full test suite**

Run: `cd backend && python -m pytest tests/ -v`
Expected: All tests PASS

- [ ] **Step 4: Commit any final fixes**

```bash
git add -A backend/
git commit -m "chore: finalize Phase 1 backend — all services, routers, and tests"
```
