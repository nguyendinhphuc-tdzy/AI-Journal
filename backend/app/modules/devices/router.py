"""Authenticated FCM registration and opt-out; never return token values."""
from hashlib import sha256
from datetime import datetime, timezone
from typing import Literal
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.models.device_token import DeviceToken

router = APIRouter(prefix="/devices", tags=["devices"])

class Registration(BaseModel):
    model_config = ConfigDict(extra="forbid")
    token: str = Field(min_length=32, max_length=4096)
    installation_id: str = Field(min_length=8, max_length=128)
    platform: Literal["android", "ios"]

    @field_validator("token", "installation_id")
    @classmethod
    def no_whitespace(cls, value: str) -> str:
        if value != value.strip() or any(ch.isspace() for ch in value):
            raise ValueError("Invalid device identifier")
        return value

class DeRegistration(BaseModel):
    model_config = ConfigDict(extra="forbid")
    token: str = Field(min_length=32, max_length=4096)

@router.post("", status_code=status.HTTP_200_OK)
def register_device(payload: Registration,
                    user: AuthenticatedUser = Depends(get_current_user),
                    db: Session = Depends(get_db)):
    uid = user.user_id
    digest = sha256(payload.token.encode("utf-8")).hexdigest()
    now = datetime.now(timezone.utc)
    same_token = db.get(DeviceToken, digest)
    same_install = db.scalar(select(DeviceToken).where(
        DeviceToken.user_id == uid,
        DeviceToken.installation_id == payload.installation_id))
    # FCM rotates tokens for the same installation. One physical device can
    # also switch accounts on the same app: new authenticated registration
    # transfers this token so the previous account stops receiving pushes.
    if same_install is not None and same_install.token_hash != digest:
        db.delete(same_install)
        db.flush()
    if same_token is None:
        devices = db.scalar(select(func.count()).select_from(DeviceToken).where(
            DeviceToken.user_id == uid)) or 0
        if devices >= 10:
            raise HTTPException(429, "Too many registered devices")
        same_token = DeviceToken(token_hash=digest, token=payload.token,
                                 user_id=uid,
                                 installation_id=payload.installation_id,
                                 platform=payload.platform, created_at=now,
                                 last_seen_at=now)
        db.add(same_token)
    else:
        same_token.user_id = uid
        same_token.installation_id = payload.installation_id
        same_token.platform = payload.platform
        same_token.last_seen_at = now
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(409, "Concurrent device registration; retry") from exc
    return {"registered": True}

@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
def unregister_device(payload: DeRegistration,
                      user: AuthenticatedUser = Depends(get_current_user),
                      db: Session = Depends(get_db)):
    digest = sha256(payload.token.encode("utf-8")).hexdigest()
    saved = db.get(DeviceToken, digest)
    if saved is not None and saved.user_id == user.user_id:
        db.delete(saved)
        db.commit()
    # Idempotent, and does not reveal another user's device existence.
    return None
