# Real mobile login and signup — Supabase Auth

Branch: feat/mobile-supabase-auth-email-phone (review before merge).

The Flutter login UI uses **Supabase Auth** with:
- Email/password sign-up (confirmation handled) and sign-in, including Gmail addresses.
- Phone sign-in/sign-up with SMS OTP verification (requires SMS provider).
- Optional Google account OAuth login, separate from Gmail email/password.

Existing Home, Journal, Study, Album and MapLibre files are preserved.
No database migrations, Supabase Auth provider settings or data were changed.

## Running on Android/macOS/Windows

Run from `mobile/`. Install the new dependency and refresh the lockfile:

    flutter pub get
    flutter run --dart-define=AUTH_ENABLED=true \
      --dart-define=SUPABASE_URL=https://rjwentsuqmwncpseakkt.supabase.co \
      --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_KEY

Use the Supabase project's publishable API key (or legacy anon key)
from Dashboard → Project Settings → API Keys. **Never pass a service-role
or secret key to Flutter or commit it.** This branch intentionally does not
store a key in the repository.

With both URL + key defined, real Auth gates the app. In debug/development,
without config, the existing unauthenticated Flutter UI demo still works.
**Release builds always require configured Supabase Auth** and fail closed if
URL/key are missing. AUTH_ENABLED=true also fails closed when config is missing.

Google OAuth is **optional**. Enable only after configuring Google
provider in Supabase, an OAuth app in Google Cloud and the allowed callback
URL `aijournal://auth-callback/` in Supabase Auth URL Configuration, and
testing Android redirect handling:

    --dart-define=GOOGLE_OAUTH_ENABLED=true

The Android manifest adds the matching callback intent filter. iOS setup
is separate and has not been validated.

## Continue without an account (guest)

The start screen now offers **Continue without an account** alongside
Email/Gmail + password and Phone + SMS OTP. User consent is shown before
entering guest mode. Neither `signInAnonymously()` nor another Supabase
authentication endpoint is invoked: guest mode creates **no Supabase account**.

- On first guest launch: OB01–OB11 onboarding, then Home.
- Guest state survives app restarts **on the same installation only**.
- Guest journals, drafts and onboarding are stored under local
  `users.local-guest.*` preferences, separate from
  `users.<supabase-auth-uuid>.*`.
- The app does not upload guest journals to Supabase, FastAPI or cloud
  storage. Existing Explore places and Album Share remain mock/demo-only.
- Profile's **Đăng nhập / Tạo tài khoản** action asks the user to confirm
  deletion of guest journal, drafts and onboarding progress before opening
  the account login. **There is no automatic guest-to-account migration.**
- Android disables automatic app backup (`allowBackup=false`) and
  adds explicit Android 12+ cloud/device-transfer exclusions so OS backups
  do not restore guest private files after reinstall.
- **Important limitations:** This repository has no iOS runner, so
  iOS device/iCloud backup exclusions have NOT been implemented or verified.
  Do not promise complete irreversible erasure on iOS yet. No software can
  delete user-made exports, screenshots, third-party backups or system copies
  outside its app sandbox. For verified privacy on iOS, implement and test
  native backup exclusions before release.
- Android backup is disabled for the **whole app**, including authenticated
  users' *local* journals. Since journal cloud sync is not yet built,
  uninstall/reinstall currently loses those local journal entries as well.
  A real Supabase account/identity still exists, but does not restore
  unsynchronized journal content.

In release builds `SUPABASE_URL` and publishable key are still required
to initialize Auth, **even when the user later selects guest**. The app
never silently grants a "logged in" server session to guests.

## Supabase Dashboard configuration (requires project admin)

1. Authentication → Sign In / Providers → Email: enable email/password
   and set email confirmation policy; verify outbound confirmation delivery.
2. Authentication → Sign In / Providers → Phone: enable phone auth and
   configure an SMS service (e.g. Twilio). SMS may incur charges; do not
   enable/trigger paid delivery without agreeing to a provider and budget.
   Test +84 E.164 number format and OTP rate limits.
3. Authentication → Sign In / Providers → Google (optional): configure
   OAuth client and redirect allowlist, then enable the Google button.
4. Test login, signup, email confirmation, logout, expired OTP, and
   automatic session restore on emulator.

## Critical database/privacy limits

Supabase Auth user accounts are managed by Supabase's `auth.users` service.
The public database tables in AI-Journal-Dev currently have **RLS disabled**.
Do NOT grant direct mobile access to public journal/album/place tables.
The backend's owner-protected routes and migrations must be deployed
separately after review, with verified RLS/grants and JWT authorization.

Until then, saved Journal and onboarding state is local-only via
`shared_preferences`, separated by the Supabase user ID to prevent
cross-account mixing on the same device. It is **not encrypted, backed up,
or synchronized to Supabase**. Existing anonymous demo data is not
silently attributed to any signed-in account. Album and Map persistence
remain separate work, pending backend deployment.

## Local testing (no real SMS or database writes from unit tests)

    cd mobile
    flutter pub get
    dart format lib/main.dart lib/core/config/app_config.dart \
      lib/features/auth lib/features/onboarding/data/onboarding_store.dart \
      lib/features/journal/data/journal_repository.dart \
      lib/features/profile/profile_screen.dart test/features/auth
    flutter analyze
    flutter test test/features/auth
    flutter test
    flutter build apk --debug

Do not claim CI/build success without running Flutter. Commit the
regenerated `mobile/pubspec.lock` after `flutter pub get`. Only enable
real auth on a device when all necessary provider settings are configured.

References:
- https://supabase.com/docs/guides/auth/quickstarts/flutter
- https://supabase.com/docs/guides/auth/phone-login
- https://supabase.com/docs/guides/auth/social-login/auth-google
