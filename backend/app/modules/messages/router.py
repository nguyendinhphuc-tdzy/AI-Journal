"""JWT-authenticated private conversations, polling, read state and place shares."""
from datetime import datetime, timezone
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import and_, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.models.message import Conversation, ConversationRead, Message, MessageHide
from app.modules.messages.service import (
    now_utc, can_send, conversation_for_user, get_or_create, peer_id,
    enforce_rate, deliver, present_message, present_conversation, unread, utc,
    visible_to,
)

conversations_router = APIRouter(prefix="/conversations", tags=["messages"])
messages_router = APIRouter(prefix="/messages", tags=["messages"])
place_shares_router = APIRouter(prefix="/place-shares", tags=["messages"])

class OpenConversation(BaseModel):
    model_config = ConfigDict(extra="forbid")
    friend_id: UUID

class SendText(BaseModel):
    model_config = ConfigDict(extra="forbid")
    client_id: str = Field(min_length=1, max_length=100)
    text: str = Field(min_length=1, max_length=2000)
    @model_validator(mode="after")
    def nonblank(self):
        if not self.text.strip():
            raise ValueError("Message text cannot be blank")
        return self

class ReadUpTo(BaseModel):
    model_config = ConfigDict(extra="forbid")
    message_id: UUID

class PlaceSnapshot(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=1, max_length=160)
    latitude: float = Field(ge=-90, le=90, allow_inf_nan=False)
    longitude: float = Field(ge=-180, le=180, allow_inf_nan=False)
    category: str | None = Field(default=None, max_length=60)
    note: str | None = Field(default=None, max_length=300)
    @model_validator(mode="after")
    def validate_label(self):
        if not self.name.strip():
            raise ValueError("Place name cannot be blank")
        return self

class SendPlace(BaseModel):
    model_config = ConfigDict(extra="forbid")
    recipient_ids: list[UUID] = Field(min_length=1, max_length=20)
    place: PlaceSnapshot

@conversations_router.get("")
def list_conversations(user: AuthenticatedUser = Depends(get_current_user),
                       db: Session = Depends(get_db)):
    rows = db.scalars(select(Conversation).where(or_(
        Conversation.user_low_id == user.user_id,
        Conversation.user_high_id == user.user_id
    )).order_by(Conversation.updated_at.desc(), Conversation.id.desc()).limit(200)).all()
    # A chat with nothing left to show (never written in, only moments, or
    # deleted by this user) is not listed; a new message brings it back.
    listed = [present_conversation(db, row, user.user_id) for row in rows]
    return [c for c in listed if c["last_message"] is not None]

@conversations_router.post("")
def open_conversation(payload: OpenConversation,
                      user: AuthenticatedUser = Depends(get_current_user),
                      db: Session = Depends(get_db)):
    if not can_send(db, user.user_id, payload.friend_id):
        raise HTTPException(403, detail="Not an accepted, unblocked friend")
    row = get_or_create(db, user.user_id, payload.friend_id)
    db.commit()
    return present_conversation(db, row, user.user_id)

def _anchor(db: Session, conversation: Conversation, message_id: UUID):
    msg = db.get(Message, message_id)
    if msg is None or msg.conversation_id != conversation.id:
        raise HTTPException(404, detail="Message not found")
    return msg

@conversations_router.get("/{conversation_id}/messages")
def list_messages(conversation_id: UUID,
                  user: AuthenticatedUser = Depends(get_current_user),
                  db: Session = Depends(get_db), after: UUID | None = None,
                  before: UUID | None = None, limit: int = Query(50, ge=1, le=100)):
    conversation = conversation_for_user(db, conversation_id, user.user_id)
    if after is not None and before is not None:
        raise HTTPException(422, detail="Use after OR before")
    q = select(Message).where(visible_to(db, conversation, user.user_id))
    if after is not None:
        anchor = _anchor(db, conversation, after)
        q = q.where(or_(Message.created_at > anchor.created_at,
            and_(Message.created_at == anchor.created_at, Message.id > anchor.id)))
        items = db.scalars(q.order_by(Message.created_at, Message.id).limit(limit)).all()
    else:
        if before is not None:
            anchor = _anchor(db, conversation, before)
            q = q.where(or_(Message.created_at < anchor.created_at,
                and_(Message.created_at == anchor.created_at, Message.id < anchor.id)))
        items = list(reversed(db.scalars(
            q.order_by(Message.created_at.desc(), Message.id.desc()).limit(limit)).all()))
    return {"items": [present_message(db, m, user.user_id) for m in items]}

