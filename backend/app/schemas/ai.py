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
    emotion: str
    observation: str
    reflection: str
    question: str
