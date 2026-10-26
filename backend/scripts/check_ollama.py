"""Manual smoke test against local Ollama. Fictional content only; no DB access.

From backend/:
  python -m scripts.check_ollama

Uses OLLAMA_MODEL and OLLAMA_BASE_URL if supplied. Local default qwen3:4b.
No authentication token, Supabase connection or database migration required.
"""

import os
import time

from app.modules.ai.service import AIProviderError, OllamaAIProvider


def main() -> int:
    provider = OllamaAIProvider(
        base_url=os.getenv("OLLAMA_BASE_URL", "http://127.0.0.1:11434"),
        model=os.getenv("OLLAMA_MODEL", "qwen3:4b"),
        timeout_seconds=float(os.getenv("OLLAMA_TIMEOUT_SECONDS", "60")),
    )
    # Only synthetic, non-personal content is sent to Ollama.
    sample = "Hôm nay mình hơi lo vì có nhiều bài tập, nhưng đã hoàn thành một việc nhỏ."
    for name, invoke in (
        ("go_deeper", lambda: provider.go_deeper(sample)),
        ("reflection", lambda: provider.reflect(sample, "lo lắng").model_dump()),
    ):
        start = time.monotonic()
        try:
            result = invoke()
        except AIProviderError as exc:
            print(f"{name}: FAILED ({exc.kind})")
            return 1
        elapsed = time.monotonic() - start
        print(f"{name}: OK ({elapsed:.2f}s)")
        print(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
