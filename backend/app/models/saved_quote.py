"""User-kept, account-scoped quotes (not model-generated attributions)."""
from datetime import datetime, timezone
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, String, Text, Uuid, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class SavedQuote(Base):
    __tablename__ = "saved_quotes"
    __table_args__ = (UniqueConstraint("user_id", "text", name="uq_saved_quote_user_text"),)

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("auth.users.id",
                    ondelete="CASCADE"), nullable=False, index=True)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    author: Mapped[str] = mapped_column(String(160), nullable=False)
    source: Mapped[str | None] = mapped_column(String(250), nullable=True)
    saved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now,
                                               nullable=False)
