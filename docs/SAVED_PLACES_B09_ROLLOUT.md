# B09 — Saved Places & Geoapify address lookup

**Status:** code staged in `feat/backend-saved-places`, based on **unmerged B06**. Not deployed, not merged; no live Supabase migrations or secret changes.

## Features for Flutter MapLibre / Trâm

- MapLibre + OpenFreeMap **renders** the map without a Google Maps API key; it does **not** provide address search or persist private pins.
- User long-presses map to drop a pin. Flutter calls `POST /api/v1/places` with `provider:"manual"`, `label`, `latitude`, `longitude` and optionally user-entered `address_text`. Works without Geoapify or location permissions.
- `GET /api/v1/places` returns private paginated markers (`items`, `next_cursor`, newest first); `GET /api/v1/places/{id}` returns one owned pin; `PATCH` edits label/address and manual-pin coordinates; `DELETE` removes owned pin. This is a **backend-only** feature; Flutter MapLibre UI remains owned by Trâm, not implemented in B09.
- Optional address autocomplete: `GET /api/v1/geo/search?q=Hanoi&lat=10.8231&lon=106.6297&limit=5`; `lat`/`lon` are optional together, used solely as a result-ranking bias. Only authenticated sessions may call this endpoint.
- Search returns `{items:[{provider:"geoapify",external_place_id,label,formatted_address,latitude,longitude}]}`. Display suggestions; when a user selects a result, submit `POST /places` with label/coordinates/`provider:"geoapify"`/`external_place_id`. **Never automatically copy provider `formatted_address` into persisted `address_text`**; it is intended for user-created text only. Respect Geoapify/OSM attribution and applicable provider usage/storage terms.
- B09 search uses Geoapify **address autocomplete**. Comprehensive commercial POI name/category lookup is not guaranteed by this endpoint and is deferred to a separately specified provider task. Users can always drop arbitrary manual pins.

## API shape and validation

```http
POST /api/v1/places
Authorization: Bearer <Supabase Auth access token>
Content-Type: application/json

{"label":"My reading spot","latitude":10.8231,"longitude":106.6297,
 "address_text":"Quiet bench near the tree","provider":"manual"}
```

- Coordinates: latitude -90..90, longitude -180..180, finite. Provider is `manual` or `geoapify`. Manual pins may not include `external_place_id`; Geoapify pins must include a nonempty provider ID (provider-neutral schema for later future services).
- Multiple manual pins may share coordinates. Identical `(user_id,provider,external_place_id)` for provider-based pins returns **409** rather than saving duplicates.
- Never include `user_id` in request bodies. The FastAPI server derives it from the verified JWT. Guessed/not-owned IDs return 404 for GET/PATCH/DELETE, and `GET /places` never lists other accounts' pins.
- `PATCH /places/{id}` supports `label`, `address_text`, and (manual pins only) `latitude`/`longitude`. Provider ID and provider-backed coordinates are immutable in MVP; create a new pin to change provider identity.
- Cursor is opaque base64url keyset with creation timestamp + ID; bounded `limit` defaults to 20, maximum 100. Pagination is owner-scoped; do not treat cursor contents as authorization.
- `GET /geo/search` uses fixed server-side Geoapify API origin, max 120 query chars / 10 items; missing key -> **503**, provider unavailable -> **502/503**, over client search quota -> **429**. Geoapify key and raw upstream error body are never returned. The simple server-side 30 requests/minute/user limit is per-process; require **distributed** limits and provider cost guards before production.

## Backend configuration (server only)

```dotenv
# backend/.env (NEVER commit!)
GEOAPIFY_API_KEY=your_private_geoapify_key
```

The existing `DATABASE_URL` and `SUPABASE_URL` stay backend-only/public respectively. Geoapify is optional until search integration; no key needed to persist manual pins. For local demos, mock autocomplete suggestions if Geoapify is unconfigured. Get Geoapify credentials from Geoapify itself, not from the Supabase dashboard.

## Schema / migration

New table `public.saved_places` from Alembic `20261018_05`, after B06 revision `20261018_04`. PostgreSQL: PK integer; FK to `auth.users(id) ON DELETE CASCADE`; `UNIQUE(id,user_id)` to support same-owner notes/links in B10; user/time indexes and unique provider ID partial index; CHECK valid coordinates, provider and provider-ID combinations. RLS enabled with `anon/authenticated` grants revoked. SQLite unit tests omit cross-schema FK to `auth.users`.

**No B10 tables/endpoints** (multiple place notes and journal links) are created in B09; those remain upcoming backend work.

## Validation and release gates

1. Predecessor stack **#7 → #8 → #9 → #10 → B09** must be reviewed/merged manually by Phúc, in order, and retargeted as needed. Nothing should merge automatically.
2. Check out B09 in a clean local directory with Python virtualenv, then run:
   ```powershell
   cd backend
   python -m pip install -r requirements.txt
   python -m pytest -q
   python -m alembic heads
   ```
   Expected `20261018_05` head. Tests create disposable SQLite databases and mock Geoapify HTTP without network.
3. Test migration first on **disposable PostgreSQL** and inspect RLS and grants. No B09 migration has been applied to the real AI-Journal-Dev database.
4. Two real Supabase accounts must confirm A/B isolation, JWT failures -> 401, provider-search disabled -> 503, manual pin persistence across login, provider duplicate -> 409, and direct anon access denied by RLS/grants.
5. UI integration with Trâm (B11) should handle loading/errors/429/503 and show user prompts without requesting raw PostgreSQL or service-role secrets.
6. Any database rollback involving deletion of saved places is intentionally blocked by the B09 downgrade. Write a reviewable backup/restore plan rather than dropping user data.

Provider docs: https://apidocs.geoapify.com/docs/geocoding/address-autocomplete/
