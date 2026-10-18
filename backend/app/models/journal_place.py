"""Private journal-to-place links; database FKs reject cross-user pairs."""
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import DateTime, ForeignKeyConstraint, Index, Integer, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class JournalPlace(Base):
    __tablename__ = "journal_places"
    __table_args__ = (
        ForeignKeyConstraint(
            ["journal_id", "user_id"],
            ["journal_entries.id", "journal_entries.user_id"],
            name="fk_journal_places_owner_journal",
            ondelete="CASCADE",
        ),
        ForeignKeyConstraint(
            ["place_id", "user_id"],
            ["saved_places.id", "saved_places.user_id"],
            name="fk_journal_places_owner_place",
            ondelete="CASCADE",
        ),
        Index("ix_journal_places_owner_place", "user_id", "place_id"),
    )

    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True)
    journal_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    place_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, nullable=False
    )
