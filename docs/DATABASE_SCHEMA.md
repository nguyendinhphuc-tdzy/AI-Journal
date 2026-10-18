# Database Schema — MVP v1 (design contract, NOT deployed)

**Status:** Approved product scope; proposed database design (B01). This document does **not** mean tables, API endpoints, auth, or security policies have been implemented.

**Database:** Supabase PostgreSQL 17; schema `public`; migrations owned by FastAPI/SQLAlchemy/Alembic. Supabase Auth owns `auth.users` and passwords. User-owned application rows are accessed through authenticated FastAPI endpoints, **not** through direct client Postgres connections. SQLite remains for isolated backend tests.

## Already deployed (migration `20261011_01`)

`public.journal_entries`: `id integer PK`, `title varchar(160) NOT NULL`, `content text NOT NULL`, `prompt varchar(500) NULL`, `mood varchar(64) NULL`, `created_at timestamptz NOT NULL`, `updated_at timestamptz NOT NULL`. No `user_id` yet. `alembic_version` tracks Alembic revisions. Do **not** assume this table already protects private journals.

## Proposed entity relations

```text
auth.users (Supabase Auth, UUID id)
  |-- 1:1 user_profiles (user_id)
  |-- 1:N journal_entries (user_id)
  |-- 1:N journal_action_days (user_id, activity_date)
  +-- 1:N saved_places (user_id)
                  |-- 1:N place_notes (place_id, user_id)
                  +-- M:N journal_entries via journal_places
```

### 1. `user_profiles` — B02

| Column | Type | Constraint / semantics |
|---|---|---|
| `user_id` | UUID | Primary key; FK `auth.users(id) ON DELETE CASCADE` |
| `display_name` | varchar(100) | Nullable |
| `timezone` | varchar(64) | NOT NULL; default `Asia/Ho_Chi_Minh`, validated against IANA timezone database in backend |
| `created_at` | timestamptz | NOT NULL; UTC |
| `updated_at` | timestamptz | NOT NULL; UTC |

Never store passwords, refresh tokens, provider secrets, or plaintext credentials in this table. A user profile is inserted idempotently on first authenticated use (and can later be updated by its owner). User identity is exclusively the verified token subject (`sub`), not a client-supplied `user_id`.

### 2. `journal_entries` — B04 (extends deployed table)

**Keep** existing integer `id`, `title`, `content`, `prompt`, `mood`, `created_at`, `updated_at` and API-visible field names. Add:

| Column | Type | Constraint / semantics |
|---|---|---|
| `user_id` | UUID | NOT NULL after safe backfill; FK `auth.users(id) ON DELETE CASCADE` |

Indexes: `(user_id, created_at DESC, id DESC)`; `(user_id, mood)` if filtering warrants it. Add `UNIQUE (id, user_id)` to support same-owner composite foreign keys from `journal_places`. Search on title/content may initially be `ILIKE` with user filter; add efficient full-text indexing only after measuring.

**Migration rule for existing data:** add `user_id` nullable, inspect rows, then assign ownership only with an explicit, verified migration mapping. **Never** assign all old diaries to the first account, fabricate ownership, or delete records automatically. Abort the NOT NULL/owner migration if unmapped entries remain. The currently inspected development database had zero journal entries, but migrations must not assume every environment is empty.

### 3. `journal_action_days` — B06 (supersedes `app_open_days`)

| Column | Type | Constraint / semantics |
|---|---|---|
| `user_id` | UUID | PK part; FK `auth.users(id) ON DELETE CASCADE` |
| `activity_date` | date | PK part; server-derived user-local date of successful journal writing |
| `first_completed_at` | timestamptz | UTC timestamp of the first successful writing action |
| `action_type` | varchar(32) | NOT NULL; `journal_written` in MVP v1 |

Primary key `(user_id, activity_date)` is the uniqueness guarantee. Use atomic `INSERT ... ON CONFLICT DO NOTHING` within the **same transaction** as the successful owned Journal write. The row records achievement history independent of the source journal, so deleting a journal later does not remove credit.

**Updated streak product semantics (approved 2026-10-18):**
- An authenticated user completes a day only by **creating a nonblank journal** or **changing the nonblank `content` of an owned journal** and successfully saving it; even one written line counts.
- App open, foreground resume, login, viewing/deleting journals, metadata-only edits, unchanged-content resubmission and failed saves do **not** count.
- Repeated or concurrent valid saves for the same user-local date count once; DB uniqueness handles races.
- `current_streak` counts consecutive days ending today, or ending yesterday when today has not yet been completed; otherwise it is zero.
- `longest_streak` counts the longest uninterrupted historical sequence, even if the current streak is zero.
- The server clock and verified profile timezone determine dates; no client-supplied date or offline backdating.
- Timezone changes do not rewrite previously recorded dates.
### 4. `saved_places` — B09

