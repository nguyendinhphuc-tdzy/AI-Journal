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

With both URL + key defined, real Auth gates the app. Without config, the
existing unauthenticated Flutter UI demo still works. With AUTH_ENABLED=true
and missing config, the app fails closed and refuses to bypass authentication.

Google OAuth is **optional**. Enable only after configuring Google
provider in Supabase, an OAuth app in Google Cloud and the allowed callback
URL `aijournal://auth-callback/` in Supabase Auth URL Configuration, and
testing Android redirect handling:

    --dart-define=GOOGLE_OAUTH_ENABLED=true

The Android manifest adds the matching callback intent filter. iOS setup
is separate and has not been validated.

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
