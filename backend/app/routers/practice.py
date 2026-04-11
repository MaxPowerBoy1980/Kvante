"""Practice session endpoint — create a session from the assignment library."""

import random
from collections import defaultdict
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session as DBSession

from app.database import get_db
from app.models.db import Assignment, ChatMessage, MathProblem, Session, Submission
from app.models.schemas import (
    ArkAssignment,
    SessionDetailResponse,
    SessionHistoryResponse,
    SessionSummary,
    SessionSummaryWithAssignments,
    WeeklyRequest,
)
from app.services.streak_service import get_streak

router = APIRouter(tags=["practice"])


class PracticeRequest(BaseModel):
    student_id: str
    topic: str
    difficulty: int = 2
    count: int = 5


@router.post("/sessions/practice")
def create_practice_session(body: PracticeRequest, db: DBSession = Depends(get_db)):
    """Create a practice session with random problems from the library."""
    problems = (
        db.query(MathProblem)
        .filter(MathProblem.topic == body.topic, MathProblem.difficulty == body.difficulty)
        .all()
    )

    if not problems:
        raise HTTPException(
            status_code=404,
            detail={
                "error": "no_problems",
                "message": f"No problems found for topic={body.topic}, difficulty={body.difficulty}",
                "student_message": "Der er ingen opgaver med de valgte indstillinger. Prøv et andet emne.",
            },
        )

    selected = random.sample(problems, min(body.count, len(problems)))

    # Generate a descriptive name for the practice session
    topic_labels = {
        "addition": "Addition",
        "subtraction": "Subtraktion",
        "multiplication": "Multiplikation",
        "division": "Division",
        "geometry": "Geometri",
        "fractions": "Brøker",
    }
    difficulty_labels = {1: "Let", 2: "Medium", 3: "Svær"}
    topic_label = topic_labels.get(body.topic, body.topic.capitalize())
    difficulty_label = difficulty_labels.get(body.difficulty, f"Niveau {body.difficulty}")
    session_name = f"Øvelser — {topic_label} ({difficulty_label})"

    session = Session(
        student_id=body.student_id,
        mode="practice",
        name=session_name,
        topic=body.topic,
        difficulty=body.difficulty,
        detected_language="da",
    )
    db.add(session)
    db.flush()

    assignments = []
    for i, problem in enumerate(selected):
        assignment = Assignment(
            session_id=session.id,
            problem_id=problem.id,
            local_id=str(i + 1),
            text=problem.text,
            type=problem.type,
            topic=problem.topic,
            difficulty_estimate=problem.difficulty,
            correct_answer=problem.correct_answer,
            position=i,
        )
        db.add(assignment)
        assignments.append(assignment)

    db.commit()

    return {
        "session_id": session.id,
        "assignments": [
            {
                "id": a.id,
                "problem_id": a.problem_id,
                "local_id": a.local_id,
                "text": a.text,
                "type": a.type,
                "topic": a.topic,
                "difficulty_estimate": a.difficulty_estimate,
                "position": a.position,
            }
            for a in assignments
        ],
    }


@router.post("/sessions/weekly")
def create_weekly_session(body: WeeklyRequest, db: DBSession = Depends(get_db)):
    """Create a mixed-topic weekly session from the assignment library."""
    problems = (
        db.query(MathProblem)
        .filter(MathProblem.grade_level <= body.grade_level)
        .all()
    )

    if not problems:
        raise HTTPException(
            status_code=404,
            detail={
                "error": "no_problems",
                "message": f"No problems found for grade_level<={body.grade_level}",
                "student_message": "Der er ingen opgaver klar til ugematematik. Prøv igen senere.",
            },
        )

    # Group by topic, then round-robin pick to get a good mix
    by_topic: dict[str, list] = defaultdict(list)
    for p in problems:
        by_topic[p.topic].append(p)

    # Shuffle within each topic for variety
    for topic_list in by_topic.values():
        random.shuffle(topic_list)

    # Round-robin across topics until we have enough
    selected = []
    topic_iters = {topic: iter(lst) for topic, lst in by_topic.items()}
    topic_keys = list(topic_iters.keys())
    idx = 0
    while len(selected) < body.count:
        key = topic_keys[idx % len(topic_keys)]
        try:
            selected.append(next(topic_iters[key]))
        except StopIteration:
            # This topic is exhausted; remove it
            topic_keys.pop(idx % len(topic_keys))
            if not topic_keys:
                break
            continue
        idx += 1

    if not selected:
        raise HTTPException(
            status_code=404,
            detail={
                "error": "no_problems",
                "message": "Could not select any problems",
                "student_message": "Der er ingen opgaver klar til ugematematik. Prøv igen senere.",
            },
        )

    # Determine ISO week number for the session name
    week_number = datetime.now(timezone.utc).isocalendar()[1]

    session = Session(
        student_id=body.student_id,
        mode="weekly",
        name=f"Ugematematik — uge {week_number}",
        detected_language="da",
    )
    db.add(session)
    db.flush()

    assignments = []
    for i, problem in enumerate(selected):
        assignment = Assignment(
            session_id=session.id,
            problem_id=problem.id,
            local_id=str(i + 1),
            text=problem.text,
            type=problem.type,
            topic=problem.topic,
            difficulty_estimate=problem.difficulty,
            correct_answer=problem.correct_answer,
            position=i,
        )
        db.add(assignment)
        assignments.append(assignment)

    db.commit()

    return {
        "session_id": session.id,
        "name": session.name,
        "assignments": [
            {
                "id": a.id,
                "problem_id": a.problem_id,
                "local_id": a.local_id,
                "text": a.text,
                "type": a.type,
                "topic": a.topic,
                "difficulty_estimate": a.difficulty_estimate,
                "position": a.position,
            }
            for a in assignments
        ],
    }


