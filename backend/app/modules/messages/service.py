"""Conversation authorization, serialization and transactional message delivery."""
from datetime import datetime, timedelta, timezone
from uuid import UUID
from fastapi import HTTPException
from sqlalchemy import and_, func, or_, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from app.models.friendship import Friendship
from app.models.message import Conversation, ConversationRead, Message
from app.models.memory_share import MemoryShare
from app.models.memory_share_recipient import MemoryShareRecipient
from app.models.user_profile import UserProfile
from app.modules.friends.router import blocked, pair

def utc(v: datetime) -> datetime:
    return v.replace(tzinfo=timezone.utc) if v.tzinfo is None else v.astimezone(timezone.utc)

def now_utc() -> datetime:
    return datetime.now(timezone.utc)

def can_send(db: Session, a: UUID, b: UUID) -> bool:
    if a == b or blocked(db, a, b):
        return False
    relation = db.get(Friendship, pair(a, b))
    return relation is not None and relation.status == "accepted"

def find_conversation(db: Session, a: UUID, b: UUID):
    low, high = pair(a, b)
    return db.scalar(select(Conversation).where(
        Conversation.user_low_id == low, Conversation.user_high_id == high))

def get_or_create(db: Session, a: UUID, b: UUID) -> Conversation:
    low, high = pair(a, b)
    item = find_conversation(db, a, b)
    if item is not None:
        return item
    try:
        # The database unique pair constraint closes the concurrent-creation race.
        with db.begin_nested():
            item = Conversation(user_low_id=low, user_high_id=high,
                                created_at=now_utc(), updated_at=now_utc())
            db.add(item)
            db.flush()
    except IntegrityError:
        item = find_conversation(db, a, b)
        if item is None:
            raise HTTPException(409, detail="Conversation creation conflict")
    return item

def conversation_for_user(db: Session, conversation_id: UUID, user_id: UUID) -> Conversation:
    item = db.get(Conversation, conversation_id)
    if item is None or user_id not in (item.user_low_id, item.user_high_id):
        raise HTTPException(404, detail="Conversation not found")
    return item

def peer_id(item: Conversation, user_id: UUID) -> UUID:
    return item.user_high_id if item.user_low_id == user_id else item.user_low_id

def enforce_rate(db: Session, sender_id: UUID, count: int = 1, now: datetime | None = None):
    at = now or now_utc()
    if db.bind.dialect.name == "postgresql":
        # Serialize concurrent sends for the same sender across API workers.
        # The transaction-scoped advisory lock is released on commit/rollback.
        db.execute(text("SELECT pg_advisory_xact_lock(hashtextextended(:uid, 0))"),
                   {"uid": str(sender_id)})
    recent = db.scalar(select(func.count()).select_from(Message).where(
        Message.sender_id == sender_id,
        Message.created_at > at - timedelta(minutes=1))) or 0
    if recent + count > 30:
        raise HTTPException(429, detail="Message rate limit exceeded")

def deliver(db: Session, conversation: Conversation, sender: UUID,
            kind: str, at: datetime, *, text: str | None = None,
            place: dict | None = None, share_id: UUID | None = None,
            client_id: str | None = None) -> Message:
    message = Message(conversation_id=conversation.id, sender_id=sender,
                      kind=kind, text=text, place=place,
                      memory_share_id=share_id, client_id=client_id, created_at=at)
    db.add(message)
    conversation.updated_at = at
    db.flush()
    return message

def _read_condition(cursor: ConversationRead | None):
    if cursor is None or cursor.last_read_at is None:
        return None
    if cursor.last_read_message_id is None:
        return Message.created_at > cursor.last_read_at
    return or_(
        Message.created_at > cursor.last_read_at,
        and_(Message.created_at == cursor.last_read_at,
             Message.id > cursor.last_read_message_id),
    )

def unread(db: Session, conversation: Conversation, viewer: UUID) -> int:
    marker = db.get(ConversationRead, (conversation.id, viewer))
    query = select(func.count()).select_from(Message).where(
        Message.conversation_id == conversation.id, Message.sender_id != viewer)
    condition = _read_condition(marker)
    if condition is not None:
        query = query.where(condition)
    return db.scalar(query) or 0

def _share_content(db: Session, share_id: UUID | None, viewer: UUID, sender: UUID,
                   at: datetime):
    if share_id is None:
        return None
    share = db.get(MemoryShare, share_id)
    if share is None:
        return None
    # After expiry, revoke, block or unfriend: keep only a non-sensitive tombstone.
    safe = {"share_id": share.id, "expires_at": share.expires_at}
    if (share.revoked_at is not None or utc(share.expires_at) <= at
        or share.text is None or share.place is None):
        return safe
    if viewer != share.owner_id and (
        db.get(MemoryShareRecipient, (share.id, viewer)) is None
        or not can_send(db, share.owner_id, viewer)):
        return safe
    safe.update(title=share.title, text=share.text,
                place_label=share.place.get("label"))
    return safe

def present_message(db: Session, m: Message, viewer: UUID, at: datetime | None = None):
    content = _share_content(db, m.memory_share_id, viewer, m.sender_id, at or now_utc()) if m.kind == "memory_share" else None
    return {
        "id": m.id, "conversation_id": m.conversation_id, "sender_id": m.sender_id,
        "kind": m.kind, "client_id": m.client_id, "created_at": m.created_at,
        "text": m.text if m.kind == "text" else None,
        "place": m.place if m.kind == "place" else None,
        "memory_share": content,
    }

def present_conversation(db: Session, c: Conversation, viewer: UUID):
    peer = peer_id(c, viewer)
    profile = db.get(UserProfile, peer)
    latest = db.scalar(select(Message).where(
        Message.conversation_id == c.id).order_by(
        Message.created_at.desc(), Message.id.desc()).limit(1))
    return {
        "id": c.id,
        "friend": {"user_id": peer,
                   "display_name": profile.display_name if profile else None,
                   "username": profile.username if profile else None},
        "last_message": present_message(db, latest, viewer) if latest else None,
        "unread_count": unread(db, c, viewer),
        "can_send": can_send(db, viewer, peer),
    }
