# AI Diary Backend

FastAPI + SQLAlchemy. Run the backend on the host PC and reach it from Android Emulator at `http://10.0.2.2:8000`.

## 1. Set up local environment

From the repository root:

```bash
cd backend
python -m venv .venv
```

Activate the environment and install dependencies:

```powershell
# Windows PowerShell
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
```

On macOS/Linux, use `source .venv/bin/activate` and `cp .env.example .env`.

Never commit `.env` or real API keys.

## 2. Select a database

SQLite is the working demo default; no separate database server is required:

```dotenv
DATABASE_URL=sqlite:///./ai_diary.db
```

For local PostgreSQL or a Supabase PostgreSQL connection, set a PostgreSQL SQLAlchemy URL in `.env`:

```dotenv
DATABASE_URL=postgresql+psycopg://USER:PASSWORD@HOST:5432/DB_NAME
```

Use the actual connection details from your PostgreSQL/Supabase configuration. Do not commit the connection string with credentials. Remote PostgreSQL connections may require SSL settings, depending on the provider.

**PostgreSQL connectivity has not yet been integration-tested; the automated tests currently exercise SQLite.**

## 3. Apply schema migrations before starting FastAPI

```bash
alembic upgrade head
alembic current
```

Then run:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- API docs: http://localhost:8000/docs
- Health: http://localhost:8000/health
- Emulator API base: http://10.0.2.2:8000/api/v1

FastAPI no longer creates tables when imported; Alembic owns schema changes.

### If you already have a local `ai_diary.db`

**Back it up before upgrading.** This initial migration creates `journal_entries`, so it will fail against an existing database where that table was previously created automatically.

For a throwaway demo DB, you can remove the old SQLite file and run `alembic upgrade head` to create a new one; **this deletes your previous entries**.

For a DB containing data you want to keep, verify the existing schema exactly matches `backend/alembic/versions/20261011_01_create_journal_entries.py`, back up the DB, then use `alembic stamp head` to record the baseline without recreating the table. Do not stamp an incompatible schema.

## 4. Tests and future schema changes

```bash
pytest -q
alembic check
```

The tests create a separate temporary SQLite database and apply migrations before calling API endpoints. Run `alembic check` against a database already upgraded to head.

When changing SQLAlchemy models:

```bash
alembic revision --autogenerate -m "describe your schema change"
# Review the generated migration before applying!
alembic upgrade head
pytest -q
```

Never use `Base.metadata.create_all()` in the application startup path once Alembic is adopted.

## Planned next PRs

- Agree user/account model and authorization before multi-user diary access
- Journal save contract, AI Reflection persistence, Album save behavior
- Streak computation from distinct journal calendar days
- Real AI provider integration (backend-only secrets, no keys in Flutter)

These decisions must match the final UI contract before implementation.
