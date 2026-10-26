# AI Journal — Local Ollama backend integration (demo, 2026-10-26)

## Responsibilities

- Phúc (Windows): build/test FastAPI using installed `qwen3:4b`.
- Vy (Mac M4 / 16 GB): install Ollama and test `qwen3.5:4b` independently, following the PDF handoff.
- Tech Lead: provider implementation, JSON validation, API authorization and CI.
- Demo devices: Android Emulator and Android phone. No iPad/iOS target.

## Architecture and boundaries

```text
Flutter (Supabase Auth SDK for sign-in)
    -> Bearer JWT + JSON -> FastAPI /api/v1/ai/*
    -> OllamaAIProvider (local httpx) -> 127.0.0.1:11434 /api/chat
    -> validated JSON -> Flutter

FastAPI (separate) -> SQLAlchemy -> Supabase PostgreSQL
```

Ollama and FastAPI should run on the **same Mac** for the final demo. Ollama stays loopback-only; clients never call it directly. LAN access to FastAPI requires authenticated clients and a trusted private network, never Internet port forwarding. The AI provider does **not** modify Supabase, create tables, migrate data, or store input journals.

## Provider configuration (backend/.env, untracked)

Windows (Phúc):

```dotenv
AI_PROVIDER=ollama
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=qwen3:4b
OLLAMA_TIMEOUT_SECONDS=60
OLLAMA_NUM_CTX=4096
OLLAMA_NUM_PREDICT=350
```

Mac (Vy, after installing model):

```dotenv
AI_PROVIDER=ollama
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=qwen3.5:4b
OLLAMA_TIMEOUT_SECONDS=60
OLLAMA_NUM_CTX=4096
OLLAMA_NUM_PREDICT=350
```

Default is `AI_PROVIDER=mock` for existing UI/unit testing. **Switching to Ollama is explicit**. If the model is unavailable, API responds 503; timeout 504; malformed output 502. No silent mock fallback. The code chooses model from environment, never a hardcoded production name.

## Testing without Vy's Mac

From backend/:

```powershell
python -m pip install -r requirements.txt
python -m pytest -q tests/test_ollama_ai.py
python -m pytest -q tests
```

These tests use `httpx.MockTransport`, no network or Supabase credentials.
For a real local smoke test, ensure Ollama is running with qwen3:4b, then in backend/:

```powershell
$env:OLLAMA_MODEL="qwen3:4b"
python -m scripts.check_ollama
```

On Mac (after installing qwen3.5:4b):

```bash
OLLAMA_MODEL=qwen3.5:4b python -m scripts.check_ollama
```

Run with fictional sample text only. The script verifies Go Deeper and Reflection directly without JWT; the **HTTP API itself requires a valid Supabase Bearer JWT when AI_PROVIDER=ollama**. The old public mock API continues to function when AI_PROVIDER=mock.

## API contract (unchanged paths)

`POST /api/v1/ai/go-deeper` request: `{"content":"..." }` -> `{"question":"..."}`.
`POST /api/v1/ai/reflection` request: `{"content":"...", "mood":"..."}` -> `{"emotion":"...","observation":"...","reflection":"...","question":"..."}`.

AI inputs: 1–8000 characters, nonblank. Outputs are constrained using Ollama's JSON schema `format` and then **validated again on FastAPI using Pydantic**. The model is instructed to avoid diagnosis and to treat journal text as data. No user text or upstream response body appears in HTTP failure details.

## Integration acceptance checklist

1. GitHub Actions backend CI green, including `test_ollama_ai.py`.
2. Windows `ollama list` includes qwen3:4b; `scripts.check_ollama` passes twice consecutively.
3. Vy's Mac responds to `GET /api/tags` and local `POST /api/chat`, with qwen3.5:4b installed.
4. Both models return valid JSON for five fictional prompts; document latency and text quality.
5. Authenticated API call reaches Ollama through FastAPI; unauthenticated returns 401.
6. Android emulator and phone can reach FastAPI, and AI errors are shown without presenting simulated content as real AI.
7. No real journals or database migrations until Supabase security gate is approved.

### Known dependency

PR #16 Auth and Journal remote integration remain unmerged. This PR provides **backend AI capabilities**, not a completed mobile E2E. Keep Ollama loopback-only even if Flutter demo still uses local/mock reflection.
