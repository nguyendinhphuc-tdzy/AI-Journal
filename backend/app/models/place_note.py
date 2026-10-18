"""Multiple private notes per saved place, with database-enforced owner identity."""
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import DateTime, ForeignKeyConstraint, Index, Integer, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class PlaceNote(Base):
    __tablename__ = "place_notes"
    __table_args__ = (
        ForeignKeyConstraint(
            ["place_id", "user_id"],
            ["saved_places.id", "saved_places.user_id"],
            name="fk_place_notes_owner_place",
            ondelete="CASCADE",
        ),
        Index(
            "ix_place_notes_owner_place_created_id",
            "user_id", "place_id", "created_at", "id",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    place_id: Mapped[int] = mapped_column(Integer, nullable=False)
    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False
    )
