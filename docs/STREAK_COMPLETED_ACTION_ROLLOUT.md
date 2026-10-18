# B06 — Completed Journal Action Streak: rollout and QA

**Status:** feature branch `feat/backend-action-streak` prepared as a stacked PR above B04; not merged, not deployed to AI-Journal-Dev.

## New product rule (approved by Phúc, 2026-10-18)

Streak is awarded only after the backend **successfully saves a meaningful writing action**, not for app opens.

| Action | Award today's completion? |
|---|---|
| Authenticated `POST /api/v1/journals` with nonblank content (at least one written line) | **Yes**, after successful DB commit |
| Authenticated `PUT /api/v1/journals/{id}` changing the journal's nonblank `content` | **Yes**, after successful DB commit |
| Repeating successful writing on a date already completed | No duplicate day |
| Open/foreground the app; log in; read journal or streak | No |
| Change title, prompt or mood only | No |
| Resubmit exactly unchanged content | No |
| Empty/blank journal, validation error, unauthorized user, or failed DB transaction | No |
| Delete a journal | No, and past credited days remain |

Future action types (e.g., finishing a guided exercise) are **not enabled** in B06 and must be explicitly designed and verified on the backend before they can count.

## Data and API

- Table: `public.journal_action_days`, composite PK `(user_id, activity_date)`, `first_completed_at` UTC, `action_type='journal_written'`. PostgreSQL FK `user_id -> auth.users(id) ON DELETE CASCADE`. Migration `20261018_04` follows B04 `20261018_03`. Do **not** migrate the shared project until Phúc explicitly approves.
- `POST /api/v1/journals` and meaningful journal content `PUT` record the day and journal data **in a single transaction** with `ON CONFLICT DO NOTHING`.
- `GET /api/v1/streak?days=30`: **read-only**, requires Supabase JWT. Returns `current_streak`, `longest_streak`, `today_completed`, `timezone`, `activity_dates`.
- `GET /streak` is safe for the Flutter home/profile UI; **no `POST /activity/open`** and no client-defined completion events or dates.
- Activity day comes from **server UTC time converted into the user's IANA profile timezone**. No automatic reconstruction of prior dates from existing journals; no offline backdating in MVP. Changing timezone keeps old recorded local dates unchanged.
- The streak does not track a source `journal_id` so deleting a journal does not erase history. Deleting a Supabase account cascades its private streak records.

## UI handoff (B07)

- Display `today_completed: false` until a successful Journal save, not until app launch.
- Refresh `GET /streak` after `POST /journals` or meaningful `PUT /journals/{id}` succeeds. Do not award or animate a completed day based solely on a local button tap.
- No streak POST endpoint, local activity counter or app lifecycle reporter.
- For failed save, retain the editor content and do not show a completed streak.
- Days shown on calendar are local dates `YYYY-MM-DD`, timezone from response.

## Security / deployment gates

1. PR chain remains `#7 B01 → #8 B02 → #9 B04 → B06`; Phúc reviews and merges manually in dependency order (and later retargets stacked PRs). None is automatically merged.
2. Validate SQLite isolated tests: new table, anonymous `GET /streak` gives 401, cross-account isolation, single-day deduplication, multi-day continuity, local midnight, metadata-only / identical-content no-ops, and a failing journal transaction rolls back its streak insert.
3. **Before deploying** run full `python -m pytest -q` and `python -m alembic heads` against an isolated clone; run PostgreSQL staging migration and A/B JWT tests. Check the actual target project and current revision.
4. PostgreSQL role grants and RLS must deny direct anon/authenticated table access; the FastAPI access path must verify owner from JWT. Real `journal_entries` table in shared AI-Journal-Dev is currently on migration `20261011_01`, without ownership or RLS. This PR does not change that.
5. Downgrade refuses to drop accumulated streak history; use a reviewed recovery/backup plan.

### Expected example

A user opens app on Oct 18: `today_completed=false`. They save one-line content successfully: `today_completed=true`, `current_streak=1`. Opening app Oct 19 does not change anything; creating or meaningfully editing a journal on Oct 19 increases the streak to 2. Multiple edits on Oct 19 still count only once. On Oct 20 without writing, the current streak stays 2 until the end of the day; by Oct 21 without writing it resets to 0 while the historical longest stays 2.
