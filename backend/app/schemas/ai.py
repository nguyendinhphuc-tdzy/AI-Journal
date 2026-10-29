from typing import Literal

from pydantic import BaseModel, Field, field_validator


class AiTextRequest(BaseModel):
    # Bound the prompt before inference to cap resource use.
    content: str = Field(min_length=1, max_length=8000)
    mood: str | None = Field(default=None, max_length=64)

    @field_validator("content")
    @classmethod
    def nonblank_content(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Journal text must not be blank")
        return value


class GoDeeperResponse(BaseModel):
    question: str


class ReflectionResponse(BaseModel):
    emotion: str = Field(min_length=1, max_length=200)
    observation: str = Field(min_length=1, max_length=1200)
    reflection: str = Field(min_length=1, max_length=1200)
    question: str = Field(min_length=1, max_length=500)
    # Additive optional fields, compatible with the existing Flutter parser.
    title: str | None = Field(default=None, max_length=160)
    analysis: str | None = Field(default=None, max_length=2000)
    topics: list[str] = Field(default_factory=list, max_length=8)
    # Quotes require separately curated sources. Ollama may not invent authors.
    quote: None = None
    # Computed by the backend (not trusted from model output).
    mood_group: Literal["joy", "grateful", "calm", "hopeful", "mixed", "tired",
                        "anxious", "afraid", "angry", "sad"] | None = None
    mood_score: int | None = Field(default=None, ge=0, le=100)

    @field_validator("topics")
    @classmethod
    def validate_topics(cls, value: list[str]) -> list[str]:
        if any(not item.strip() or len(item) > 80 for item in value):
            raise ValueError("Invalid topic")
        return value
