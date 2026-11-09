from datetime import datetime, timezone
from uuid import UUID
from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Uuid
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base


class UserBlock(Base):
    __tablename__ = "user_blocks"
    __table_args__ = (CheckConstraint("blocker_id <> blocked_id", name="ck_block_distinct"),)
    blocker_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), primary_key=True)
    blocked_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
