from fastapi import APIRouter, Depends

from .quota import enforce_ai_quota

from app.schemas.ai import AiTextRequest, GoDeeperResponse, ReflectionResponse
from .service import AIProvider, get_ai_provider

# Never expose mock or Ollama through an unauthenticated AI route.
router = APIRouter(
    prefix="/ai", tags=["ai"], dependencies=[Depends(enforce_ai_quota)]
)


@router.post("/go-deeper", response_model=GoDeeperResponse)
def go_deeper(
    payload: AiTextRequest,
    provider: AIProvider = Depends(get_ai_provider),
):
    return GoDeeperResponse(question=provider.go_deeper(payload.content))


@router.post("/reflection", response_model=ReflectionResponse)
def reflection(
    payload: AiTextRequest,
    provider: AIProvider = Depends(get_ai_provider),
):
    return provider.reflect(payload.content, payload.mood)
