# PR29 ↔ B14 Reconciliation — 28 Oct 2026

## What was actually combined

This **draft** integration PR builds from B14 PR #28, with **UI, assets, sound, Study and Album PIN from Vy PR #29** overlaid. Source UI commit: `9cfdac3`. All previous PR chains stay open and unmerged.

- **Kept from B14:** `mobile/lib/main.dart` SupabaseAuthService + AuthGate; account-scoped LocalJournalRepository and LocalAlbumRepository; B14 backend FastAPI tree with private JWT owner-scoped APIs; `RemoteJournalRepository`; API client and device-draft protections; Android Emulator launch scripts.
- **Adopted from Vy PR29:** redesigned Home, Journal list + delete confirmation, Study writing and source labels, hand-drawn MapLibre style / Explore UI, Album four-digit PIN UX and local photo UI, app typography, audio/sound assets, latest tests.
- **Resolved shared config:** pubspec now contains `supabase_flutter`, `crypto`, `audioplayers` and fonts/assets for both sides. Flutter dependency lockfile should be refreshed using `flutter pub get` in a reviewed checkout before release.
- **Identity privacy:** AuthGate injects `LocalStudyProgressStore(userId: ...)`, and `PinAlbumAuth(LocalAlbumPins(userId: ...))`. Do not import an old globally keyed Study progress or PIN from another user account. Guest uses a distinct guest namespace. Existing scoped journals and albums remain unchanged.
- **Music:** B14's AuthGate entrypoint now calls the PR29 sound start routine, including signed-in sessions.

## Study → Cloud Journal source (new API 09)

PR29 adds `JournalContent.source` (`kind`, `id`, `label`, `task`). Sending journal text without this field loses the association to the Study challenge. To avoid that data loss, this PR adds **additive Alembic `20261028_09`** and a nullable `journal_entries.source` JSON column, plus Pydantic validation and Flutter client serialization. The source may be null for old journals. Editing source increments the journal body version but not the written-text streak. JWT/owner 404 and RLS policies stay intact.

**Current shared Supabase database remains at `20261026_08`.** Migration 09 was **NOT deployed**. The updated runtime launcher intentionally checks for 09 so that code depending on `source` does not run against an outdated schema. Do not alter `alembic_version` by hand. To deploy after PR review, use a reviewed Alembic upgrade or explicit authorized migration transaction that preserves both Alembic and Supabase migration history; perform normal backup/release controls.

## Features deliberately NOT claimed as cloud-enabled

| Screen | Current persistence in reconciled code |
|---|---|
| Auth / signed-in session | Real Supabase Auth |
| Journal list, create, update, delete | Real FastAPI/Supabase when `JOURNAL_CLOUD_ENABLED=true` and no existing local journal would be hidden; otherwise scoped local |
| Study-written JournalSource | Real FastAPI/Supabase only after migration 09 and Cloud flag; Study progress/drafts otherwise remain scoped device storage |
| Album/Memory | Account-scoped **local** repository; backend album APIs exist but no reviewed mobile cloud adapter yet |
| Album PIN | Per-device hashed 4-digit PIN, scoped per identity. UI lock only: **not data encryption** and no recovery flow |
| Explore / Saved Places | MapLibre UI, sample search / local pins; FastAPI place APIs exist but are **not yet wired to these screens** |
| AI | FastAPI AI endpoint uses mock by default; Ollama activation is separate |

**No automatic import** of private local journals/albums into Supabase. Never replace a scoped authenticated repository with a global SharedPreferences store.

## Outstanding release work

1. Recheck combined Flutter analyze, widget tests, asset bundle and backend disposable PostgreSQL 17 migrations via GitHub Actions on this PR (do not equate old PR CI with combined release CI).
2. Review PR29's Album PIN migration and whether lost PIN recovery is acceptable; PIN storage is not encryption.
3. Decide the cloud rollout and migration 09 deployment before launching this branch on a real device.
4. Implement separate mobile adapters for backend Album/Memory and Saved Places, with media transfer and owner-scoped authorization, before claiming *all* screens sync across devices.
5. Finish M01–M04 only **after** rebasing their MapLibre search work onto the reconciled UI, so new Map styles/overlays are preserved.

## Local commands after migration approval

```powershell
cd C:\Users\PC\Documents\AI-Journal
git fetch origin
git worktree add --detach ..\AI-Journal-UI-Cloud origin/integration/vy-ui-cloud-20261028

cd ..\AI-Journal-UI-Cloud
Copy-Item ..\AI-Journal-Cloud\backend\.env .\backend\.env
Copy-Item ..\AI-Journal-Cloud\mobile\.env.journal-cloud.json .\mobile\.env.journal-cloud.json

# Install deps as usual, ensure live DB has revision 09 before start.
powershell -ExecutionPolicy Bypass -File .\scripts\start_journal_cloud_backend.ps1
```

Use a running Android emulator, then in another terminal `powershell -ExecutionPolicy Bypass -File .\scripts\start_journal_cloud_mobile.ps1`. The latter remains gated by `AUTH_ENABLED` and `JOURNAL_CLOUD_ENABLED` in the ignored JSON config.
