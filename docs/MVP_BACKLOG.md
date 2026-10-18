# AI-Journal MVP Backend — PR backlog (B01–B13)

**Base branch:** `setup/initial-import` (NOT `main`). **Backend owner and merger:** Phúc. Only Phúc approves and merges. **Trâm currently leads Flutter Explore/MapLibre**; Vy maintains her assigned Study/Challenge UI. Agree any extra Flutter ownership before assigning tasks; the backend owner does not silently edit other members' Flutter feature files.

## Current baseline and boundaries

- Deployed Supabase **AI-Journal-Dev** project (Singapore) has revision `20261011_01`: journal_entries and alembic_version only; original journal CRUD still lacks auth/ownership.
- Open PR #4: CI; #5: Vy Study; #6: Trâm Journal/Home/Profile. They are **not merged** at time of B01 preparation. Coordinate changes to files touched by #6.
- No new database tables, RLS policies, FastAPI routes, Flutter packages or Supabase secrets are added in **B01**.
- One feature PR at a time per changed surface. New backend work uses Phúc-owned feature branches; Trâm and Vy do not make random branches or merge.

| ID | Owner | Dependency | Deliverable | Acceptance gate |
|---|---|---|---|---|
| **B01** | Phúc | None | schema, API contract, ADR, architecture, MapLibre setup and backlog docs | Documentation matches decisions and live repo; no DB writes |
| **B02** | Phúc | B01 | JWT verification, profile table/endpoint, auth gates, RLS/grant plan | valid/invalid tokens tested; personal data closed to anonymous requests |
| **B03** | Flutter assignee coordinated by Phúc | B02 | email/password UI and session integration | login/restore/logout/token attachment on emulator |
| **B04** | Phúc | B02 | safe journal user_id migration + ownership-filtered archive API | A cannot read/write B; legacy records handled safely; PostgreSQL tests |
| **B05** | Flutter assignee coordinated by Phúc | B03+B04+PR #6 | Journal API integration and archive UI | save/restart/load/edit/delete; errors preserve draft |
| **B06** | Phúc | B02+B04 | journal_action_days table, journal-save action hook, read-only streak API | no credit for opens; per-day once; timezone and rollback tests |
| **B07** | Flutter assignee coordinated by Phúc | B03+B06 | read-only streak UI after completed Journal save | writing counts, opening app does not |
| **B08** | Trâm | B01; PR #6 coordinated | MapLibre/OpenFreeMap on Explore, pan/zoom/drop pin | emulator map renders without Google key; no new secrets |
| **B09** | Phúc | B02+B01 | saved_places CRUD + optional Geoapify address autocomplete | manual pins without a key, provider results, JWT A/B isolation and quotas |
| **B10** | Phúc | B04+B09 | multiple notes & journal-place link tables/APIs (staged PR) | composite owner FK on both sides, many notes, many-to-many, safe deletes |
| **B11** | Trâm | B03+B08+B09+B10 | MapLibre saved markers, location search, note editor | persist across re-login, no cross-user data |
| **B12** | Flutter assignee coordinated by Phúc | B05+B10+B11 | Journal↔Place linking UI | navigate both directions, unlink nondestructively |
| **B13** | Phúc, team assists | all implemented | integration/privacy/staging database tests + CI | PostgreSQL migration, RLS/grants, JWT and A/B tests green |

## Backend files likely touched (later PRs, NOT B01)

| PR | Files likely to be added/updated |
|---|---|
| B02 | `backend/app/core/auth.py`, `backend/app/models/user_profile.py`, `backend/app/modules/profile/router.py`, `backend/app/core/config.py`, `backend/app/main.py`, `backend/alembic/versions/*`, `backend/tests/test_auth.py` |
| B04 | `backend/app/models/journal.py`, `backend/app/modules/journal/router.py`, `backend/app/schemas/journal.py`, `backend/alembic/versions/*`, `backend/tests/test_journal_authorization.py` |
| B06 | `backend/app/models/journal_action_day.py`, `backend/app/modules/streak/router.py`, `backend/app/modules/streak/service.py`, `backend/alembic/versions/*`, `backend/tests/test_streak.py` |
| B09 | `backend/app/models/saved_place.py`, `backend/app/modules/places/router.py`, `backend/app/modules/geo/router.py`, `backend/alembic/versions/*`, `backend/tests/test_saved_places.py` |
| B10 | `backend/app/models/place_note.py`, `backend/app/models/journal_place.py`, `backend/app/modules/places/router.py`, `backend/alembic/versions/*`, `backend/tests/test_place_notes.py` |
| B13 | `backend/tests/*`, `.github/workflows/*`, `docs/MVP_TEST_PLAN.md` |

## Required quality gates on backend PRs

1. Add/alter models and migrations only in the owning PR; Alembic upgrade/current/check on a disposable PostgreSQL development environment. Verify downgrade/recovery plan before changing shared schema.
2. Use synthetic users A/B and JWT unit tests: missing/expired/forged token -> 401; foreign-owned IDs -> 404 across all resource types; requests never accept a client-supplied owner.
3. Concurrent successful Journal writes cannot double-count a date; app time is not trusted and no `/activity/open` endpoint exists.
4. Notes and links use database-level composite owner FKs, not only Python checks.
5. Keep Supabase privileged credentials and Geoapify API key on backend only; never check in `.env`. Follow backend-only data access and applicable RLS/grant review.
6. Leave PRs unmerged for Phúc's review; never silently bypass failing CI or force-push teammates' branches.

## Handoff to Trâm for MapLibre (independent of backend availability)

- Start from `docs/MAPLIBRE_SETUP.md`; MapLibre/OpenFreeMap **does not require Google Maps API key**.
- Demo can display map, zoom and drop pin using local state before B09/B10.
- **Do not** expose the PostgreSQL password, reuse service-role secrets in Flutter, or create duplicate PRs while #6 is open.
- Search/address suggestions require a separate backend/provider API. MapLibre does not search places by itself.
