# Private Memory photo storage — gated rollout

Backend endpoints (all require a verified Supabase user JWT):
- `PUT /api/v1/albums/{album_id}/memories/{memory_id}/photo`: raw JPEG/PNG/WebP request body, max 5 MiB, response `{"photo_available":true}`.
- `GET .../photo`: private image bytes, never a public URL.
- `DELETE .../photo`: remove current image.

The storage request uses the **same end-user JWT** as FastAPI. No `service_role` key is used. Set `SUPABASE_PUBLISHABLE_KEY` (public key) only on backend together with `SUPABASE_URL`. The bucket `journal-memory-private` is private, limited to 5 MiB and JPEG/PNG/WebP; the owner prefix is `{user_uuid}/{album_uuid}/{memory_uuid}/{random_uuid}.{ext}`. Every endpoint checks the Album/Memory owner in SQL **before** querying Storage. Do not make the bucket public.

**Migration:** Alembic `20261028_10` requires `20261028_09`. It adds nullable `album_memories.photo_path`. On real Supabase PostgreSQL, it creates/locks the private bucket and per-owner storage policies. Disposable PostgreSQL without the Supabase Storage schema skips bucket creation. Never stamp Alembic manually. Verify current database revision, backups and migration compatibility before running it. RLS must remain enabled on `storage.objects`.

**Release gates:** backend test suite and PostgreSQL migration rehearsal; a real Supabase Auth user/JWT; user A upload, read, delete; user B denied access to A's photo and parent Memory; verify image MIME/size rejection, JWT expiry, stale photo replacement, repeat uploads, and object cleanup. Flutter remote Album repository now uploads a picked photo after creating/updating a note-backed cloud Memory and reads private images through FastAPI into a per-user private device cache. Existing local photos are **not** automatically synced, and photo-only Memory still needs a separately reviewed contract.

**Current intentional limits:** note text is still mandatory; there is one remote photo per Memory. Normal Album/Memory API deletion removes photos first, but storage/network and database transactions are not atomic; an object reconciliation job remains required for rare interrupted or failed operations. Do not advertise this as end-to-end complete until real Dev JWT tests pass.
