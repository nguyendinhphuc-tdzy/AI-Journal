from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class JournalCreate(BaseModel):
    title: str = Field(default="Untitled", max_length=160)
    content: str = Field(min_length=1)
    prompt: str | None = Field(default=None, max_length=500)
    mood: str | None = Field(default=None, max_length=64)


class JournalUpdate(BaseModel):
    title: str | None = Field(default=None, max_length=160)
    content: str | None = Field(default=None, min_length=1)
    prompt: str | None = Field(default=None, max_length=500)
    mood: str | None = Field(default=None, max_length=64)


class JournalRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    content: str
    prompt: str | None
    mood: str | None
    created_at: datetime
    updated_at: datetime
