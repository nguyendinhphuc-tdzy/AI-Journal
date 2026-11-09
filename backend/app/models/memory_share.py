"""Friends-only time-bound Memory shares. No public photo URLs."""
from datetime import datetime, timezone
from uuid import UUID, uuid4
from sqlalchemy import DateTime, ForeignKey, LargeBinary, Uuid, String, Text, JSON
from sqlalchemy.orm import Mapped, deferred, mapped_column
from app.core.database import Base


def now_utc():
    return datetime.now(timezone.utc)


class MemoryShare(Base):
    __tablename__ = "memory_shares"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    memory_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True), ForeignKey("album_memories.id", ondelete="SET NULL"), nullable=True, index=True)
    title: Mapped[str | None] = mapped_column(String(160), nullable=True)
    text: Mapped[str | None] = mapped_column(String(300), nullable=True)
    place: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    category: Mapped[str | None] = mapped_column(String(60), nullable=True)
    owner_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # The share's own image (sent by its owner), served only to the owner and
    # its recipients while active; loaded only when asked for.
    photo: Mapped[bytes | None] = deferred(mapped_column(LargeBinary, nullable=True))
    photo_type: Mapped[str | None] = mapped_column(String(16), nullable=True)
