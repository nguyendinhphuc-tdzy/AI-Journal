# AI Journal — Facebook Login on Android

## Scope and current status

Facebook Login is integrated in Flutter and Supabase Auth on the stacked
authentication Draft PR #24. The feature is **disabled by default** until
the Supabase Dashboard, Meta dashboard, and Android callback are verified.

**Not included:** finding Facebook friends, Graph API friend sync, contacts
upload, `user_friends` permission, syncing private journals, or a completed
real Android sign-in test.

## 1. Facebook Developer App

- Use Case: **Authentication and Account Creation**
- Permissions: `public_profile` and `email` both ready for testing
- Under Facebook Login OAuth Settings, save this **exact** Valid OAuth Redirect URI:
  `https://rjwentsuqmwncpseakkt.supabase.co/auth/v1/callback`
- Keep web OAuth login, HTTPS and strict redirect URI matching on.
- In Meta Development mode, add and use authorized developer/tester accounts;
  ordinary Facebook accounts are not eligible until Meta Live/review gates pass.

Never commit or paste the Meta App Secret into Flutter, git or a chat.

## 2. Supabase Dashboard

1. Authentication → Sign In / Providers → Facebook: **Enabled**,
   **Facebook App ID** and **App Secret** saved; confirm the provider toggle,
   not only the fields.
2. Authentication → URL Configuration → **Redirect URLs**:
   add exactly `aijournal://auth-callback/`.
3. The custom-scheme redirect is for Supabase to return to Flutter.
   Do **not** put it in Meta Valid OAuth Redirect URIs; Meta only gets
   the HTTPS Supabase callback.
4. Use test-only accounts and synthetic journal content for OAuth QA.

## 3. Flutter and Android

- Auth implementation: `SupabaseAuthService.signInFacebook()` uses
  `client.auth.signInWithOAuth(OAuthProvider.facebook, ...)`;
  it requests only `email,public_profile`.
- The `AuthScreen` shows the Facebook button only if
  `FACEBOOK_OAUTH_ENABLED=true`. Supabase still verifies sessions.
- OAuth uses `redirectTo: aijournal://auth-callback/`.
- `mobile/android/app/src/main/AndroidManifest.xml` already declares
  the `aijournal` scheme with `auth-callback` host.
- `AuthGate` listens for the resulting Supabase signed-in session.
- No Facebook SDK or App Secret is stored in the Android app.

From the separate Auth worktree, inside `mobile/`:

```powershell
flutter pub get
flutter run `
  --dart-define=AUTH_ENABLED=true `
  --dart-define=FACEBOOK_OAUTH_ENABLED=true `
  --dart-define=SUPABASE_URL=https://rjwentsuqmwncpseakkt.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Use the Supabase **publishable** key; never a secret/service_role key.
The publishable key is designed for client applications, though it should
still be supplied via local development configuration rather than stored in
repository source.

## 4. Acceptance / privacy

- Widget test: Facebook button hidden by default and wired to AuthService
  when enabled; CI analyze/test/asset bundle must pass.
- Manual Android emulator/phone: tap "Tiếp tục bằng Facebook", browser
  opens, Meta test account signs in, redirects back into app, then
  Supabase Authentication → Users shows the same account.
- Sign out; sign in again; check local journal data stays isolated by
  Supabase user ID (no data shared with another login).
- Meta login prompts do not grant access to contacts or friend lists.
- Do not automatically publish the user's Facebook identity, name,
  profile or activity to other AI Journal users. Any friend-discovery
  feature must require separate user opt-in and authorized Meta API
  permissions; provide username/invite code as an independent fallback.
- Authentication does not sync on-device Journal or Album content to
  Supabase; app uninstall still loses unsynchronized local data.

References:
- https://supabase.com/docs/guides/auth/social-sign-in/auth-facebook
- https://supabase.com/docs/reference/dart/auth-signinwithoauth
- https://supabase.com/docs/guides/auth/redirect-urls
