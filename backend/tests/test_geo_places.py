"""Geoapify Places contract: Vietnamese POIs, strict boundaries and safe errors."""
import asyncio
import httpx
import pytest
from fastapi import HTTPException

from app.modules.geo.places_service import geoapify_places


def _fetch(handler, **overrides):
    params = dict(lat=10.7769, lon=106.7009, radius=1500,
                  category="cafe", name="Cà phê", limit=15)
    params.update(overrides)
    async def call():
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            return await geoapify_places(client, "server-secret", **params)
    return asyncio.run(call())


def test_places_vietnamese_name_address_category_and_location():
    def upstream(request):
        assert request.url.host == "api.geoapify.com"
        assert request.url.path == "/v2/places"
        assert request.url.params["categories"] == "catering.cafe"
        assert request.url.params["lang"] == "vi"
        assert request.url.params["name"] == "Cà phê"
        assert request.url.params["filter"] == "circle:106.7009,10.7769,1500"
        return httpx.Response(200, json={"features": [
            {"properties": {"place_id": "vn-cafe-1", "name": "Cà phê Việt",
                            "formatted": "Quận 1, TP. Hồ Chí Minh",
                            "categories": ["catering.cafe", "catering"]},
             "geometry": {"type": "Point", "coordinates": [106.7009, 10.7769]}},
            {"properties": {"place_id": "vn-cafe-1", "name": "Duplicate"},
             "geometry": {"type": "Point", "coordinates": [106.7009, 10.7769]}},
            {"properties": {"place_id": "bad-coords", "name": "Invalid"},
             "geometry": {"type": "Point", "coordinates": ["not-a-number", 10.0]}},
            {"properties": {"place_id": "unnamed"},
             "geometry": {"type": "Point", "coordinates": [106, 10]}},
        ]})
    items = _fetch(upstream)
    assert len(items) == 1
    assert items[0]["label"] == "Cà phê Việt"
    assert items[0]["formatted_address"] == "Quận 1, TP. Hồ Chí Minh"
    assert items[0]["categories"] == ["catering.cafe", "catering"]
    assert items[0]["latitude"] == 10.7769
    assert "server-secret" not in str(items)


@pytest.mark.parametrize("code,expected", [(429, 503), (401, 502), (500, 502)])
def test_places_hides_upstream_errors(code, expected):
    def upstream(request):
        return httpx.Response(code, text="upstream secret")
    with pytest.raises(HTTPException) as exc:
        _fetch(upstream)
    assert exc.value.status_code == expected
    assert "upstream secret" not in exc.value.detail


def test_places_rejects_malformed_payload():
    with pytest.raises(HTTPException) as exc:
        _fetch(lambda req: httpx.Response(200, json={"results": []}))
    assert exc.value.status_code == 502


def test_places_empty_is_not_fake_demo_data():
    assert _fetch(lambda req: httpx.Response(
        200, json={"type": "FeatureCollection", "features": []})) == []
