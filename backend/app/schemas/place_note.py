"""Typed note endpoints; clients cannot submit owner/place identities."""
from datetime import datetime, timezone

from pydantic import BaseModel, ConfigDict, Field, field_validator


class NoteContent(BaseModel):
    model_config = ConfigDict(extra="forbid")
    content: str = Field(min_length=1, max_length=10000)

    @field_validator("content")
    @classmethod
    def nonblank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Place note content must not be blank")
        return value


class NoteRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    place_id: int
    content: str
    created_at: datetime
    updated_at: datetime

    @field_validator("created_at", "updated_at")
    @classmethod
    def utc_timestamp(cls, value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)


class NotePage(BaseModel):
    items: list[NoteRead]
    next_cursor: str | None
