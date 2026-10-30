# FCM push integration handoff — Vy / Phúc

## Status and ownership
- **Firebase project created:** `AI-Journal-Dev` (`ai-journal-dev-a084b`); Android application ID confirmed as `com.aijournal.mobile`. A dedicated `ai-journal-fcm-sender` service account was granted `Firebase Cloud Messaging API Admin`. Project permissions are set, but device delivery is not yet tested.
- **Phúc:** FastAPI `/devices`, `device_tokens` revision `20261030_21`, FCM HTTP v1 backend events and server tests. **The Firebase project exists externally; never commit its service-account private key.**
- **Vy:** Firebase project and Android registration, FCM token refresh/signout registration, notification permission, app foreground/background handling, deep-link navigation, and local journal reminders. This PR changes the Android package/namespace to `com.aijournal.mobile`. **Verify that Gradle, Kotlin and `google-services.json` all use this same ID.**
- **Android application ID:** confirmed `com.aijournal.mobile`, applied in PR #90; ensure the Android app registered in Firebase matches. Vy/Phúc must ensure ownership/uniqueness, update Gradle `applicationId` and `namespace`, Kotlin `MainActivity` package, Google OAuth SHA-1/SHA-256, Supabase redirects and icon aliases together. The Firebase Android package name is case-sensitive and immutable once registered.

## Backend environment
On the actual backend machine, add `FCM_PROJECT_ID=ai-journal-dev-a084b` in `backend/.env` (not committed), and export `GOOGLE_APPLICATION_CREDENTIALS=$HOME/.config/ai-journal/fcm-sender.json` in the SAME shell that starts FastAPI. Store the key file with `chmod 600` outside the repository. The Google Auth library reads the exported environment variable; it is not automatically loaded from FastAPI's `.env`. The service-account file and Firebase key must never enter Git, Android assets or Supabase public keys. Install backend requirements and restart FastAPI. Without `FCM_PROJECT_ID`, pushes remain disabled without changing application business endpoints; tokens may still register.

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

## What may be committed to GitHub

- Android Firebase public configuration: `mobile/android/app/google-services.json` may be added **after verifying** `client[].client_info.android_client_info.package_name == "com.aijournal.mobile"` and `project_info.project_id == "ai-journal-dev-a084b"`. It is not a service-account private key. Review/restrict client API keys at Google Cloud as appropriate. Ask Vy before merging changes to FlutterFire Gradle plugins.
- Backend Service Account JSON (`fcm-sender.json`) contains `private_key`. **NEVER commit it, even to private GitHub.** The repository has explicit gitignore patterns to reduce accidents, but secrets already committed would require revocation and key rotation.
- If teammates run FastAPI locally, distribute the service account through a secure password manager or use workload identity. Do not paste it into PRs, issues, CI logs or chat.
- PR #90 (Android package rename) affects installations: old `com.example.ai_diary` and new `com.aijournal.mobile` are different packages; local on-device data will not migrate automatically.

## Firebase connection acceptance
1. Verify Firebase Cloud Messaging API v1 is enabled for `ai-journal-dev-a084b`.
2. Verify Google OAuth from the backend with ADC using scope `https://www.googleapis.com/auth/firebase.messaging`; never print access token.
3. After Vy integrates `firebase_messaging` and obtains a real registration token, register it with JWT through `POST /api/v1/devices`.
4. Send a real event (friend request, acceptance, text or memory share); confirm Android receives the generic notification and deep-link requires fresh JWT and ACL checks. A passing backend CI alone does not demonstrate FCM delivery.
