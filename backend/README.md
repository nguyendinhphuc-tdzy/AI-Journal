# Backend

FastAPI backend for the local emulator demo.

## Run

```bash
python -m venv .venv
# activate venv
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Swagger: `http://127.0.0.1:8000/docs`

Android Emulator base host: `http://10.0.2.2:8000`

## Test

```bash
pytest -q
```
