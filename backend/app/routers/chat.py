from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session as DBSession

from app.config import settings
from app.database import get_db
from app.models.db import Assignment, Session
from app.services.ai_client import get_ai_client

import logging

logger = logging.getLogger(__name__)

router = APIRouter()

_system_prompt = None


def get_system_prompt():
    global _system_prompt
    if _system_prompt is None:
        _system_prompt = (settings.prompts_dir / "chat.txt").read_text()
    return _system_prompt


class ChatRequest(BaseModel):
    session_id: str
    assignment_id: str
    message: str
    language: str = "da"


class ChatResponse(BaseModel):
    reply: str


@router.post("/chat/", response_model=ChatResponse)
async def chat(request: ChatRequest, db: DBSession = Depends(get_db)):
    """Handle free-text chat from the student."""
    session = db.query(Session).filter(Session.id == request.session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    assignment = (
        db.query(Assignment)
        .filter(Assignment.id == request.assignment_id, Assignment.session_id == request.session_id)
        .first()
    )

    assignment_context = ""
    if assignment:
        assignment_context = f"\nElevens aktuelle opgave: {assignment.text}"
        if assignment.status == "complete":
            assignment_context += " (eleven har løst den korrekt)"

    logger.info("Chat message from student: '%s'", request.message)

    system = get_system_prompt() + assignment_context
    client = get_ai_client()
    reply = client.send_text(system, request.message)

    logger.info("Chat reply: '%s'", reply[:100])
    return ChatResponse(reply=reply)
