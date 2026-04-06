from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session as DBSession

from app.config import settings
from app.database import get_db
from app.models.db import Assignment, ChatMessage, Session
from app.models.schemas import (
    ChatMessageOut,
    LoadMessagesResponse,
    SaveMessagesRequest,
    SaveMessagesResponse,
)
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


@router.post("/chat/messages/save", response_model=SaveMessagesResponse)
def save_messages(request: SaveMessagesRequest, db: DBSession = Depends(get_db)):
    """Save chat messages for a session (batch)."""
    session = db.query(Session).filter(Session.id == request.session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    for msg in request.messages:
        chat_msg = ChatMessage(
            session_id=request.session_id,
            assignment_id=msg.assignment_id,
            sender=msg.sender,
            content_type=msg.content_type,
            content=msg.content,
        )
        db.add(chat_msg)

    db.commit()
    return SaveMessagesResponse(saved_count=len(request.messages))


@router.get("/chat/messages/{session_id}", response_model=LoadMessagesResponse)
def load_messages(session_id: str, db: DBSession = Depends(get_db)):
    """Load all chat messages for a session, ordered by creation time."""
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    messages = (
        db.query(ChatMessage)
        .filter(ChatMessage.session_id == session_id)
        .order_by(ChatMessage.created_at)
        .all()
    )

    return LoadMessagesResponse(
        session_id=session_id,
        messages=[
            ChatMessageOut(
                id=m.id,
                session_id=m.session_id,
                assignment_id=m.assignment_id,
                sender=m.sender,
                content_type=m.content_type,
                content=m.content,
                created_at=m.created_at.isoformat(),
            )
            for m in messages
        ],
    )
