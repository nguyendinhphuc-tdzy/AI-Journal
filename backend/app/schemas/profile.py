"""Public profile API shapes (email comes from verified JWT only)."""
from datetime import datetime
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ProfileUpdate(BaseModel):
    display_name: str | None = Field(default=None, max_length=100)
    timezone: str | None = Field(default=None, max_length=64)

    @field_validator("timezone")
    @classmethod
    def timezone_is_valid(cls, value: str | None) -> str | None:
        if value is not None:
            try:
                ZoneInfo(value)
            except (ZoneInfoNotFoundError, ValueError, KeyError) as exc:
                raise ValueError("timezone must be a valid IANA timezone") from exc
        return value


class ProfileRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: UUID
    email: str | None
    display_name: str | None
    timezone: str
    created_at: datetime
