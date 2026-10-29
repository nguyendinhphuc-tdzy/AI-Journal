"""Versioned private AI results, quotes and feedback."""
from datetime import datetime
from uuid import UUID
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

class AnalyzeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    force: bool = False


class AnalysisRead(BaseModel):
    id: UUID
    journal_id: int
    body_version: int
    saved_at: datetime
    stale: bool
    analysis: dict
    feedback: Literal["up", "down"] | None = None


class FeedbackUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    rating: Literal["up", "down"] | None


class SavedQuoteCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    text: str = Field(min_length=1, max_length=1000)
    author: str = Field(min_length=1, max_length=160)
    source: str | None = Field(default=None, max_length=250)


class SavedQuoteRead(SavedQuoteCreate):
    id: UUID
    saved_at: datetime
