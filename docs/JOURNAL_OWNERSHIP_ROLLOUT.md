# B04 — Journal ownership rollout and review checklist

**Status:** code prepared on `feat/backend-journal-ownership`; NOT merged or deployed.

**PR dependency chain:** B01 `docs/mvp-backend-contracts` (#7) → B02 `feat/backend-auth-profiles` (#8) → B04 `feat/backend-journal-ownership` (stacked PR). The repository's actual base is `setup/initial-import`. Never merge a stacked PR out of dependency order; Phúc reviews and merges every PR manually.

## What changes in B04

- Extends existing `journal_entries` with **NOT NULL `user_id`** (Supabase `auth.users.id` UUID, real PostgreSQL FK with `ON DELETE CASCADE`).
- Adds `UNIQUE(id, user_id)` to support forthcoming same-owner `journal_places` composite foreign key.
- Owner index on `(user_id, created_at, id)` for private archive pagination.
- Replaces the temporary B02 journal gate (401 unauthenticated; 503 all authenticated) with owner-scoped authenticated journal CRUD. Requests cannot specify `user_id`.
- Changes `GET /api/v1/journals` from an **array** (v0.1) to `{"items":[...],"next_cursor":null}` (MVP v1). Supports `limit` (1–100), opaque cursor, optional `mood`, `from`/`to` profile-local dates, and text search `q`. Client integration (B05) MUST coordinate this breaking response change.
- Every journal detail/update/delete checks `(journal_id,user_id)` and returns 404 on cross-user access.

## Legacy rows — fail closed, never auto-adopt

**Migration `20261018_03` refuses to run if `journal_entries` contains ANY rows.** A legacy entry has no verified owner, so B04 will never assign it to the first account, invent an owner, or delete it.

If an environment contains older entries, first review them privately and create a **separately approved manual mapping** to existing verified `auth.users.id` UUIDs, then adapt the migration to add the nullable column, backfill using the reviewed mapping, validate no unowned rows and only then enforce NOT NULL / composite constraints. Do not use this empty-only migration directly on that environment.

For the current AI-Journal-Dev shared project, at read-only inspection on 2026-10-18: `journal_entries` has **0 rows**, revision `20261011_01`. **Neither B02 nor B04 migration has been run on Supabase**. Check again immediately before rollout; counts can change.

## Local verification (safe)

Run from an isolated B04 working tree. Use `backend/.venv` but do not copy the shared Supabase `.env` into test environments if unnecessary:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m pytest -q
python -m alembic heads
```

The automated API tests use temporary **SQLite** and synthetic identity objects; they do not query Supabase. The migration safety regression creates an independent temporary SQLite database and verifies an ownerless row stays untouched.

Do not run `python -m alembic upgrade head` while reviewing this PR: it would apply B02 and B04 to the configured database, including the security grant/RLS changes.

## Before approving deployment (must be done separately)

1. B01 and B02 reviewed, tested and merged in order; B04 retargeted from B02 to `setup/initial-import` after its predecessors merge.
2. Resolve actual Supabase asymmetric JWT signing configuration; verify real tokens on staging.
3. Confirm correct PostgreSQL project/credentials and check **real** journal row count immediately before migration.
4. Run migration against disposable **PostgreSQL** staging (not just SQLite), verify the auth.users FK, index and RLS behavior.
5. Verify endpoint isolation using two real Supabase test accounts; invalid/missing tokens → 401; cross-owner access → 404; owner data persists across login/restart.
6. Review Flutter B05 integration for the paginated list shape. Until then, do not update backend deployed to clients expecting a bare list.
7. Revisit rollback plan: B04 downgrade deliberately refuses to remove owner boundaries to avoid making private journals public. Recovery requires a reviewed plan/backup.

**Known active risk in production-like development baseline:** `journal_entries` and `alembic_version` presently have RLS disabled and the base journal endpoints have no authorization. Do not expose them publicly or store personal diaries before the authenticated authorization hardening is actually deployed. B02 migration proposes enabling RLS and revoking direct client privileges; B04 keeps RLS enabled; neither has been applied yet.
