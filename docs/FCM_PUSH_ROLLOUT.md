# FCM push integration handoff — Vy / Phúc

## Status and ownership
- **Phúc:** FastAPI `/devices`, `device_tokens` revision `20261030_21`, FCM HTTP v1 backend events and server tests. **No Firebase project or service account has been created in this PR.**
- **Vy:** Firebase project and Android registration, FCM token refresh/signout registration, notification permission, app foreground/background handling, deep-link navigation, and local journal reminders. The Android source currently uses `com.example.ai_diary`; **do not register this placeholder with Firebase**.
- **Android application ID:** recommended proposal `com.aijournal.mobile`, **not yet applied or registered**. Vy/Phúc must ensure ownership/uniqueness, update Gradle `applicationId` and `namespace`, Kotlin `MainActivity` package, Google OAuth SHA-1/SHA-256, Supabase redirects and icon aliases together. The Firebase Android package name is case-sensitive and immutable once registered.

## Backend environment
On the actual backend machine, add private `FCM_PROJECT_ID=<Firebase project ID>` and `GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/private-firebase-service-account.json`. The service-account file and Firebase key must never enter Git, Android assets or Supabase public keys. Install backend requirements and restart FastAPI. Without `FCM_PROJECT_ID`, pushes remain disabled without changing application business endpoints; tokens may still register.

## Client contract
1. Only after Supabase login, obtain `firebase_messaging` FCM token and a persistent per-installation identifier.
2. `POST /api/v1/devices` body `{ "token": "<FCM token>", "installation_id": "<install ID>", "platform": "android" }`; use the user's Supabase bearer access token.
3. Call the same route on token refresh, foreground reauthentication and account change; `DELETE /api/v1/devices` body `{ "token": "<old FCM token>" }` **before signout**, where possible.
4. Show generic message such as **"Bạn có tin nhắn mới"** on lock screen. Never include the message body, album note, photo or exact place.
5. Data keys are `type` with optional `sender_id`, `friend_id`, `conversation_id`, or `share_id`. On tap, re-fetch actual content with JWT, revalidate friendship, blocking, and share expiry. Never trust a push as a permission grant.
6. Approve `flutter_local_notifications` and `timezone` in Flutter pubspec. Local OB10 daily reminders require Android `POST_NOTIFICATIONS` permission on Android 13+, schedule/reboot handling and notification settings in Profile; they are independent of FCM. Exact alarms are not required for the MVP.
7. Test two emulator/accounts, rotate token, logout/login, friend invitation, acceptance, one text send and its idempotent retry, place share, 24-hour memory share, block/unfriend, and disabled FCM mode.
8. Delivery currently uses post-commit FastAPI BackgroundTasks; **not guaranteed** if process stops after commit. Production hardening: durable outbox, retries, monitoring, opt-out preferences and distributed rate limit.

## Database acceptance
Migration `20261030_21` from `20261030_20` creates a **private** token table with `anon`/`authenticated` grants revoked, RLS enabled, and `auth.users` ON DELETE CASCADE FK. It is safe for existing rows because it adds a new empty table. Use disposable PostgreSQL CI before applying to AI-Journal-Dev. Do not apply twice.
