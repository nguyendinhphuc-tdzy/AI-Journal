"""Photo validation boundary requires no live Supabase credentials."""
import pytest
from fastapi import HTTPException
from app.modules.albums.photos_router import MAX_BYTES, validate_image


@pytest.mark.parametrize("mime,blob", [
    ("image/jpeg", b"\xff\xd8\xff\xe0test"),
    ("image/png", b"\x89PNG\r\n\x1a\ntest"),
    ("image/webp", b"RIFFxxxxWEBPtest"),
])
def test_valid_image_signatures(mime, blob):
    validate_image(blob, mime)


@pytest.mark.parametrize("mime,blob", [
    ("image/jpeg", b"<svg>"),
    ("image/png", b"bad"),
    ("image/svg+xml", b"<svg>"),
])
def test_invalid_images_fail_closed(mime, blob):
    with pytest.raises(HTTPException):
        validate_image(blob, mime)


def test_oversized_image_rejected():
    with pytest.raises(HTTPException) as result:
        validate_image(b"x" * (MAX_BYTES + 1), "image/jpeg")
    assert result.value.status_code == 413


def test_replacement_committed_even_if_old_storage_cleanup_fails(monkeypatch):
    """A committed new photo must not trigger client retries when old cleanup is down."""
    import asyncio
    from types import SimpleNamespace
    from uuid import uuid4

    import httpx
    from fastapi import HTTPException
    from starlette.requests import Request

    from app.modules.albums import photos_router

    own = uuid4()
    album_id, memory_id = uuid4(), uuid4()
    memory = SimpleNamespace(photo_path="prior/owner/old.jpeg")
    calls = []

    def storage(method, path, token, **kwargs):
        calls.append((method, path))
        if method == "POST":
            return httpx.Response(201, content=b"{}")
        if method == "DELETE":
            raise HTTPException(503, "Old object cleanup unavailable")
        raise AssertionError("Unexpected storage call")

    monkeypatch.setattr(photos_router, "_memory_or_404", lambda *args: memory)
    monkeypatch.setattr(photos_router, "_storage_request", storage)
    committed = []
    db = SimpleNamespace(commit=lambda: committed.append(True),
                         rollback=lambda: None)
    async def read_body():
        return {"type": "http.request", "body": b"\xff\xd8\xff\xe0test", "more_body": False}
    request = Request({"type": "http", "method": "PUT",
                       "headers": [(b"content-type", b"image/jpeg")]}, read_body)
    result = asyncio.run(photos_router.upload_memory_photo(
        album_id, memory_id, request, authorization="Bearer test",
        user=SimpleNamespace(user_id=own), db=db,
    ))
    assert result == {"photo_available": True}
    assert len(committed) == 1
    assert memory.photo_path != "prior/owner/old.jpeg"
    assert calls[0][0] == "POST"
    assert calls[1] == ("DELETE", "prior/owner/old.jpeg")
