"""No external network, model download, database or Supabase credentials required."""

import json
import importlib

import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.modules.ai.service import (
    AIProviderError,
    MockAIProvider,
    OllamaAIProvider,
    get_ai_provider,
)
from app.schemas.ai import AiTextRequest

ai_router = importlib.import_module("app.modules.ai.router")


def _provider(reply: dict | None = None, *, status: int = 200, handler=None):
    if handler is None:
        def handler(request: httpx.Request) -> httpx.Response:
            payload = json.loads(request.content)
            assert request.url.path == "/api/chat"
            assert payload["model"] == "qwen3:4b"
            assert payload["stream"] is False
            assert payload["think"] is False
            assert payload["options"]["num_ctx"] == 4096
            assert "format" in payload
            assert payload["messages"][0]["role"] == "system"
            assert payload["messages"][1]["role"] == "user"
            assert "Bearer" not in str(request.headers)
            return httpx.Response(
                status, json={"message": {"content": json.dumps(reply)}}
            )
    return OllamaAIProvider(
        base_url="http://127.0.0.1:11434",
        model="qwen3:4b",
        transport=httpx.MockTransport(handler),
    )


def _reflection():
    return {
        "emotion": "lo lắng",
        "observation": "Bạn có thể đang lo về lịch trình.",
        "reflection": "Có lẽ bạn muốn dành thời gian sắp xếp lại.",
        "question": "Điều gì khiến bạn nghĩ nhiều nhất?",
    }


def _app(provider):
    app = FastAPI()
    app.include_router(ai_router.router, prefix="/api/v1")
    app.dependency_overrides[get_ai_provider] = lambda: provider
    return app


def test_ollama_reflection_json_schema_and_vietnamese():
    provider = _provider(_reflection())
    result = provider.reflect("Hôm nay có nhiều việc", "lo lắng")
    assert result.emotion == "lo lắng"
    assert result.question.endswith("?")


def test_ollama_go_deeper_uses_same_contract():
    provider = _provider({"question": "Điều gì khó khăn nhất hôm nay?"})
    assert provider.go_deeper("Hôm nay hơi khó") == "Điều gì khó khăn nhất hôm nay?"


@pytest.mark.parametrize("reply", [
    None,
    {"question": "   "},
    {"question": "valid", "extra": "unexpected"},
    {"emotion": "lo lắng"},  # Incomplete reflection
])
def test_bad_output_fail_closed(reply):
    provider = _provider(reply)
    with pytest.raises(AIProviderError) as error:
        provider.reflect("nội dung") if reply == {"emotion": "lo lắng"} else provider.go_deeper("nội dung")
    assert error.value.kind == "invalid_response"


def test_model_not_installed_is_unavailable():
    provider = _provider({"question": "x"}, status=404)
    with pytest.raises(AIProviderError) as error:
        provider.go_deeper("nội dung")
    assert error.value.kind == "unavailable"


def test_timeout_is_sanitized():
    def handler(request):
        raise httpx.ReadTimeout("remote detail should not surface", request=request)

    provider = _provider(handler=handler)
    with pytest.raises(AIProviderError) as error:
        provider.reflect("private diary: do not expose")
    assert error.value.kind == "timeout"
    assert "private diary" not in str(error.value)


def test_connection_failure_is_sanitized():
    def handler(request):
        raise httpx.ConnectError("network detail should not surface", request=request)

    provider = _provider(handler=handler)
    with pytest.raises(AIProviderError) as error:
        provider.go_deeper("secret journal")
    assert error.value.kind == "unavailable"
    assert "secret journal" not in str(error.value)


def test_mock_routes_remain_public_for_ui_tests():
    with TestClient(_app(MockAIProvider())) as client:
        res = client.post("/api/v1/ai/reflection", json={"content": "sample"})
        assert res.status_code == 200
        assert set(res.json()) == {"emotion", "observation", "reflection", "question"}


def test_ollama_routes_reject_missing_and_invalid_bearer(monkeypatch):
    provider = _provider(_reflection())
    with TestClient(_app(provider)) as client:
        missing = client.post("/api/v1/ai/reflection", json={"content": "private"})
        assert missing.status_code == 401
        # Invalid credentials are verified, never accepted by the AI route.
        def deny(_token):
            raise ai_router.HTTPException(status_code=401, detail="Invalid token")
        monkeypatch.setattr(ai_router, "verify_supabase_token", deny)
        invalid = client.post(
            "/api/v1/ai/reflection",
            json={"content": "private"},
            headers={"Authorization": "Bearer invalid"},
        )
        assert invalid.status_code == 401


def test_ollama_routes_success_with_verified_token(monkeypatch):
    monkeypatch.setattr(ai_router, "verify_supabase_token", lambda _token: object())
    with TestClient(_app(_provider(_reflection()))) as client:
        res = client.post(
            "/api/v1/ai/reflection",
            json={"content": "nhật ký giả lập", "mood": "lo lắng"},
            headers={"Authorization": "Bearer test-only"},
        )
    assert res.status_code == 200
    assert res.json() == _reflection()


def test_ollama_unavailable_maps_to_503_without_leaking_details(monkeypatch):
    monkeypatch.setattr(ai_router, "verify_supabase_token", lambda _token: object())
    def handler(request):
        raise httpx.ConnectError("private-diary-body", request=request)
    with TestClient(_app(_provider(handler=handler))) as client:
        res = client.post(
            "/api/v1/ai/go-deeper",
            json={"content": "my private diary"},
            headers={"Authorization": "Bearer test-only"},
        )
    assert res.status_code == 503
    assert "private" not in res.text


def test_journal_input_length_and_blank_validation():
    assert AiTextRequest(content="nhật ký").content == "nhật ký"
    with pytest.raises(ValueError):
        AiTextRequest(content="   ")
    with pytest.raises(ValueError):
        AiTextRequest(content="x" * 8001)
