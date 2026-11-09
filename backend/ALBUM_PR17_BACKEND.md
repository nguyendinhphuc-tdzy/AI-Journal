# Backend integration for mobile PR #17

Branch: `feat/backend-album-pr17`. Not merged or deployed.

## Authenticated Album/Memory API

- `GET, POST /api/v1/albums`
- `GET, PATCH, DELETE /api/v1/albums/{album_id}`
- `GET, POST /api/v1/albums/{album_id}/memories`
- `GET, PATCH, DELETE /api/v1/albums/{album_id}/memories/{memory_id}`

All require a verified Supabase JWT. Ownership always comes from token
`sub`. Unknown or other-account album/memory IDs return 404. No client
`user_id` is permitted. Each memory carries the album's owner ID and
a composite foreign key ensures that ownership cannot be changed silently.

Mapping from PR17 mobile code:

- Album: `name`, `themeId` → `theme_id`,
  `locked`, `hideNameWhenLocked` → `hide_name_when_locked`.
- Memory: `title`, `note`, `displayDate` → `display_date`,
  `MemoryPlace` → `place` snapshot
  `{label,latitude,longitude,named,address,place_id}`.
- Backend IDs are UUIDs rather than the `local-...` IDs created by Flutter.
  A future sync adapter must map local IDs to server IDs.
- E05 place selection is saved on the memory; it does not automatically
  create a `SavedPlace` nor publish anything on the map.

## Deliberately excluded from this stage

- Photo storage: PR17 `photoPath` points to a *device-local file*. Never
  upload this path as if it were a remotely accessible photo. The backend
  currently requires a nonempty note for each memory, even if it has a
  local photo. Private Supabase Storage upload/download, authorization,
  deletion and quota are a separate work item.
- 24-hour sharing: PR17 has a `MemorySharing` interface but no final
  `ShareAudience` policy. No public Explore posts are created by this API.
  Do not switch off `NoAlbumPublishing` before audience/lock/revocation/
  expiration rules are implemented and tested server-side.
- Guest storage: guests never possess a Supabase Auth access token and
  cannot call these endpoints. Guest albums/photos stay entirely local.
- Album biometric lock is a device UX feature, not a substitute for
  JWT-based ownership checks on the server.
- The existing Flutter `LocalAlbumRepository` is not yet connected to
  these endpoints. PR16 still needs Account/Guest AlbumScope isolation.

## Database and security

The new Alembic revision `20261025_07` adds `albums` and
`album_memories` to the migration chain after `20261018_06`. On
PostgreSQL, RLS is enabled and client `anon`/`authenticated` SQL
grants are revoked; FastAPI uses the server database role and owner-
scoped queries. It does NOT modify Supabase itself simply by merging code.

Do not run this migration on the shared Supabase project until previous
migration gaps, backup, and existing RLS warnings are resolved and the
owner explicitly approves it.

Local validation only:

```bash
cd backend
python -m pip install -r requirements.txt
python -m pytest tests/test_api.py -q
python -m alembic heads
```
