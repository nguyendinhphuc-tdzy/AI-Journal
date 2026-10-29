# API Contract — runtime integration (29/10/2026)

**Source of truth:** FastAPI routers in `backend/app/main.py`, `backend/app/modules/**/router.py` and `backend/app/schemas/`; Flutter adapters under `mobile/lib/`. This describes the current **integration** branch, not the repository's separate `setup/initial-import` default branch. All routes below are relative to `/api/v1`, except `GET /health`. Availability in a deployed environment requires valid Supabase configuration, database revision, optional feature flags and upstream providers; a documented route does not prove Android end-to-end deployment.

## Transport, authentication, errors

- `GET /health` and `GET /prompts/daily` are public. All other routes in this document require `Authorization: Bearer <Supabase access_token>`, verified at the FastAPI boundary. Neither Facebook, Google nor phone-number login is a FastAPI endpoint: Flutter authenticates with **Supabase Auth** and passes its JWT to FastAPI.
- JSON over HTTPS for deployed environments; the Android emulator may use `http://10.0.2.2:8000/api/v1` for local development. Private photo endpoints transfer image bytes rather than JSON.
- Owner-scoped resources return 404 if missing or not owned. Common statuses: 200 read/update, 201 create, 204 delete, 400 invalid request, 401 missing/invalid access token, 403 forbidden, 404 absent/not owned, 409 conflict, 422 schema validation, 429 quota, 502/503 upstream unavailable. FastAPI errors normally use `{"detail": ...}` (the detail may be structured validation errors).
- Journal, Place and Note list routes return `{"items":[...],"next_cursor":null|string}`; Album and Memory list routes deliberately return **bare arrays** with `limit`/`offset`. Do not silently interchange these pagination protocols.
- Identifiers: Journal/Place/Note IDs are integers; Supabase users, Albums, Memories, Friends and Shares use UUIDs. Dates are `YYYY-MM-DD`; timestamps are UTC/RFC3339. Never accept client-supplied ownership as authority.

## Public endpoints

| Method and path | Response |
| --- | --- |
| `GET /health` (outside API prefix) | `{"status":"ok","service":"ai-diary-backend"}` |
| `GET /prompts/daily` | `{"id":"daily-001","text":"..."}` (daily prompt) |

## Authentication and my profile

Supabase Auth handles email/password, Google/Facebook OAuth and SMS OTP (when configured); the backend only validates access tokens. Flutter flags `AUTH_ENABLED`, `GOOGLE_OAUTH_ENABLED`, `FACEBOOK_OAUTH_ENABLED`, `PHONE_OTP_ENABLED` control the visible login methods, not access to public FastAPI routes.

| Method and path | Request / response |
| --- | --- |
| `GET /me` | My `user_id`, `email`, `display_name`, `timezone`, `discoverable`, `created_at`; profile can be created on first access |
| `PATCH /me` | Partial `{"display_name":"...", "timezone":"Asia/Ho_Chi_Minh", "discoverable":false}`; **explicit** `discoverable:null` gives 422, omission leaves value unchanged |

## Journal and streak

| Method and path | Contract |
| --- | --- |
| `GET /journals?limit=20&cursor=...&mood=...&q=...` | Owner-scoped `JournalPage {items,next_cursor}`, `limit` 1–100; `cursor` max 512, `mood` max 64, `q` max 120 |
| `POST /journals` | `JournalCreate`: `title` (optional), required `content`, optional `prompt`, `mood`, `guided`, `source`; 201 `JournalRead` |
| `GET /journals/{journal_id}` | `JournalRead` |
| `PUT /journals/{journal_id}` | Partial `JournalUpdate`; 200. `body_version` increases only if `content`, `mood`, `guided` or `source` **actually changes**; unchanged body/title-only update does not manufacture a new version or writing streak |
| `DELETE /journals/{journal_id}` | 204; private deletion |
| `GET /streak?days=30` | `current_streak`, `longest_streak`, `today_completed`, `timezone`, `activity_dates`; `days` 1–365 |

