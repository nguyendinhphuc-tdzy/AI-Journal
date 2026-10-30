# B14 — Journal Cloud runtime integration (27 October 2026)

## Implementation status

The integration branch `integration/journal-cloud-runtime-20261027` combines:

- **Backend Phase 2:** the full backend tree of `feat/backend-journal-cloud-contract-20261026` (PR #26), including Alembic migration `20261026_08`, private FastAPI CRUD, guided snapshots and body-version management.
- **Flutter Phase 2:** `feat/flutter-journal-cloud-persistence-20261026` (PR #27), including Supabase Auth, `RemoteJournalRepository`, local drafts and optional AI.
- **Supabase AI-Journal-Dev:** migration `20261026_08` was applied on 26 October, schema/RLS checked. **Do not reapply it** or fake Alembic revision.
- **User direction:** skip further manual E2E testing at this stage. Accordingly this integration **has not been validated on the user's Windows PC/Android Emulator**. Code and database readiness are distinct from operational acceptance.

The branch is review-only: **nothing was merged into the repository's default branch or either original PR**, and `JOURNAL_CLOUD_ENABLED` is still false unless explicitly passed at app launch.

## Step 1 — checkout both parts together (Windows PowerShell)

```powershell
cd C:\Users\PC\Documents\AI-Journal
git fetch origin
git worktree add --detach ..\AI-Journal-Cloud origin/integration/journal-cloud-runtime-20261027

cd ..\AI-Journal-Cloud\backend
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt

# Reuse the already-rotated PRIVATE credentials on this machine:
Copy-Item C:\Users\PC\Documents\AI-Journal-DB\backend\.env .\.env
notepad .env
```

The local `backend/.env` must include:

```dotenv
APP_ENV=development
DATABASE_URL=postgresql+psycopg://<USER>:<URL_ENCODED_PASSWORD>@<SESSION_POOLER_HOST>:5432/postgres?sslmode=require
SUPABASE_URL=https://rjwentsuqmwncpseakkt.supabase.co
AI_PROVIDER=mock
```

Use the *real* connection string already configured privately. The `<...>` text is illustrative, not usable configuration. **Do not share or commit database credentials**. If `MIGRATION_DATABASE_URL` is present but points at an unreachable IPv6 Direct endpoint, remove it or correct it to the same reviewed target: the runtime launcher checks Alembic revision through that URL.

Ensure Supabase Auth access tokens use **ES256 or RS256** signing keys (not HS256), because FastAPI intentionally rejects legacy HS256. Flutter uses only the public Supabase publishable key; never copy Postgres passwords or JWT secrets into mobile files.

## Step 2 — start FastAPI (PowerShell window 1)

```powershell
cd C:\Users\PC\Documents\AI-Journal-Cloud
powershell -ExecutionPolicy Bypass -File .\scripts\start_journal_cloud_backend.ps1
```

The launcher checks Alembic current revision is exactly `20261026_08` (read-only) and **refuses to start** on another revision. It binds `127.0.0.1:8000` only. It does NOT run `alembic upgrade head` or mutate Supabase.

Local Swagger: `http://127.0.0.1:8000/docs`; local health endpoint: `http://127.0.0.1:8000/health`.

## Step 3 — start Flutter (PowerShell window 2)

```powershell
cd C:\Users\PC\Documents\AI-Journal-Cloud
Copy-Item .\mobile\journal_cloud.example.json .\mobile\.env.journal-cloud.json
notepad .\mobile\.env.journal-cloud.json
```

Replace `REPLACE_WITH_PUBLISHABLE_KEY` with the **Supabase publishable key** from the project dashboard (never a service_role/secret key). The `mobile/.env.journal-cloud.json` path is Git-ignored.

With an Android Emulator running:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start_journal_cloud_mobile.ps1
```

The Flutter launcher only accepts emulator URL `http://10.0.2.2:8000/api/v1` and project `rjwentsuqmwncpseakkt` to avoid accidental use of another server. The code explicitly opts into `AUTH_ENABLED=true` and `JOURNAL_CLOUD_ENABLED=true`.

**Physical Android devices cannot use `10.0.2.2`; this script is emulator-only.** Local plain HTTP must never be used to expose private journal traffic over public networks; use HTTPS for any deployment.

## What changes and what does not

- Verified signed-in Supabase sessions with **no existing local Journal entries** use FastAPI `/api/v1/journals` for cloud CRUD.
- Signed-in accounts with local entries continue to use device storage. **No existing local journal is silently uploaded, deleted, or hidden.**
- Guest and fake-auth sessions always stay local. Auto-saved drafts stay local even during cloud use; a server failure never claims a successful save.
- JWT is verified by FastAPI before any private Journal CRUD. IDs are owner-scoped on the backend.
- This is **not** full automatic local↔cloud synchronization: no offline queue, no historical import UX, no cross-device drafts, no edit conflict resolution and no exactly-once create retry.
- Current backend defaults to `AI_PROVIDER=mock`. Ollama integration is a **separate future task**; don't confuse cloud journal storage with live AI.

## Release gates / intentionally deferred

The user opted to skip more test execution here. That does not establish that Android↔FastAPI↔Supabase operation is E2E-verified. PR review, merging stacked prerequisites in the correct order, real JWT configuration and later device validation remain outstanding before production use. Only use non-sensitive demo journals until the integration has actually been exercised end to end.

The backend PR chain remains #19 → #25 → #26, the Flutter PR chain #21 → #23 → #24 → #27, and this combined integration branch is staged separately.
