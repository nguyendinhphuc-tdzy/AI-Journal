"""Tests for private reverse-geocoding without real provider requests."""
import pytest
import httpx
from fastapi import HTTPException

from app.modules.geo.service import geoapify_reverse


@pytest.mark.anyio
async def test_reverse_returns_vietnamese_address():
    def handler(request):
        assert request.url.path == "/v1/geocode/reverse"
        assert request.url.params["lang"] == "vi"
        assert request.url.params["lat"] == "10.7769"
        assert request.url.params["lon"] == "106.7009"
        return httpx.Response(200, json={"features": [{"properties": {
            "name": "Bưu điện Trung tâm",
            "formatted": "Quận 1, Thành phố Hồ Chí Minh"
        }}]})
    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as c:
        result = await geoapify_reverse(c, "secret", lat=10.7769, lon=106.7009)
    assert result["label"] == "Bưu điện Trung tâm"
    assert result["latitude"] == 10.7769


@pytest.mark.anyio
async def test_reverse_empty_response():
    async with httpx.AsyncClient(transport=httpx.MockTransport(
        lambda req: httpx.Response(200, json={"features": []})
    )) as c:
        assert await geoapify_reverse(c, "key", lat=10.0, lon=106.0) is None


@pytest.mark.anyio
async def test_reverse_upstream_secret_is_not_exposed():
    async with httpx.AsyncClient(transport=httpx.MockTransport(
        lambda req: httpx.Response(401, json={"error": "private provider detail"})
    )) as c:
        with pytest.raises(HTTPException) as exc:
            await geoapify_reverse(c, "secret", lat=10.0, lon=106.0)
    assert exc.value.status_code == 502
    assert "private" not in exc.value.detail
