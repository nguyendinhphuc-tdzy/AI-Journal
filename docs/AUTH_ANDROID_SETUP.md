# Android Auth integration — Google, Facebook and SMS OTP

Updated 2026-10-29. Maintainer checklist for PR #66. Backend is Supabase Auth + FastAPI JWT validation; **no API secrets in Git or Flutter**.

## Status and security

- Android OAuth launch/session handling and OTP UI are in PR #66. The build **must not** display real providers whose corresponding `--dart-define` feature flag is false.
- GitHub unit/widget tests use fake AuthService; they do not prove that external Google/Meta providers or an SMS gateway are configured. Test on a physical/emulated Android device with a real Supabase session and an authorized test account.
- The browser opening is not successful authentication. The app waits for Supabase to process the deep link, and exits the waiting state on success, error, manual stop or a two-minute timeout. Stopping the **local** wait does not revoke an external browser's eventual OAuth authorization. To revoke such a session, use the app's sign out.
- Do not associate accounts by email/phone by assumption. Supabase OAuth/OTP may create a **different user ID** from an existing email account. AI Journal keeps journals, analyses and pins separated by authenticated user ID; identity linking requires a separate, explicit product flow.
- Do not enable public SMS delivery until you review usage limits, CAPTCHA / abuse controls and SMS billing. Phone OTP is hidden in the app unless `PHONE_OTP_ENABLED=true`.

## 1. Supabase project and URL settings

Use the existing **AI-Journal-Dev** project reference `rjwentsuqmwncpseakkt` (verify it is the intended environment before changes):

- Dashboard: https://supabase.com/dashboard/project/rjwentsuqmwncpseakkt/auth/providers
- Auth → URL Configuration: https://supabase.com/dashboard/project/rjwentsuqmwncpseakkt/auth/url-configuration
- Add **exactly** `aijournal://auth-callback/` to redirect allow-list. Android manifest registers `scheme=aijournal`, `host=auth-callback`. `mobile/lib/core/config/app_config.dart` uses that same URL.
- OAuth provider callbacks use Supabase **HTTPS** endpoint: `https://rjwentsuqmwncpseakkt.supabase.co/auth/v1/callback`. This is configured in Google/Meta, **not** the mobile deep link.

## 2. Google OAuth (Dashboard-only secrets)

1. In https://console.cloud.google.com/apis/credentials select/create the project's OAuth consent screen, audience and test users (if in Testing); request only `openid`, email and basic profile.
2. Create an **OAuth Client ID of type Web application** for Supabase hosted OAuth (not an Android-only credential). Add `https://rjwentsuqmwncpseakkt.supabase.co/auth/v1/callback` as an authorized redirect URI. The exact authorized origins must follow your configured origins; do not invent an unrelated domain.
3. In Supabase → Authentication → Providers → Google, enable and paste the Google **Client ID** and **Client Secret** directly in the dashboard. Do not paste the secret in chat or commit it.
4. Build the Android app with `GOOGLE_OAUTH_ENABLED=true`. Use a Google tester account. Confirm browser → Supabase → app redirect, `AuthGate` receives the real session, the same Supabase user ID appears on subsequent opens, and FastAPI `GET /me` works with that JWT.
5. Test deny/cancel, offline callback, expired session and sign out. A browser launch that fails to establish an Auth session must not advance to the authenticated home.

Documentation: https://supabase.com/docs/guides/auth/social-sign-in/auth-google

## 3. Facebook OAuth (Meta App ID/Secret only in Supabase)

1. In https://developers.facebook.com/apps/ create/select a Meta app with the Authentication and Account Creation use case / Facebook Login setup.
2. Add the same Supabase HTTPS callback URI to **Valid OAuth Redirect URIs**. Do not use the `aijournal://` URI in Meta's redirect list.
3. Ensure `public_profile` and `email` permissions are ready for testing. If Meta app remains in development, add your own Facebook accounts as App Roles testers/developers. Public rollout may require Live mode and review.
4. In Supabase Auth → Providers → Facebook enter the **App ID** and **App Secret** privately; enable provider.
5. Build with `FACEBOOK_OAUTH_ENABLED=true`. Verify login, declined permissions, account without accessible email, callback error and sign out. Mock Facebook-friends UI is **not** the real provider and should never be used in authenticated builds.

