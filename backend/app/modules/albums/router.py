"""Owner-scoped PR17 Album + Memory APIs. Never serve guest or public posts."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.models.album import Album, AlbumMemory
from app.schemas.album import (
    AlbumCreate, AlbumRead, AlbumUpdate, MemoryCreate, MemoryRead, MemoryUpdate,
)

router = APIRouter(prefix="/albums", tags=["albums"])


def _album_or_404(db: Session, album_id: UUID, user_id: UUID) -> Album:
    album = db.scalar(select(Album).where(
        Album.id == album_id, Album.user_id == user_id,
    ))
    if album is None:
        raise HTTPException(status_code=404, detail="Album not found")
    return album


def _memory_or_404(db: Session, album_id: UUID, memory_id: UUID, user_id: UUID) -> AlbumMemory:
    item = db.scalar(select(AlbumMemory).where(
        AlbumMemory.id == memory_id,
        AlbumMemory.album_id == album_id,
        AlbumMemory.user_id == user_id,
    ))
    if item is None:
        raise HTTPException(status_code=404, detail="Memory not found")
    return item


def _album_read(db: Session, album: Album) -> AlbumRead:
    count = db.scalar(select(func.count()).select_from(AlbumMemory).where(
        AlbumMemory.album_id == album.id, AlbumMemory.user_id == album.user_id,
    ))
    return AlbumRead.model_validate({
        "id": album.id, "name": album.name, "theme_id": album.theme_id,
        "locked": album.locked, "hide_name_when_locked": album.hide_name_when_locked,
        "memory_count": count or 0, "created_at": album.created_at,
        "updated_at": album.updated_at,
    })


@router.get("", response_model=list[AlbumRead])
def list_albums(
    limit: int = Query(default=50, ge=1, le=100),
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    items = db.scalars(
        select(Album).where(Album.user_id == user.user_id)
        .order_by(Album.created_at.desc(), Album.id.desc()).limit(limit)
    ).all()
    return [_album_read(db, album) for album in items]


@router.post("", response_model=AlbumRead, status_code=status.HTTP_201_CREATED)
def create_album(
    payload: AlbumCreate,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    album = Album(**payload.model_dump(), user_id=user.user_id)
    db.add(album)
    db.commit()
    db.refresh(album)
    return _album_read(db, album)


@router.get("/{album_id}", response_model=AlbumRead)
def get_album(
    album_id: UUID,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _album_read(db, _album_or_404(db, album_id, user.user_id))


@router.patch("/{album_id}", response_model=AlbumRead)
def update_album(
    album_id: UUID,
    payload: AlbumUpdate,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    album = _album_or_404(db, album_id, user.user_id)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(album, field, value)
    db.commit()
    db.refresh(album)
    return _album_read(db, album)


@router.delete("/{album_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_album(
    album_id: UUID,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    album = _album_or_404(db, album_id, user.user_id)
    db.delete(album)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{album_id}/memories", response_model=list[MemoryRead])
def list_memories(
    album_id: UUID,
    limit: int = Query(default=100, ge=1, le=100),
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _album_or_404(db, album_id, user.user_id)
    return db.scalars(
        select(AlbumMemory).where(
            AlbumMemory.album_id == album_id, AlbumMemory.user_id == user.user_id,
        ).order_by(
            AlbumMemory.display_date.desc(), AlbumMemory.created_at.desc(),
            AlbumMemory.id.desc(),
        ).limit(limit)
    ).all()


@router.post("/{album_id}/memories", response_model=MemoryRead,
             status_code=status.HTTP_201_CREATED)
def create_memory(
    album_id: UUID,
    payload: MemoryCreate,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _album_or_404(db, album_id, user.user_id)
    data = payload.model_dump()
    memory = AlbumMemory(**data, album_id=album_id, user_id=user.user_id)
    db.add(memory)
    db.commit()
    db.refresh(memory)
    return memory


@router.get("/{album_id}/memories/{memory_id}", response_model=MemoryRead)
def get_memory(
    album_id: UUID, memory_id: UUID,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _memory_or_404(db, album_id, memory_id, user.user_id)


@router.patch("/{album_id}/memories/{memory_id}", response_model=MemoryRead)
def update_memory(
    album_id: UUID, memory_id: UUID, payload: MemoryUpdate,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    memory = _memory_or_404(db, album_id, memory_id, user.user_id)
    changes = payload.model_dump(exclude_unset=True)
    for field, value in changes.items():
        setattr(memory, field, value)
    db.commit()
    db.refresh(memory)
    return memory


@router.delete("/{album_id}/memories/{memory_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_memory(
    album_id: UUID, memory_id: UUID,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    memory = _memory_or_404(db, album_id, memory_id, user.user_id)
    db.delete(memory)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
