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

Supabase Auth handles email/password, Google OAuth and SMS OTP (when configured); the backend only validates access tokens. Flutter flags `AUTH_ENABLED`, `GOOGLE_OAUTH_ENABLED`, `PHONE_OTP_ENABLED` control the visible login methods, not access to public FastAPI routes.

| Method and path | Request / response |
| --- | --- |
| `GET /me` | My `user_id`, `email`, `display_name`, `username`, `timezone`, `discoverable`, `created_at`; profile can be created on first access |
| `PATCH /me` | Partial `{"display_name":"...", "username":"vytuong", "timezone":"Asia/Ho_Chi_Minh", "discoverable":false}`; **explicit** `discoverable:null` gives 422, omission leaves value unchanged |

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
| `POST /ai/reflection` | `{"content":"...","mood":"..."}` | Existing four required fields, plus optional `title`, `analysis`, `topics`, and normalized `mood_group`/`mood_score`; `quote` is null until a vetted catalog is available |

Both endpoints require a **verified Supabase JWT even in mock mode**. `content` is nonblank and at most **8,000 characters**, optional `mood` at most 64. The development limiter allows **12 requests/minute/user**, **one concurrent per user**, **two total in-flight in one process**; excess gets 429. Limits live in process memory, so **multi-worker/production rate limiting remains necessary**. Flutter sends the multi-round `Câu hỏi:/Trả lời:` conversation as `content` bounded to backend limits; no separate `context` request parameter currently exists. Backend mock/Ollama provider selected by configuration; mobile never calls Ollama directly.

**Cloud AI APIs proposed in migration `20261029_16`:** `POST/GET /journals/{id}/analysis`, `GET /journals?include=analysis`, `PUT /journals/{id}/analysis/feedback`, `GET/POST/DELETE /saved-quotes`, and `GET /insights/week?start=YYYY-MM-DD`. Full schemas, opt-in `generate_summary=true`, privacy constraints and mobile compatibility are in [API_AI_CLOUD_CONTRACT.md](API_AI_CLOUD_CONTRACT.md). **These routes are not deployed until the new migration and backend are released.** Vy's existing `AnalysisArchive` and `SavedQuotes` still save **on the device**, even once the new routes are merged, until mobile adapters are connected. Scores are non-clinical display conventions, unknown emotions have null values, and no weekly narrative is fabricated when AI is unavailable.

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

Geoapify Places: `GET /geo/places?lat=10.7769&lon=106.7009&radius=1500&category=all&q=...&limit=25` — JWT required. Server-only key; returns `{items:[{provider,external_place_id,label,formatted_address,latitude,longitude,categories}]}` from real OSM-based Geoapify POIs. Category allowlist: `all|cafe|food|shop|hotel|school|health|attraction|transport`. Search name `q` is optional (2–120 chars), radius 100–5000 meters, limit 1–40, `lang=vi`. Missing key 503; provider errors 502/503; per-user 30/min in-memory rate limit, 60s cache. Results are nearby snapshots, not guaranteed exhaustive or permanent, and are never silently persisted to a personal SavedPlace.

Geoapify configuration/availability determines live lookup. Cloud Saved Places are opt-in through `PLACES_CLOUD_ENABLED`; local pins must be scoped per signed-in account when cloud is disabled.

## Friends, sharing and community (backend routes; UI may still be mocked)

