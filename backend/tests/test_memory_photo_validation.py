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
