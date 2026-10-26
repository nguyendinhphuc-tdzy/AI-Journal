# AI Journal — Phase 1 database readiness (26 October 2026)

## Actual Supabase project observed

Project: `AI-Journal-Dev`, reference `rjwentsuqmwncpseakkt`
(PostgreSQL 17.11). Read-only inspection on 2026-10-26 found:

| Gate | Observed | Implication |
|---|---|---|
| `public.alembic_version` | `20261011_01` | Six later revisions are not deployed |
| `public.journal_entries` | 0 rows | B04 owner migration is unblocked **at inspection time** |
| `auth.users` | 0 rows | Facebook/email login not yet recorded at inspection |
| `public` base tables | `journal_entries`, `alembic_version` | Profile / streak / places / albums not deployed |
| RLS | Enabled on both base tables | Client-side access currently denied |
| Direct SELECT by anon/authenticated | Revoked for both | Continue backend-only private data access |
| `public.journal_entries_id_seq` | Exists, no client USAGE | B02 sequence revoke is valid |
| Security Advisor | `rls_enabled_no_policy` INFO (two base tables) | Expected for backend-only role access |

These are time-specific observations; rerun before any deployment. No SQL
writes or schema migrations were made during the inspection.

## Repository migration chain

| Revision | Target |
|---|---|
| `20261011_01` | Existing Journal baseline |
| `20261018_02` | `user_profiles`, Auth FK and client lock-down |
| `20261018_03` | Require journal `user_id`; reject existing unowned rows |
| `20261018_04` | `journal_action_days` |
| `20261018_05` | `saved_places` |
| `20261018_06` | `place_notes`, `journal_places` |
| `20261025_07` | `albums`, `album_memories` (PR #19) |

**Important:** The `20261025_07` migration belongs to the *draft*
backend Album PR #19, not the default branch. The code used in a real
migration run must include PR #19 first. Do not run `alembic upgrade head`
from a stale backend checkout that does not contain this revision.

### Preconditions and known risks

1. `20261018_03` intentionally raises if any legacy journal rows exist;
   never rewrite old entries to the first registered user.
2. Later revisions have deliberately disabled destructive `downgrade()`
   paths. **Do not assume Alembic downgrade is a recovery strategy.**
3. Because the new tables are foreign keyed to `auth.users`, Supabase-managed
   `auth.users` must remain the source of identity.
4. `anon` and `authenticated` must not receive grants on private tables.
   The FastAPI PostgreSQL role needs sufficient direct SQL privileges and
   a tested owner-scoping strategy.
5. The source has been run in disposable PostgreSQL CI with synthetic
   `auth.users`, but a real Supabase project's extensions, roles, grants
   and existing RLS state differ. The updated integration fixture first
   reproduces the exact public-table / revision baseline before upgrading.
6. `alembic_version` is Alembic's own version table. Running migration SQL
   manually through the Supabase SQL Editor without recording the revisions
   correctly will desynchronize the application and its migration history.

## Fast, FREE preflight command (read-only)

Use this PR's backend directory and a private untracked `.env`
containing `DATABASE_URL` or `MIGRATION_DATABASE_URL`. For production
migration, the URL must point to a role authorized for schema changes.
Do not paste its username/password in chat or commit it.

```powershell
cd backend
python -m pip install -r requirements.txt
python -m scripts.phase1_preflight --project-ref rjwentsuqmwncpseakkt
python -m alembic heads
```

Expected pass:

```text
Expected migration: 20261011_01 -> 20261025_07
Current migration: 20261011_01
Public tables: alembic_version, journal_entries
Journal row count: 0
...
PREFLIGHT PASS: schema matched reviewed baseline.
NO MIGRATIONS APPLIED.
```

The preflight refuses a non-Postgres URL or a DSN whose host/username does
not identify this Supabase project. It opens a PostgreSQL **READ ONLY**
transaction; it does not save, delete, migrate or export personal content.

## No subscription required for a manual logical backup

The Supabase Free Dashboard does not supply paid daily restore/PITR,
but Supabase's official documentation supports manual `supabase db dump`
for Free projects. To avoid secret leakage, do not type the DB password into
a shared terminal transcript or the PR, and do not send the dump to GitHub.

On your own Windows machine, see:

- https://supabase.com/docs/guides/platform/backups
- https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore

Use `supabase db dump --help` to confirm current CLI syntax before dumping.
A locally encrypted logical SQL export is not automatic point-in-time
recovery; restoring it requires a verified manual procedure. Do not drop or
reset any existing Supabase-managed schemas while restoring.

## The migration step is NOT authorized by CI alone

After GitHub PostgreSQL CI passes on this PR and a new read-only preflight
reports PASS:

1. Confirm correct branch/revision, schema owner role and network access.
2. Decide and document how to recover if a migration partially fails,
   especially because destructive Alembic downgrades are disabled.
3. Obtain specific approval for a shared-database migration run.
4. Run `python -m alembic upgrade head` **once using an approved, private
   PostgreSQL connection from the backend checkout**, not from SQL Editor.
5. Immediately verify:
   - `SELECT version_num FROM public.alembic_version` is `20261025_07`.
   - expected `user_profiles`, `journal_action_days`, `saved_places`,
     `place_notes`, `journal_places`, `albums`, `album_memories`.
   - RLS enabled on all private tables.
   - `anon` / `authenticated` have no direct table reads/writes.
   - backend JWT/owner-isolation integration tests pass.
   - no real journal data used until all gates are green.

### Scope of Phase 1 PR

- Includes preflight script and unit tests.
- Extends disposable PostgreSQL 17 migration test from a clean bootstrap to
  an **already deployed 20261011_01 plus existing RLS/grant** scenario.
- No database write has been made to `AI-Journal-Dev`; this is staged
  deployment preparation only.
- Does not merge PR #19/#22/#23/#24 or activate new Supabase tables.
