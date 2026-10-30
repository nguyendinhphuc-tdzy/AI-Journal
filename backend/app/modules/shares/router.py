"""Explicit, private 24-hour friend shares. Never read album notes for recipients."""
from datetime import datetime, timedelta, timezone
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import select, update
from sqlalchemy.orm import Session
from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.models.album import AlbumMemory
from app.models.friendship import Friendship
from app.models.memory_share import MemoryShare
from app.models.memory_share_recipient import MemoryShareRecipient
from app.models.user_profile import UserProfile
from app.modules.albums.photos_router import validate_image
from app.modules.friends.router import blocked, pair

router = APIRouter(prefix="/memory-shares", tags=["memory-shares"])
PHOTO_MAX_BYTES = 3 * 1024 * 1024

class PlacePayload(BaseModel):
    model_config = ConfigDict(extra="forbid")
    label: str = Field(min_length=1, max_length=160)
    latitude: float = Field(ge=-90, le=90, allow_inf_nan=False)
    longitude: float = Field(ge=-180, le=180, allow_inf_nan=False)

class ShareCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    memory_id: UUID | None = None
    recipient_ids: list[UUID] = Field(min_length=1, max_length=20)
    title: str | None = Field(default=None, max_length=160)
    text: str = Field(min_length=1, max_length=300)
    place: PlacePayload
    category: str | None = Field(default=None, max_length=60)
    replacing: UUID | None = None

    @model_validator(mode="after")
    def valid(self):
        if not self.text.strip() or (self.title is not None and not self.title.strip()):
            raise ValueError("Share text/title must not be blank")
        return self

class ShareInfo(BaseModel):
    id: UUID
    memory_id: UUID | None
    expires_at: datetime
    revoked: bool

class SharedMemory(BaseModel):
    share_id: UUID
    memory_id: UUID | None
    title: str | None
    text: str
    place: PlacePayload
    category: str | None
    expires_at: datetime
    has_photo: bool = False

class ReceivedShare(SharedMemory):
    sender_id: UUID
    display_name: str | None = None
    username: str | None = None

def utc(v: datetime) -> datetime:
    return v.replace(tzinfo=timezone.utc) if v.tzinfo is None else v.astimezone(timezone.utc)

def missing():
    raise HTTPException(status_code=404, detail="Share not found")

def eligible(db: Session, owner: UUID, reader: UUID) -> bool:
    if owner == reader or blocked(db, owner, reader):
        return False
    relation = db.get(Friendship, pair(owner, reader))
    return relation is not None and relation.status == "accepted"

def active(share: MemoryShare, now: datetime) -> bool:
    return share.revoked_at is None and utc(share.expires_at) > now and share.text is not None and share.place is not None

def presented(share: MemoryShare) -> dict:
    return dict(share_id=share.id, memory_id=share.memory_id, title=share.title,
                text=share.text, place=share.place, category=share.category,
                expires_at=share.expires_at, has_photo=share.photo_type is not None)

def drop_photo(share: MemoryShare) -> None:
    share.photo = None
    share.photo_type = None

def readable(db: Session, s: MemoryShare | None, reader: UUID) -> MemoryShare:
    """The share for its owner or an eligible recipient while active; else 404."""
    if s is None or not active(s, datetime.now(timezone.utc)):
        missing()
    if reader != s.owner_id and (
        db.get(MemoryShareRecipient, (s.id, reader)) is None or
        not eligible(db, s.owner_id, reader)):
        missing()
    return s

