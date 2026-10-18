# B13 — Backend integration, privacy and migration acceptance plan

**Status:** Test code and CI staged in PR B13. **No application PR has merged or been deployed.** This document is a release gate, not approval to run migrations against AI-Journal-Dev.

## Dependency / Git policy

Stacked PR order: **#7 B01 → #8 B02 → #9 B04 → #10 B06 → #11 B09 → #12 B10 → B13**. Actual project base is `setup/initial-import`, never `main`. Contributors do not create/merge branches without permission. **Only Phúc reviews and merges PRs, manually in order.** Rebase/retarget subsequent stacked PRs and review the diff after each merge. B13 does not merge code.

## Matrix

| Gate | Expected result | Implemented test/workflow |
|---|---|---|
| JWT authentication | ES256/RS256 valid issuer/audience/sub/exp signed token passes; missing/wrong/HS256/expired token fails 401 | `backend/tests/test_auth_security.py` |
| Anonymous access | `/me`, `/journals`, `/streak`, `/places`, notes & link endpoints reject missing Bearer | `backend/tests/test_api.py`; PostgreSQL TestClient |
| Owner isolation | User A cannot GET/PATCH/DELETE user B's journal, location or notes, cannot link mixed ownership | SQLite tests + PostgreSQL TestClient and **composite owner FKs** |
| Journal migration | Legacy ownerless entries are preserved; B04 refuses migration without verified owner mapping | `test_journal_migration_safety.py` |
| Action-based streak | Saving meaningful journal content counts once per user-local day; app open, notes, links, metadata-only updates never count | `test_api.py`; date/timezone & transaction rollback |
| Map pins / Geoapify | Manual pins need no provider key; bad coordinates rejected; provider errors sanitized; rate limited | `test_api.py`, mocked HTTP only |
| Multiple place notes | Validate nonblank content, pagination, A/B isolation, update/delete | `test_api.py` |
| Journal↔Place | Idempotent links; FK prevents cross-owner rows; delete place cascades notes/links not journal; delete journal doesn't delete place | `test_api.py`; `test_postgres_integration.py` |
| PostgreSQL DDL | All Alembic revisions `20261011_01 → 20261018_06` apply cleanly, real `auth.users` FKs, unique indexes and CHECK constraints | `test_postgres_integration.py` on disposable Postgres 17 |
| RLS + Data API grants | Every public application table, including `alembic_version`, has RLS enabled and direct anon/authenticated table privileges denied | `test_postgres_integration.py` |
| CI | Both SQLite JWT/API job and PostgreSQL 17 job pass without a secret or live Supabase DB URL | `.github/workflows/backend-security.yml` |

## How to run safely

### 1. Pure local SQLite/JWT tests (no Supabase access)

From a clean B13 checkout:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
$env:DATABASE_URL="sqlite:///./b13_ci_only.db"
$env:MIGRATION_DATABASE_URL="sqlite:///./b13_ci_only.db"
python -m pytest -q tests
python -m alembic heads
```

Do **not** run Alembic `upgrade head` with the shared Supabase `.env`; `heads` does not modify database.

### 2. Real PostgreSQL CI tests (on throwaway GitHub Actions service)

GitHub Actions `backend-postgres` job starts disposable `postgres:17` with **database name `ai_journal_b13_ci`**, creates a minimal mock `auth.users` and `anon`/`authenticated` roles only within CI, then applies migrations to that service and tests roles, constraints and API owner isolation.

`test_postgres_integration.py` **refuses to connect** unless `B13_POSTGRES_TEST_URL` is exactly PostgreSQL `postgres@localhost:5432/ai_journal_b13_ci` (or loopback IP). A Supabase/pooler URI will fail **before** opening a connection. CI does not use/require Supabase credentials, JWT signing secrets or Geoapify API keys.

For reproducibility without the GitHub service, start an *isolated* local PostgreSQL 17 container with the same `ai_journal_b13_ci` database and `postgres` user, set `B13_POSTGRES_TEST_URL` to its localhost URI, and run:

```powershell
python -m pytest -q tests/test_postgres_integration.py
```

**Never** point test env variables to `AI-Journal-Dev`, `*.supabase.co`, direct Supabase IP addresses or an actual developer database.

### 3. What remains before release

- [ ] Full SQLite unit suite **actually passes** on fresh branch/CI; do not count merely writing tests as validation.
- [ ] PostgreSQL disposable service **actually passes** migrations and constraint tests.
- [ ] Verify Supabase project JWT signing key algorithm and run real Supabase Auth user A/B tests against a **separately approved staging instance**, not an unreviewed production/shared database.
- [ ] Review RLS policy/role grants carefully. Backend connects with elevated PostgreSQL roles and may bypass RLS: FastAPI owner filtering is still mandatory. Confirm Data API behavior with anon/authenticated client roles.
- [ ] Inspect `alembic check` autogeneration consistency on disposable Postgres, and decide any differences in a **new migration**, never by editing a deployed migration silently.
- [ ] Resolve provider rate-limit and Geoapify storage/attribution/licensing before public rollout.
- [ ] Verify Flutter B03/B05/B07/B08/B11/B12 contract integration, breaking Journal paged-list response, and MapLibre lifecycle.
- [ ] Back up shared database and inspect `journal_entries` for any pre-existing ownerless rows immediately before any **explicitly authorized** migration on shared Supabase.

## Current shared Supabase safety state (read-only snapshot)

Supabase `AI-Journal-Dev` (project ref `rjwentsuqmwncpseakkt`) previously had only `journal_entries` and `alembic_version`, Alembic `20261011_01`. **RLS is disabled on both tables** and legacy journal routes have no user ownership controls. This is a critical privacy blocker. Do **not** expose them publicly or store real private diaries. B02 proposes RLS/grants hardening but is currently unmerged and unapplied. B13 CI intentionally does **not** change these shared tables.

### If owner explicitly authorizes RLS fix later

Do **not** run this automatically. Review whether clients should query tables directly or exclusively through FastAPI. Example baseline SQL proposed for owner review, not executed:

```sql
ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alembic_version ENABLE ROW LEVEL SECURITY;
```

With no policies, direct authenticated/anon data reads/writes will be denied. Review database grants and whether any tooling assumes client access before changing it. FastAPI must independently enforce verified JWT ownership.
