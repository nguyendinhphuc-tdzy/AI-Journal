"""Opt-in, text-only, authenticated and manually moderated community feed."""
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from app.core.auth import AuthenticatedUser, get_current_user
from app.core.config import Settings, get_settings
from app.core.database import get_db
from app.models.community import CommunityPost, CommunityReport

router = APIRouter(prefix="/community", tags=["community"])


def enabled(settings: Settings = Depends(get_settings)) -> None:
    if not settings.community_feed_enabled:
        raise HTTPException(status_code=503, detail="Community feed is not enabled")


def moderator(user: AuthenticatedUser = Depends(get_current_user),
              settings: Settings = Depends(get_settings)) -> AuthenticatedUser:
    if str(user.user_id) not in {
        item.strip() for item in settings.community_moderator_ids.split(",") if item.strip()
    }:
        raise HTTPException(status_code=403, detail="Moderator role required")
    return user


class PostCreate(BaseModel):
    body: str = Field(min_length=10, max_length=2000)


class PostRead(BaseModel):
    id: UUID
    body: str
    status: str
    created_at: str


class ReportCreate(BaseModel):
    reason: str = Field(min_length=5, max_length=200)


def _post(item: CommunityPost) -> PostRead:
    return PostRead(id=item.id, body=item.body, status=item.status,
                    created_at=item.created_at.isoformat())


@router.post("/posts", response_model=PostRead, status_code=201,
             dependencies=[Depends(enabled)])
def submit_post(payload: PostCreate,
                user: AuthenticatedUser = Depends(get_current_user),
                db: Session = Depends(get_db)):
    if not payload.body.strip() or len(payload.body.strip()) < 10:
        raise HTTPException(status_code=422, detail="Post content is too short")
    # Explicit user-supplied text only. Never ingest an existing Memory.
    post = CommunityPost(author_id=user.user_id,
                         body=payload.body.strip(), status="pending")
    db.add(post)
    db.commit()
    db.refresh(post)
    return _post(post)


@router.get("/feed", response_model=list[PostRead],
            dependencies=[Depends(enabled)])
def get_feed(limit: int = Query(default=20, ge=1, le=50),
             user: AuthenticatedUser = Depends(get_current_user),
             db: Session = Depends(get_db)):
    del user
    items = db.scalars(select(CommunityPost).where(
        CommunityPost.status == "approved"
    ).order_by(CommunityPost.created_at.desc(), CommunityPost.id.desc())
        .limit(limit)).all()
    return [_post(item) for item in items]


@router.get("/mine", response_model=list[PostRead],
            dependencies=[Depends(enabled)])
def get_my_posts(user: AuthenticatedUser = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    items = db.scalars(select(CommunityPost).where(
        CommunityPost.author_id == user.user_id
    ).order_by(CommunityPost.created_at.desc()).limit(100)).all()
    return [_post(item) for item in items]


@router.delete("/posts/{post_id}", status_code=204,
               dependencies=[Depends(enabled)])
def delete_my_post(post_id: UUID,
                   user: AuthenticatedUser = Depends(get_current_user),
                   db: Session = Depends(get_db)):
    item = db.get(CommunityPost, post_id)
    if item is None or item.author_id != user.user_id:
        raise HTTPException(status_code=404, detail="Post not found")
    db.delete(item)
    db.commit()


@router.post("/posts/{post_id}/reports", status_code=204,
             dependencies=[Depends(enabled)])
def report_post(post_id: UUID, payload: ReportCreate,
                user: AuthenticatedUser = Depends(get_current_user),
                db: Session = Depends(get_db)):
    item = db.get(CommunityPost, post_id)
    if item is None or item.status != "approved":
        raise HTTPException(status_code=404, detail="Post not found")
    if item.author_id == user.user_id:
        raise HTTPException(status_code=422, detail="Cannot report own post")
    db.add(CommunityReport(post_id=post_id, reporter_id=user.user_id,
                           reason=payload.reason.strip()))
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Report already submitted")


@router.get("/moderation/pending", response_model=list[PostRead],
            dependencies=[Depends(enabled)])
def pending_posts(moderator_user: AuthenticatedUser = Depends(moderator),
                  db: Session = Depends(get_db)):
    del moderator_user
    items = db.scalars(select(CommunityPost).where(
        CommunityPost.status == "pending"
    ).order_by(CommunityPost.created_at.asc()).limit(100)).all()
    return [_post(item) for item in items]


@router.post("/moderation/{post_id}/{decision}", response_model=PostRead,
             dependencies=[Depends(enabled)])
def decide_post(post_id: UUID, decision: str,
                moderator_user: AuthenticatedUser = Depends(moderator),
                db: Session = Depends(get_db)):
    del moderator_user
    if decision not in ("approve", "reject"):
        raise HTTPException(status_code=422, detail="Invalid moderation decision")
    item = db.get(CommunityPost, post_id)
    if item is None or item.status != "pending":
        raise HTTPException(status_code=404, detail="Pending post not found")
    item.status = "approved" if decision == "approve" else "rejected"
    db.commit()
    return _post(item)


class ReportRead(BaseModel):
    post_id: UUID
    reason: str
    created_at: str


@router.get("/moderation/reports", response_model=list[ReportRead],
            dependencies=[Depends(enabled)])
def moderation_reports(moderator_user: AuthenticatedUser = Depends(moderator),
                       db: Session = Depends(get_db)):
    del moderator_user
    reports = db.scalars(select(CommunityReport)
        .order_by(CommunityReport.created_at.desc()).limit(100)).all()
    return [ReportRead(post_id=item.post_id, reason=item.reason,
                       created_at=item.created_at.isoformat()) for item in reports]


@router.post("/moderation/{post_id}/hide", response_model=PostRead,
             dependencies=[Depends(enabled)])
def hide_reported_post(post_id: UUID,
                       moderator_user: AuthenticatedUser = Depends(moderator),
                       db: Session = Depends(get_db)):
    del moderator_user
    item = db.get(CommunityPost, post_id)
    if item is None or item.status != "approved":
        raise HTTPException(status_code=404, detail="Approved post not found")
    item.status = "rejected"
    db.commit()
    return _post(item)