def _truncate_feedback(text: str | None, max_len: int = 140) -> str | None:
    """Truncate feedback text to ~max_len chars at sentence boundary."""
    if not text:
        return text
    if len(text) <= max_len:
        return text
    # Find last sentence-ending punctuation within max_len
    truncated = text[:max_len]
    for sep in (". ", "! ", "? "):
        last = truncated.rfind(sep)
        if last > 0:
            return text[: last + 1] + "..."
    # No sentence boundary found — truncate at word boundary
    last_space = truncated.rfind(" ")
    if last_space > 0:
        return text[:last_space] + "..."
    return text[:max_len] + "..."


def _compute_ark_status(assignment: Assignment, submissions: list[Submission]) -> str:
    """Compute ark_status from assignment status and submissions."""
    if assignment.status in ("complete", "completed"):
        return "done"
    if submissions:
        return "in_progress"
    return "not_started"


@router.get("/sessions/{session_id}", response_model=SessionDetailResponse)
def get_session(session_id: str, db: DBSession = Depends(get_db)):
    """Return a session and its assignments with ark-overlay fields.

    Used by iOS to enter/re-enter a session. Returns per-assignment status,
    latest scan thumbnail ID, AI feedback summary, and teacher comments.
    """
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    assignments = (
        db.query(Assignment)
        .filter(Assignment.session_id == session_id)
        .order_by(Assignment.position)
        .all()
    )

    # Batch-load all submissions and scan chat messages for this session
    all_submissions = (
        db.query(Submission)
        .filter(Submission.session_id == session_id)
        .order_by(Submission.created_at)
        .all()
    )
    submissions_by_assignment: dict[str, list[Submission]] = defaultdict(list)
    for sub in all_submissions:
        submissions_by_assignment[sub.assignment_id].append(sub)

    # Find latest scanned_image chat messages per assignment
    scan_messages = (
        db.query(ChatMessage)
        .filter(
            ChatMessage.session_id == session_id,
            ChatMessage.content_type == "scanned_image",
        )
        .order_by(ChatMessage.created_at)
        .all()
    )
    latest_scan_by_assignment: dict[str, str | None] = {}
    for msg in scan_messages:
        if msg.assignment_id and isinstance(msg.content, dict):
            scan_id = msg.content.get("scan_id")
            if scan_id:
                latest_scan_by_assignment[msg.assignment_id] = scan_id

    # Compute current_assignment_index (first non-done assignment)
    current_index = len(assignments)  # default: all done
    for i, a in enumerate(assignments):
        if a.status not in ("complete", "completed"):
            current_index = i
            break

    ark_assignments = []
    for a in assignments:
        subs = submissions_by_assignment.get(a.id, [])
        # Latest feedback and student answer from the most recent submission
        latest_feedback = None
        student_answer = None
        if subs:
            latest_sub = subs[-1]
            latest_feedback = _truncate_feedback(latest_sub.feedback_text)
            if latest_sub.analysis:
                analysis = latest_sub.analysis
                if isinstance(analysis, str):
                    import json as _json
                    analysis = _json.loads(analysis)
                student_answer = analysis.get("student_answer")

        ark_assignments.append(
            ArkAssignment(
                id=a.id,
                local_id=a.local_id,
                text=a.text,
                type=a.type,
                topic=a.topic,
                difficulty_estimate=a.difficulty_estimate,
                position=a.position,
                ark_status=_compute_ark_status(a, subs),
                latest_scan_id=latest_scan_by_assignment.get(a.id),
                latest_ai_feedback_summary=latest_feedback,
                teacher_comment=None,  # Always null in Pakke 2a
                correct_answer=a.correct_answer,
                student_answer=student_answer,
            )
        )

    streak_data = get_streak(db, session.student_id)

    return SessionDetailResponse(
        session_id=session.id,
        session_name=session.name or "",
        current_assignment_index=current_index,
        assignments=ark_assignments,
        streak=streak_data,
    )


