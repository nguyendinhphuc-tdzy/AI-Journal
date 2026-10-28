"""Private, owner-scoped photo proxy for Memory. Never issues public object URLs."""
from uuid import UUID, uuid4
from urllib.parse import quote

import httpx
from fastapi import APIRouter, Depends, Header, HTTPException, Request, Response
from sqlalchemy.orm import Session

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.config import get_settings
from app.core.database import get_db
from app.modules.albums.router import _memory_or_404

router = APIRouter(prefix="/albums", tags=["memory-photos"])
BUCKET = "journal-memory-private"
MAX_BYTES = 5 * 1024 * 1024
TYPES = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}


def validate_image(data: bytes, content_type: str) -> None:
    if not data or len(data) > MAX_BYTES or content_type not in TYPES:
        raise HTTPException(413 if len(data) > MAX_BYTES else 415, "Unsupported image or size")
    signatures = {
        "image/jpeg": data.startswith(b"\xff\xd8\xff"),
        "image/png": data.startswith(b"\x89PNG\r\n\x1a\n"),
        "image/webp": data.startswith(b"RIFF") and data[8:12] == b"WEBP",
    }
    if not signatures[content_type]:
        raise HTTPException(415, "Image signature mismatch")


def _storage_request(method: str, path: str, token: str, *, data: bytes | None = None,
                     content_type: str | None = None) -> httpx.Response:
    settings = get_settings()
    base = (settings.supabase_url or "").rstrip("/")
    key = settings.supabase_publishable_key
    if not base or not key:
        raise HTTPException(503, "Private photo storage is not configured")
    headers = {"apikey": key, "Authorization": token}
    if content_type:
        headers["Content-Type"] = content_type
    try:
        with httpx.Client(timeout=20.0, follow_redirects=False) as client:
            return client.request(method, f"{base}/storage/v1/object/{BUCKET}/{quote(path, safe='/')}",
                                  headers=headers, content=data)
    except httpx.RequestError as exc:
        raise HTTPException(503, "Photo storage is temporarily unavailable") from exc


def _storage_error(response: httpx.Response) -> None:
    if response.status_code not in (200, 201, 204):
        # Do not expose storage internals or object names to the client.
        raise HTTPException(503 if response.status_code >= 500 else 502,
                            "Private photo storage operation failed")


@router.put("/{album_id}/memories/{memory_id}/photo")
async def upload_memory_photo(
    album_id: UUID, memory_id: UUID, request: Request,
    authorization: str = Header(),
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    memory = _memory_or_404(db, album_id, memory_id, user.user_id)
    content_type = request.headers.get("content-type", "").split(";")[0].strip().lower()
    # Bounded read prevents loading unbounded request bodies into application memory.
    data = await request.stream().__anext__() if False else b""
    async for chunk in request.stream():
        data += chunk
        if len(data) > MAX_BYTES:
            raise HTTPException(413, "Photo must not exceed 5 MB")
    validate_image(data, content_type)
    path = f"{user.user_id}/{album_id}/{memory_id}/{uuid4()}{TYPES[content_type]}"
    result = _storage_request("POST", path, authorization, data=data, content_type=content_type)
    _storage_error(result)
    old_path = memory.photo_path
    memory.photo_path = path
    try:
        db.commit()
    except Exception:
        db.rollback()
        _storage_request("DELETE", path, authorization)
        raise
    if old_path:
        _storage_request("DELETE", old_path, authorization)
    return {"photo_available": True}


@router.get("/{album_id}/memories/{memory_id}/photo")
def download_memory_photo(
    album_id: UUID, memory_id: UUID,
    authorization: str = Header(),
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    memory = _memory_or_404(db, album_id, memory_id, user.user_id)
    if not memory.photo_path:
        raise HTTPException(404, "Photo not found")
    result = _storage_request("GET", memory.photo_path, authorization)
    _storage_error(result)
    return Response(result.content, media_type=result.headers.get("content-type", "application/octet-stream"),
                    headers={"Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff"})


@router.delete("/{album_id}/memories/{memory_id}/photo", status_code=204)
def remove_memory_photo(
    album_id: UUID, memory_id: UUID,
    authorization: str = Header(),
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    memory = _memory_or_404(db, album_id, memory_id, user.user_id)
    if memory.photo_path:
        _storage_error(_storage_request("DELETE", memory.photo_path, authorization))
        memory.photo_path = None
        db.commit()
    return Response(status_code=204)
