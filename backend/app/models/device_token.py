"""FCM registration tokens are private server-side credentials."""
from datetime import datetime, timezone
from uuid import UUID
from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, String, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base

def now_utc() -> datetime:
    return datetime.now(timezone.utc)

class DeviceToken(Base):
    __tablename__ = "device_tokens"
    __table_args__ = (
        UniqueConstraint("user_id", "installation_id", name="uq_device_owner_installation"),
        CheckConstraint("platform IN ('android','ios')", name="ck_device_platform"),
        Index("ix_device_tokens_user_last_seen", "user_id", "last_seen_at"),
    )
    # A bounded index of the hash (rather than indexing a 4 KiB FCM token).
    token_hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    token: Mapped[str] = mapped_column(Text, nullable=False)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"),
        nullable=False)
    installation_id: Mapped[str] = mapped_column(String(128), nullable=False)
    platform: Mapped[str] = mapped_column(String(10), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=now_utc)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=now_utc)
