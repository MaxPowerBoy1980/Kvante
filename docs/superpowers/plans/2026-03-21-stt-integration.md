# STT Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `POST /stt` endpoint that converts Danish speech to text via Whisper, then matches the transcription against available feedback actions using the existing AI client.

**Architecture:** Singleton `STTService` loaded eagerly in `lifespan()` when enabled. The service wraps `faster-whisper` for transcription and delegates action matching to the existing `AIClient`. The router is always registered but returns 503 when STT is disabled.

**Tech Stack:** faster-whisper (CTranslate2), existing Gemini/Claude AI client, FastAPI

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `backend/app/config.py` | Modify | Add `stt_enabled`, `stt_model`, `stt_max_duration`, `stt_language` |
| `backend/app/services/stt_service.py` | Create | `STTService` class: transcribe audio, match against actions |
| `backend/app/prompts/match_action.txt` | Create | System prompt for AI action matching |
| `backend/app/models/schemas.py` | Modify | Add `STTResponse` schema |
| `backend/app/routers/stt.py` | Create | `POST /stt` endpoint |
| `backend/app/main.py` | Modify | Register router, load STT in lifespan |
| `backend/requirements.txt` | Modify | Add `faster-whisper` |
| `backend/tests/test_stt_service.py` | Create | Unit tests for STTService |
| `backend/tests/test_stt_router.py` | Create | Router integration tests |

---

### Task 1: Config additions

**Files:**
- Modify: `backend/app/config.py:5-21`
- Test: `backend/tests/test_stt_router.py` (tested implicitly via router tests)

- [ ] **Step 1: Add STT settings to config**

```python
# Add after line 18 (log_dir) in Settings class:
    stt_enabled: bool = False
    stt_model: str = "tiny"
    stt_max_duration: int = 5
    stt_language: str = "da"
```

- [ ] **Step 2: Verify config loads**

Run: `cd backend && .venv/bin/python -c "from app.config import settings; print(settings.stt_enabled, settings.stt_model)"`
Expected: `False tiny`

- [ ] **Step 3: Commit**

```bash
git add backend/app/config.py
git commit -m "feat(stt): add STT config settings (disabled by default)"
```

---

### Task 2: Response schema

**Files:**
- Modify: `backend/app/models/schemas.py`

- [ ] **Step 1: Add STTResponse to schemas.py**

Add after the `HealthResponse` class:

```python
class STTResponse(BaseModel):
    transcription: str
    matched_action: str | None = None
    confidence: float = 0.0
```

- [ ] **Step 2: Verify schema loads**

Run: `cd backend && .venv/bin/python -c "from app.models.schemas import STTResponse; print(STTResponse(transcription='test', matched_action='explain_different', confidence=0.9))"`
Expected: prints the model instance

- [ ] **Step 3: Commit**

```bash
git add backend/app/models/schemas.py
git commit -m "feat(stt): add STTResponse schema"
```

---

### Task 3: Action matching prompt

**Files:**
- Create: `backend/app/prompts/match_action.txt`

- [ ] **Step 1: Create the match_action prompt**

```text
Du er en hjælper der matcher en elevs talte besked med den rigtige handling.

Eleven har sagt noget, og du skal finde ud af hvilken af de tilgængelige handlinger eleven mener.

## Input
- "transcription": Hvad eleven sagde (transskriberet fra tale)
- "available_actions": Liste af handlinger med id og label

## Regler
- Match elevens intention, ikke ordret tekst. "sig det igen" = "Forklar på en anden måde"
- Hvis ingen handling passer, returner null
- Vær liberal i matchingen — børn formulerer sig upræcist

## Output
Returner KUN valid JSON, ingen markdown, ingen forklaring:

{
  "matched_action": "action_id eller null",
  "confidence": 0.0-1.0
}
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/prompts/match_action.txt
git commit -m "feat(stt): add action matching system prompt"
```

---

### Task 4: STT Service — transcription

**Files:**
- Create: `backend/app/services/stt_service.py`
- Create: `backend/tests/test_stt_service.py`

