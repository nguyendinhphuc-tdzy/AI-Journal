"""Aggregated week data; null scores mean unknown, never invented."""
from datetime import date
from typing import Literal

from pydantic import BaseModel, Field


class InsightDay(BaseModel):
    date: date
    journal_count: int = Field(ge=0)
    analyzed_count: int = Field(ge=0)
    score: float | None = Field(default=None, ge=0, le=100)


class EmotionCount(BaseModel):
    mood_group: Literal["joy", "grateful", "calm", "hopeful", "mixed",
                        "tired", "anxious", "afraid", "angry", "sad"]
    count: int = Field(ge=1)


class WeekInsights(BaseModel):
    start: date
    end: date
    days: list[InsightDay]
    top_emotions: list[EmotionCount]
    summary: str | None
    summary_status: Literal["ready", "not_requested", "no_data", "unavailable"]
