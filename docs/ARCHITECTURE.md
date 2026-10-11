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
