"""Authenticated, friends-only, expiring Memory text shares.

Private Memory photo bytes are deliberately never returned here.
"""
from datetime import datetime, timedelta, timezone
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import or_, select
from sqlalchemy.orm import Session
from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.models.album import AlbumMemory
from app.models.friendship import Friendship
from app.models.memory_share import MemoryShare
from app.modules.friends.router import blocked, pair

router = APIRouter(prefix="/memory-shares", tags=["memory-shares"])


class ShareInfo(BaseModel):
    id: UUID
    memory_id: UUID
    expires_at: datetime
    revoked: bool


class SharedMemory(BaseModel):
    share_id: UUID
    title: str | None
    note: str
    display_date: str
    expires_at: datetime


def utc(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def _share(db: Session, share_id: UUID) -> MemoryShare:
    item = db.get(MemoryShare, share_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Share not found")
    return item


def _friend(db: Session, owner: UUID, reader: UUID) -> bool:
    if owner == reader:
        return True
    if blocked(db, owner, reader):
        return False
    relation = db.get(Friendship, pair(owner, reader))
    return relation is not None and relation.status == "accepted"


@router.post("", response_model=ShareInfo, status_code=status.HTTP_201_CREATED)
def create_share(memory_id: UUID, user: AuthenticatedUser = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    memory = db.scalar(select(AlbumMemory).where(
        AlbumMemory.id == memory_id, AlbumMemory.user_id == user.user_id
    ))
    if memory is None:
        raise HTTPException(status_code=404, detail="Memory not found")
    now = datetime.now(timezone.utc)
    share = MemoryShare(memory_id=memory_id, owner_id=user.user_id,
                        created_at=now, expires_at=now + timedelta(hours=24))
    db.add(share)
    db.commit()
    db.refresh(share)
    return ShareInfo(id=share.id, memory_id=share.memory_id,
                     expires_at=share.expires_at, revoked=False)


@router.get("/{share_id}", response_model=SharedMemory)
def read_shared_memory(share_id: UUID,
                       user: AuthenticatedUser = Depends(get_current_user),
                       db: Session = Depends(get_db)):
    share = _share(db, share_id)
    if share.revoked_at is not None or utc(share.expires_at) <= datetime.now(timezone.utc):
        raise HTTPException(status_code=404, detail="Share not found")
    if not _friend(db, share.owner_id, user.user_id):
        raise HTTPException(status_code=404, detail="Share not found")
    memory = db.scalar(select(AlbumMemory).where(
        AlbumMemory.id == share.memory_id,
        AlbumMemory.user_id == share.owner_id
    ))
    if memory is None:
        raise HTTPException(status_code=404, detail="Share not found")
    return SharedMemory(share_id=share.id, title=memory.title,
                        note=memory.note, display_date=memory.display_date.isoformat(),
                        expires_at=share.expires_at)


@router.delete("/{share_id}", status_code=204)
def revoke_share(share_id: UUID,
                 user: AuthenticatedUser = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    share = _share(db, share_id)
    if share.owner_id != user.user_id:
        raise HTTPException(status_code=404, detail="Share not found")
    if share.revoked_at is None:
        share.revoked_at = datetime.now(timezone.utc)
        db.commit()
