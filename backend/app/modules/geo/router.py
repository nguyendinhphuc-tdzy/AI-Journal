"""Authenticated address autocomplete through FastAPI, never through Flutter keys."""
import time
from collections import OrderedDict, deque
from threading import Lock
from uuid import UUID

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.config import Settings, get_settings
from app.modules.geo.service import geoapify_search, geoapify_reverse
from app.schemas.place import Latitude, Longitude


router = APIRouter(prefix="/geo", tags=["geo"])

# Local development safeguard. Multi-process/production deployments must use
# a distributed limiter before exposing this external-cost API publicly.
RATE_WINDOW_SECONDS = 60.0
RATE_LIMIT = 30
_recent_requests: dict[UUID, deque[float]] = {}
_rate_lock = Lock()

# Owner-isolated, bounded in-process cache; rate limit still applies to hits.
GEO_CACHE_TTL_SECONDS = 60.0
GEO_CACHE_MAX_ITEMS = 500
_geo_cache: OrderedDict[tuple, tuple[float, list[dict]]] = OrderedDict()
_geo_cache_lock = Lock()


def _cached_geo_result(key: tuple) -> list[dict] | None:
    now = time.monotonic()
    with _geo_cache_lock:
        entry = _geo_cache.get(key)
        if entry is None:
            return None
        expires_at, items = entry
        if expires_at <= now:
            del _geo_cache[key]
            return None
        _geo_cache.move_to_end(key)
        return [dict(item) for item in items]


def _store_geo_result(key: tuple, items: list[dict]) -> None:
    with _geo_cache_lock:
        _geo_cache[key] = (
            time.monotonic() + GEO_CACHE_TTL_SECONDS,
            [dict(item) for item in items],
        )
        _geo_cache.move_to_end(key)
        while len(_geo_cache) > GEO_CACHE_MAX_ITEMS:
            _geo_cache.popitem(last=False)



def enforce_geo_rate_limit(
    user: AuthenticatedUser = Depends(get_current_user),
) -> None:
    now = time.monotonic()
    with _rate_lock:
        # Prune expired buckets BEFORE inserting the current user's bucket.
        if len(_recent_requests) > 2000:
            for key, value in list(_recent_requests.items()):
                if not value or value[-1] <= now - RATE_WINDOW_SECONDS:
                    del _recent_requests[key]
        recent = _recent_requests.setdefault(user.user_id, deque())
        while recent and recent[0] <= now - RATE_WINDOW_SECONDS:
            recent.popleft()
        if len(recent) >= RATE_LIMIT:
            raise HTTPException(
                status_code=429,
                detail="Too many place searches; retry later",
                headers={"Retry-After": "60"},
            )
        recent.append(now)


async def get_geo_client():
    async with httpx.AsyncClient(timeout=httpx.Timeout(5.0, connect=3.0)) as client:
        yield client


class GeoResult(BaseModel):
    provider: str = "geoapify"
    external_place_id: str
    label: str = Field(max_length=160)
    formatted_address: str | None
    latitude: Latitude
    longitude: Longitude


class GeoResults(BaseModel):
    items: list[GeoResult]


@router.get("/search", response_model=GeoResults)
async def search_locations(
    q: str = Query(min_length=2, max_length=120),
    limit: int = Query(default=5, ge=1, le=10),
    lat: Latitude | None = None,
    lon: Longitude | None = None,
    user: AuthenticatedUser = Depends(get_current_user),
    _rate_limited: None = Depends(enforce_geo_rate_limit),
    settings: Settings = Depends(get_settings),
    client: httpx.AsyncClient = Depends(get_geo_client),
):
    del _rate_limited
    if (lat is None) != (lon is None):
        raise HTTPException(
            status_code=422, detail="lat and lon must be supplied together"
        )
    if not q.strip() or len(q.strip()) < 2:
        raise HTTPException(status_code=422, detail="Search must contain at least two characters")
    api_key = settings.geoapify_api_key
    if not api_key:
        raise HTTPException(
            status_code=503, detail="Place search is not configured"
        )
    normalized = " ".join(q.strip().split())
    cache_key = (user.user_id, api_key, normalized.casefold(), limit, lat, lon)
    cached = _cached_geo_result(cache_key)
    if cached is not None:
        return GeoResults(items=cached)
    items = await geoapify_search(
        client, api_key, query=normalized, limit=limit, lat=lat, lon=lon
    )
    _store_geo_result(cache_key, items)
    return GeoResults(items=items)


class GeoReverseResult(BaseModel):
    label: str = Field(max_length=160)
    formatted_address: str | None
    latitude: Latitude
    longitude: Longitude


@router.get("/reverse", response_model=GeoReverseResult | None)
async def reverse_location(
    lat: Latitude,
    lon: Longitude,
    user: AuthenticatedUser = Depends(get_current_user),
    _rate_limited: None = Depends(enforce_geo_rate_limit),
    settings: Settings = Depends(get_settings),
    client: httpx.AsyncClient = Depends(get_geo_client),
):
    del _rate_limited
    api_key = settings.geoapify_api_key
    if not api_key:
        raise HTTPException(status_code=503, detail="Place search is not configured")
    # Rounded coordinates avoid duplicate requests for sub-meter pin movements.
    cache_key = (user.user_id, api_key, "reverse", round(lat, 5), round(lon, 5))
    cached = _cached_geo_result(cache_key)
    if cached is not None:
        return GeoReverseResult(**cached[0]) if cached else None
    result = await geoapify_reverse(client, api_key, lat=lat, lon=lon)
    _store_geo_result(cache_key, [result] if result is not None else [])
    return GeoReverseResult(**result) if result is not None else None
