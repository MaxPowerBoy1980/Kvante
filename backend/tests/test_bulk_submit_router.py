"""Router integration tests for POST /sessions/{id}/bulk-submit (Pakke 4).

Python 3.14 + SQLAlchemy 2.0.36 have a Union.__getitem__ incompatibility that
prevents importing any module that touches app.models.db (SQLAlchemy metaclass
crashes at class-definition time).

Workaround: inject fake module stubs into sys.modules BEFORE any app imports
happen in this file. The stubs provide plain classes that the router can use
for isinstance-routing in the mocked DB, while never triggering SQLAlchemy.
"""

import asyncio
import json
import sys
from unittest.mock import MagicMock, patch

import pytest

# ---------------------------------------------------------------------------
# sys.modules stubs — must happen before any app.* import
# ---------------------------------------------------------------------------

# The router does things like: db.query(Session).filter(Session.id == x)
# Session.id must be an attribute that can be accessed on the class-level stub
# without crashing. We use MagicMock() objects (not classes) as model stubs —
# they support any attribute access. The _build_db helper uses `model is _FakeXxx`
# for identity-based routing.
_FakeSession = MagicMock(name="Session")
_FakeAssignment = MagicMock(name="Assignment")
_FakeScan = MagicMock(name="Scan")
_FakeSubmission = MagicMock(name="Submission")

_fake_db_module = MagicMock()
_fake_db_module.Session = _FakeSession
_fake_db_module.Assignment = _FakeAssignment
_fake_db_module.Scan = _FakeScan
_fake_db_module.Submission = _FakeSubmission

sys.modules.setdefault("app.models.db", _fake_db_module)
sys.modules.setdefault("app.database", MagicMock())

# Now safe to import the router (it will use the stub models)
from app.routers.bulk_submit import bulk_submit  # noqa: E402


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_upload_file(content: bytes, filename: str = "page.jpg"):
    """Build a minimal async-readable UploadFile mock."""
    from fastapi import UploadFile
    upload = MagicMock(spec=UploadFile)
    upload.filename = filename
    upload.size = len(content)

    async def _read():
        return content

    upload.read = _read
    return upload


def _make_mock_assignment(id, text, correct_answer, position=0, status="not_started"):
    a = MagicMock()
    a.id = id
    a.text = text
    a.correct_answer = correct_answer
    a.position = position
    a.status = status
    return a


def _make_mock_session(id="sess-1", student_id="default"):
    s = MagicMock()
    s.id = id
    s.student_id = student_id
    return s


def _ai_response_json(matches: list) -> str:
    return json.dumps({"matches": matches})


def _build_db(mock_session, assignments, submission_count=0):
    """Build a DB mock that routes db.query(Model) calls correctly."""
    db = MagicMock()

    def query_side_effect(model):
        inner = MagicMock()
        f = MagicMock()
        inner.filter.return_value = f
        o = MagicMock()
        f.order_by.return_value = o

        if model is _FakeSession:
            f.first.return_value = mock_session
        elif model is _FakeAssignment:
            o.all.return_value = assignments
        elif model is _FakeSubmission:
            f.count.return_value = submission_count

        return inner

    db.query.side_effect = query_side_effect
    db.add.return_value = None
    db.commit.return_value = None
    db.refresh.side_effect = lambda obj: setattr(obj, "id", "auto-id")
    return db


# ---------------------------------------------------------------------------
# Test 1: Successful bulk submit — correct + incorrect counts
# ---------------------------------------------------------------------------

def test_bulk_submit_correct_and_incorrect():
    """Bulk submit with one correct and one incorrect answer returns proper counts."""
    mock_session = _make_mock_session()
    a1 = _make_mock_assignment("a1", "34 + 67", "101", position=0)
    a2 = _make_mock_assignment("a2", "245 + 378", "623", position=1)
    db = _build_db(mock_session, [a1, a2])

    ai_matches = [
        {"assignment_index": 0, "student_answer": "101", "confidence": 0.95,
         "page_index": 0, "error_type": None, "error_description": None},
        {"assignment_index": 1, "student_answer": "613", "confidence": 0.88,
         "page_index": 0, "error_type": "procedural", "error_description": "Mente-fejl"},
    ]

    with (
        patch("app.routers.bulk_submit.get_ai_client") as mock_get_ai,
        patch("app.routers.bulk_submit.update_streak"),
        patch("builtins.open", MagicMock()),
        patch("os.makedirs", MagicMock()),
    ):
        mock_ai = MagicMock()
        mock_ai.send_vision_multi.return_value = _ai_response_json(ai_matches)
        mock_get_ai.return_value = mock_ai

        images = [_make_upload_file(b"fake-jpeg-data")]
        response = asyncio.run(bulk_submit("sess-1", images=images, db=db))

    assert response.session_id == "sess-1"
    assert response.summary.correct == 1
    assert response.summary.incorrect == 1
    assert response.summary.not_found == 0
    assert len(response.results) == 2


