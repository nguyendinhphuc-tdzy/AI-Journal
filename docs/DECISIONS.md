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