| Method and path | Contract |
| --- | --- |
| `GET /friends`, `POST /friends/requests`, `POST /friends/{other_id}/accept`, `DELETE /friends/{other_id}` | Authenticated friendship listing/request/accept/remove; list also returns peer display_name and username |
| `GET /friends/discover?q=...` | Opt-in search by @username prefix or display name (length 3–60), returns user_id/display_name/username without email; username unique and lowercase |
| `GET /friends/blocks`, `POST /friends/blocks`, `DELETE /friends/blocks/{other_id}` | Block list/add/remove |
| `POST /memory-shares` | Explicit shared snapshot: `{recipient_ids, title?, text, place:{label,latitude,longitude}, category?, memory_id?, replacing?}`; 1–20 unique accepted/unblocked friends, text 1–300 characters, 24h server expiry; optional owned cloud memory or device-only memory without memory_id. Replacement revokes old share atomically. No private memory.note or photos copied. |
| `GET /memory-shares/received?limit=50` | Active authorized shares only with sender_id, display_name, username and shared snapshot; limit 1–100. Map bounds filtering is future work. |
| `GET /memory-shares/mine?memory_id=UUID` | Current user's active share metadata; optional cloud memory filter. Local-only shares are listed without filter. |
| `GET /memory-shares/{share_id}` | Authorized shared snapshot only, never memory.note or storage photo key; old legacy shares without snapshot are unreadable. |
| `DELETE /memory-shares/{share_id}` | Owner only; revoke (204); the share's photo is deleted with it. |
| `PUT /memory-shares/{share_id}/photo` | Migration 20261030_20. Owner only, active share; raw body JPEG/PNG/WebP (signature checked), at most 3 MB; 204. Replaces the previous photo. Never the album's stored photo or its storage key. |
| `GET /memory-shares/{share_id}/photo` | Owner or an eligible recipient while active; image bytes with `Cache-Control: private, no-store`; 404 when none. Share reads include `has_photo`. |
| `POST /community/posts`, `GET /community/feed?limit=20`, `GET /community/mine` | Community posting and feed, when enabled; feed limit 1–50 |
| `DELETE /community/posts/{post_id}`, `POST /community/posts/{post_id}/reports` | Delete own post / report |
| `GET /community/moderation/pending`, `POST /community/moderation/{post_id}/{decision}`, `GET /community/moderation/reports` | Moderator-only routes, feature-gated |

Social APIs existing in FastAPI do **not** imply the Flutter screens are all connected. Flutter friend selection uses accepted app friendships from GET /friends. Facebook friends are not used.

## Private one-to-one messaging — migration 20261030_19

**Server-owned data.** Conversation history, explicit place message snapshots, and message read cursors are stored in PostgreSQL. All routes below are authenticated under `/api/v1`; guests cannot access them. Flutter polls in the foreground; there are no push notifications in this phase.

| Method and path | Request / response |
| --- | --- |
| `GET /conversations` | Bare list newest first: `id`, `friend:{user_id,display_name,username}`, `last_message`, `unread_count`, `can_send` |
| `POST /conversations` | `{friend_id:UUID}`; get/create single conversation for an accepted, unblocked friend |
| `GET /conversations/{id}/messages?after=&before=&limit=50` | `{items:[Message]}`, oldest first; after/before are UUID message cursors, mutually exclusive, limit 1–100; defaults to newest 50 |
| `POST /conversations/{id}/messages` | `{client_id:string,text:string}`; nonblank <=2,000 chars; idempotent per conversation+sender+client_id; reused key with changed content => 409 |
| `POST /conversations/{id}/read` | `{message_id:UUID}`; monotonic read cursor, returns `{unread_count}` |
| `GET /messages/unread-count` | `{count}` for the current user |
| `POST /place-shares` | `{recipient_ids:[UUID],place:{name,latitude,longitude,category?,note?}}`; 1–20 distinct accepted, unblocked friends; only an explicitly submitted place snapshot is sent; `{conversation_ids:[UUID]}` |
| `POST /memory-shares` | Does **not** create chat messages (changed 30/10/2026): a 24-hour moment is seen on the recipients' map and in their moments list (`GET /memory-shares/received`). `memory_share` messages created before this change stay readable as history, under the expiry rules below |

A `Message` contains `id,conversation_id,sender_id,kind,client_id,created_at,text?,place?,memory_share?`. `kind` is `text|place|memory_share`. A place message's name and coordinates are explicitly supplied by sender; server never copies a private SavedPlace note. Optional `place.note` is an explicitly authored message caption, not a private journal note.

**Access control:** only participants may list/read/mark-read messages; opening and sending requires a currently accepted unblocked friendship. After unfriend or block, conversation history is read-only. Attempting to read other people's conversations/messages returns 404. Sends are capped at 30 persisted messages per user per rolling minute (app instance/database); batch shares count once per recipient. Idempotency is enforced by a database unique constraint; a retry of an existing message does not send twice. Large-scale global quota enforcement may need a dedicated distributed limiter.

