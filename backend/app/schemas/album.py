"""Owner-only album contracts shaped around Flutter PR #17.

Photo-only memories and 24-hour publication are intentionally not accepted
until private object storage and an audience policy have been implemented.
"""
from datetime import date, datetime, timezone
from math import isfinite
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class AlbumCreate(StrictModel):
    name: str = Field(min_length=1, max_length=120)
    theme_id: str = Field(default="classic", min_length=1, max_length=60)
    locked: bool = False
    hide_name_when_locked: bool = False

    @field_validator("name", "theme_id")
    @classmethod
    def nonblank(cls, text: str) -> str:
        value = text.strip()
        if not value:
            raise ValueError("Value must not be blank")
        return value


class AlbumUpdate(StrictModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    theme_id: str | None = Field(default=None, min_length=1, max_length=60)
    locked: bool | None = None
    hide_name_when_locked: bool | None = None

    @model_validator(mode="after")
    def no_explicit_null(self):
        for key in self.model_fields_set:
            if getattr(self, key) is None:
                raise ValueError(f"{key} must not be null")
        return self

    @field_validator("name", "theme_id")
    @classmethod
    def nonblank(cls, text: str | None) -> str | None:
        if text is None:
            return None
        value = text.strip()
        if not value:
            raise ValueError("Value must not be blank")
        return value


class AlbumRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    theme_id: str
    locked: bool
    hide_name_when_locked: bool
    memory_count: int
    created_at: datetime
    updated_at: datetime

    @field_validator("created_at", "updated_at")
    @classmethod
    def utc_timestamp(cls, value: datetime):
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


class MemoryPlace(StrictModel):
    label: str = Field(min_length=1, max_length=160)
    latitude: float = Field(ge=-90, le=90, allow_inf_nan=False)
    longitude: float = Field(ge=-180, le=180, allow_inf_nan=False)
    named: bool = True
    address: str | None = Field(default=None, max_length=2000)
    place_id: str | None = Field(default=None, max_length=2048)

    @field_validator("label")
    @classmethod
    def nonblank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Place label must not be blank")
        return value


class MemoryCreate(StrictModel):
    title: str | None = Field(default=None, max_length=160)
    note: str = Field(min_length=1, max_length=10000)
    display_date: date
    place: MemoryPlace | None = None

    @field_validator("note")
    @classmethod
    def nonblank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Memory needs a nonblank note until photo uploads exist")
        return value


class MemoryUpdate(StrictModel):
    title: str | None = Field(default=None, max_length=160)
    note: str | None = Field(default=None, min_length=1, max_length=10000)
    display_date: date | None = None
    place: MemoryPlace | None = None

    @model_validator(mode="after")
    def protected_required_values(self):
        for key in ("note", "display_date"):
            if key in self.model_fields_set and getattr(self, key) is None:
                raise ValueError(f"{key} must not be null")
        return self

    @field_validator("note")
    @classmethod
    def nonblank(cls, value: str | None) -> str | None:
        if value is not None and not value.strip():
            raise ValueError("Memory note must not be blank")
        return value


class MemoryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    album_id: UUID
    title: str | None
    note: str
    display_date: date
    place: MemoryPlace | None
    created_at: datetime
    updated_at: datetime

    @field_validator("created_at", "updated_at")
    @classmethod
    def utc_timestamp(cls, value: datetime):
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)