@router.get("/students/{student_id}/sessions")
def get_session_history(
    student_id: str,
    limit: int = 20,
    include: str | None = None,
    db: DBSession = Depends(get_db),
):
    """Return session history for a student, most recent first.

    Args:
        limit: Max sessions to return. 0 = all sessions (used by notebook).
        include: Set to "assignments" to inline ArkAssignment objects per session.
    """
    query = (
        db.query(Session)
        .filter(Session.student_id == student_id)
        .order_by(Session.created_at.desc())
    )
    if limit > 0:
        query = query.limit(limit)
    sessions = query.all()

    if not sessions:
        return SessionHistoryResponse(sessions=[])

    session_ids = [s.id for s in sessions]

    # Batch-load all assignments for all sessions (fixes backend N+1)
    all_assignments = (
        db.query(Assignment)
        .filter(Assignment.session_id.in_(session_ids))
        .order_by(Assignment.position)
        .all()
    )
    assignments_by_session: dict[str, list[Assignment]] = defaultdict(list)
    for a in all_assignments:
        assignments_by_session[a.session_id].append(a)

    if include == "assignments":
        # Batch-load submissions and scan messages for all sessions
        all_submissions = (
            db.query(Submission)
            .filter(Submission.session_id.in_(session_ids))
            .order_by(Submission.created_at)
            .all()
        )
        submissions_by_assignment: dict[str, list[Submission]] = defaultdict(list)
        for sub in all_submissions:
            submissions_by_assignment[sub.assignment_id].append(sub)

        scan_messages = (
            db.query(ChatMessage)
            .filter(
                ChatMessage.session_id.in_(session_ids),
                ChatMessage.content_type == "scanned_image",
            )
            .order_by(ChatMessage.created_at)
            .all()
        )
        latest_scan_by_assignment: dict[str, str] = {}
        for msg in scan_messages:
            if msg.assignment_id and isinstance(msg.content, dict):
                scan_id = msg.content.get("scan_id")
                if scan_id:
                    latest_scan_by_assignment[msg.assignment_id] = scan_id

        summaries = []
        for s in sessions:
            session_assignments = assignments_by_session.get(s.id, [])
            total = len(session_assignments)
            completed = sum(1 for a in session_assignments if a.status in ("complete", "completed"))

            # Compute current_assignment_index
            current_index = total
            for i, a in enumerate(session_assignments):
                if a.status not in ("complete", "completed"):
                    current_index = i
                    break

            # Build ArkAssignment objects
            ark_assignments = []
            for a in session_assignments:
                subs = submissions_by_assignment.get(a.id, [])
                latest_feedback = None
                student_answer = None
                if subs:
                    latest_sub = subs[-1]
                    latest_feedback = _truncate_feedback(latest_sub.feedback_text)
                    if latest_sub.analysis:
                        analysis = latest_sub.analysis
                        if isinstance(analysis, str):
                            import json as _json
                            analysis = _json.loads(analysis)
                        student_answer = analysis.get("student_answer")

                ark_assignments.append(
                    ArkAssignment(
                        id=a.id,
                        local_id=a.local_id,
                        text=a.text,
                        type=a.type,
                        topic=a.topic,
                        difficulty_estimate=a.difficulty_estimate,
                        position=a.position,
                        ark_status=_compute_ark_status(a, subs),
                        latest_scan_id=latest_scan_by_assignment.get(a.id),
                        latest_ai_feedback_summary=latest_feedback,
                        teacher_comment=None,
                        correct_answer=a.correct_answer,
                        student_answer=student_answer,
                    )
                )

            summaries.append(
                SessionSummaryWithAssignments(
                    session_id=s.id,
                    name=s.name,
                    mode=s.mode,
                    topic=s.topic,
                    status=s.status,
                    assignment_count=total,
                    completed_count=completed,
                    created_at=s.created_at.isoformat(),
                    completed_at=s.completed_at.isoformat() if s.completed_at else None,
                    assignments=ark_assignments,
                    current_assignment_index=current_index,
                )
            )

        return SessionHistoryResponse(sessions=summaries)

    # Default path: summaries only (no per-session queries now!)
    summaries = []
    for s in sessions:
        session_assignments = assignments_by_session.get(s.id, [])
        total = len(session_assignments)
        completed = sum(1 for a in session_assignments if a.status in ("complete", "completed"))
        summaries.append(
            SessionSummary(
                session_id=s.id,
                name=s.name,
                mode=s.mode,
                topic=s.topic,
                status=s.status,
                assignment_count=total,
                completed_count=completed,
                created_at=s.created_at.isoformat(),
                completed_at=s.completed_at.isoformat() if s.completed_at else None,
            )
        )

    return SessionHistoryResponse(sessions=summaries)


@router.post("/sessions/{session_id}/complete")
def complete_session(session_id: str, db: DBSession = Depends(get_db)):
    """Mark a session as completed."""
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        raise HTTPException(
            status_code=404,
            detail={
                "error": "session_not_found",
                "message": f"Session {session_id} not found",
                "student_message": "Sessionen blev ikke fundet.",
            },
        )

    session.status = "completed"
    session.completed_at = datetime.now(timezone.utc)
    db.commit()

    return {"session_id": session.id, "status": session.status}