- [ ] **Step 1: Write failing test for transcribe**

Create `backend/tests/test_stt_service.py`:

```python
import json

import pytest
from pathlib import Path
from unittest.mock import patch, MagicMock


def _make_stt_service():
    """Helper to create STTService with mocked Whisper and prompt file."""
    with patch("app.services.stt_service.WhisperModel"), \
         patch.object(Path, "read_text", return_value="mock prompt"):
        from app.services.stt_service import STTService
        return STTService(model_name="tiny")


class TestSTTServiceTranscribe:
    def test_transcribe_returns_text(self):
        """transcribe() should return the concatenated text from Whisper segments."""
        mock_segment = MagicMock()
        mock_segment.text = " hej med dig"

        service = _make_stt_service()
        service._model.transcribe.return_value = (
            [mock_segment],
            MagicMock(language="da"),
        )
        result = service.transcribe(b"fake-audio-bytes")

        assert result == "hej med dig"

    def test_transcribe_joins_multiple_segments(self):
        """transcribe() should join text from multiple Whisper segments."""
        seg1 = MagicMock()
        seg1.text = " forklar det"
        seg2 = MagicMock()
        seg2.text = " på en anden måde"

        service = _make_stt_service()
        service._model.transcribe.return_value = (
            [seg1, seg2],
            MagicMock(language="da"),
        )
        result = service.transcribe(b"fake-audio-bytes")

        assert result == "forklar det på en anden måde"

    def test_transcribe_empty_audio_returns_empty(self):
        """transcribe() should return empty string for silent audio."""
        service = _make_stt_service()
        service._model.transcribe.return_value = (
            [],
            MagicMock(language="da"),
        )
        result = service.transcribe(b"fake-audio-bytes")

        assert result == ""
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && .venv/bin/python -m pytest tests/test_stt_service.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'app.services.stt_service'`

- [ ] **Step 3: Implement STTService with transcribe()**

Create `backend/app/services/stt_service.py`:

```python
import json
import logging
import tempfile
import time

from faster_whisper import WhisperModel

from app.config import settings

logger = logging.getLogger(__name__)


class STTService:
    def __init__(self, model_name: str = "tiny"):
        logger.info("Loading Whisper model: %s", model_name)
        start = time.time()
        self._model = WhisperModel(model_name, device="cpu", compute_type="int8")
        self._match_prompt = (settings.prompts_dir / "match_action.txt").read_text()
        elapsed = time.time() - start
        logger.info("Whisper model loaded in %.1fs", elapsed)

    def transcribe(self, audio_bytes: bytes) -> str:
        """Transcribe audio bytes to Danish text."""
        start = time.time()
        with tempfile.NamedTemporaryFile(suffix=".m4a", delete=True) as f:
            f.write(audio_bytes)
            f.flush()
            segments, info = self._model.transcribe(
                f.name,
                language=settings.stt_language,
                beam_size=5,
            )
            text = "".join(seg.text for seg in segments).strip()

        elapsed = time.time() - start
        logger.info("Transcribed %d bytes in %.1fs: '%s'", len(audio_bytes), elapsed, text[:100])
        return text
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && .venv/bin/python -m pytest tests/test_stt_service.py::TestSTTServiceTranscribe -v`
Expected: 3 PASSED

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/stt_service.py backend/tests/test_stt_service.py
git commit -m "feat(stt): add STTService with transcribe method"
```

---

### Task 5: STT Service — action matching

**Files:**
- Modify: `backend/app/services/stt_service.py`
- Modify: `backend/tests/test_stt_service.py`

- [ ] **Step 1: Write failing test for match_action**

Add to `backend/tests/test_stt_service.py`:

```python
import json


