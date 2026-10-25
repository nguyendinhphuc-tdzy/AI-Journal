# Demo integration gate — 26 October 2026

Status: **PARTIAL / NOT DEMO READY**. This integration branch is for review only.
Never apply migrations on AI-Journal-Dev or merge the stacked PRs solely because a CI job is green.

## Verified findings

- Flutter CI run 38512113954 failed 11 widget tests, with Nudaeng artwork assets referenced in decomposed Unicode while tracked file names are NFC. This branch normalizes five source references. Re-run the suite: older test results do not certify the current HEAD.
- PR #16 (mobile Supabase Auth/guest) diverged from base and was nonmergeable when inspected. Its `pubspec.yaml` and `main.dart` are from a version that predates Album and image/local_auth dependencies. **Do not replace either file wholesale**. PR #16 also lacked regenerated `pubspec.lock`.
- Default `main.dart` starts `LocalJournalRepository` and `LocalAlbumRepository`. These are device-local only.
- Default `ExploreScreen` keeps saved locations in a StatefulWidget list; manually saved places are lost when that widget is destroyed. Sample anonymous shares and inbox flows are UI demos, **not network sends**. Do not display a successful share unless an actual backend has acknowledged it.
- PR #19 adds JWT owner-scoped Album/Memory endpoints and migration 20261025_07. SQLite and disposable PostgreSQL CI succeeded on 25 October, but the mobile adapter is missing. Uploaded photos, server-side sharing expiry and private storage are explicitly out of scope.
- `mobile/lib/core/network/api_client.dart` now accepts an optional access-token provider and avoids embedding private server response text in exceptions. This is **infrastructure only**. It is not yet wired to Supabase Auth or a Journal repository.
- Backend Journal only stores `title/content/prompt/mood`; Flutter Journal also has guided values, `bodyVersion` and drafts. Do **not** map this silently and discard structured fields. A versioned backend contract or explicit local-only policy is needed.
- Android APK/emulator/device E2E has not been verified in this environment.

## Integration work order and acceptance criteria

### Gate 1 — Flutter CI and Android build (P0)
- Review this branch's GitHub Actions run; run `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug` on a configured SDK machine.
- Fix any remaining failing tests; confirm physical emulator boot, map plugin and asset display. The bundle job does **not** validate an APK.
- Do not merge PR #4's old CI workflow over this one without checking overlap.

### Gate 2 — PR #16 Auth reconciliation (P0)
- Create a new Auth reconciliation branch from current default HEAD; port needed auth files/logic intentionally.
- Retain current AlbumScope and its dependencies; add authenticated/guest account-scoped AlbumRepository and Explore local storage so users sharing a device never see another account's data.
- Regenerate `pubspec.lock`, run full Flutter QA and verify guest→onboarding→logout, identity switch, reinstall. Do not turn on email/SMS/Google production billing or flows without configuration.
- Only after checks pass should the maintainer close/supersede or merge the original PR.

### Gate 3 — JWT-aware Journal (P0)
- Inject `Supabase.instance.client.auth.currentSession?.accessToken` through an authenticated ApiClient factory, never client-side database access.
- Implement a distinct API-backed JournalRepository for authenticated accounts; guest continues explicit on-device mode.
- Resolve the guided-fields/version API contract first, preserving existing journal content and drafts. Correctly handle cursor pagination `{items,next_cursor}`, 401, 403/404, connectivity failure and retry without silent local success.
- E2E: authenticated user A creates journal → reads from backend after app restart; B cannot access it; day streak increments once for meaningful text change only.

### Gate 4 — Album review (P1)
- Review PR #19 migration order 01..07, user isolation and request schemas against the current mobile Album models. Local photo paths are not remote photos.
- Account isolation and storage/24-hour sharing policy are separate gates, not shippable by PR #19 alone.
- Do not apply Alembic to shared Supabase before a fresh backup and written approval.

### Gate 5 — Map + E2E (P0)
- Replace per-widget `_savedPlaces` with an identity-scoped repository and persist/reload markers; signed-in uses protected `/places`, guest uses device-only storage.
- Manual pin save should survive app restart and not appear in another user's account. Handle failed saves visibly; do not show success prematurely.
- Keep anonymous sharing off until the audience, consent, expiry and API are implemented; do not use fake “delivered” success messaging in a real demo.
- E2E Journal/AI and Album/Map must both be executed on emulator/real device with documented actual results.

### Gate 6 — Shared Supabase safety review (P0 security, **NO WRITES**)
- Existing security snapshot in `docs/MVP_TEST_PLAN.md` reported RLS disabled and legacy ownerless records; this snapshot is **not** a current DB health check.
- Obtain fresh read-only inspection of `alembic_version`, public RLS/grants, orphan journal rows and Auth JWT config.
- Capture a verified, restorable backup; stage migration on a disposable PostgreSQL clone; test rollback and user A/B isolation.
- Ask Phúc for explicit approval of exact migration SQL, target project and backup before any DDL/DML against AI-Journal-Dev.

## Review status
This PR fixes source-level CI blockers and introduces network/auth foundation only. It does not claim PR #16 conflict resolution, remote Journal/Album/Map persistence, database migrations, or passing end-to-end tests.
