"""JWT-authenticated private friendship requests; no public user directory."""
from datetime import datetime, timezone
from uuid import UUID
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.models.friendship import Friendship
from app.models.user_block import UserBlock
from app.models.user_profile import UserProfile, auth_users
from app.modules.devices.push import send_push_to_user

router = APIRouter(prefix="/friends", tags=["friends"])


class FriendTarget(BaseModel):
    user_id: UUID


class FriendRead(BaseModel):
    user_id: UUID
    status: str
    direction: str
    display_name: str | None = None
    username: str | None = None


def pair(a: UUID, b: UUID) -> tuple[UUID, UUID]:
    if a == b:
        raise HTTPException(status_code=422, detail="Cannot friend yourself")
    return tuple(sorted((a, b), key=lambda value: value.int))


def _read(item: Friendship, own: UUID, db: Session) -> FriendRead:
    other = item.user_high_id if item.user_low_id == own else item.user_low_id
    direction = "outgoing" if item.requester_id == own else "incoming"
    profile = db.get(UserProfile, other)
    return FriendRead(user_id=other, status=item.status, direction=direction,
                      display_name=profile.display_name if profile else None,
                      username=profile.username if profile else None)


def blocked(db: Session, a: UUID, b: UUID) -> bool:
    return db.scalar(select(UserBlock.blocker_id).where(or_(
        (UserBlock.blocker_id == a) & (UserBlock.blocked_id == b),
        (UserBlock.blocker_id == b) & (UserBlock.blocked_id == a),
    )).limit(1)) is not None


def _get(db: Session, own: UUID, other: UUID) -> Friendship:
    item = db.get(Friendship, pair(own, other))
    if item is None:
        raise HTTPException(status_code=404, detail="Friend relationship not found")
    return item


@router.get("", response_model=list[FriendRead], response_model_exclude_none=True)
def list_friends(user: AuthenticatedUser = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    items = db.scalars(select(Friendship).where(
        or_(Friendship.user_low_id == user.user_id,
            Friendship.user_high_id == user.user_id)
    ).order_by(Friendship.created_at.desc()).limit(200)).all()
    return [_read(item, user.user_id, db) for item in items
            if not blocked(db, user.user_id,
                item.user_high_id if item.user_low_id == user.user_id else item.user_low_id)]


@router.post("/requests", response_model=FriendRead, status_code=201,
             response_model_exclude_none=True)
def request_friend(payload: FriendTarget, background_tasks: BackgroundTasks,
                   user: AuthenticatedUser = Depends(get_current_user),
                   db: Session = Depends(get_db)):
    low, high = pair(user.user_id, payload.user_id)
    if blocked(db, user.user_id, payload.user_id):
        raise HTTPException(status_code=404, detail="User not found")
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
    background_tasks.add_task(send_push_to_user, payload.user_id, "friend_request",
                              {"sender_id": str(user.user_id)})
    return _read(item, user.user_id, db)


@router.post("/{other_id}/accept", response_model=FriendRead,
             response_model_exclude_none=True)
def accept_friend(other_id: UUID, background_tasks: BackgroundTasks,
                  user: AuthenticatedUser = Depends(get_current_user),
                  db: Session = Depends(get_db)):
    if blocked(db, user.user_id, other_id):
        raise HTTPException(status_code=404, detail="Friend relationship not found")
    item = _get(db, user.user_id, other_id)
    if item.status != "pending" or item.requester_id == user.user_id:
        raise HTTPException(status_code=409, detail="No incoming pending request")
    item.status = "accepted"
    db.commit()
    background_tasks.add_task(send_push_to_user, item.requester_id, "friend_accepted",
                              {"friend_id": str(user.user_id)})
    return _read(item, user.user_id, db)


@router.delete("/{other_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_friend(other_id: UUID,
                  user: AuthenticatedUser = Depends(get_current_user),
                  db: Session = Depends(get_db)):
    item = _get(db, user.user_id, other_id)
    db.delete(item)
    db.commit()


class DiscoveryRead(BaseModel):
    user_id: UUID
    display_name: str
    username: str | None = None


@router.get("/discover", response_model=list[DiscoveryRead],
            response_model_exclude_none=True)
def discover_friends(
    q: str = Query(min_length=3, max_length=60),
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    clean = q.strip().removeprefix("@")
    if len(clean) < 3 or len(clean) > 60 or not all(
        char.isalnum() or char in " _" for char in clean
    ):
        raise HTTPException(status_code=422, detail="Invalid search")
    # Only opted-in profiles. No emails, phone numbers or auth metadata.
    escaped = clean.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    profiles = db.scalars(select(UserProfile).where(
        UserProfile.discoverable.is_(True),
        UserProfile.user_id != user.user_id,
        or_(
            UserProfile.username.ilike(escaped + "%", escape="\\"),
            UserProfile.display_name.ilike("%" + escaped + "%", escape="\\"),
        ),
    ).order_by(UserProfile.username.asc(), UserProfile.display_name.asc()).limit(20)).all()
    return [DiscoveryRead(user_id=p.user_id, display_name=p.display_name or p.username,
                          username=p.username)
            for p in profiles if (p.display_name or p.username) and
            not blocked(db, user.user_id, p.user_id)]


@router.get("/blocks", response_model=list[FriendTarget])
def list_blocks(user: AuthenticatedUser = Depends(get_current_user),
                db: Session = Depends(get_db)):
    blocks = db.scalars(select(UserBlock).where(
        UserBlock.blocker_id == user.user_id
    ).limit(200)).all()
    return [FriendTarget(user_id=b.blocked_id) for b in blocks]


@router.post("/blocks", status_code=204)
def block_user(payload: FriendTarget,
               user: AuthenticatedUser = Depends(get_current_user),
               db: Session = Depends(get_db)):
    low, high = pair(user.user_id, payload.user_id)
    if db.get(UserBlock, (user.user_id, payload.user_id)) is None:
        db.add(UserBlock(blocker_id=user.user_id, blocked_id=payload.user_id))
    relationship = db.get(Friendship, (low, high))
    if relationship is not None:
        db.delete(relationship)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Cannot block user") from exc


@router.delete("/blocks/{other_id}", status_code=204)
def unblock_user(other_id: UUID,
                 user: AuthenticatedUser = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    item = db.get(UserBlock, (user.user_id, other_id))
    if item is None:
        raise HTTPException(status_code=404, detail="Block not found")
    db.delete(item)
    db.commit()
