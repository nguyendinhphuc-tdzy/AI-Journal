# B10 — Private place notes and journal-place linking

**Status:** implemented on stacked feature branch `feat/backend-place-notes-links`, **not merged or deployed**.

**Dependency chain:** #7 B01 → #8 B02 → #9 B04 → #10 B06 → #11 B09 → B10. Real base is `setup/initial-import`, not `main`. Only Phúc reviews and merges, in dependency order and after testing and retargeting. No changes to Trâm's or Vy's branches.

## Product behavior

- Users can save **multiple private notes per saved location**. Notes are free text; nonblank required, 1–10000 characters, and can be edited/deleted independently.
- A private Journal can link to **many saved places**, and each private saved place can link to **many Journals**.
- Users may link/unlink only **their own Journal and their own saved place**. Non-owned or missing IDs always return HTTP 404, including guessing an ID or combining a Journal from A with a place from B.
- Linking twice is idempotent (one row), unlinking twice is safe (204 if both parent resources still exist). Unlinking **never** deletes either Journal or saved place.
- Deleting a **place** removes its notes and Journal associations, **not** the Journals. Deleting a **Journal** removes its associations, **not** saved places, their notes or previously earned action-based streak history.

## API for Flutter

Every endpoint below requires `Authorization: Bearer <Supabase access token>`. User ID is **never** provided in the body/query; all owner filters use the verified JWT.

| Method and path | Behavior |
|---|---|
| `POST /api/v1/places/{place_id}/notes` | Body `{"content":"Quiet corner"}`, return 201 with id/place_id/content/created_at/updated_at |
| `GET /api/v1/places/{place_id}/notes?limit=20&cursor=...` | Return `{"items":[...],"next_cursor":null}`, newest first |
| `PATCH /api/v1/places/{place_id}/notes/{note_id}` | Body `{"content":"Updated note"}`; return 200 |
| `DELETE /api/v1/places/{place_id}/notes/{note_id}` | 204 |
| `PUT /api/v1/journals/{journal_id}/places/{place_id}` | Idempotently link two owned resources; 204 |
| `DELETE /api/v1/journals/{journal_id}/places/{place_id}` | Idempotently unlink without deleting either parent; 204 |
| `GET /api/v1/journals/{journal_id}/places` | Return `{"items":[...saved-place objects...]}` |
| `GET /api/v1/places/{place_id}/journals?limit=20&cursor=...` | Return paged `{"items":[...journal objects...],"next_cursor":null}` |

Notes and Journal lists have bounded page size 1–100 and opaque base64url keyset cursors; cursors are not authorizations. Missing/foreign resources produce 404, blank/too-long note text produces 422, malformed cursor produces 400.

## Schema `20261018_06`

- `place_notes`: `id` PK, `place_id`, `user_id`, `content`, UTC `created_at`/`updated_at`; FK `(place_id,user_id) → saved_places(id,user_id) ON DELETE CASCADE`; index on owner/place/time/id.
- `journal_places`: composite PK `(user_id,journal_id,place_id)`, UTC `created_at`; composite FK `(journal_id,user_id) → journal_entries(id,user_id) ON DELETE CASCADE` AND FK `(place_id,user_id) → saved_places(id,user_id) ON DELETE CASCADE`; index on `(user_id,place_id)`.
- Composite foreign keys **prevent cross-account relationships even if an application bug writes directly to DB**. SQLite unit tests explicitly enable FK enforcement using `PRAGMA foreign_keys=ON`; PostgreSQL enforces by default.
- PostgreSQL migration enables RLS on both new public tables and revokes direct `anon`/`authenticated` table privileges and `place_notes` sequence privileges. This remains a **proposed migration only**, not live.
- Destructive downgrade is intentionally blocked; use a separately reviewed backup/recovery plan.

## B12 / Trâm + UI handoff

- Trâm may use B09 MapLibre pins as the location selector. Place details open multiple notes; Journal editor/detail can link an owned saved place. Do not create duplicate place records merely to link to them.
- Refresh linked places/Journals after a successful 204. Treat 404 as resource missing/not owned; do not expose other users' data.
- Notes/links **do not earn a streak** in the current B06 rule. Only saving or meaningfully changing Journal **content** counts as completed daily action.
- MapLibre/OpenFreeMap is still only for map rendering; no Supabase DB credentials, Geoapify secret, Google Maps key or privileged token goes into Flutter.

## Verification / deployment gates

1. Review each ancestor PR and **merge manually in order** only when authorized. This task does not merge anything, run SQL, or update Supabase.
2. Checkout the B10 branch in a clean isolated tree, install backend dependencies, run `python -m pytest -q` (SQLite temporary), `python -m alembic heads` (expected `20261018_06`), `python -m alembic check` only on disposable/staging DB.
3. Test cascade behavior with DB foreign keys enabled and direct malicious cross-owner insert cases, not only with route 404 guards. Tests are provided in `backend/tests/test_api.py`; use synthetic users A/B.
4. Run **PostgreSQL staging migration** with real `auth.users`, test insert/edits/delete cascades, verify FK definitions, indexes, RLS and grants. Explicitly confirm shared project and migration history **before** any future real rollout.
5. Verify manual pins + notes persist across restart and re-login and that linking/notes have no effect on B06 streak calculation.
6. Real Supabase AI-Journal-Dev remains at `20261011_01` unless the owner explicitly approves a later rollout. Legacy `journal_entries` and `alembic_version` RLS are currently disabled; do not expose unowned prototype Journal endpoints to the Internet or save real private diaries before the security migrations are deployed.

This B10 PR changes **backend plus docs only**; no Flutter code is written or merged.
