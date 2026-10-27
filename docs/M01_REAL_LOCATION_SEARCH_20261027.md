# M01 — Real Location Search (MapLibre + Geoapify)

**Status:** implementation staged for review in `feat/map-m01-real-search` on top of B14 integration PR #28. No database migration, deploy or merge was run.

## Scope

- Keep MapLibre map tiles/styles and existing pan, zoom, tap, temporary pin and overlay UI.
- For **real Supabase-authenticated users only**, replace the three-place search demo in Explore and the mock search in the Album Place Picker with the single FastAPI endpoint `GET /api/v1/geo/search`.
- FastAPI: existing Geoapify v1 Address Autocomplete (street, district, postal address) + bounded Geoapify v2 Places search (named POIs) merged by provider ID, with named POIs first. Both return a normalized list under `{"items":[...]}`. Search results rank around the **current map center** supplied as `lat` and `lon`.
- Nearby category phrases `quán cà phê`, `cafe`, `coffee`, `nhà hàng`, `quán ăn`, `công viên`, `park` and `tiệm bánh` select a category; other phrases use the Places API `name` parameter. The POI search is restricted to a 20 km circle around the map center to avoid broad billed searches.
- Flutter uses the existing `ApiClient` with `requireAuth:true`; it retrieves the logged-in Supabase access token per request, debounces user input (Explore 350 ms, picker 300 ms) and prevents older responses from replacing newer ones.
- Guest/fake-auth sessions retain only the **explicitly marked Demo** preview; no guest requests use the server-side Geoapify key.
- Search results can be tapped to reposition the map or choose a place. **This M01 task does not implement persistent Saved Places or reverse geocoding.**

## Setup (Windows + Android Emulator)

The user already has B14 FastAPI and the Android Emulator setup. Use **a new worktree** from the M01 branch rather than editing the existing `AI-Journal-Cloud` code:

```powershell
cd C:\Users\PC\Documents\AI-Journal
git fetch origin
git worktree add --detach ..\AI-Journal-M01 origin/feat/map-m01-real-search

cd ..\AI-Journal-M01
Copy-Item ..\AI-Journal-Cloud\backend\.env .\backend\.env
Copy-Item ..\AI-Journal-Cloud\mobile\.env.journal-cloud.json .\mobile\.env.journal-cloud.json

cd backend
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
notepad .env
```

Add this line to the **local, ignored** `backend/.env`:

```dotenv
GEOAPIFY_API_KEY=YOUR_GEOAPIFY_KEY
```

The key comes from the developer's Geoapify account. Never place it in Flutter, `mobile/.env.journal-cloud.json`, a `--dart-define` or GitHub. Do **not** rotate/re-enter PostgreSQL credentials unless necessary and do not rerun Alembic migration: Supabase dev database is already at `20261026_08`.

Stop the B14 FastAPI process first (same port), then from root of the new M01 worktree:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start_journal_cloud_backend.ps1
```

In a second PowerShell terminal, with Android Emulator booted and `flutter devices` showing Android:

```powershell
cd C:\Users\PC\Documents\AI-Journal-M01
powershell -ExecutionPolicy Bypass -File .\scripts\start_journal_cloud_mobile.ps1
```

Only real authenticated sessions use the Geoapify-backed search. If a signed-in user gets HTTP 503 / a search error, verify the **backend-side** key and Geoapify quota in local `.env`, then restart FastAPI. Network errors remain visible rather than silently returning sample places.

## Backend contract

`GET /api/v1/geo/search?q=c%C3%A0%20ph%C3%AA&lat=10.8231&lon=106.6297&limit=10`

- `q`: trimmed text, 2–120 chars; `lat` and `lon` paired, optional for address-only queries, required for POI search; server validates finite in-range coordinates.
- Response `items` objects: `provider`, `external_place_id`, `label`, `formatted_address`, `latitude`, `longitude`, nullable `category`.
- Geoapify credentials, endpoint URL and provider error bodies are never disclosed by FastAPI.
- JWT, user-scoped rate limiter (30 search requests/minute in **one FastAPI process**), upstream timeout and sanitized 502/503 behavior stay in effect.
- Geoapify POI matching comes from its data source; not every recently opened Vietnamese business will be present. Manual pin drop remains available without search.
- Autocomplete and Places API can each incur charges/credits for one user query. For a public rollout use a shared distributed limiter + quotas/usage alarms and review provider terms.

## Not included in M01

- M02 reverse geocoding (`lat,lon → address`) and name resolution on a dropped pin.
- M03 GPS, mobile permission prompts.
- M04 account-scoped persistent Saved Places and marker reload.
- M05 Journal/Album linking and M06 clustering/advanced map UX.
- Manual emulator↔FastAPI↔Geoapify end-to-end acceptance is not implied by GitHub CI.

## References

- Geoapify Autocomplete: https://apidocs.geoapify.com/docs/geocoding/address-autocomplete/
- Geoapify Places API: https://apidocs.geoapify.com/docs/places/
- Existing `docs/MAPLIBRE_SETUP.md` for MapLibre renderer, Android setup and tile attribution.