# ---------------------------------------------------------------------------
# Test 2: Assignment status updated (complete for correct, in_progress for incorrect)
# ---------------------------------------------------------------------------

def test_bulk_submit_updates_assignment_status():
    """Correct assignments get status=complete; incorrect get in_progress + feedback_summary."""
    mock_session = _make_mock_session()
    a1 = _make_mock_assignment("a1", "34 + 67", "101")
    a2 = _make_mock_assignment("a2", "7 × 8", "56")
    db = _build_db(mock_session, [a1, a2])

    ai_matches = [
        {"assignment_index": 0, "student_answer": "101", "confidence": 0.9,
         "page_index": 0, "error_type": None, "error_description": None},
        {"assignment_index": 1, "student_answer": "48", "confidence": 0.85,
         "page_index": 0, "error_type": "careless", "error_description": "Forkert tabel"},
    ]

    with (
        patch("app.routers.bulk_submit.get_ai_client") as mock_get_ai,
        patch("app.routers.bulk_submit.update_streak"),
        patch("builtins.open", MagicMock()),
        patch("os.makedirs", MagicMock()),
    ):
        mock_ai = MagicMock()
        mock_ai.send_vision_multi.return_value = _ai_response_json(ai_matches)
        mock_get_ai.return_value = mock_ai

        images = [_make_upload_file(b"img")]
        asyncio.run(bulk_submit("sess-1", images=images, db=db))

    assert a1.status == "complete"
    assert a2.status == "in_progress"
    assert a2.feedback_summary == "Forkert tabel"


# ---------------------------------------------------------------------------
# Test 3: Already-complete assignments are excluded from total
# ---------------------------------------------------------------------------

def test_bulk_submit_skips_complete_assignments():
    """An already-complete assignment is skipped; not counted in not_found; total reduced."""
    mock_session = _make_mock_session()
    a1 = _make_mock_assignment("a1", "34 + 67", "101", status="complete")
    db = _build_db(mock_session, [a1], submission_count=1)

    ai_matches = [
        {"assignment_index": 0, "student_answer": "101", "confidence": 0.95,
         "page_index": 0, "error_type": None, "error_description": None},
    ]

    with (
        patch("app.routers.bulk_submit.get_ai_client") as mock_get_ai,
        patch("app.routers.bulk_submit.update_streak"),
        patch("builtins.open", MagicMock()),
        patch("os.makedirs", MagicMock()),
    ):
        mock_ai = MagicMock()
        mock_ai.send_vision_multi.return_value = _ai_response_json(ai_matches)
        mock_get_ai.return_value = mock_ai

        images = [_make_upload_file(b"img")]
        response = asyncio.run(bulk_submit("sess-1", images=images, db=db))

    # validate_and_build_results skips complete assignment → 0 validated results
    # previously_complete_not_matched = 1 → total = 1 - 1 = 0
    assert response.summary.correct == 0
    assert response.summary.not_found == 0
    assert response.summary.total == 0


# ---------------------------------------------------------------------------
# Test 4: 404 for non-existent session
# ---------------------------------------------------------------------------

def test_bulk_submit_404_for_missing_session():
    """bulk_submit raises HTTPException(404) when session is not found."""
    from fastapi import HTTPException

    db = MagicMock()

    def query_side_effect(model):
        inner = MagicMock()
        f = MagicMock()
        inner.filter.return_value = f
        if model is _FakeSession:
            f.first.return_value = None
        return inner

    db.query.side_effect = query_side_effect

    with patch("os.makedirs", MagicMock()):
        images = [_make_upload_file(b"img")]
        with pytest.raises(HTTPException) as exc_info:
            asyncio.run(bulk_submit("nonexistent", images=images, db=db))

    assert exc_info.value.status_code == 404
    assert "Session not found" in str(exc_info.value.detail)


# ---------------------------------------------------------------------------
# Test 5: Empty AI matches → all assignments appear as not_found
# ---------------------------------------------------------------------------

def test_bulk_submit_empty_matches_returns_not_found():
    """When AI returns no matches, all assignments appear as not_found."""
    mock_session = _make_mock_session()
    a1 = _make_mock_assignment("a1", "34 + 67", "101")
    a2 = _make_mock_assignment("a2", "7 × 8", "56")
    db = _build_db(mock_session, [a1, a2])

    with (
        patch("app.routers.bulk_submit.get_ai_client") as mock_get_ai,
        patch("app.routers.bulk_submit.update_streak"),
        patch("builtins.open", MagicMock()),
        patch("os.makedirs", MagicMock()),
    ):
        mock_ai = MagicMock()
        mock_ai.send_vision_multi.return_value = _ai_response_json([])
        mock_get_ai.return_value = mock_ai

        images = [_make_upload_file(b"img")]
        response = asyncio.run(bulk_submit("sess-1", images=images, db=db))

    assert response.summary.not_found == 2
    assert response.summary.correct == 0
    statuses = {r.status for r in response.results}
    assert statuses == {"not_found"}
