"""Read-only streak results; clients cannot submit completion events."""
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.modules.streak.service import get_streak


router = APIRouter(prefix="/streak", tags=["streak"])


class StreakRead(BaseModel):
    current_streak: int = Field(ge=0)
    longest_streak: int = Field(ge=0)
    today_completed: bool
    timezone: str
    activity_dates: list[str]


@router.get("", response_model=StreakRead)
def read_streak(
    days: int = Query(default=30, ge=1, le=365),
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return get_streak(db, user.user_id, days=days)