class TestSTTServiceMatchAction:
    def test_match_action_returns_result(self):
        """match_action() should return matched action from AI response."""
        mock_ai = MagicMock()
        mock_ai.send_text.return_value = json.dumps({
            "matched_action": "explain_different",
            "confidence": 0.9,
        })

        available_actions = [
            {"id": "explain_different", "label": "Forklar på en anden måde"},
            {"id": "try_again", "label": "Jeg vil prøve igen"},
        ]

        service = _make_stt_service()
        result = service.match_action(
            "sig det på en anden måde", available_actions, mock_ai
        )

        assert result["matched_action"] == "explain_different"
        assert result["confidence"] == 0.9

    def test_match_action_low_confidence_returns_none(self):
        """match_action() should return None when confidence is below threshold."""
        mock_ai = MagicMock()
        mock_ai.send_text.return_value = json.dumps({
            "matched_action": "try_again",
            "confidence": 0.3,
        })

        available_actions = [
            {"id": "explain_different", "label": "Forklar på en anden måde"},
            {"id": "try_again", "label": "Jeg vil prøve igen"},
        ]

        service = _make_stt_service()
        result = service.match_action(
            "øhm hvad", available_actions, mock_ai
        )

        assert result["matched_action"] is None

    def test_match_action_ai_failure_returns_none(self):
        """match_action() should return None gracefully when AI fails."""
        mock_ai = MagicMock()
        mock_ai.send_text.side_effect = Exception("API error")

        available_actions = [
            {"id": "explain_different", "label": "Forklar på en anden måde"},
        ]

        service = _make_stt_service()
        result = service.match_action(
            "forklar det", available_actions, mock_ai
        )

        assert result["matched_action"] is None
        assert result["confidence"] == 0.0
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && .venv/bin/python -m pytest tests/test_stt_service.py::TestSTTServiceMatchAction -v`
Expected: FAIL — `AttributeError: 'STTService' object has no attribute 'match_action'`

- [ ] **Step 3: Implement match_action()**

Add method to `STTService` class in `backend/app/services/stt_service.py` (note: `import json` and `self._match_prompt` are already present from Task 4):

```python
# Add method:
    def match_action(
        self,
        transcription: str,
        available_actions: list[dict],
        ai_client,
    ) -> dict:
        """Match transcription against available actions using AI."""
        user_message = json.dumps({
            "transcription": transcription,
            "available_actions": available_actions,
        }, ensure_ascii=False)

        try:
            start = time.time()
            raw = ai_client.send_text(self._match_prompt, user_message)
            elapsed = time.time() - start

            cleaned = raw.strip()
            if cleaned.startswith("```"):
                cleaned = cleaned.split("\n", 1)[1]
            if cleaned.endswith("```"):
                cleaned = cleaned.rsplit("```", 1)[0]
            result = json.loads(cleaned.strip())

            confidence = result.get("confidence", 0.0)
            matched = result.get("matched_action")
            if confidence < settings.confidence_threshold:
                matched = None

            logger.info(
                "Action match in %.1fs: '%s' → %s (confidence=%.2f)",
                elapsed, transcription, matched, confidence,
            )
            return {
                "matched_action": matched,
                "confidence": confidence,
            }
        except Exception as e:
            logger.warning("Action matching failed: %s", e)
            return {"matched_action": None, "confidence": 0.0}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && .venv/bin/python -m pytest tests/test_stt_service.py -v`
Expected: 6 PASSED

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/stt_service.py backend/tests/test_stt_service.py
git commit -m "feat(stt): add action matching to STTService"
```

---

### Task 6: STT Router

**Files:**
- Create: `backend/app/routers/stt.py`
- Create: `backend/tests/test_stt_router.py`

- [ ] **Step 1: Write failing tests for the router**

Create `backend/tests/test_stt_router.py`:

