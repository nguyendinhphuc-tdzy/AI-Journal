"""Privacy-preserving FCM HTTP v1 sender. Delivery is best effort after commit.

A real Google service account is never read until FCM_PROJECT_ID is configured.
The Android client never receives credentials or private journal content.
"""
import logging
import re
from datetime import datetime, timedelta, timezone
from threading import Lock
from uuid import UUID

import httpx
from sqlalchemy import select
from app.core.config import get_settings
from app.core.database import SessionLocal
from app.models.device_token import DeviceToken

log = logging.getLogger(__name__)
_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_creds = None
_creds_lock = Lock()
_TITLES = {
    "friend_request": ("AI-Journal", "Bạn có lời mời kết bạn mới"),
    "friend_accepted": ("AI-Journal", "Lời mời kết bạn đã được chấp nhận"),
    "message": ("AI-Journal", "Bạn có tin nhắn mới"),
    "memory_share": ("AI-Journal", "Bạn có kỷ niệm mới từ bạn bè"),
}

def access_token() -> str:
    """Google ADC or GOOGLE_APPLICATION_CREDENTIALS, short-lived OAuth2 only."""
    global _creds
    import google.auth
    from google.auth.transport.requests import Request
    with _creds_lock:
        if _creds is None:
            _creds, _ = google.auth.default(scopes=[_SCOPE])
        if not _creds.valid:
            _creds.refresh(Request())
        return _creds.token

def fcm_payload(token: str, kind: str, data: dict[str, str]) -> dict:
    if kind not in _TITLES:
        raise ValueError("Unknown notification type")
    title, body = _TITLES[kind]
    # No names, private notes, message text, photos or coordinates on lock screen.
    return {
        "message": {
            "token": token,
            "notification": {"title": title, "body": body},
            "data": {"type": kind, **data},
            "android": {
                "priority": "HIGH",
                "notification": {"visibility": "PRIVATE"},
                "ttl": "86400s",
            },
        }
    }

def send_fcm(client: httpx.Client, project_id: str, bearer: str,
             token: str, kind: str, data: dict[str, str]) -> bool:
    """Return true only for permanently UNREGISTERED tokens."""
    endpoint = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    resp = client.post(endpoint, headers={"Authorization": f"Bearer {bearer}"},
                       json=fcm_payload(token, kind, data))
    if resp.status_code in (200, 201):
        return False
    if resp.status_code == 404:
        try:
            err = resp.json().get("error", {})
            if err.get("status") == "UNREGISTERED":
                return True
        except ValueError:
            pass
    # Never log token, upstream body, private event IDs or auth credentials.
    log.warning("FCM delivery rejected (HTTP %s)", resp.status_code)
    return False

def send_push_to_user(user_id: UUID, kind: str, data: dict[str, str]):
    settings = get_settings()
    project = settings.fcm_project_id
    if not project:
        return  # Feature is disabled until Vy's Firebase project is configured.
    if kind not in _TITLES or not re.fullmatch(r"[a-z][a-z0-9-]{4,}", project):
        log.warning("FCM disabled: invalid project or notification kind")
        return
    try:
        bearer = access_token()
    except Exception:
        log.exception("FCM authorization unavailable (credentials not logged)")
        return
    threshold = datetime.now(timezone.utc) - timedelta(days=60)
    with SessionLocal() as db:
        # Only currently-owned installations, no stale registrations.
        rows = db.scalars(select(DeviceToken).where(
            DeviceToken.user_id == user_id,
            DeviceToken.last_seen_at >= threshold).limit(10)).all()
        if not rows:
            return
        with httpx.Client(timeout=8.0) as client:
            for row in rows:
                try:
                    if send_fcm(client, project, bearer, row.token, kind, data):
                        db.delete(row)
                except httpx.HTTPError:
                    log.warning("FCM network unavailable, event remains in app inbox")
        db.commit()
