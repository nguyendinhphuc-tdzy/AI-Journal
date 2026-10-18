# Technical Architecture

## System overview

```text
Android Emulator (Flutter)
        |
        | HTTP / JSON
        v
FastAPI backend on developer PC
        |
        +---- SQLAlchemy ----> Supabase PostgreSQL (shared team DB)
        |                       (SQLite only for isolated automated tests)
        |
        +---- AIService -----> MockAIProvider by default
                               Real provider later
```

Android Emulator calls the host machine using `10.0.2.2`.

## Mobile architecture

Feature-first structure:

```text
mobile/lib/
├── core/
│   ├── config/
│   ├── network/
│   ├── theme/
│   └── widgets/
├── features/
│   ├── onboarding/
│   ├── home/
│   ├── journal/
│   ├── study/
│   ├── album/
│   ├── explore/
│   └── profile/
├── navigation/
└── main.dart
```

For the first sprint, screens use mock/local state so UI work can proceed before backend integration. Network and repository code should be introduced per feature rather than creating one giant global service.

## Backend architecture

```text
backend/app/
├── core/
│   ├── config.py
│   └── database.py
├── models/
├── schemas/
├── modules/
│   ├── journal/
│   ├── prompts/
│   └── ai/
└── main.py
```

Keep `main.py` thin: application setup + router registration only.

## Integration boundary

`docs/API_CONTRACT.md` is the contract between Flutter and FastAPI. Feature code may evolve independently as long as the contract remains stable.

## AI boundary

The app talks only to the backend. Flutter must not store production AI provider keys or call a paid AI provider directly.

```text
Flutter -> FastAPI -> AIService -> provider
```

`AIService` starts with a deterministic mock implementation so the app remains demoable even without network/provider access.

## MVP v1 integration architecture (design, not deployed)

```text
Flutter
  |-- Supabase Auth SDK -> Supabase Auth (email/password, session/JWT)
  |-- MapLibre native map renderer -> OpenFreeMap style/tiles
  +-- Bearer JWT / JSON -> FastAPI
          |-- verify Supabase JWT; obtain owner UUID
          |-- /me + /journals + /activity/open + /streak
          |-- /geo/search -> Geoapify (backend key, optional)
          +-- /places + /notes + /journal-place links
                |
                +-- SQLAlchemy / Alembic -> Supabase PostgreSQL
```

**Trust boundary:** Supabase Auth is identity provider, while FastAPI alone authorizes access to private journal/place/streak data. Using MapLibre to render tiles does not make place notes public. No GPS permission is needed to tap/drop a pin manually; location permission is a separate future decision. Backend verifies ownership even when RLS is enabled; a privileged backend role may bypass RLS.

**Deployment/security gate:** Existing unauthenticated journal CRUD is prototype-only. Do not expose it publicly or persist private customer data until B02/B04 authorization, RLS/grants and A/B isolation tests pass. Current Supabase public tables `journal_entries` and `alembic_version` were observed with RLS disabled. B01 only documents the changes; migrations and policy/grant changes require follow-up PRs.

**Interface contracts:** `docs/API_CONTRACT.md` for Flutter↔FastAPI; `docs/DATABASE_SCHEMA.md` for schema and migration order; `docs/MVP_BACKLOG.md` for ownership and dependency gates; `docs/MAPLIBRE_SETUP.md` for Flutter mapping.