`JournalRead` fields: `id`, `title`, `content`, `prompt`, `mood`, `guided`, `source`, `body_version`, `created_at`, `updated_at`. `guided` includes template ID, version and fields; `source.kind` is one of `challenge|course|lesson|framework`. Streak is derived from the server's completed journal-writing action, never from invented UI numbers. Flutter's combined repository keeps legacy device-only journals visible; new journal records use cloud when `JOURNAL_CLOUD_ENABLED=true` and an authenticated session exists. Device records are not silently uploaded.

## AI — authenticated mock or local Ollama

| Method and path | Request | Response |
| --- | --- | --- |
| `POST /ai/go-deeper` | `{"content":"..."}` | `{"question":"..."}` |
| `POST /ai/reflection` | `{"content":"...","mood":"..."}` | `{"emotion":"...","observation":"...","reflection":"...","question":"..."}` |

Both endpoints require a **verified Supabase JWT even in mock mode**. `content` is nonblank and at most **8,000 characters**, optional `mood` at most 64. The development limiter allows **12 requests/minute/user**, **one concurrent per user**, **two total in-flight in one process**; excess gets 429. Limits live in process memory, so **multi-worker/production rate limiting remains necessary**. Flutter sends the multi-round `Câu hỏi:/Trả lời:` conversation as `content` bounded to backend limits; no separate `context` request parameter currently exists. Backend mock/Ollama provider selected by configuration; mobile never calls Ollama directly.

**Not yet implemented on the server:** `POST /journals/{id}/analysis`, `GET /journals/{id}/analysis`, `GET /journals?include=analysis`, normalized `mood_group`/`mood_score` in AI responses, or `GET /insights/week?start=YYYY-MM-DD`. Vy's saved AI analyses and weekly emotion chart currently use **account-scoped on-device storage**. The 0–100 mood score is an app-defined display mapping, not a clinical assessment; no server-generated weekly narrative exists.

## Albums, Memories and private images

| Method and path | Contract |
| --- | --- |
| `GET /albums?limit=50&offset=0` | Bare array of `AlbumRead`; `limit` 1–100; `offset` 0–100000 |
| `POST /albums`, `GET /albums/{album_id}`, `PATCH /albums/{album_id}`, `DELETE /albums/{album_id}` | Owner-scoped create/read/update/delete; 201/200/200/204 |
| `GET /albums/{album_id}/memories?limit=100&offset=0` | Bare array of `MemoryRead`; `limit` 1–100; `offset` 0–100000 |
| `POST /albums/{album_id}/memories` | 201 `MemoryRead`; requires nonblank `note` (current backend cannot create a photo-only Memory) |
| `GET /albums/{album_id}/memories/{memory_id}`, `PATCH /albums/{album_id}/memories/{memory_id}`, `DELETE /albums/{album_id}/memories/{memory_id}` | Read/update/delete Memory; 200/200/204 |
| `PUT /albums/{album_id}/memories/{memory_id}/photo` | Upload JPEG/PNG/WebP bytes, max 5 MiB, owner JWT; storage proxy |
| `GET /albums/{album_id}/memories/{memory_id}/photo` | Authenticated image bytes |
| `DELETE /albums/{album_id}/memories/{memory_id}/photo` | Remove private image, 204 |

`AlbumRead` contains `id`, `name`, `theme_id`, `locked`, `hide_name_when_locked`, `memory_count`, `created_at`, `updated_at`. `MemoryRead` contains `id`, `album_id`, `title`, `note`, `display_date`, `place`, **`photo_available: boolean`**, `created_at`, `updated_at`: **never return `photo_path`**, a private Supabase Storage object key. Flutter downloads photos via authenticated photo endpoints and caches them under the current user. Pagination uses offsets for compatibility; concurrent insert/delete during pagination can shift results. The PIN/lock UI is not server-side encryption or an extra API authorization boundary.

## Saved Places, Notes, location lookup and links

