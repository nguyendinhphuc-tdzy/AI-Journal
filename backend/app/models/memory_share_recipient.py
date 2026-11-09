"""Explicit recipient allowlist for expiring Memory shares."""
from uuid import UUID
from sqlalchemy import CheckConstraint, ForeignKey, Uuid
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base


class MemoryShareRecipient(Base):
    __tablename__ = "memory_share_recipients"
    __table_args__ = (
        CheckConstraint("owner_id <> recipient_id", name="ck_share_recipient_distinct"),
    )
    share_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("memory_shares.id", ondelete="CASCADE"), primary_key=True)
    owner_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), nullable=False)
    recipient_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), primary_key=True)
