"""Private albums and memories introduced by mobile PR #17 (A01–A12/E05).

Photos remain device-local until private object storage and upload authorization
are implemented. A UI lock is never a substitute for authenticated ownership.
"""
from datetime import date, datetime, timezone
from uuid import UUID, uuid4

from sqlalchemy import (
    Boolean, CheckConstraint, Date, DateTime, ForeignKey, ForeignKeyConstraint,
    Index, JSON, String, Text, UniqueConstraint, Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class Album(Base):
    __tablename__ = "albums"
    __table_args__ = (
        UniqueConstraint("id", "user_id", name="uq_albums_id_user"),
        Index("ix_albums_user_created", "user_id", "created_at", "id"),
        CheckConstraint("length(trim(name)) > 0", name="ck_albums_nonblank"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("auth.users.id", ondelete="CASCADE", name="fk_albums_auth_users"),
        nullable=False,
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    theme_id: Mapped[str] = mapped_column(String(60), nullable=False, default="classic")
    locked: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    hide_name_when_locked: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now
    )


class AlbumMemory(Base):
    __tablename__ = "album_memories"
    __table_args__ = (
        ForeignKeyConstraint(
            ["album_id", "user_id"], ["albums.id", "albums.user_id"],
            name="fk_album_memories_owner_album", ondelete="CASCADE",
        ),
        Index("ix_album_memories_owner_album_date", "user_id", "album_id", "display_date", "created_at"),
        CheckConstraint("note IS NOT NULL AND length(trim(note)) > 0",
                        name="ck_album_memories_nonblank_note"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    album_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    title: Mapped[str | None] = mapped_column(String(160), nullable=True)
    note: Mapped[str] = mapped_column(Text, nullable=False)
    display_date: Mapped[date] = mapped_column(Date, nullable=False)
    # PR17's MemoryPlace snapshot: name/coords/address/provider ID.
    place: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    photo_path: Mapped[str | None] = mapped_column(String(400), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now
    )