Documentation: https://supabase.com/docs/guides/auth/social-sign-in/auth-facebook

## 4. SMS OTP — currently NO paid gateway configured

**Development without sending real SMS:** Supabase supports **test phone numbers with fixed OTP codes** in the Auth testing configuration. Add a dedicated, non-personal test number and fixed code directly in Supabase; never hardcode the test number/code in source or build flags. Enable Phone Auth for this QA configuration only if Supabase allows verified test-number login; then build with `PHONE_OTP_ENABLED=true` and verify that a six-digit code produces a real Supabase session (no external SMS sent). Use a number reserved for testing, not another user's number.

**For real SMS** after approving costs, select a supported service such as **Twilio** (or Vonage). Configure phone/SMS sender, delivery destination and credentials inside Supabase's Phone provider page, verify +84/Vietnam delivery eligibility, sender/country restrictions and pricing in the SMS provider console. Never expose SMS credentials in Flutter. Confirm OTP send/verify with a real handset; configure server-side rate limits, CAPTCHA, fraud monitoring and any applicable local sender registration.

- UI accepts E.164 phone numbers, e.g. `+849...`, and a six-digit SMS OTP.
- A successful OTP verify must return a Supabase session. Invalid/expired codes display a recovery message. A resend requested within 60 seconds is blocked by the UI (Supabase may apply stricter limits).
- Changing the phone number resets the OTP field. Phone OTP signup/signin can create a new Supabase user; it must not silently merge an existing Google/email account.

Documentation: https://supabase.com/docs/guides/auth/phone-login and https://supabase.com/docs/guides/auth/testing-auth-flows

## 5. Android emulator build

Run from the `mobile` directory (replace placeholders locally, **publishable** key only):

```bash
flutter pub get
flutter run \
  --dart-define=AUTH_ENABLED=true \
  --dart-define=SUPABASE_URL=https://rjwentsuqmwncpseakkt.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY \
  --dart-define=GOOGLE_OAUTH_ENABLED=true \
  --dart-define=FACEBOOK_OAUTH_ENABLED=false \
  --dart-define=PHONE_OTP_ENABLED=false
```

Only toggle Google/Facebook/Phone to `true` **after** the corresponding Supabase provider is configured (or for explicitly configured phone test numbers). Do not set `FORCE_LOGIN_ON_START=true` while testing session persistence; it intentionally signs out at startup. Existing `JOURNAL_CLOUD_ENABLED`, `ALBUM_CLOUD_ENABLED`, `PLACES_CLOUD_ENABLED` flags are independent.

## 6. Verification matrix (required before calling external login "done")

| Path | Expected result |
| --- | --- |
| Google valid tester | Returns to Android; Supabase session and JWT; FastAPI /me succeeds |
| Google rejected/cancelled/timeout | Sign-in not claimed; local wait can be stopped; no fake account |
| Facebook test-role valid | Same as Google; correct Supabase provider and access permissions |
| Facebook tester denied / email unavailable | Clear error; no demo account or simulated friends data |
| Phone test number + fixed code | Real Supabase session without SMS billing |
| Phone wrong code / resend too soon | Error; no session / no duplicate SMS request |
| Physical phone with paid gateway | Actual SMS received and verified after cost approval |
| Sign out / restart / change account | No private journals/album/analysis leak across user IDs |

## Scope boundaries

- No provider credentials, paid SMS service, or Auth dashboard changes were made by this PR.
- No external OAuth/real SMS end-to-end claim until the owner completes provider setup and Vy confirms device test.
- Separate privacy-policy approval from provider enablement; PR #66's policy remains draft.