@router.post("", response_model=ShareInfo, status_code=status.HTTP_201_CREATED)
def create_share(payload: ShareCreate, user: AuthenticatedUser = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    if len(set(payload.recipient_ids)) != len(payload.recipient_ids) or any(
        not eligible(db, user.user_id, r) for r in payload.recipient_ids
    ):
        raise HTTPException(status_code=422, detail="Invalid or ineligible share recipients")
    if payload.memory_id is not None:
        memory = db.scalar(select(AlbumMemory).where(
            AlbumMemory.id == payload.memory_id, AlbumMemory.user_id == user.user_id))
        if memory is None:
            raise HTTPException(status_code=404, detail="Memory not found")
    old = None
    if payload.replacing is not None:
        old = db.get(MemoryShare, payload.replacing)
        if old is None or old.owner_id != user.user_id or not active(old, datetime.now(timezone.utc)):
            missing()
        if old.memory_id != payload.memory_id:
            raise HTTPException(status_code=422, detail="Replacement memory mismatch")
    now = datetime.now(timezone.utc)
    # Photos never outlive their 24 hours: the owner's expired ones go now.
    db.execute(update(MemoryShare).where(
        MemoryShare.owner_id == user.user_id, MemoryShare.expires_at <= now,
        MemoryShare.photo_type.is_not(None)).values(photo=None, photo_type=None)
        .execution_options(synchronize_session=False))
    share = MemoryShare(memory_id=payload.memory_id, owner_id=user.user_id,
        title=payload.title, text=payload.text, place=payload.place.model_dump(),
        category=payload.category, created_at=now, expires_at=now + timedelta(hours=24))
    if old is not None:
        old.revoked_at = now
        drop_photo(old)
    db.add(share)
    db.flush()
    db.add_all(MemoryShareRecipient(share_id=share.id, owner_id=user.user_id,
               recipient_id=r) for r in payload.recipient_ids)
    # A 24-hour moment is seen on the recipients' map and in their friends'
    # moments list, not as a chat message (product decision 30/10/2026).
    db.commit()
    return ShareInfo(id=share.id, memory_id=share.memory_id,
                     expires_at=share.expires_at, revoked=False)

@router.get("/received", response_model=list[ReceivedShare])
def received(user: AuthenticatedUser = Depends(get_current_user),
             db: Session = Depends(get_db), limit: int = Query(50, ge=1, le=100)):
    now = datetime.now(timezone.utc)
    rows = db.execute(select(MemoryShare, UserProfile).join(
        MemoryShareRecipient, MemoryShareRecipient.share_id == MemoryShare.id
    ).outerjoin(UserProfile, UserProfile.user_id == MemoryShare.owner_id).where(
        MemoryShareRecipient.recipient_id == user.user_id,
        MemoryShare.revoked_at.is_(None), MemoryShare.expires_at > now,
        MemoryShare.text.is_not(None)
    ).order_by(MemoryShare.created_at.desc()).limit(limit)).all()
    return [dict(**presented(s), sender_id=s.owner_id,
                 display_name=p.display_name if p else None,
                 username=p.username if p else None)
            for s, p in rows if active(s, now) and eligible(db, s.owner_id, user.user_id)]

@router.get("/mine", response_model=list[ShareInfo])
def mine(user: AuthenticatedUser = Depends(get_current_user),
         db: Session = Depends(get_db), memory_id: UUID | None = None):
    now = datetime.now(timezone.utc)
    q = select(MemoryShare).where(MemoryShare.owner_id == user.user_id,
         MemoryShare.revoked_at.is_(None), MemoryShare.expires_at > now,
         MemoryShare.text.is_not(None)).order_by(MemoryShare.created_at.desc()).limit(100)
    if memory_id is not None:
        q = q.where(MemoryShare.memory_id == memory_id)
    return [ShareInfo(id=s.id, memory_id=s.memory_id, expires_at=s.expires_at,
                      revoked=False) for s in db.scalars(q) if active(s, now)]

@router.get("/{share_id}", response_model=SharedMemory)
def read_shared_memory(share_id: UUID, user: AuthenticatedUser = Depends(get_current_user),
                       db: Session = Depends(get_db)):
    return presented(readable(db, db.get(MemoryShare, share_id), user.user_id))

@router.put("/{share_id}/photo", status_code=204)
async def upload_share_photo(share_id: UUID, request: Request,
                             user: AuthenticatedUser = Depends(get_current_user),
                             db: Session = Depends(get_db)):
    """The owner's image for an active share (JPEG/PNG/WebP, at most 3 MB)."""
    s = db.get(MemoryShare, share_id)
    if s is None or s.owner_id != user.user_id or not active(s, datetime.now(timezone.utc)):
        missing()
    content_type = request.headers.get("content-type", "").split(";")[0].strip().lower()
    data = b""
    async for chunk in request.stream():
        data += chunk
        if len(data) > PHOTO_MAX_BYTES:
            raise HTTPException(413, "Photo must not exceed 3 MB")
    validate_image(data, content_type)
    s.photo = data
    s.photo_type = content_type
    db.commit()

@router.get("/{share_id}/photo")
def download_share_photo(share_id: UUID, user: AuthenticatedUser = Depends(get_current_user),
                         db: Session = Depends(get_db)):
    s = readable(db, db.get(MemoryShare, share_id), user.user_id)
    if s.photo_type is None or s.photo is None:
        raise HTTPException(404, "Photo not found")
    return Response(s.photo, media_type=s.photo_type,
                    headers={"Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff"})

@router.delete("/{share_id}", status_code=204)
def revoke_share(share_id: UUID, user: AuthenticatedUser = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    s = db.get(MemoryShare, share_id)
    if s is None or s.owner_id != user.user_id:
        missing()
    if s.revoked_at is None or s.photo_type is not None:
        s.revoked_at = s.revoked_at or datetime.now(timezone.utc)
        drop_photo(s)
        db.commit()
