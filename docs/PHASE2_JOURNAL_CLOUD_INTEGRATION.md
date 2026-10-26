# Phase 2 — AI Journal Cloud Persistence (Draft, 2026-10-26)

## Status and dependencies

- Backend: Draft PR #26 (`feat/backend-journal-cloud-contract-20261026`)
  stacked on Phase 1 PR #25 and Album backend PR #19.
- Mobile: Draft PR #27 (`feat/flutter-journal-cloud-persistence-20261026`)
  stacked on Auth/Facebook PR #24.
- **Supabase AI-Journal-Dev is now at Alembic `20261026_08`.**
  The team explicitly authorized and applied the additive migration on
  2026-10-26. Its columns, check constraint and RLS were verified.
  **Do not apply the migration a second time.**
- Default `JOURNAL_CLOUD_ENABLED=false`: existing app remains local-only.
- All guest sessions, fake-auth test sessions and accounts with existing
  local Journal entries remain local-only even if the cloud flag is enabled.
- Local drafts (`SharedPreferences`, scoped by user) are NEVER transmitted
  by the repository. No existing local entries are silently uploaded or
  deleted. Plan a separate explicit user-approved import experience.

## Contract

Flutter `JournalEntry` ↔ FastAPI `/api/v1/journals`:

| Flutter | FastAPI / PostgreSQL | Notes |
| --- | --- | --- |
| `id: "cloud-42"` | `id: 42` integer | ID prefix prevents collisions with `local-...` |
| `content.body` | `content` | Nonblank, validated server-side |
| `content.mood?.name` | `mood` | Known six enum names; reject unknown values |
| `content.guided.toJson()` | `guided` JSON | Snapshot `{id,version,fields}` preserved |
| `bodyVersion` | `body_version` | Server-owned, starts at 1 |
| `createdAt/updatedAt` | `created_at/updated_at` | Server timestamps in UTC |

Body version increases if body text, mood or guided structure changes; it
does not increase for a no-op or title/prompt-only edit. Only actual text
changes count toward the completion streak. Clients cannot set
`body_version` or `user_id`.

API calls: `GET /journals` (100-row cursor pages), `GET /journals/{id}`,
`POST /journals`, `PUT /journals/{id}`, `DELETE /journals/{id}`.
Private endpoints demand a fresh Supabase Bearer access token before any HTTP
request. Remote repository errors never silently return a local/mock diary.

## Backend migration 08 — release guard

The shared project was already upgraded from `20261025_07` to
`20261026_08` via an authorized transaction; do not rerun Alembic upgrade
on it. The **combined** runtime integration branch is
`integration/journal-cloud-runtime-20261027`. Use
`docs/B14_JOURNAL_CLOUD_RUNTIME_20261027.md` to set up the Windows
FastAPI and Android Emulator launchers. Private credentials stay only in
ignored local `.env`; startup revision checks are read-only.

The migration adds `guided JSON NULL`, `body_version INTEGER NOT NULL
DEFAULT 1` and a CHECK enforcing version >= 1. It does not drop or rewrite
existing journal contents. Legacy journals receive version 1. Downgrade is
intentionally disabled because it would lose guided values.

After authorized migration, inspect the live version (`20261026_08`),
columns and constraints, 9 private tables' RLS/grants and schema advisor
results. Do NOT manually fake or edit `alembic_version`. Never commit
PostgreSQL passwords or configure PostgreSQL access from Flutter.

## Android emulator acceptance

Start FastAPI locally from the backend Phase 2 branch and verify
`GET http://127.0.0.1:8000/health`. For Android Emulator, use
`--dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1`.
A physical phone needs a different, reachable backend URL; do not assume
`10.0.2.2` works there.

Once the migration is verified, run Flutter with these `--dart-define`
flags:

- `AUTH_ENABLED=true`
- `JOURNAL_CLOUD_ENABLED=true`
- `SUPABASE_URL=https://rjwentsuqmwncpseakkt.supabase.co`
- `SUPABASE_PUBLISHABLE_KEY=<publishable key>`
- `API_BASE_URL=http://10.0.2.2:8000/api/v1`
- `FACEBOOK_OAUTH_ENABLED=true` only if the Facebook Meta/Supabase
  provider setup is ready for test users.

**Future release acceptance sequence (deferred by user request to skip further tests now):**

1. Login to account A; new account, no local entries; write one
   Guided Journal; verify server `guided` and version 1.
2. Restart Android; log in as A; verify original journal reloads.
3. Edit its text/mood/guided values; verify server version increments,
   the same id is preserved and streak only follows writing.
4. Interrupt backend before save; verify the unsent draft is still available
   on device and no fabricated success is shown.
5. Logout and log in as account B; verify B cannot read or mutate A's
   journal (HTTP 404 for direct owned-resource URLs).
6. Confirm guest mode never makes journal API calls and device entries
   created before enabling Cloud remain on device.
7. Test cursor pagination, Android process death and re-login.

## Known limitations for follow-up PRs

- No automatic guest/account local-to-cloud migration, offline sync queue,
  edit conflict resolution or guaranteed exactly-once create retry.
- Signed-in accounts with existing local entries intentionally remain local
  until a deliberate import/sync design exists.
- Drafts are device-only and are not cross-device synced.
- A full end-to-end Android + running FastAPI + real Meta/Supabase Auth
  session is still required before enabling Cloud in a release.
- Backend PR #26 and Flutter PR #27 already passed their original CI jobs.
  PR #28 contains both codebases and runtime launchers on a single
  integration branch, still unmerged. No direct merge to the default branch
  was performed.
