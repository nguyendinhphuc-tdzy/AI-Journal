"""Authenticated user journal input/output models."""
from datetime import datetime, timezone

from pydantic import BaseModel, ConfigDict, Field, field_validator


class GuidedContent(BaseModel):
    """The Flutter guided-template snapshot, never regenerated on the server."""

    model_config = ConfigDict(extra="forbid")

    id: str = Field(min_length=1, max_length=100)
    version: int = Field(ge=1, le=100000)
    fields: dict[str, str] = Field(max_length=40)

    @field_validator("fields")
    @classmethod
    def validate_fields(cls, value: dict[str, str]) -> dict[str, str]:
        if any(not k or len(k) > 100 or len(v) > 4000 for k, v in value.items()):
            raise ValueError("Invalid guided fields")
        return value


class JournalSource(BaseModel):
    """Attribution of journal text from PR29 Study screens."""

    model_config = ConfigDict(extra="forbid")

    kind: str = Field(pattern=r"^(challenge|course|lesson|framework)$")
    id: str = Field(min_length=1, max_length=100)
    label: str = Field(min_length=1, max_length=160)
    task: int | None = Field(default=None, ge=0, le=1000)


class JournalCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str = Field(default="Untitled", min_length=1, max_length=160)
    content: str = Field(min_length=1)
    prompt: str | None = Field(default=None, max_length=500)
    mood: str | None = Field(default=None, max_length=64)
    guided: GuidedContent | None = None
    source: JournalSource | None = None

    @field_validator("content")
    @classmethod
    def content_cannot_be_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Journal content cannot be blank")
        return value


class JournalUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str | None = Field(default=None, max_length=160)
    content: str | None = Field(default=None, min_length=1)
    prompt: str | None = Field(default=None, max_length=500)
    mood: str | None = Field(default=None, max_length=64)
    guided: GuidedContent | None = None
    source: JournalSource | None = None

    @field_validator("title")
    @classmethod
    def title_cannot_be_null_or_blank(cls, value: str | None) -> str:
        if value is None or not value.strip():
            raise ValueError("Journal title cannot be null or blank")
        return value

    @field_validator("content")
    @classmethod
    def content_cannot_be_blank(cls, value: str | None) -> str:
        if value is None or not value.strip():
            raise ValueError("Journal content cannot be null or blank")
        return value


class JournalRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    content: str
    prompt: str | None
    mood: str | None
    guided: GuidedContent | None
    source: JournalSource | None
    body_version: int
    created_at: datetime
    updated_at: datetime

    @field_validator("created_at", "updated_at")
    @classmethod
    def timestamps_are_utc(cls, value: datetime) -> datetime:
        # SQLite test database loses timezone info; timestamps are stored in UTC.
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)


class JournalPage(BaseModel):
    items: list[JournalRead]
    next_cursor: str | None
