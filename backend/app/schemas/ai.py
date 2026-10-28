from pydantic import BaseModel, ConfigDict, Field, field_validator


class AiTextRequest(BaseModel):
    content: str = Field(min_length=1, max_length=8000)
    mood: str | None = Field(default=None, max_length=64)

    @field_validator("content")
    @classmethod
    def nonblank_content(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Journal text must not be blank")
        return value

    @field_validator("mood")
    @classmethod
    def trim_optional_mood(cls, value: str | None) -> str | None:
        return value.strip() or None if value is not None else None


class GoDeeperResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")
    question: str = Field(min_length=1, max_length=400)

    @field_validator("question")
    @classmethod
    def nonblank_question(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Empty question")
        return value.strip()


class ReflectionResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")
    emotion: str = Field(min_length=1, max_length=80)
    observation: str = Field(min_length=1, max_length=650)
    reflection: str = Field(min_length=1, max_length=650)
    question: str = Field(min_length=1, max_length=400)

    @field_validator("emotion", "observation", "reflection", "question")
    @classmethod
    def nonblank_fields(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Empty AI response field")
        return value.strip()
