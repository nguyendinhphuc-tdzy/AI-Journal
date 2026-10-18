# Architecture Decision Log

## ADR-001 — Flutter for the mobile client

**Status:** accepted from current product/UI plan.

Reason: the latest UI implementation plan and folder structure are Flutter-based.

## ADR-002 — Feature-first mobile structure

**Status:** accepted.

Reason: three contributors + Codex agents can work in different feature directories with less merge conflict.

## ADR-003 — FastAPI backend

**Status:** retained from the team's technical direction.

## ADR-004 — Supabase PostgreSQL is the team database

**Status:** accepted (2026-10-11, confirmed by Phúc).

Use hosted PostgreSQL from Supabase for the shared development/demo environment. Flutter continues calling FastAPI; FastAPI accesses Postgres using SQLAlchemy. Use Session pooler for IPv4 development and an optional Direct migration connection where IPv6 is available. Automated tests remain isolated on SQLite. Database credentials are only in untracked `backend/.env`. See `docs/SUPABASE_SETUP.md`.

Supabase Auth and Storage are not automatically included in this decision.

## ADR-005 — Mock AI provider first

**Status:** provisional.

No production AI provider is finalized. A deterministic mock protects UI/backend development from provider availability and secret management while preserving the integration boundary.

## ADR-006 — Supabase Auth email/password; FastAPI verifies access tokens

**Status:** accepted by Phúc for MVP v1 (2026-10-18); implementation pending B02/B03.

Supabase Auth manages passwords, sign-up/sign-in, email verification and session refresh. Flutter calls Auth through the supported Supabase SDK and supplies access tokens to FastAPI. FastAPI validates the JWT signature, issuer, audience, expiry and subject before looking up user-owned records. The server obtains `user_id` only from verified token claims, never from client payloads. Default profile timezone is `Asia/Ho_Chi_Minh`.

## ADR-007 — Streak means authenticated app-open days, not journal completion

**Status:** accepted by Phúc for MVP v1; implementation pending B06/B07.

An authenticated first open or foreground-resume request creates at most one `app_open_days` event for a server-calculated local date. A day with multiple opens still counts once; writing a journal is neither required nor sufficient. Streaks derive from stored dates rather than a mutable client counter. MVP v1 does not backdate offline opens. Previously stored dates remain unchanged after timezone edits.

## ADR-008 — MapLibre + OpenFreeMap; provider-neutral saved places

**Status:** accepted by Phúc for MVP v1; implementation pending B08/B09/B11.

Flutter renders maps via MapLibre with OpenFreeMap styles (without Google Maps billing or Google Maps SDK keys). User can drop a pin at arbitrary coordinates. Address/POI search is a **separate** service; proposed MVP provider is Geoapify through FastAPI, with its key server-side and service terms/quotas reviewed before integration. Persist `provider` + `external_place_id`, coordinates and user-created labels/notes; do not hardcode `google_place_id` or store an unrestricted copy of provider data.

## ADR-009 — Multiple private notes and journal-place linking

**Status:** accepted by Phúc; implementation pending B10/B11/B12.

A saved place may have many notes and may link to many journals; a journal may link to many places. All three entities are private and owned by a verified account; composite foreign keys enforce same-owner links. Deleting a place removes its notes and association rows, but **never** deletes journal content. Unlinking is nondestructive.

## ADR-010 — Secure data-access boundary and migration rules

**Status:** accepted target architecture; not yet enforced.

Flutter uses Supabase Auth for login and FastAPI for personal data. No database connection string or elevated Supabase key goes into Flutter. PostgreSQL models/migrations are owned by FastAPI + Alembic. Enable appropriate RLS/grant restrictions on public data tables and block direct client access until audited, while still enforcing owner filters within FastAPI. Existing `journal_entries` has no `user_id`: preserve old rows, require explicit owner mapping before enforcing `NOT NULL`, and never delete or claim legacy entries automatically. No direct SQL schema changes in B01.