| Method and path | Contract |
| --- | --- |
| `GET /places?limit=20&cursor=...` | `PlacePage {items,next_cursor}`, `limit` 1–100 |
| `POST /places`, `GET /places/{place_id}`, `PATCH /places/{place_id}`, `DELETE /places/{place_id}` | Own saved places CRUD; `label`, coordinates, optional `address_text`, `provider`, `external_place_id` |
| `POST /places/{place_id}/notes` | Note `{"content":"..."}`, 201 |
| `GET /places/{place_id}/notes?limit=20&cursor=...` | `NotePage {items,next_cursor}` |
| `PATCH /places/{place_id}/notes/{note_id}`, `DELETE /places/{place_id}/notes/{note_id}` | Update/delete owner note |
| `PUT /journals/{journal_id}/places/{place_id}`, `DELETE /journals/{journal_id}/places/{place_id}` | Link/unlink private Journal and private Place |
| `GET /journals/{journal_id}/places` | `LinkedPlaces {items}` |
| `GET /places/{place_id}/journals?limit=20&cursor=...` | `JournalPage {items,next_cursor}` |
| `GET /geo/search?q=...&limit=5&lat=...&lon=...` | Authenticated search; `q` length 2–120, `limit` 1–10, optional bias coordinates |
| `GET /geo/reverse?lat=...&lon=...` | Authenticated reverse geocoding, place or null |

Geoapify configuration/availability determines live lookup. Cloud Saved Places are opt-in through `PLACES_CLOUD_ENABLED`; local pins must be scoped per signed-in account when cloud is disabled.

## Friends, sharing and community (backend routes; UI may still be mocked)

| Method and path | Contract |
| --- | --- |
| `GET /friends`, `POST /friends/requests`, `POST /friends/{other_id}/accept`, `DELETE /friends/{other_id}` | Authenticated friendship listing/request/accept/remove |
| `GET /friends/discover?q=...` | Opt-in discovery of discoverable profiles, search length 3–60 |
| `GET /friends/blocks`, `POST /friends/blocks`, `DELETE /friends/blocks/{other_id}` | Block list/add/remove |
| `POST /memory-shares` | `{"memory_id":"UUID","recipient_ids":["UUID"]}`; 1–20 friends; time-limited share |
| `GET /memory-shares/{share_id}`, `DELETE /memory-shares/{share_id}` | Read authorized share / revoke owner share |
| `POST /community/posts`, `GET /community/feed?limit=20`, `GET /community/mine` | Community posting and feed, when enabled; feed limit 1–50 |
| `DELETE /community/posts/{post_id}`, `POST /community/posts/{post_id}/reports` | Delete own post / report |
| `GET /community/moderation/pending`, `POST /community/moderation/{post_id}/{decision}`, `GET /community/moderation/reports` | Moderator-only routes, feature-gated |

Social APIs existing in FastAPI do **not** imply the Flutter screens are all connected. Mock Facebook-friends UI is separate from Supabase Facebook OAuth and must not be mistaken for real account connection.

## Deployment / API compatibility reminders

1. Deploy Flutter and backend together when changing the JSON Memory field `photo_path` to `photo_available`. Older client builds must be handled by upgrade/versioning; no implicit backward compatibility.
2. JWT verification requires a properly configured Supabase URL and signing keys; the Storage proxy needs `SUPABASE_PUBLISHABLE_KEY` on a separate line in `backend/.env` and a private bucket. Do not commit credentials or database URLs.
3. Backend migration checks must match live Alembic revision. Changes in this document do not themselves migrate a database.
4. OAuth login completion is asynchronous: opening the browser is not a valid session. SMS OTP requires enabled Supabase Phone provider / SMS delivery and `PHONE_OTP_ENABLED`.
5. This contract describes code routes, not guarantees that unavailable providers (Ollama, Supabase, Geoapify or configured community moderation) are working at a particular moment.

**References:** `backend/app/main.py`, `backend/app/modules/`, `backend/app/schemas/`, `mobile/lib/core/network/api_client.dart`, `mobile/lib/features/*/data/`. Historical design assumptions from MVP B01 belong in Git history rather than in the live contract.