| Column | Type | Constraint / semantics |
|---|---|---|
| `id` | integer | Primary key |
| `user_id` | UUID | NOT NULL; FK `auth.users(id) ON DELETE CASCADE` |
| `label` | varchar(160) | NOT NULL; user-defined name |
| `latitude` | numeric(9,6) | NOT NULL; CHECK from -90 to 90 |
| `longitude` | numeric(9,6) | NOT NULL; CHECK from -180 to 180 |
| `address_text` | text | Nullable; **user-entered** address/description |
| `provider` | varchar(32) | NOT NULL: `manual` or `geoapify` initially |
| `external_place_id` | text | Nullable for manually dropped pins |
| `created_at`, `updated_at` | timestamptz | UTC, NOT NULL |

Indexes: `(user_id, created_at DESC, id DESC)`; B09 implements a partial unique `(user_id, provider, external_place_id)` where `external_place_id IS NOT NULL` to prevent duplicate provider-defined places. Coordinates are checked in Pydantic **and** by PostgreSQL CHECK constraints. Add `UNIQUE (id, user_id)` for composite ownership foreign keys.

**Provider-neutral schema:** use `provider` and `external_place_id`, never a `google_place_id` dependency. MapLibre/OpenFreeMap is for rendering, **not** for place searches. Geoapify can be used for search later; never persist a whole third-party API response unless its retention terms permit it. Attribution and service terms must be respected.

### 5. `place_notes` — B10

| Column | Type | Constraint / semantics |
|---|---|---|
| `id` | integer | Primary key |
| `place_id` | integer | NOT NULL |
| `user_id` | UUID | NOT NULL |
| `content` | text | NOT NULL; non-blank validated by API |
| `created_at`, `updated_at` | timestamptz | UTC, NOT NULL |

Composite FK `(place_id, user_id) -> saved_places(id, user_id) ON DELETE CASCADE`. Index `(user_id, place_id, created_at DESC, id DESC)`. Multiple notes per place; deleting a saved place deletes its notes, **not** its journals. Derive `user_id` from verified auth context.

### 6. `journal_places` — B10

| Column | Type | Constraint / semantics |
|---|---|---|
| `user_id` | UUID | NOT NULL; verified owner |
| `journal_id` | integer | NOT NULL |
| `place_id` | integer | NOT NULL |
| `created_at` | timestamptz | UTC, NOT NULL |

Primary key `(user_id, journal_id, place_id)`; FK `(journal_id, user_id) -> journal_entries(id, user_id) ON DELETE CASCADE`; FK `(place_id, user_id) -> saved_places(id, user_id) ON DELETE CASCADE`. Add index `(user_id, place_id)` for retrieving journals from a marker. Database constraints and FastAPI both reject cross-user links. Unlinking does **not** delete the journal or saved place.

## Security / RLS acceptance gate

**Known present-day risk:** Supabase's public schema inspection reports Row Level Security (RLS) **disabled** on both `journal_entries` and `alembic_version`. Existing FastAPI journal routes also have **no user ownership filter**. The current demo must not accept real sensitive entries or run publicly.

Before any multi-user/private data:
1. Implement Supabase JWT verification (signature, issuer, audience, expiry, subject) in FastAPI and enforce `user_id` on **every** personal-data query and write.
2. Enable RLS for user-owned `public` tables (defense in depth) and explicitly choose **deny direct anon/authenticated access** when FastAPI is the only data gateway; alternatively, if direct Supabase client data access is later approved, define tested owner-only RLS policies using `auth.uid()`.
3. Review access grants / RLS for `alembic_version`, which should not be client-accessible. Applying RLS without policies can break direct client queries, so coordinate it with the auth release.
4. Validate real PostgreSQL authorization and foreign keys, not just SQLite mocks; production database roles may bypass RLS, so RLS is **not a replacement** for FastAPI ownership filtering.

**Do not apply RLS or migrations as part of B01**; changes must be reviewed and delivered as Alembic migrations in later PRs.

## Migration order (not executed in B01)

- **B02:** `user_profiles`; JWT auth and `/me`; consider baseline RLS/grants for deployed journal/alembic tables before exposure.
- **B04:** safely backfill/protect `journal_entries.user_id`; ownership indexes and authorization.
- **B06:** `journal_action_days` + completed-writing streak logic.
- **B09:** `saved_places` migration `20261018_05`, coordinate/ownership CHECK and indexes, private API, optional Geoapify autocomplete (backend key only).
- **B10:** `place_notes`, `journal_places`, composite owner FKs, delete behavior.
- **B13:** PostgreSQL staging migration, RLS grants and A/B cross-user authorization tests.

Excluded from MVP v1 schema: images, voice transcription, saved AI reflection, reminders, Study progress, public map sharing, background GPS tracking, offline backfill.