```python
import json
from unittest.mock import patch, MagicMock

import pytest


def test_stt_disabled_returns_503(client):
    """When STT is disabled, endpoint should return 503 with fallback flag."""
    client.app.state.stt_service = None
    resp = client.post(
        "/stt",
        data={"submission_id": "test-sub-id"},
        files={"audio": ("test.m4a", b"fake-audio", "audio/mp4")},
    )
    assert resp.status_code == 503
    data = resp.json()
    assert data["error"] == "STT disabled"
    assert data["fallback"] is True


def test_stt_returns_transcription_and_match(client, test_db):
    """When STT is enabled, endpoint should transcribe and match action."""
    from app.models.db import Assignment, Session, Submission

    # Create test data
    session = Session(id="s1", student_id="default", page_image_path="/tmp/test.jpg",
                      detected_language="da")
    test_db.add(session)
    assignment = Assignment(id="a1", session_id="s1", local_id="1a",
                            text="2+3=", type="addition", topic="addition")
    test_db.add(assignment)
    submission = Submission(id="sub1", session_id="s1", assignment_id="a1",
                            work_image_path="/tmp/work.jpg",
                            analysis={"steps": []},
                            feedback_text="Godt arbejde!")
    test_db.add(submission)
    test_db.commit()

    mock_stt = MagicMock()
    mock_stt.transcribe.return_value = "forklar det på en anden måde"
    mock_stt.match_action.return_value = {
        "matched_action": "explain_different",
        "confidence": 0.9,
    }
    client.app.state.stt_service = mock_stt

    resp = client.post(
        "/stt",
        data={"submission_id": "sub1"},
        files={"audio": ("test.m4a", b"fake-audio", "audio/mp4")},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["transcription"] == "forklar det på en anden måde"
    assert data["matched_action"] == "explain_different"
    assert data["confidence"] == 0.9
    assert "X-STT-Latency-Ms" in resp.headers


def test_stt_submission_not_found_returns_404(client):
    """Should return 404 if submission_id doesn't exist."""
    mock_stt = MagicMock()
    client.app.state.stt_service = mock_stt

    resp = client.post(
        "/stt",
        data={"submission_id": "nonexistent"},
        files={"audio": ("test.m4a", b"fake-audio", "audio/mp4")},
    )
    assert resp.status_code == 404


def test_stt_audio_too_large_returns_400(client):
    """Should reject audio files over 500KB."""
    mock_stt = MagicMock()
    client.app.state.stt_service = mock_stt

    large_audio = b"x" * (512 * 1024)  # 512 KB
    resp = client.post(
        "/stt",
        data={"submission_id": "sub1"},
        files={"audio": ("test.m4a", large_audio, "audio/mp4")},
    )
    assert resp.status_code == 400
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && .venv/bin/python -m pytest tests/test_stt_router.py -v`
Expected: FAIL — `ModuleNotFoundError` or route not found

- [ ] **Step 3: Implement the STT router**

Create `backend/app/routers/stt.py`:

```python
import logging
import time

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session as DBSession

from app.config import settings
from app.database import get_db
from app.models.db import Submission, Session
from app.models.schemas import STTResponse
from app.services.ai_client import get_ai_client
from app.services.feedback_generator import STRUCTURED_PROMPTS

logger = logging.getLogger(__name__)
router = APIRouter()

# Actions that can be matched via STT (excludes next_assignment which is navigation-only)
VALID_STT_ACTIONS = {"explain_different", "another_example", "show_first_step", "what_did_well", "try_again"}
MAX_AUDIO_SIZE = 500 * 1024  # 500 KB (~5 sec AAC)


@router.post("/stt", response_model=STTResponse)
async def speech_to_text(
    request: Request,
    audio: UploadFile = File(...),
    submission_id: str = Form(...),
    db: DBSession = Depends(get_db),
):
    stt_service = request.app.state.stt_service
    if stt_service is None:
        return JSONResponse(
            status_code=503,
            content={"error": "STT disabled", "fallback": True},
        )

    audio_bytes = await audio.read()
    if len(audio_bytes) > MAX_AUDIO_SIZE:
        raise HTTPException(status_code=400, detail="Audio file too large (max 500 KB)")

    submission = db.query(Submission).filter(Submission.id == submission_id).first()
    if not submission:
        raise HTTPException(status_code=404, detail="Submission not found")

    session = db.query(Session).filter(Session.id == submission.session_id).first()
    language = session.detected_language if session else "da"

    start = time.time()

    try:
        transcription = stt_service.transcribe(audio_bytes)
    except Exception as e:
        logger.exception("Whisper transcription failed")
        return JSONResponse(
            status_code=503,
            content={"error": "Transcription failed", "fallback": True},
        )

    # Get available actions filtered to valid STT actions
    all_prompts = STRUCTURED_PROMPTS.get(language, STRUCTURED_PROMPTS["en"])
    available_actions = [p for p in all_prompts if p["id"] in VALID_STT_ACTIONS]

    ai_client = get_ai_client()
    match_result = stt_service.match_action(transcription, available_actions, ai_client)

    elapsed_ms = int((time.time() - start) * 1000)
    logger.info("STT total: %dms, transcription='%s', action=%s",
                elapsed_ms, transcription, match_result["matched_action"])

    return JSONResponse(
        status_code=200,
        content=STTResponse(
            transcription=transcription,
            matched_action=match_result["matched_action"],
            confidence=match_result["confidence"],
        ).model_dump(),
        headers={"X-STT-Latency-Ms": str(elapsed_ms)},
    )
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && .venv/bin/python -m pytest tests/test_stt_router.py -v`
Expected: 4 PASSED

