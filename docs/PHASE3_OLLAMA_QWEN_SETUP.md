# Phase 3 — Ollama Qwen3.5:4b reflection (Mac Vy)

The **Ollama model runs on Vy's Mac**, NOT inside the Flutter mobile app.
Architecture: Flutter -> FastAPI `/api/v1/ai/reflection` and `/api/v1/ai/go-deeper` -> Ollama `/api/generate`.
Both endpoints preserve their current JSON response contracts. The AI provider is **mock by default**.

## Mac running Ollama

1. In Terminal: `ollama list` and confirm exact model tag `qwen3.5:4b`.
2. `ollama run qwen3.5:4b` to make sure inference works.
3. `curl http://127.0.0.1:11434/api/tags` to confirm Ollama's loopback API.
4. Keep Ollama bound to loopback. **Do not set OLLAMA_HOST=0.0.0.0 or port-forward port 11434 to the internet.**

## FastAPI on the same Mac

Set in a local, ignored `backend/.env`:

```dotenv
AI_PROVIDER=ollama
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=qwen3.5:4b
OLLAMA_TIMEOUT_SECONDS=90
```

Run `python -m uvicorn app.main:app --host 127.0.0.1 --port 8000` from `backend/`.
For a Flutter emulator/simulator on the same Mac, configure the app's FastAPI base URL using its supported development networking settings. **Do not configure Flutter to call Ollama port 11434 directly.**

## FastAPI running on another computer

Ollama is only accessible on Vy's Mac loopback. Use a **private authenticated SSH tunnel** or an equivalent access-controlled tunnel from FastAPI host to the Mac, with tunnel endpoint on **FastAPI host loopback**. The backend's `OLLAMA_BASE_URL` remains `http://127.0.0.1:11434`. Coordinate secure SSH setup and avoid conflicting local ports.

Do not expose a personal journal or Ollama API through a public unauthenticated tunnel. The current AI endpoints do **not** require JWT; secure them before exposing a backend beyond trusted development networks.

## Check endpoint behavior

Request `POST /api/v1/ai/reflection`:
```json
{"content":"Hôm nay mình vui vì được gặp lại bạn thân.", "mood":"vui"}
```
Response should have exactly four Vietnamese string fields: `emotion`, `observation`, `reflection`, `question`.
`POST /api/v1/ai/go-deeper` returns `{"question":"..."}`.
If the model is missing, offline, or malformed, the endpoint returns generic HTTP 503 without revealing journal text, internal endpoints or upstream errors.

## Constraints

- This PR does not modify Vy's Flutter UI.
- No model weights are copied into the repository or mobile app.
- Do not assume the model is reachable from Windows until a private tunnel or same-host FastAPI is configured.
- User diary text is sent from FastAPI to the configured Ollama process; treat Vy's Mac as an entrusted development inference host.
- Response style and latency require real Vietnamese evaluation on Vy's Mac. Automated tests mock the network.
