# API Contract — MVP v1 (design contract, NOT yet implemented)

**Base:** `/api/v1`. **Owner:** Phúc (FastAPI + PostgreSQL). **Flutter integrators:** Trâm (auth, Journal, streak, map UI) and Vy (remaining assigned Flutter features). This document is the proposed contract for B01; **do not assume new endpoints work until their owning PR merges**.

## Implementation status and backward compatibility

- **Historical base branch (v0.1):** `GET /health`, `GET /api/v1/prompts/daily`, public mock AI and unscoped journal CRUD. The **current integration branch** requires a Supabase JWT for `/api/v1/ai/*` and all Journal operations; never use the v0.1 descriptions as the live runtime contract.
- **PLANNED for MVP v1 (B02/B04/B06/B09/B10):** Supabase JWT authentication, owner-scoped Journal APIs, profile, completed-action streak, search and saved places, multiple notes, journal-place linking.
- B04 changes `GET /journals` from a bare list to a paginated object `{items,next_cursor}`. Trâm must switch at the same integration milestone; **do not silently deploy a breaking change to active Flutter clients**. Preserve existing integer Journal IDs and basic input fields.
- There is **no** production AI integration in MVP v1; mock responses remain in the separate AI module.
- **STAGED B14 (not merged):** unified runtime branch `integration/journal-cloud-runtime-20261027` contains reviewed backend Phase 2 (PR #26), Flutter Phase 2 (PR #27), and manual runtime launchers. Shared Supabase Dev has Alembic `20261026_08`, but runtime E2E on Android is **not yet verified**. This does not change the API in the default GitHub branch.

## Transport, authentication and error conventions

- JSON over HTTPS in any deployed environment; development emulator may call `http://10.0.2.2:8000` to a local FastAPI instance.
- Flutter signs up/signs in via **Supabase Auth email/password** (`supabase_flutter`); FastAPI **does not** store passwords or expose duplicate `/register` or `/login` endpoints.
- For personal-data endpoints attach `Authorization: Bearer <Supabase access token>`. Backend validates JWT signature using configured key/JWKS mechanism, plus `iss`, `aud`, `exp` and `sub`; do not trust body/query `user_id`.
- All IDs in URL for application rows are integers. JWT `sub`/profile ID is UUID. Times are RFC3339 UTC (suffix `Z`), dates are `YYYY-MM-DD`. Client may display dates in the profile timezone.
- Input string validation: diary content/note must be nonempty after trimming; coordinates range `[-90,90]`, `[-180,180]`. Max sizes set by Pydantic. Client cannot edit `created_at`, `user_id`, or a computed streak.
- For another user's resource, return `404` (prevent resource enumeration), even if the ID exists.
- Responses: `400` malformed request, `401` missing/invalid token, `403` forbidden operation, `404` absent/not-owned item, `409` conflicting state, `422` validation error, `429` rate-limit, `502/503` upstream provider outage. Error format remains FastAPI-compatible `{"detail":"human-readable explanation"}` for ordinary errors.
- APIs listing data use opaque cursor paging, `limit` default 20, maximum 100; `next_cursor = null` when complete. The server signs/validates paging state or otherwise treats it as untrusted.

## Current public and AI routes (unchanged in B01)

### `GET /health`
```json
{"status":"ok","service":"ai-diary-backend"}
```

### `GET /api/v1/prompts/daily`
```json
{"id":"daily-001","text":"What is something you want to remember about today?"}
```

### `POST /api/v1/ai/go-deeper` (authenticated; mock or Ollama)

**Current integration contract:** Both AI endpoints require `Authorization: Bearer <Supabase access token>`. Missing or invalid auth returns 401. If Supabase signing keys are temporarily inaccessible, authentication can return 503. `content` is a nonblank string of at most 8000 characters; optional `mood` is at most 64 characters. Invalid input returns 422. Neither endpoint persists the generated response. Server configuration controls the mock/Ollama provider.
Request: `{"content":"I felt peaceful today."}`; response: `{"question":"What made today feel different?"}` (exact mock question may differ).

### `POST /api/v1/ai/reflection` (authenticated; mock or Ollama)
Request: `{"content":"I finished my task.","mood":"relieved"}`; response fields: `emotion`, `observation`, `reflection`, `question`. The mock AI module remains test-only and is no longer reachable without authentication on the current integration branch.

## B02 — Profile / authenticated session

### `GET /api/v1/me` → 200
```json
{
  "user_id":"00000000-0000-4000-8000-000000000001",
  "email":"member@example.com",
  "display_name":"Member",
  "timezone":"Asia/Ho_Chi_Minh",
  "created_at":"2026-10-18T04:00:00Z"
}
```
Email is sourced from verified Supabase identity, not copied from an untrusted request. If user profile does not exist, create it idempotently.

### `PATCH /api/v1/me` → 200
Request: `{"display_name":"My Name","timezone":"Asia/Ho_Chi_Minh"}`. Only these editable fields may be changed; user ID/email cannot be forged here. Validate timezone using IANA values. Return updated profile.

## B04 — Journal archive (all routes require verified user)

### `POST /api/v1/journals` → 201
```json
{"title":"A calmer afternoon","content":"I felt more relaxed.","prompt":"What helped?","mood":"calm"}
```
Returns a Journal object containing `id`, `title`, `content`, `prompt`, `mood`, `created_at`, `updated_at`. Backend determines owner.

### `GET /api/v1/journals?limit=20&cursor=...&mood=calm&from=2026-10-01&to=2026-10-31&q=calmer` → 200
```json
{
  "items":[
    {
      "id":1,
      "title":"A calmer afternoon",
      "content":"I felt more relaxed.",
      "prompt":"What helped?",
      "mood":"calm",
      "created_at":"2026-10-18T04:00:00Z",
      "updated_at":"2026-10-18T04:00:00Z"
    }
  ],
  "next_cursor":null
}
```
Filtering is applied within the verified user's entries. `from`/`to` are ISO calendar dates, inclusive and interpreted using the user's profile timezone. Order: `created_at DESC, id DESC`; cursor based on same sort. `q` searches title/content (MVP `ILIKE`, optional later index).

### `GET /api/v1/journals/{journal_id}` → 200 / 404
Get one owned entry.

### `PUT /api/v1/journals/{journal_id}` → 200 / 404
Keep current partial-update semantics for the existing fields; omitted fields unchanged. Consider moving to `PATCH` later in a versioned change. Respond with updated entry.

### `DELETE /api/v1/journals/{journal_id}` → 204 / 404
Removes entry and its `journal_places` join rows only; does not delete saved places or their notes.

### Phase 2 cloud Journal extension (PR #26/#27, staged)

This extension is active **only** when FastAPI is running code containing Alembic
`20261026_08` and Flutter opts into `JOURNAL_CLOUD_ENABLED=true`.
It supplements the earlier B04 examples (which omit these optional fields):

- `POST /api/v1/journals` accepts `guided` (nullable JSON object) in addition
  to existing `content`, `mood`, `title`, `prompt` fields. The guided
  format is `{"id":"onboarding_first_entry","version":1,"fields":{"cause":"trời mát"}}`.
- Journal responses and paginated archive entries include `guided` (object
  or `null`) and server-owned `body_version` (positive integer, starts at 1).
- `PUT /api/v1/journals/{journal_id}` accepts the same guided snapshot.
  `body_version` increments on changed content, mood or guided values;
  no-op and title/prompt-only edits do not increment. Streak credit still
  requires actual changed, nonblank **content text**.
- `user_id`, `body_version`, server timestamps and integer row IDs cannot
  be assigned by the client. An entry belonging to another user is a `404`.
- Flutter maps server integer ID `42` to UI ID `cloud-42` to prevent a
  collision with local-only journal IDs (`local-...`). The UI ID is never
  sent in JSON mutation bodies.
- Auto-saved `JournalDraft` remains device-only, scoped by signed-in account.
  No draft endpoints or automatic local-entry imports are implemented.
- All private cloud requests require a fresh Supabase Bearer token, validated
  through the existing FastAPI JWKS verifier. Plain HTTP is only supported
  for local Android Emulator ↔ laptop development; deploy with HTTPS.

## B06 — Streak on a completed journal-writing action

**Revised by Phúc on 2026-10-18. Supersedes the old app-open rule.**

Opening/foregrounding the app **does not count**. There is **no** `POST /api/v1/activity/open` endpoint. The server records one `journal_action_days` row **in the same database transaction** whenever a verified user successfully:

- Creates a journal with non-blank `content` via `POST /api/v1/journals` (one written line is enough); or
- Updates the `content` of an owned journal to a **different**, non-blank value via `PUT /api/v1/journals/{journal_id}`.

Updating only mood/title/prompt, submitting unchanged content, merely viewing or deleting a journal, logging in, or resuming the app never earns credit. Duplicate completions within one user-local calendar date count once. Deleting a journal later does not erase past achievement history. No offline backdating in v1. The client must not submit a completion date/counter.

### `GET /api/v1/streak?days=30` → 200 (authenticated)

```json
{
  "current_streak": 3,
  "longest_streak": 7,
  "today_completed": true,
  "timezone": "Asia/Ho_Chi_Minh",
  "activity_dates": ["2026-10-16", "2026-10-17", "2026-10-18"]
}
```

`days` ranges 1–365; dates are ascending and limited to the requested history window. The server computes dates from its own UTC clock and the user's IANA timezone. The current streak ends today if completed, otherwise yesterday if the user completed yesterday; it is 0 when neither day was completed. Longest streak uses the user's full recorded history. Changing timezone does not rewrite historical dates. The only streak-changing operations are successful journal-content writes.
## B09 — MapLibre saved places (FastAPI private CRUD; Geoapify optional)

MapLibre/OpenFreeMap renders maps in Flutter **without** a Google Maps API key. Backend Geoapify key lives only in `backend/.env`; never expose it to Flutter or a Git commit. Begin Map UI with mock search if the provider is not configured; **manual dropped pins still persist without a key**. B09 code is staged on an unmerged PR, not yet deployed.

### `GET /api/v1/geo/search?q=Hanoi&lat=10.8231&lon=106.6297&limit=5` → 200
`q` required (2–120 characters), `lat`/`lon` optional **together** as a ranking bias, `limit` 1–10. Backend implements Geoapify **address autocomplete**, which is not a substitute for comprehensive category/POI name search. Debounce requests in Flutter; local per-process 30/minute/user throttle returns 429; scale with a distributed limiter before public deployment. Missing API key returns 503; upstream errors map to 502/503.

```json
{
  "items":[
    {
      "provider":"geoapify",
      "external_place_id":"example-provider-id",
      "label":"Example address",
      "formatted_address":"Example address in Vietnam",
      "latitude":10.8231,
      "longitude":106.6297
    }
  ]
}
```
Example only; returned provider data is for suggestion display, not automatic persistence. Follow Geoapify's storage/attribution terms and avoid auto-filling persisted `address_text` with third-party text.

### `POST /api/v1/places` → 201
User-assigned label and coordinates are required. Provider-specific ID optional:
```json
{
  "label":"My reading spot",
  "latitude":10.8231,
  "longitude":106.6297,
  "address_text":"My own description",
  "provider":"manual",
  "external_place_id":null
}
```
`provider` accepts `manual` or `geoapify`; `external_place_id` required for a provider-backed result and forbidden for `manual`. `address_text` is user-entered text, not an automatically persisted copy of provider results. Returns owned saved-place object with `id`, editable fields, `created_at`, `updated_at`. Provider-backed `external_place_id` must be nonempty; manual pins must omit it. Duplicate `(user, provider, external_place_id)` returns HTTP 409.

### `GET /api/v1/places?limit=20&cursor=...` → 200
`{"items":[{"id":9,"label":"My reading spot","latitude":10.8231,"longitude":106.6297,"provider":"manual","external_place_id":null,"address_text":"My own description","created_at":"2026-10-18T04:00:00Z","updated_at":"2026-10-18T04:00:00Z"}],"next_cursor":null}`.

### `GET /api/v1/places/{place_id}` → 200 / 404
Get owned place.

### `PATCH /api/v1/places/{place_id}` → 200 / 404
Can modify `label`/`address_text` and coordinates for manually created pins. Provider-sourced coordinates and provider identity are immutable in MVP v1 to prevent contradictory IDs; create a new place instead.

### `DELETE /api/v1/places/{place_id}` → 204 / 404
Delete owned place, its notes, and journal-place links. **Do not** delete journal entries.

## B10 — Multiple notes per place (implemented on unmerged B10 branch)

### `POST /api/v1/places/{place_id}/notes` → 201
Request `{"content":"Quiet corner with a nice view."}` (non-blank, max 10,000 characters). Return `{"id":5,"place_id":9,"content":"Quiet corner with a nice view.","created_at":"2026-10-18T04:10:00Z","updated_at":"2026-10-18T04:10:00Z"}`.

### `GET /api/v1/places/{place_id}/notes?limit=20&cursor=...` → 200
Paged result `{"items":[...],"next_cursor":null}`, newest first; `limit` defaults to 20, maximum 100.

### `PATCH /api/v1/places/{place_id}/notes/{note_id}` → 200 / 404
Request `{"content":"Updated place note"}`. Must verify place and note belong to the current user.

### `DELETE /api/v1/places/{place_id}/notes/{note_id}` → 204 / 404
Delete only this note. An unknown/non-owned note or place is 404.

## B10 — Link Journal ↔ saved place (many-to-many; staged, not merged)

### `PUT /api/v1/journals/{journal_id}/places/{place_id}` → 204 / 404
Idempotently attach two **owned** resources, no duplicate join row; this does **not** count as a B06 journal-writing action. Return 204 for both first and repeated valid requests.

### `DELETE /api/v1/journals/{journal_id}/places/{place_id}` → 204 / 404
Unlink without deleting journal or place; deletes of either parent cascade only to association rows, not to the other parent.

### `GET /api/v1/journals/{journal_id}/places` → 200
Returns `{"items":[{...saved place object...}]}`.

### `GET /api/v1/places/{place_id}/journals?limit=20&cursor=...` → 200
Returns paginated owned journals linked to one place (`limit` 1–100). Database composite owner foreign keys **on both sides** and backend authorization must agree. Deleting a saved place removes associated notes and links but not the linked Journal entries. Deleting a Journal removes links but not places or notes.

## Acceptance scenarios and rollout gates

1. User A and B have separate JWTs; A cannot fetch, mutate or link B's journals, places, or notes (including guessed IDs).
2. Opening the app never counts; a successful journal-content write records at most **one** `journal_action_days` date per user-local day.
3. Journal and notes survive Android app restart and re-login; manual MapLibre dropped pins use coordinates without a search-provider ID.
4. Privacy-critical routes are inaccessible before auth is integrated. B04 must coordinate response change with Trâm, not break an active Flutter consumer unexpectedly.
5. All schema changes use reviewed Alembic migrations, real PostgreSQL staging tests and explicit RLS/grants checks. **B01 changes documents only**.
