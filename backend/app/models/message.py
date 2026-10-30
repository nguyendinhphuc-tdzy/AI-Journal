"""Private one-to-one conversations and idempotent messages."""
from datetime import datetime, timezone
from uuid import UUID, uuid4
from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, JSON, String, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base

def now_utc():
    return datetime.now(timezone.utc)

class Conversation(Base):
    __tablename__ = "conversations"
    __table_args__ = (
        UniqueConstraint("user_low_id", "user_high_id", name="uq_conversations_pair"),
        CheckConstraint("user_low_id <> user_high_id", name="ck_conversation_distinct"),
    )
    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_low_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), nullable=False)
    user_high_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc, nullable=False)

class Message(Base):
    __tablename__ = "messages"
    __table_args__ = (
        UniqueConstraint("conversation_id", "sender_id", "client_id", name="uq_message_client_id"),
        CheckConstraint("kind IN ('text','place','memory_share')", name="ck_message_kind"),
        CheckConstraint("kind != 'text' OR recalled_at IS NOT NULL OR (text IS NOT NULL AND length(trim(text)) > 0 AND length(text) <= 2000)", name="ck_message_text"),
        Index("ix_messages_conversation_created", "conversation_id", "created_at", "id"),
        Index("ix_messages_sender_created", "sender_id", "created_at"),
    )
    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    conversation_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False)
    sender_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), nullable=False)
    kind: Mapped[str] = mapped_column(String(20), nullable=False)
    client_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    text: Mapped[str | None] = mapped_column(Text, nullable=True)
    place: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    memory_share_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True), ForeignKey("memory_shares.id", ondelete="SET NULL"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc, nullable=False)
    # Recalled by its sender: kept for order, content gone for both.
    recalled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

class ConversationRead(Base):
    __tablename__ = "conversation_reads"
    __table_args__ = (
        Index("ix_conversation_reads_user", "user_id"),
    )
    conversation_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("conversations.id", ondelete="CASCADE"), primary_key=True)
    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), primary_key=True)
    last_read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_read_message_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True), ForeignKey("messages.id", ondelete="SET NULL"), nullable=True)
    # The user deleted the conversation: nothing up to here shows for them.
    cleared_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

class MessageHide(Base):
    """One message deleted by one user, for that user only."""
    __tablename__ = "message_hides"
    __table_args__ = (Index("ix_message_hides_user", "user_id"),)
    message_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("messages.id", ondelete="CASCADE"), primary_key=True)
    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc, nullable=False)
