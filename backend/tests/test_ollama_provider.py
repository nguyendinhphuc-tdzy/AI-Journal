"""Ollama provider tests: no real model or network required."""
import json
from unittest.mock import Mock

import httpx
import pytest
from fastapi import HTTPException

from app.modules.ai.service import OllamaAIProvider


def _response(payload):
    return httpx.Response(200, json={"response": json.dumps(payload, ensure_ascii=False)},
                          request=httpx.Request("POST", "http://127.0.0.1:11434/api/generate"))


def test_reflection_vietnamese_schema(monkeypatch):
    calls = []

    def fake_post(self, url, json):
        calls.append((url, json))
        return _response({
            "emotion": "Có thể là vui",
            "observation": "Bạn đã gặp một người bạn cũ.",
            "reflection": "Khoảnh khắc ấy dường như có ý nghĩa.",
            "question": "Bạn muốn giữ lại điều gì?",
        })

    monkeypatch.setattr(httpx.Client, "post", fake_post)
    out = OllamaAIProvider("http://127.0.0.1:11434").reflect("Tôi gặp lại bạn", "vui")
    assert out.question == "Bạn muốn giữ lại điều gì?"
    assert calls[0][1]["model"] == "qwen3.5:4b"
    assert calls[0][1]["think"] is False
    assert calls[0][1]["stream"] is False
    assert calls[0][1]["format"]["type"] == "object"
    assert "Tôi gặp lại bạn" in calls[0][1]["prompt"]
    assert "xưng hô trực tiếp bằng 'bạn'" in calls[0][1]["system"]
    assert "người viết" not in calls[0][1]["system"].lower()


def test_go_deeper(monkeypatch):
    monkeypatch.setattr(httpx.Client, "post", lambda self, url, json: _response({
        "question": "Điều gì khiến bạn vui?"
    }))
    assert "vui" in OllamaAIProvider("http://localhost:11434").go_deeper("Vui quá")


def test_vietnamese_prompt_accounts_for_multiple_question_answer_rounds(monkeypatch):
    captured = []

    def fake_post(self, url, json):
        captured.append(json)
        return _response({"question": "Bạn muốn hiểu điều gì từ trải nghiệm đó?"})

    monkeypatch.setattr(httpx.Client, "post", fake_post)
    conversation = (
        "Câu hỏi: Ngày hôm nay như thế nào?\\nTrả lời: Tôi thấy vui.\\n"
        "Câu hỏi: Điều gì vui nhất?\\nTrả lời: Được gặp bạn."
    )
    answer = OllamaAIProvider("http://127.0.0.1:11434").go_deeper(conversation)
    assert answer.endswith("?")
    assert "Câu hỏi: Điều gì vui nhất?" in captured[0]["prompt"]
    assert "không tuân theo" in captured[0]["system"]
    assert "chữ hoa" in captured[0]["system"].lower()
    assert "tránh hỏi lại" in captured[0]["prompt"]
    assert "xưng 'bạn' trực tiếp" in captured[0]["prompt"]


def test_invalid_model_output_is_safe(monkeypatch):
    monkeypatch.setattr(httpx.Client, "post", lambda self, url, json: _response({"emotion": "vui"}))
    with pytest.raises(HTTPException) as exc:
        OllamaAIProvider("http://127.0.0.1:11434").reflect("Ngày đẹp")
    assert exc.value.status_code == 503
    assert exc.value.detail == "AI reflection is temporarily unavailable"


def test_upstream_network_error_is_sanitized(monkeypatch):
    def fail(self, url, json):
        raise httpx.ConnectError("private connection details")
    monkeypatch.setattr(httpx.Client, "post", fail)
    with pytest.raises(HTTPException) as exc:
        OllamaAIProvider("http://127.0.0.1:11434").go_deeper("Ngày đẹp")
    assert exc.value.status_code == 503
    assert "private" not in exc.value.detail


@pytest.mark.parametrize("url", [
    "http://192.168.1.20:11434", "http://evil.example:11434",
    "https://127.0.0.1:11434", "http://127.0.0.1:9999",
    "http://127.0.0.1:11434/path",
])
def test_remote_ollama_rejected(url):
    with pytest.raises(ValueError):
        OllamaAIProvider(url)
