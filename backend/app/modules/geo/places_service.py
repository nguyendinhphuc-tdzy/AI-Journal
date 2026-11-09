"""Verified server-side Geoapify Places adapter. No provider credentials in Flutter."""
import math
import httpx
from fastapi import HTTPException

PLACES_ENDPOINT = "https://api.geoapify.com/v2/places"
# Server-controlled allowlist: never proxy raw category/filter strings.
CATEGORIES = {
    "all": "catering,commercial,education,healthcare,tourism,entertainment,accommodation,public_transport",
    "cafe": "catering.cafe",
    "food": "catering.restaurant,catering.fast_food",
    "shop": "commercial",
    "hotel": "accommodation",
    "school": "education",
    "health": "healthcare",
    "attraction": "tourism,entertainment",
    "transport": "public_transport",
}

async def geoapify_places(client: httpx.AsyncClient, api_key: str, *,
                         lat: float, lon: float, radius: int,
                         category: str, name: str | None, limit: int) -> list[dict]:
    params = {
        "apiKey": api_key, "categories": CATEGORIES[category],
        "filter": f"circle:{lon},{lat},{radius}",
        "bias": f"proximity:{lon},{lat}", "lang": "vi", "limit": limit,
    }
    if name:
        params["name"] = name
    try:
        response = await client.get(PLACES_ENDPOINT, params=params)
        if response.status_code == 429:
            raise HTTPException(503, detail="Place provider rate limited")
        if response.status_code >= 400:
            raise HTTPException(502, detail="Place provider unavailable")
        payload = response.json()
    except httpx.TimeoutException as exc:
        raise HTTPException(503, detail="Place provider timed out") from exc
    except httpx.RequestError as exc:
        raise HTTPException(503, detail="Place provider unavailable") from exc
    except ValueError as exc:
        raise HTTPException(502, detail="Invalid place provider response") from exc
    if not isinstance(payload, dict) or not isinstance(payload.get("features"), list):
        raise HTTPException(502, detail="Invalid place provider response")
    items = []
    seen = set()
    for feature in payload["features"][:limit]:
        if not isinstance(feature, dict) or not isinstance(feature.get("properties"), dict):
            continue
        props = feature["properties"]
        identity, label = props.get("place_id"), props.get("name") or props.get("address_line1")
        position = feature.get("geometry")
        coords = position.get("coordinates") if isinstance(position, dict) else None
        if not (isinstance(identity, str) and 0 < len(identity) <= 2048
                and isinstance(label, str) and label.strip()
                and isinstance(coords, list) and len(coords) >= 2):
            continue
        lo, la = coords[:2]
        if (isinstance(lo, bool) or isinstance(la, bool)
            or not isinstance(lo, (int, float)) or not isinstance(la, (int, float))
            or not math.isfinite(lo) or not math.isfinite(la)
            or not (-180 <= lo <= 180 and -90 <= la <= 90)
            or identity in seen):
            continue
        seen.add(identity)
        address = props.get("formatted")
        raw_categories = props.get("categories")
        categories = [s[:80] for s in raw_categories[:8] if isinstance(s, str)] if isinstance(raw_categories, list) else []
        items.append({
            "provider": "geoapify", "external_place_id": identity,
            "label": label.strip()[:160],
            "formatted_address": address[:500] if isinstance(address, str) else None,
            "latitude": float(la), "longitude": float(lo),
            "categories": categories,
        })
    return items
