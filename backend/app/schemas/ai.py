from pydantic import BaseModel, Field


class AiTextRequest(BaseModel):
    content: str = Field(min_length=1)
    mood: str | None = None


class GoDeeperResponse(BaseModel):
    question: str


class ReflectionResponse(BaseModel):
    emotion: str
    observation: str
    reflection: str
    question: str