**Expiring content:** every message referencing `memory_share` rechecks the active share and its ACL at read time. After expiry, revoke or loss of friendship, `memory_share` contains only `share_id` and `expires_at` (no title, caption, coordinates or private note), including in `last_message`. New messages cannot access album-private `memory.note` or photo storage keys.

**Data lifecycle:** conversations and messages use foreign keys that cascade when a user account is deleted in Supabase Auth. The backend cannot provide end-to-end encryption; message history is server-side and should be disclosed in privacy and deletion policies. Supabase Data API roles `anon` and `authenticated` have no direct table privileges, with RLS enabled, so messages are accessed through FastAPI only.

## Device registration and privacy-safe push — migration 20261030_21

Only the Android app registered by Vy's Firebase configuration can obtain genuine FCM registration tokens. The backend does **not** create Firebase projects and never issues client tokens.

| Method and path | Request / response |
| --- | --- |
| `POST /devices` | `{token,installation_id,platform:"android"|"ios"}`; JWT required; 200 `{registered:true}`. Token 32–4096 chars, installation ID 8–128 chars; no whitespace. Same token/installation can refresh or rotate. Registration for a new account on the same device transfers ownership of the token to prevent cross-account push leaks. |
| `DELETE /devices` | JSON body `{token}`; JWT required; 204, idempotent. Only removes caller-owned token. The client must unregister on sign-out and register on FCM token refresh / next login. |

`device_tokens` is server-only: full token stored privately for delivery, 64-hex SHA-256 primary key to avoid indexing 4 KiB tokens; unique per user+installation; max 10 devices/user, 60-day last-seen dispatch filter, cascade delete on `auth.users`. Supabase `anon` and `authenticated` have no direct table privileges; RLS enabled. No endpoint lists or exposes tokens.

FCM HTTP v1 is **disabled unless** backend `FCM_PROJECT_ID` and Google ADC (`GOOGLE_APPLICATION_CREDENTIALS` pointing to a private service-account JSON, or a workload identity) are configured. The server requests OAuth 2.0 token scoped to Firebase Messaging, and never uses legacy FCM server keys.

Post-commit push event kinds: `friend_request` (data `sender_id`), `friend_accepted` (data `friend_id`), `message` (data `conversation_id` from text/place messages), `memory_share` (data `share_id`). Content on lock screen is **generic** (no text, photo, note, place, coordinates, username, sender display name); `android.notification.visibility=PRIVATE`. The client resolves the ID via authenticated API and rechecks active ACL, 24-hour expiry and blocks on open. No notification is sent on failed, unauthorized or repeated-idempotent sends.

Current implementation uses FastAPI BackgroundTasks **after database commit** and is best-effort: no durable outbox, crash recovery or guaranteed FCM delivery. A future production phase needs transactional outbox/queue + worker, retry/backoff, metrics, and preference controls. Removing invalid `UNREGISTERED` tokens is supported. Local reminder notifications via `flutter_local_notifications` / `timezone` are a separate **on-device Flutter responsibility** and do not use these APIs.

## Deployment / API compatibility reminders

1. Deploy Flutter and backend together when changing the JSON Memory field `photo_path` to `photo_available`. Older client builds must be handled by upgrade/versioning; no implicit backward compatibility.
2. JWT verification requires a properly configured Supabase URL and signing keys; the Storage proxy needs `SUPABASE_PUBLISHABLE_KEY` on a separate line in `backend/.env` and a private bucket. Do not commit credentials or database URLs.
3. Backend migration checks must match live Alembic revision. Changes in this document do not themselves migrate a database.
4. OAuth login completion is asynchronous: opening the browser is not a valid session. SMS OTP requires enabled Supabase Phone provider / SMS delivery and `PHONE_OTP_ENABLED`.
5. This contract describes code routes, not guarantees that unavailable providers (Ollama, Supabase, Geoapify or configured community moderation) are working at a particular moment.

**References:** `backend/app/main.py`, `backend/app/modules/`, `backend/app/schemas/`, `mobile/lib/core/network/api_client.dart`, `mobile/lib/features/*/data/`. Historical design assumptions from MVP B01 belong in Git history rather than in the live contract.
