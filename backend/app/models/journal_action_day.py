"""Persist one verified journal-writing completion per user-local date.

The row is an achievement record: deleting the source journal does not erase
historical streak activity. No client supplies this model's user or date.
"""
from datetime import date, datetime
from uuid import UUID

from sqlalchemy import Date, DateTime, ForeignKey, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class JournalActionDay(Base):
    __tablename__ = "journal_action_days"

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "auth.users.id",
            name="fk_journal_action_days_auth_users",
            ondelete="CASCADE",
        ),
        primary_key=True,
    )
    activity_date: Mapped[date] = mapped_column(Date, primary_key=True)
    first_completed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    action_type: Mapped[str] = mapped_column(
        String(32), nullable=False, default="journal_written"
    )
