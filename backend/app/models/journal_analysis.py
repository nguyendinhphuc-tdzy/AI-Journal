"""Private per-journal AI analysis and optional user feedback."""
from datetime import datetime, timezone
from uuid import UUID, uuid4

from sqlalchemy import (CheckConstraint, DateTime, ForeignKeyConstraint, Index,
                        Integer, JSON, String, Uuid, UniqueConstraint)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class JournalAnalysis(Base):
    __tablename__ = "journal_analyses"
    __table_args__ = (
        # Must match BOTH journal id and verified owner. Deleting journal
        # cascades to analysis; a different user's journal cannot be linked.
        ForeignKeyConstraint(
            ["journal_id", "user_id"], ["journal_entries.id", "journal_entries.user_id"],
            ondelete="CASCADE", name="fk_analysis_owned_journal"),
        UniqueConstraint("journal_id", "user_id", name="uq_analysis_owned_journal"),
        CheckConstraint("body_version >= 1", name="ck_analysis_body_version"),
        CheckConstraint("feedback IN ('up', 'down') OR feedback IS NULL",
                        name="ck_analysis_feedback"),
        Index("ix_analysis_user_created", "user_id", "created_at"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    journal_id: Mapped[int] = mapped_column(Integer, nullable=False)
    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    body_version: Mapped[int] = mapped_column(Integer, nullable=False)
    result: Mapped[dict] = mapped_column(JSON, nullable=False)
    feedback: Mapped[str | None] = mapped_column(String(8), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now,
                                                onupdate=utc_now, nullable=False)
