"""Current account profile backed by Supabase Auth identity."""
from fastapi import APIRouter, Depends
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.models.user_profile import UserProfile
from app.schemas.profile import ProfileRead, ProfileUpdate

router = APIRouter(prefix="/me", tags=["profile"])


def _ensure_profile(db: Session, identity: AuthenticatedUser) -> UserProfile:
    profile = db.get(UserProfile, identity.user_id)
    if profile is not None:
        return profile

    profile = UserProfile(user_id=identity.user_id)
    db.add(profile)
    try:
        db.commit()
    except IntegrityError:
        # Concurrent first requests can both attempt profile creation.
        db.rollback()
        existing = db.get(UserProfile, identity.user_id)
        if existing is None:
            raise
        return existing
    db.refresh(profile)
    return profile


def _response(profile: UserProfile, identity: AuthenticatedUser) -> ProfileRead:
    return ProfileRead(
        user_id=profile.user_id,
        discoverable=profile.discoverable,
        email=identity.email,
        display_name=profile.display_name,
        timezone=profile.timezone,
        created_at=profile.created_at,
    )


@router.get("", response_model=ProfileRead)
def get_my_profile(
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _response(_ensure_profile(db, user), user)


@router.patch("", response_model=ProfileRead)
def update_my_profile(
    payload: ProfileUpdate,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    profile = _ensure_profile(db, user)
    changes = payload.model_dump(exclude_unset=True)
    for field, value in changes.items():
        if field == "timezone" and value is None:
            continue  # timezone cannot become NULL
        setattr(profile, field, value)
    db.commit()
    db.refresh(profile)
    return _response(profile, user)
