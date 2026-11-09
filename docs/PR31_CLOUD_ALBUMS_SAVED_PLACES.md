# PR31 — Backend Albums/Memories and Explore/Saved Places ↔ Vy PR29 UI

**Branch:** `feat/cloud-albums-places-pr29-20261028` (Draft PR on top of PR30).

This integrates **already existing** owner-scoped FastAPI Album, Memory, Saved Place and Place Note endpoints. No backend DDL is added. **The shared Supabase Dev database remains at migration `20261026_08`; parent PR30 needs `20261028_09` before this integrated runtime can launch.** Do not stamp Alembic manually, run migrations on the user's behalf, or merge these stacked PRs without review.

## Existing API contract used

- `GET/POST /api/v1/albums`, `GET/PATCH/DELETE /api/v1/albums/{uuid}`
- `GET/POST /api/v1/albums/{uuid}/memories`, `GET/PATCH/DELETE /api/v1/albums/{uuid}/memories/{uuid}`
- `GET/POST /api/v1/places`, `GET/PATCH/DELETE /api/v1/places/{int}`
- `GET/POST /api/v1/places/{int}/notes`.
- All calls are through `ApiClient` with `requireAuth:true`, which requires a fresh Supabase access token before sending any request. Private IDs are never accepted as a user ID or as an owner.

## Flutter changes

`RemoteAlbumRepository` is a normal `AlbumRepository` accepted by Vy's screens. It converts cloud UUIDs into prefixed UI IDs and implements server CRUD for album settings, note-based memories and memory places. Only requests with note content and **no device photo path** are allowed: current backend has no upload endpoint or private media storage. Attempts to add an image into cloud Memory fail before any network mutation; do not claim this functionality works or upload absolute device paths. Saved drafts always stay on-device, scoped by account.

`RemoteSavedPlacesRepository` uses owner-scoped paginated Saved Places and separate private Place Notes. A versioned note payload retains the UI mood/category/description labels that do not exist on the `saved_places` schema. The actual coordinates and name are stored in Saved Places. MapLibre loads returned pins and displays them with existing native markers and sheets. It creates and deletes real private pins, while anonymous/friend-share UX remains device-only and is explicitly distinguished. If the pin saves but its note fails, UI reloads the real pin rather than blindly re-creating it.

`ProfileScreen` also regains real AuthGate logout, which PR29 accidentally removed.

## Explicit opt-in for real Supabase sessions

The fields below are **local Android Emulator launch config**, never committed with a private key:

```json
{
  "AUTH_ENABLED": "true",
  "JOURNAL_CLOUD_ENABLED": "true",
  "ALBUM_CLOUD_ENABLED": "true",
  "PLACES_CLOUD_ENABLED": "true",
  "SUPABASE_URL": "https://rjwentsuqmwncpseakkt.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "<your PUBLIC publishable key>",
  "API_BASE_URL": "http://10.0.2.2:8000/api/v1"
}
```

Existing `mobile/.env.journal-cloud.json` is intentionally Git-ignored and its key must never be copied to chat or committed. Release must use HTTPS. Guest/fake auth sessions never see a cloud repository.

When `ALBUM_CLOUD_ENABLED` is on, **CombinedAlbumRepository displays existing local albums alongside remote albums**. Old `local-*` IDs keep their device-only data and support photos; new albums are created on FastAPI as `cloud-*` and currently support note-only memories. All operations are routed by album ID. This is not bidirectional sync or an upload/import of device photos; a separate reviewed import UX and private object storage remain future work.

## Limitations before production

1. Album/Memory API supports notes + optional place only; photo uploads, thumbnails, private URLs and restoration on a second device **are not implemented**. A private Supabase Storage/FastAPI upload contract with access checks is needed.
2. Server album and memory collection endpoints cap at 100 rows. Until server-side cursors exist, clients should not assume archives over that size are fully loaded.
3. For cloud Saved Places, a separate `/notes` request is made for each place; this is a small-user MVP strategy. For large pin libraries, add a server aggregate endpoint and transactional create-with-note.
4. Places/Memories stay private. Mock anonymous/community shares do not publish data to a real public feed.
5. UI personal draft preferences and sound controls are not cloud-synced.
6. M01 live POI search, M02 reverse geocoding, M03 GPS and later map features remain separate PRs; do not merge unrelated work into this PR.

## CI

Flutter analyze/unit/widget/bundle and earlier backend security/migrations must pass on the current integration branch before release. A green CI does not prove a real device and shared Supabase are ready. Review parent PR30 migration 09 first.
