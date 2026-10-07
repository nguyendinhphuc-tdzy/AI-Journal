# Database Schema — v0.1

The current functional slice needs one persistent entity first: `journal_entries`.

## journal_entries

| Field | Type | Notes |
|---|---|---|
| id | integer | primary key |
| title | string | optional/short title |
| content | text | journal body |
| prompt | string | prompt used to start writing, optional |
| mood | string | optional lightweight metadata |
| created_at | datetime | UTC timestamp |
| updated_at | datetime | UTC timestamp |

## Later candidates — not committed yet

These should be added only when their feature contract is finalized:

- users / auth
- journal_images
- reminders
- streak/activity history
- framework/challenge progress
- album collections
- places / journal-place links
- persisted AI reflections

The repository defaults to SQLite locally. `DATABASE_URL` is configurable so the same SQLAlchemy models can move to PostgreSQL later.
