"""Private friend relationship, keyed by canonical unordered Supabase user pair."""
from datetime import datetime, timezone
from uuid import UUID
from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base


def now_utc():
    return datetime.now(timezone.utc)


class Friendship(Base):
    __tablename__ = "friendships"
    __table_args__ = (
        CheckConstraint("user_low_id <> user_high_id", name="ck_friend_distinct"),
        CheckConstraint("status IN ('pending', 'accepted')", name="ck_friend_status"),
    )

    user_low_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), primary_key=True)
    user_high_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), primary_key=True)
    requester_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="pending")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc, onupdate=now_utc, nullable=False)
