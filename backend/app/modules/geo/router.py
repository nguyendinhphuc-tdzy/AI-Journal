"""Authenticated address autocomplete through FastAPI, never through Flutter keys."""
import time
from collections import deque
from threading import Lock
from uuid import UUID

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.config import Settings, get_settings
from app.modules.geo.service import geoapify_search
from app.schemas.place import Latitude, Longitude


router = APIRouter(prefix="/geo", tags=["geo"])

# Local development safeguard. Multi-process/production deployments must use
# a distributed limiter before exposing this external-cost API publicly.
RATE_WINDOW_SECONDS = 60.0
RATE_LIMIT = 30
_recent_requests: dict[UUID, deque[float]] = {}
_rate_lock = Lock()


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
    del user, _rate_limited
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
    items = await geoapify_search(
        client, api_key, query=q.strip(), limit=limit, lat=lat, lon=lon
    )
    return GeoResults(items=items)
