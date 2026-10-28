# Private Memory photo storage — gated rollout

Backend endpoints (all require a verified Supabase user JWT):
- `PUT /api/v1/albums/{album_id}/memories/{memory_id}/photo`: raw JPEG/PNG/WebP request body, max 5 MiB, response `{"photo_available":true}`.
- `GET .../photo`: private image bytes, never a public URL.
- `DELETE .../photo`: remove current image.

The storage request uses the **same end-user JWT** as FastAPI. No `service_role` key is used. Set `SUPABASE_PUBLISHABLE_KEY` (public key) only on backend together with `SUPABASE_URL`. The bucket `journal-memory-private` is private, limited to 5 MiB and JPEG/PNG/WebP; the owner prefix is `{user_uuid}/{album_uuid}/{memory_uuid}/{random_uuid}.{ext}`. Every endpoint checks the Album/Memory owner in SQL **before** querying Storage. Do not make the bucket public.

**Migration:** Alembic `20261028_10` requires `20261028_09`. It adds nullable `album_memories.photo_path`. On real Supabase PostgreSQL, it creates/locks the private bucket and per-owner storage policies. Disposable PostgreSQL without the Supabase Storage schema skips bucket creation. Never stamp Alembic manually. Verify current database revision, backups and migration compatibility before running it. RLS must remain enabled on `storage.objects`.

**Release gates:** backend test suite and PostgreSQL migration rehearsal; a real Supabase Auth user/JWT; user A upload, read, delete; user B denied access to A's photo and parent Memory; verify image MIME/size rejection, JWT expiry, stale photo replacement, repeat uploads, and object cleanup. Existing Flutter Cloud repository still treats `MemoryContent.photoPath` as **local-only** and will reject photo saves until a Flutter photo adapter is separately wired. No old photos are silently synced.

**Current intentional limits:** note text is still mandatory; there is one remote photo per Memory; automatic deletion on Album/Memory cascade and cleanup of stale objects after network failure require a follow-up reconciliation job. Do not advertise this as photo sync or E2E complete until these are addressed.
