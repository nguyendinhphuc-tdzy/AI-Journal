# Phase 3 Explore — real PlaceLookup rollout

## What changed

For a real Supabase session, `PlacePickerScreen` inherits `RemotePlaceLookup`; guest users retain `MockPlaceLookup`. No visual widget redesign or direct Geoapify request from Flutter.

- `GET /api/v1/geo/search?q=<url-encoded name>` returns authenticated location suggestions.
- `GET /api/v1/geo/reverse?lat=<latitude>&lon=<longitude>` resolves a dropped pin.
- Reverse returns JSON `null` for an unnamed point; HTTP failures are surfaced as unavailable so the picker can offer a manual name.
- Existing 30/min per-user limit and 60-second cache remain in backend.

## Backend configuration

In ignored `backend/.env` set `GEOAPIFY_API_KEY=<server-only Geoapify key>`, plus working `SUPABASE_URL` and `DATABASE_URL`. Restart FastAPI. Never put the Geoapify key in Flutter or a committed file.

Verify with a valid Supabase test JWT, held in the local PowerShell session:

```powershell
Invoke-RestMethod -Uri 'http://127.0.0.1:8000/api/v1/geo/search?q=Ha%20Noi' -Headers @{Authorization="Bearer $env:AI_JOURNAL_TEST_JWT_A"}
Invoke-RestMethod -Uri 'http://127.0.0.1:8000/api/v1/geo/reverse?lat=10.7769&lon=106.7009' -Headers @{Authorization="Bearer $env:AI_JOURNAL_TEST_JWT_A"}
```

## Mobile run configuration

Run Flutter with the existing `AUTH_ENABLED`, Supabase, and `API_BASE_URL` settings. On a physical phone, `API_BASE_URL` must be reachable from the device (not the phone's own 127.0.0.1 or emulator 10.0.2.2). A development API should be exposed only through a trusted LAN/private tunnel, not a publicly open server. Authenticated users automatically get real PlaceLookup; no special new flag is required.

## Test and release

Run `flutter analyze` and `flutter test` from `mobile/`. Verify real search and pin selection on a phone with a valid Supabase session and configured backend key. No live Geoapify or physical-device result is claimed by CI.
