"""Cached narrative of the week's private, version-valid analyses."""
from datetime import date, datetime, timezone
from uuid import UUID, uuid4

from sqlalchemy import Date, DateTime, ForeignKey, String, Text, Uuid, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class WeeklyInsight(Base):
    __tablename__ = "weekly_insights"
    __table_args__ = (UniqueConstraint("user_id", "monday", name="uq_weekly_insight_user_week"),)

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("auth.users.id",
                      ondelete="CASCADE"), nullable=False, index=True)
    monday: Mapped[date] = mapped_column(Date, nullable=False)
    fingerprint: Mapped[str] = mapped_column(String(64), nullable=False)
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    generated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now,
                                                   nullable=False)
