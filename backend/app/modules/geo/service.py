"""Fixed-origin Geoapify autocomplete adapter (server-only API key)."""
import math

import httpx
from fastapi import HTTPException

GEOAPIFY_ENDPOINT = "https://api.geoapify.com/v1/geocode/autocomplete"


async def geoapify_search(
    client: httpx.AsyncClient,
    api_key: str,
    *,
    query: str,
    limit: int,
    lat: float | None,
    lon: float | None,
) -> list[dict]:
    params: dict[str, str | int] = {
        "text": query,
        "limit": limit,
        "format": "geojson",
        "apiKey": api_key,
    }
    if lat is not None and lon is not None:
        # Geoapify proximity requires longitude first, then latitude.
        params["bias"] = f"proximity:{lon},{lat}"

    try:
        response = await client.get(GEOAPIFY_ENDPOINT, params=params)
        if response.status_code == 429:
            raise HTTPException(
                status_code=503, detail="Place search provider is rate limited"
            )
        if response.status_code >= 400:
            raise HTTPException(
                status_code=502, detail="Place search provider returned an error"
            )
        payload = response.json()
    except httpx.TimeoutException as exc:
        raise HTTPException(
            status_code=503, detail="Place search provider timed out"
        ) from exc
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=503, detail="Place search provider is unavailable"
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=502, detail="Invalid place search response"
        ) from exc

    if not isinstance(payload, dict) or not isinstance(payload.get("features"), list):
        raise HTTPException(
            status_code=502, detail="Invalid place search response"
        )
    results: list[dict] = []
    for feature in payload["features"][:limit]:
        if not isinstance(feature, dict):
            continue
        props = feature.get("properties")
        if not isinstance(props, dict):
            continue
        place_id = props.get("place_id")
        if not isinstance(place_id, str) or not 0 < len(place_id.strip()) <= 2048:
            continue

        latitude, longitude = props.get("lat"), props.get("lon")
        if not isinstance(latitude, (int, float)) or isinstance(latitude, bool):
            continue
        if not isinstance(longitude, (int, float)) or isinstance(longitude, bool):
            continue
        if not math.isfinite(latitude) or not -90 <= latitude <= 90:
            continue
        if not math.isfinite(longitude) or not -180 <= longitude <= 180:
            continue

        formatted = props.get("formatted")
        label = props.get("name") or props.get("address_line1") or formatted
        if not isinstance(label, str) or not label.strip():
            continue
        if formatted is not None and not isinstance(formatted, str):
            formatted = None
        results.append({
            "provider": "geoapify",
            "external_place_id": place_id.strip(),
            "label": label[:160],
            "formatted_address": formatted,
            "latitude": float(latitude),
            "longitude": float(longitude),
        })
    return results
