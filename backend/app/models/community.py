"""Opt-in text-only community posts and private reports."""
from datetime import datetime, timezone
from uuid import UUID, uuid4
from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class CommunityPost(Base):
    __tablename__ = "community_posts"
    __table_args__ = (CheckConstraint("status IN ('pending','approved','rejected')", name="ck_community_status"),)
    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    author_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), nullable=False, index=True)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="pending")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)


class CommunityReport(Base):
    __tablename__ = "community_reports"
    __table_args__ = (UniqueConstraint("post_id", "reporter_id", name="uq_community_reporter_post"),)
    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    post_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("community_posts.id", ondelete="CASCADE"), nullable=False)
    reporter_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), nullable=False)
    reason: Mapped[str] = mapped_column(String(200), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)
