"""JWT-authenticated private friendship requests; no public user directory."""
from datetime import datetime, timezone
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.models.friendship import Friendship
from app.models.user_profile import auth_users

router = APIRouter(prefix="/friends", tags=["friends"])


class FriendTarget(BaseModel):
    user_id: UUID


class FriendRead(BaseModel):
    user_id: UUID
    status: str
    direction: str


def pair(a: UUID, b: UUID) -> tuple[UUID, UUID]:
    if a == b:
        raise HTTPException(status_code=422, detail="Cannot friend yourself")
    return tuple(sorted((a, b), key=lambda value: value.int))


def _read(item: Friendship, own: UUID) -> FriendRead:
    other = item.user_high_id if item.user_low_id == own else item.user_low_id
    direction = "outgoing" if item.requester_id == own else "incoming"
    return FriendRead(user_id=other, status=item.status, direction=direction)


def _get(db: Session, own: UUID, other: UUID) -> Friendship:
    item = db.get(Friendship, pair(own, other))
    if item is None:
        raise HTTPException(status_code=404, detail="Friend relationship not found")
    return item


@router.get("", response_model=list[FriendRead])
def list_friends(user: AuthenticatedUser = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    items = db.scalars(select(Friendship).where(
        or_(Friendship.user_low_id == user.user_id,
            Friendship.user_high_id == user.user_id)
    ).order_by(Friendship.created_at.desc()).limit(200)).all()
    return [_read(item, user.user_id) for item in items]


@router.post("/requests", response_model=FriendRead, status_code=201)
def request_friend(payload: FriendTarget,
                   user: AuthenticatedUser = Depends(get_current_user),
                   db: Session = Depends(get_db)):
    low, high = pair(user.user_id, payload.user_id)
    # Do not create ghost users or profiles. Query auth.users as a
    # read-only Supabase-owned table; no email discovery endpoint.
    target = db.execute(select(auth_users.c.id).where(
        auth_users.c.id == payload.user_id
    )).scalar_one_or_none() if db.bind.dialect.name == "postgresql" else payload.user_id
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")
    if db.get(Friendship, (low, high)) is not None:
        raise HTTPException(status_code=409, detail="Friend request already exists")
    item = Friendship(user_low_id=low, user_high_id=high,
                      requester_id=user.user_id, status="pending")
    db.add(item)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Friend request could not be created") from exc
    return _read(item, user.user_id)


@router.post("/{other_id}/accept", response_model=FriendRead)
def accept_friend(other_id: UUID,
                  user: AuthenticatedUser = Depends(get_current_user),
                  db: Session = Depends(get_db)):
    item = _get(db, user.user_id, other_id)
    if item.status != "pending" or item.requester_id == user.user_id:
        raise HTTPException(status_code=409, detail="No incoming pending request")
    item.status = "accepted"
    db.commit()
    return _read(item, user.user_id)


@router.delete("/{other_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_friend(other_id: UUID,
                  user: AuthenticatedUser = Depends(get_current_user),
                  db: Session = Depends(get_db)):
    item = _get(db, user.user_id, other_id)
    db.delete(item)
    db.commit()
