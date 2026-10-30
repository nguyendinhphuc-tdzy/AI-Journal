# M1 — MapLibre Vietnam: rich OSM labels + Geoapify Places API

## Design
Keep `maplibre_gl 0.27.1` and OpenFreeMap vector tiles. The old custom style suppressed the entire `poi` layer. The enhanced style now renders real OSM POI labels at zoom 14+, dense POIs at zoom 17+, house numbers at zoom 18+, rail/footways and administrative boundaries. This is **not** an exhaustive copy of every OSM feature: the tile provider, zoom and collision layout determine which labels are available.

Flutter signed-in Explore discovers nearby POIs at zoom 14+ from `GET /geo/places` and overlays small, neutral POI markers (not Nudaeng journal pins). Touch a marker to view its **real name, provider address and category** and choose Save; saving still uses the current private `POST /places` flow. Text search combines existing address autocomplete with Geoapify Places name matching around the visible map center (up to 5 km). The old guest/local mock behavior remains unchanged. The map does not request location permission for browsing; GPS is still opt-in.

## Backend
- `GET /api/v1/geo/places?lat=10.7769&lon=106.7009&radius=1500&category=cafe&q=Cà%20phê&limit=25`
- Uses Geoapify `/v2/places` server-side with `categories` allowlist, `filter=circle:lon,lat,radius`, `bias=proximity:lon,lat`, `lang=vi`. Validates name, location, all result fields. No Geoapify key, raw upstream errors or arbitrary upstream parameters in responses.
- Must supply `GEOAPIFY_API_KEY` in the ignored backend `.env`; do NOT place it in Dart or check it into Git.
- 30 requests/min/user in-process shared with geocoding, 60-second per-user cache, 40-result upper bound. Beyond development, require a distributed limiter, usage budget alarms and viewport batching.
- No new DB schema/migration. Existing AI-Journal-Dev `20261030_20` remains the required revision. Results are ephemeral; save deliberately to create private records.
- Provider coverage depends on OSM contributions and Geoapify's update cycle; `lang=vi` requests Vietnamese labels when available but does not invent them.

## Acceptance
1. Set server `GEOAPIFY_API_KEY` and restart FastAPI; use a valid test JWT. No key => 503, invalid token => 401.
2. Test HCMC center `lat=10.7769&lon=106.7009` for category `cafe`, `food`, `health`, and text name; repeat for Hanoi center `lat=21.0285&lon=105.8542`.
3. On Android emulator/physical device, zoom to 14+ and pan, then tap a small POI dot; verify real name/address, Save, and that personal Nudaeng pins remain distinct. Search Vietnamese diacritics and compare to provider results.
4. Verify provider offline/429/503, fast pan/zoom, guest mode and slow networks. Native tile rendering and actual live Geoapify require on-device checks, not only CI.
5. Verify tile attribution remains visible and provider terms are followed.

Sources: https://apidocs.geoapify.com/docs/places/ and https://openmaptiles.org/docs/schema/
