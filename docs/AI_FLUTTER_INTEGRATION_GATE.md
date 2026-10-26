# AI Journal — Flutter ↔ FastAPI Local AI integration gate (2026-10-26)

This branch provides real AI widgets and a private HTTP adapter **without**
enabling uploads for guests or adding Supabase credentials to Flutter.

## Delivery / source branches

- Backend model provider: [PR #22](https://github.com/nguyendinhphuc-tdzy/AI-Journal/pull/22).
- Flutter integration infrastructure + CI: [PR #21](https://github.com/nguyendinhphuc-tdzy/AI-Journal/pull/21).
- This PR is **stacked on PR #21**. Merge the reviewed PR #21 first, then
  rebase this branch on the up-to-date default after CI succeeds.
- Authentication [PR #16](https://github.com/nguyendinhphuc-tdzy/AI-Journal/pull/16)
  still requires reconciliation with current AlbumScope and pubspec.lock.
  Do **not** merge the old PR wholesale.

## Boundaries

1. `ApiAIService` is injected explicitly into `AiDiaryApp(ai: ...)` or
   `AiRemoteScope`; the default app uses the original device-only demo
   and `MockReflectionService`. This avoids silently transmitting a
   guest's journals to the network.
2. All `ApiAIService` calls set `requireAuth: true`. An empty/absent
   access token throws `MissingAccessTokenException` **before HTTP**.
   Never insert a long-lived static token into Flutter, dart-define or git.
3. The backend PR #22 requires a verified Supabase JWT in Ollama mode.
   Its mock mode is reserved for pre-integration local UI tests.
4. The real writer Go Deeper button awaits `/api/v1/ai/go-deeper`, then
   displays that question. Errors show a retryable snackbar rather than
   substituting a canned question.
5. The real reflection screen awaits `/api/v1/ai/reflection` and displays
   all four fields. Errors are visible and retryable with no fake analysis.
6. The onboarding reflection reuses `ReflectionService`: injected
   `ApiAIService` sets `simulated=false`; unconfigured demo remains
   simulated, never disguised as real AI.
7. The Flutter Journal repository still uses local storage; this PR does
   **not** implement remote Journal persistence, cloud sharing or streak
   synchronization. Do not suggest otherwise in a demo.

## Wiring after Auth PR reconciliation

In the **authenticated-session** tree (not the guest tree), construct
and pass an account-scoped service:

```dart
final api = ApiClient(
  accessTokenProvider: () async =>
      supabase.auth.currentSession?.accessToken,
);
final ai = ApiAIService(api);

// Attach to the signed-in subtree ONLY:
AiRemoteScope(service: ai, child: authenticatedApp);
```

If using the default `AiDiaryApp` builder for an authenticated session
instead of AuthGate, use `AiDiaryApp(ai: ai)`. Do not attach the service
to guest mode, or instantiate the remote client before confirming an
authenticated user. Clean up the underlying ApiClient when the session
ends, and invalidate stale results when accounts switch.

## Configuration for demo devices

Android emulator on the FastAPI host:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Android phone on the same trusted LAN as the FastAPI server:

```powershell
flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_HOST:8000/api/v1
```

Local HTTP is only acceptable with fictional demo data on a private network;
use HTTPS for production and personal journals. `10.0.2.2` is valid only
when Android Emulator runs on the same host machine as FastAPI.

## Acceptance

- `flutter analyze --no-pub`, `flutter test --no-pub`,
  `flutter build bundle --no-pub` pass on GitHub Actions.
- Unit/widget tests verify token preflight, dynamic token refresh,
  API contract, server content rendered in UI, and no silent fake fallback.
- Auth PR passes Flutter CI, and only signed-in users receive real AI.
- Full mobile E2E requires real Supabase JWT and private FastAPI LAN
  connection and is **not certified by isolated unit tests**.
- No modifications to shared Supabase, no migrations, no real journal data.