@conversations_router.post("/{conversation_id}/messages")
def send_message(conversation_id: UUID, payload: SendText,
                 user: AuthenticatedUser = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    conversation = conversation_for_user(db, conversation_id, user.user_id)
    # Idempotency first: retry an already-sent request without creating a duplicate.
    existing = db.scalar(select(Message).where(
        Message.conversation_id == conversation.id, Message.sender_id == user.user_id,
        Message.client_id == payload.client_id))
    if existing is not None:
        if existing.kind != "text" or existing.text != payload.text:
            raise HTTPException(409, detail="client_id already used for different content")
        return present_message(db, existing, user.user_id)
    if not can_send(db, user.user_id, peer_id(conversation, user.user_id)):
        raise HTTPException(403, detail="Conversation is read-only")
    at = now_utc()
    enforce_rate(db, user.user_id, now=at)
    try:
        # A separate savepoint leaves the session available to look up a
        # concurrent duplicate request after the UNIQUE constraint rejects it.
        with db.begin_nested():
            message = deliver(db, conversation, user.user_id, "text", at,
                              text=payload.text, client_id=payload.client_id)
        db.commit()
        return present_message(db, message, user.user_id)
    except IntegrityError:
        db.rollback()
        found = db.scalar(select(Message).where(
            Message.conversation_id == conversation.id, Message.sender_id == user.user_id,
            Message.client_id == payload.client_id))
        if found is not None and found.kind == "text" and found.text == payload.text:
            return present_message(db, found, user.user_id)
        raise HTTPException(409, detail="Message conflict")

@conversations_router.post("/{conversation_id}/read")
def mark_read(conversation_id: UUID, payload: ReadUpTo,
              user: AuthenticatedUser = Depends(get_current_user),
              db: Session = Depends(get_db)):
    conversation = conversation_for_user(db, conversation_id, user.user_id)
    message = _anchor(db, conversation, payload.message_id)
    marker = db.get(ConversationRead, (conversation.id, user.user_id))
    if marker is None:
        marker = ConversationRead(conversation_id=conversation.id, user_id=user.user_id)
        db.add(marker)
    if (marker.last_read_at is None or
        (utc(message.created_at), message.id.int) >
        (utc(marker.last_read_at), marker.last_read_message_id.int if marker.last_read_message_id else -1)):
        marker.last_read_at = message.created_at
        marker.last_read_message_id = message.id
    db.commit()
    return {"unread_count": unread(db, conversation, user.user_id)}

def _marker(db: Session, conversation: Conversation, user_id: UUID) -> ConversationRead:
    marker = db.get(ConversationRead, (conversation.id, user_id))
    if marker is None:
        marker = ConversationRead(conversation_id=conversation.id, user_id=user_id)
        db.add(marker)
    return marker

@conversations_router.delete("/{conversation_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_conversation(conversation_id: UUID,
                        user: AuthenticatedUser = Depends(get_current_user),
                        db: Session = Depends(get_db)):
    """Deletes the chat for this user only: everything up to now is gone for
    them (and read); the friend keeps theirs. A new message shows again."""
    conversation = conversation_for_user(db, conversation_id, user.user_id)
    latest = db.scalar(select(Message).where(Message.conversation_id == conversation.id)
                       .order_by(Message.created_at.desc(), Message.id.desc()).limit(1))
    marker = _marker(db, conversation, user.user_id)
    marker.cleared_at = latest.created_at if latest is not None else now_utc()
    if latest is not None:
        marker.last_read_at = latest.created_at
        marker.last_read_message_id = latest.id
    db.commit()

@conversations_router.post("/{conversation_id}/messages/{message_id}/recall")
def recall_message(conversation_id: UUID, message_id: UUID,
                   user: AuthenticatedUser = Depends(get_current_user),
                   db: Session = Depends(get_db)):
    """The sender takes a message back for both: its content is erased."""
    conversation = conversation_for_user(db, conversation_id, user.user_id)
    message = _anchor(db, conversation, message_id)
    if message.sender_id != user.user_id:
        raise HTTPException(403, detail="Only the sender can recall a message")
    if message.recalled_at is None:
        message.recalled_at = now_utc()
        message.text = None
        message.place = None
        db.commit()
    return present_message(db, message, user.user_id)

@conversations_router.delete("/{conversation_id}/messages/{message_id}",
                             status_code=status.HTTP_204_NO_CONTENT)
def hide_message(conversation_id: UUID, message_id: UUID,
                 user: AuthenticatedUser = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    """Deletes one message for this user only; the friend still has it."""
    conversation = conversation_for_user(db, conversation_id, user.user_id)
    message = _anchor(db, conversation, message_id)
    if db.get(MessageHide, (message.id, user.user_id)) is None:
        db.add(MessageHide(message_id=message.id, user_id=user.user_id, created_at=now_utc()))
        db.commit()

@messages_router.get("/unread-count")
def all_unread(user: AuthenticatedUser = Depends(get_current_user),
               db: Session = Depends(get_db)):
    conversations = db.scalars(select(Conversation).where(or_(
        Conversation.user_low_id == user.user_id,
        Conversation.user_high_id == user.user_id
    ))).all()
    return {"count": sum(unread(db, c, user.user_id) for c in conversations)}

@place_shares_router.post("", status_code=201)
def share_place(payload: SendPlace,
                user: AuthenticatedUser = Depends(get_current_user),
                db: Session = Depends(get_db)):
    recipients = payload.recipient_ids
    if len(recipients) != len(set(recipients)) or any(
        not can_send(db, user.user_id, target) for target in recipients
    ):
        raise HTTPException(422, detail="Invalid or ineligible recipients")
    at = now_utc()
    enforce_rate(db, user.user_id, len(recipients), at)
    ids = []
    # No own place_note or SavedPlace row is read. Only this explicitly
    # submitted public-to-friends snapshot is stored in each message.
    for target in recipients:
        conversation = get_or_create(db, user.user_id, target)
        deliver(db, conversation, user.user_id, "place", at,
                place=payload.place.model_dump(exclude_none=True))
        ids.append(conversation.id)
    db.commit()
    return {"conversation_ids": ids}
