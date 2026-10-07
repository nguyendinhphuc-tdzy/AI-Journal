from dataclasses import dataclass

from app.schemas.ai import ReflectionResponse


class AIProvider:
    def go_deeper(self, content: str) -> str:
        raise NotImplementedError

    def reflect(self, content: str, mood: str | None = None) -> ReflectionResponse:
        raise NotImplementedError


@dataclass
class MockAIProvider(AIProvider):
    """Deterministic local provider for UI/backend integration before a real provider is selected."""

    def go_deeper(self, content: str) -> str:
        return "What part of this moment felt most different from what you expected?"

    def reflect(self, content: str, mood: str | None = None) -> ReflectionResponse:
        emotion = mood or "reflective"
        return ReflectionResponse(
            emotion=emotion,
            observation="You seem to be noticing how this moment changed the way you felt.",
            reflection="There may be value in paying attention to what helped the shift happen.",
            question="What would you want to remember from this experience tomorrow?",
        )


def get_ai_provider() -> AIProvider:
    # Replace with provider selection after the team finalizes the production AI choice.
    return MockAIProvider()
