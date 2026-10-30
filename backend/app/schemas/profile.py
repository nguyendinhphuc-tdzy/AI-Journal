"""Public profile API shapes (email comes from verified JWT only)."""
from datetime import datetime
import re
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ProfileUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    discoverable: bool | None = None

    @field_validator("discoverable")
    @classmethod
    def discoverable_must_not_be_null(cls, value: bool | None) -> bool:
        # Omitted is valid (partial PATCH); explicit JSON null is not.
        # Without validation, SQLAlchemy writes NULL to a NOT NULL column (500).
        if value is None:
            raise ValueError("discoverable must not be null")
        return value
    username: str | None = Field(default=None, min_length=3, max_length=24)

    @field_validator("username")
    @classmethod
    def normalize_username(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip().removeprefix("@").lower()
        if not re.fullmatch(r"[a-z0-9_]{3,24}", normalized):
            raise ValueError("username must contain 3-24 lowercase letters, digits or underscores")
        return normalized

    display_name: str | None = Field(default=None, max_length=100)
    timezone: str | None = Field(default=None, max_length=64)

    @field_validator("timezone")
    @classmethod
    def timezone_is_valid(cls, value: str | None) -> str | None:
        if value is None:
            raise ValueError("timezone must not be null")
        try:
            ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError, KeyError) as exc:
            raise ValueError("timezone must be a valid IANA timezone") from exc
        return value


class ProfileRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: UUID
    discoverable: bool
    email: str | None
    display_name: str | None
    username: str | None
    timezone: str
    created_at: datetime
