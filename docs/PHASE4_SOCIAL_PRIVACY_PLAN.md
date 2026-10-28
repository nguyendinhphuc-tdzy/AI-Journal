# Phase 4 — Social and privacy architecture (draft for review)

## Product boundary

Phase 4 adds **friends**, explicitly chosen **24-hour Memory sharing**, and eventually an opt-in **community feed**. Journals, Album Memories, photographs, Saved Places and notes are private by default. A user must explicitly choose an individual Memory and its intended audience to publish anything. Do not automatically publish existing Memories or expose journal text.

## Proposed delivery order

1. Friends / request / accept / reject / unfriend with authenticated owner checks.
2. 24-hour sharing records for a chosen Memory; server verifies owner and expiry on **every read**, not only in Flutter.
3. Audience enforcement (friends-only first), revoke, block and deletion propagation.
4. Community feed as a separate opt-in feature, with abuse/report/moderation requirements agreed before enabling it.
5. Production readiness: distributed rate limiting, server-side pagination, job/expiry cleanup, observability without logging personal content, access audits and migrations.

## Data model proposal (not yet migrated)

- `friend_requests(id, requester_id, recipient_id, status, created_at, responded_at)`: requester and recipient distinct, unique active pair, no self-request; both users can view the request, only recipient accepts, requester can cancel. Blocked users cannot request.
- `friendships(user_low_id, user_high_id, created_at)`: canonical ordered UUID pair; only mutual acceptance inserts.
- `memory_shares(id, memory_id, owner_id, audience, created_at, expires_at, revoked_at)`: enforce `expires_at <= created_at + 24h`, verify memory ownership on create, and never allow direct arbitrary recipient IDs. Start with `audience='friends'` only.
- `blocks(blocker_id, blocked_id, created_at)`: restrict discovery, friend and share access in **both** directions as applicable; blocking immediately invalidates access.
- A separate immutable `share_snapshot` may be needed if edits/deletion must not unexpectedly expose data. Prefer server-side joins to live private Memory until explicit retention rules are decided.

## Authorization requirements

- Authenticated user ID comes exclusively from verified Supabase JWT, never from request body.
- Friends-only shared Memory can be read **only** if the share is active, unrevoked, unexpired and recipient remains a friend; block and privacy settings override friendship.
- Never reuse private photo download routes as public share links. A share-specific endpoint must check audience and expiry **before** issuing short-lived media access; avoid long-lived signed URLs.
- Deleting an Album or Memory must revoke associated shares and remove accessible photos consistently.
- Avoid leaking whether a private Memory exists: use 404 for unauthorized read.
- Expiration enforcement is request-time; background cleanup handles storage hygiene only.
- Default deny for community feed and external discovery until feature, consent and moderation are validated.

## Initial test matrix

- A/B strangers: no friends-only share read; no private photo read.
- Request -> accept -> friend -> share -> read; revoke -> 404.
- Expiry at exactly 24h -> 404 with deterministic clock.
- Unfriend or block -> immediate 404.
- Deleted Memory/Album -> share and media inaccessible.
- B cannot create, update or revoke A's shares.
- No cached/signed URL is usable beyond authorization guarantees.
- Rate-limit requests, pagination, and idempotency tests.

## Deployment note

This document is an architecture proposal only. It does **not** create a public social feature, execute a Supabase migration, or change Flutter UI. Implementation should proceed incrementally after reviewing relationship and audience semantics.