- [ ] **Step 5: Commit**

```bash
git add backend/app/routers/stt.py backend/tests/test_stt_router.py
git commit -m "feat(stt): add POST /stt router with transcription and action matching"
```

---

### Task 7: Wire up lifespan and register router

**Files:**
- Modify: `backend/app/main.py:11,19-62,86-90`

- [ ] **Step 1: Add import and router registration**

In `backend/app/main.py`:

Add to imports (line 11):
```python
from app.routers import assignments, feedback, health, pages, submissions, stt
```

Add router registration after line 90:
```python
app.include_router(stt.router)
```

- [ ] **Step 2: Add STT loading to lifespan**

In `lifespan()`, after the default student creation block (after line 37) and before the Bonjour block:

```python
    stt_service = None
    if settings.stt_enabled:
        try:
            from app.services.stt_service import STTService
            stt_service = STTService(model_name=settings.stt_model)
            logger.info("STT loaded: model=%s, language=%s", settings.stt_model, settings.stt_language)
        except Exception as e:
            logger.warning("STT loading failed (non-fatal): %s", e)
    app.state.stt_service = stt_service
```

- [ ] **Step 3: Run all tests to verify nothing is broken**

Run: `cd backend && .venv/bin/python -m pytest tests/ -v --ignore=tests/test_integration.py`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add backend/app/main.py
git commit -m "feat(stt): register STT router and load model in lifespan"
```

---

### Task 8: Add dependency and final verification

**Files:**
- Modify: `backend/requirements.txt`

- [ ] **Step 1: Add faster-whisper to requirements.txt**

Add after the last line:
```
faster-whisper==1.1.0
```

- [ ] **Step 2: Install the dependency**

Run: `cd backend && .venv/bin/pip install faster-whisper==1.1.0`

- [ ] **Step 3: Run full test suite**

Run: `cd backend && .venv/bin/python -m pytest tests/ -v --ignore=tests/test_integration.py`
Expected: All tests PASS

- [ ] **Step 4: Smoke test — disabled mode**

Run: `cd backend && .venv/bin/python -c "from app.config import settings; print('stt_enabled:', settings.stt_enabled)"`
Expected: `stt_enabled: False`

Run: `cd backend && KVANTE_STT_ENABLED=false .venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8001 &`
Wait 3 seconds, then:
Run: `curl -s -X POST http://localhost:8001/stt -F "audio=@/dev/null" -F "submission_id=test" | python3 -m json.tool`
Expected: `{"error": "STT disabled", "fallback": true}` with status 503

Kill the test server after.

- [ ] **Step 5: Commit and push**

```bash
git add backend/requirements.txt
git commit -m "feat(stt): add faster-whisper dependency"
git push
```
