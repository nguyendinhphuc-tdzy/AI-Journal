"""User-owned geographic pins. Place Notes / Journal links follow in B10."""
from datetime import datetime, timezone
from decimal import Decimal
from uuid import UUID

from sqlalchemy import (
    CheckConstraint, DateTime, ForeignKey, Index, Integer, Numeric, String,
    Text, UniqueConstraint, Uuid, text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class SavedPlace(Base):
    __tablename__ = "saved_places"
    __table_args__ = (
        CheckConstraint(
            "latitude >= -90 AND latitude <= 90", name="ck_saved_places_lat"
        ),
        CheckConstraint(
            "longitude >= -180 AND longitude <= 180", name="ck_saved_places_lon"
        ),
        CheckConstraint(
            "provider IN ('manual', 'geoapify')",
            name="ck_saved_places_provider",
        ),
        CheckConstraint(
            "(provider = 'manual' AND external_place_id IS NULL) OR "
            "(provider = 'geoapify' AND external_place_id IS NOT NULL "
            "AND length(trim(external_place_id)) > 0)",
            name="ck_saved_places_external_id",
        ),
        UniqueConstraint("id", "user_id", name="uq_saved_places_id_user_id"),
        Index("ix_saved_places_user_created_id", "user_id", "created_at", "id"),
        Index(
            "uq_saved_places_owner_provider_external_id",
            "user_id", "provider", "external_place_id",
            unique=True,
            postgresql_where=text("external_place_id IS NOT NULL"),
            sqlite_where=text("external_place_id IS NOT NULL"),
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "auth.users.id",
            name="fk_saved_places_auth_users",
            ondelete="CASCADE",
        ),
        nullable=False,
    )
    label: Mapped[str] = mapped_column(String(160), nullable=False)
    latitude: Mapped[Decimal] = mapped_column(Numeric(9, 6), nullable=False)
    longitude: Mapped[Decimal] = mapped_column(Numeric(9, 6), nullable=False)
    address_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    provider: Mapped[str] = mapped_column(String(32), nullable=False, default="manual")
    external_place_id: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False
    )
