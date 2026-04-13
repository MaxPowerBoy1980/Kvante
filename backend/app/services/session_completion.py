"""Auto-complete a session when all its assignments are done."""

import logging
from datetime import datetime, timezone

from sqlalchemy.orm import Session as DBSession

from app.models.db import Assignment, Session

logger = logging.getLogger(__name__)


def check_and_complete_session(db: DBSession, session_id: str) -> bool:
    """Check if all assignments in a session are complete; if so, mark the session completed.

    Returns True if the session was just completed, False otherwise.
    """
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session or session.status == "completed":
        return False

    assignments = db.query(Assignment).filter(Assignment.session_id == session_id).all()
    if not assignments:
        return False

    all_done = all(a.status in ("complete", "completed") for a in assignments)
    if not all_done:
        return False

    session.status = "completed"
    session.completed_at = datetime.now(timezone.utc)
    db.commit()
    logger.info("Session %s auto-completed (all %d assignments done)", session_id, len(assignments))
    return True
