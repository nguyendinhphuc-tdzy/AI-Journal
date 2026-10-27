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
        "lang": "vi",
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


# Unlike address autocomplete, Places API indexes named POIs and permits
# categories + name filtering within a bounded geographical area.
GEOAPIFY_PLACES_ENDPOINT = "https://api.geoapify.com/v2/places"
_POI_CATEGORIES = "catering,commercial,entertainment,leisure,tourism,accommodation,education"


def _poi_request(query: str) -> tuple[str, str | None]:
    """Translate a few explicit category searches; otherwise match POI names."""
    import unicodedata

    normalized = "".join(
        ch for ch in unicodedata.normalize("NFD", query.casefold())
        if unicodedata.category(ch) != "Mn"
    ).replace("đ", "d").strip()
    exact_categories = {
        "cafe": "catering.cafe",
        "ca phe": "catering.cafe",
        "quan ca phe": "catering.cafe",
        "coffee": "catering.cafe",
        "coffee shop": "catering.cafe",
        "nhà hàng": "catering.restaurant",
        "nha hang": "catering.restaurant",
        "restaurant": "catering.restaurant",
        "quan an": "catering",
        "cong vien": "leisure.park",
        "park": "leisure.park",
        "tiem banh": "commercial.food_and_drink.bakery",
        "bakery": "commercial.food_and_drink.bakery",
    }
    category = exact_categories.get(normalized)
    return (category, None) if category else (_POI_CATEGORIES, query)


async def geoapify_poi_search(
    client: httpx.AsyncClient,
    api_key: str,
    *,
    query: str,
    limit: int,
    lat: float,
    lon: float,
) -> list[dict]:
    """Search named POIs near map center; coordinates and key stay server-side.

    Do not allow arbitrary categories, endpoints, URLs or unbounded scans.
    A category request (e.g. 'cà phê') lists nearby examples; otherwise
    Places API's `name` field searches place names, not street addresses.
    """
    categories, name = _poi_request(query)
    params: dict[str, str | int] = {
        "categories": categories,
        "filter": f"circle:{lon},{lat},20000",
        "bias": f"proximity:{lon},{lat}",
        "limit": limit,
        "lang": "vi",
        "apiKey": api_key,
    }
    if name is not None:
        params["name"] = name

    try:
        response = await client.get(GEOAPIFY_PLACES_ENDPOINT, params=params)
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
        raise HTTPException(status_code=502, detail="Invalid place search response")

    results: list[dict] = []
    for feature in payload["features"][:limit]:
        if not isinstance(feature, dict):
            continue
        props = feature.get("properties")
        if not isinstance(props, dict):
            continue
        place_id = props.get("place_id")
        label = props.get("name")
        if (not isinstance(place_id, str) or not 0 < len(place_id.strip()) <= 2048
                or not isinstance(label, str) or not label.strip()):
            continue
        latitude, longitude = props.get("lat"), props.get("lon")
        if (not isinstance(latitude, (int, float)) or isinstance(latitude, bool)
                or not isinstance(longitude, (int, float)) or isinstance(longitude, bool)
                or not math.isfinite(latitude) or not -90 <= latitude <= 90
                or not math.isfinite(longitude) or not -180 <= longitude <= 180):
            continue
        formatted = props.get("formatted")
        if not isinstance(formatted, str):
            formatted = None
        categories_value = props.get("categories")
        category = (
            categories_value[0] if isinstance(categories_value, list)
            and categories_value and isinstance(categories_value[0], str)
            else None
        )
        results.append({
            "provider": "geoapify",
            "external_place_id": place_id.strip(),
            "label": label.strip()[:160],
            "formatted_address": formatted,
            "latitude": float(latitude),
            "longitude": float(longitude),
            "category": category,
        })
    return results
