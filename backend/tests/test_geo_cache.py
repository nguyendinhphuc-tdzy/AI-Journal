"""Fast in-memory Geo cache tests; no external Geoapify network."""
from uuid import uuid4
from app.modules.geo import router as geo


def test_cache_is_owner_scoped_and_defensive(monkeypatch):
    clock = [100.0]
    monkeypatch.setattr(geo.time, "monotonic", lambda: clock[0])
    geo._geo_cache.clear()
    uid_a, uid_b = uuid4(), uuid4()
    key_a = (uid_a, "api-test-key", "cafe", 5, None, None)
    key_b = (uid_b, "api-test-key", "cafe", 5, None, None)
    try:
        geo._store_geo_result(key_a, [{"label": "Cafe A"}])
        assert geo._cached_geo_result(key_b) is None
        cached = geo._cached_geo_result(key_a)
        assert cached == [{"label": "Cafe A"}]
        cached[0]["label"] = "modified"
        assert geo._cached_geo_result(key_a) == [{"label": "Cafe A"}]
        clock[0] += geo.GEO_CACHE_TTL_SECONDS + 1
        assert geo._cached_geo_result(key_a) is None
    finally:
        geo._geo_cache.clear()


def test_cache_has_hard_size_cap(monkeypatch):
    monkeypatch.setattr(geo.time, "monotonic", lambda: 500.0)
    geo._geo_cache.clear()
    try:
        for i in range(geo.GEO_CACHE_MAX_ITEMS + 20):
            geo._store_geo_result((str(i),), [{"label": str(i)}])
        assert len(geo._geo_cache) == geo.GEO_CACHE_MAX_ITEMS
        assert geo._cached_geo_result(("0",)) is None
        assert geo._cached_geo_result((str(geo.GEO_CACHE_MAX_ITEMS + 19),)) is not None
    finally:
        geo._geo_cache.clear()
