"""Public mock for UI development; authenticated-only local model inference."""

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials

from app.core.auth import bearer_scheme, verify_supabase_token
from app.schemas.ai import AiTextRequest, GoDeeperResponse, ReflectionResponse
from .service import AIProvider, AIProviderError, OllamaAIProvider, get_ai_provider

router = APIRouter(prefix="/ai", tags=["ai"])

_ERRORS = {
    "unavailable": (503, "Local AI model is unavailable"),
    "timeout": (504, "Local AI request timed out"),
    "invalid_response": (502, "Local AI returned an invalid response"),
}


def private_ai_provider(
    provider: AIProvider = Depends(get_ai_provider),
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> AIProvider:
    # Never expose an unauthenticated local AI compute endpoint on the LAN.
    # Preserve old unauthenticated mock routes for existing Flutter demo tests.
    if isinstance(provider, OllamaAIProvider):
        if credentials is None or credentials.scheme.lower() != "bearer":
            raise HTTPException(
                status_code=401,
                detail="Missing authentication token",
                headers={"WWW-Authenticate": "Bearer"},
            )
        verify_supabase_token(credentials.credentials)
    return provider


def _safe_ai_error(error: AIProviderError) -> HTTPException:
    code, detail = _ERRORS[error.kind]
    return HTTPException(status_code=code, detail=detail)


@router.post("/go-deeper", response_model=GoDeeperResponse)
def go_deeper(
    payload: AiTextRequest,
    provider: AIProvider = Depends(private_ai_provider),
):
    try:
        return GoDeeperResponse(question=provider.go_deeper(payload.content))
    except AIProviderError as exc:
        raise _safe_ai_error(exc) from exc


@router.post("/reflection", response_model=ReflectionResponse)
def reflection(
    payload: AiTextRequest,
    provider: AIProvider = Depends(private_ai_provider),
):
    try:
        return provider.reflect(payload.content, payload.mood)
    except AIProviderError as exc:
        raise _safe_ai_error(exc) from exc
