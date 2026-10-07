# Architecture Decision Log

## ADR-001 — Flutter for the mobile client

**Status:** accepted from current product/UI plan.

Reason: the latest UI implementation plan and folder structure are Flutter-based.

## ADR-002 — Feature-first mobile structure

**Status:** accepted.

Reason: three contributors + Codex agents can work in different feature directories with less merge conflict.

## ADR-003 — FastAPI backend

**Status:** retained from the team's technical direction.

## ADR-004 — SQLite as local default only

**Status:** provisional.

The product document still mentions PostgreSQL/Supabase without a final choice. SQLite is used only to make local emulator development immediately runnable. `DATABASE_URL` remains configurable.

## ADR-005 — Mock AI provider first

**Status:** provisional.

No production AI provider is finalized. A deterministic mock protects UI/backend development from provider availability and secret management while preserving the integration boundary.
