"""Development-only per-process quota guarding authenticated Ollama compute.

Not a distributed production limit. Multiple workers/replicas require a
shared Redis or gateway rate limiter before internet exposure.
"""
from collections import deque
from collections.abc import Iterator
from threading import BoundedSemaphore, Lock
from time import monotonic
from uuid import UUID

from fastapi import Depends, HTTPException

from app.core.auth import AuthenticatedUser, get_current_user


_MAX_REQUESTS_PER_MINUTE = 12
_MAX_GLOBAL_INFERENCE = 2
_MAX_IN_FLIGHT_PER_USER = 1
_WINDOW_SECONDS = 60.0

_lock = Lock()
_slots = BoundedSemaphore(_MAX_GLOBAL_INFERENCE)
_recent: dict[UUID, deque[float]] = {}
_active: dict[UUID, int] = {}


def enforce_ai_quota(
    user: AuthenticatedUser = Depends(get_current_user),
) -> Iterator[None]:
    """Deny excessive concurrent/rapid inference before invoking the model."""
    uid = user.user_id
    now = monotonic()
    with _lock:
        history = _recent.setdefault(uid, deque())
        while history and history[0] <= now - _WINDOW_SECONDS:
            history.popleft()
        # Never keep empty histories from users who stopped calling AI.
        if len(_recent) > 4096:
            for stale_uid, events in list(_recent.items()):
                if (stale_uid != uid and stale_uid not in _active
                        and (not events or events[-1] <= now - _WINDOW_SECONDS)):
                    _recent.pop(stale_uid, None)
        if len(history) >= _MAX_REQUESTS_PER_MINUTE or _active.get(uid, 0) >= _MAX_IN_FLIGHT_PER_USER:
            raise HTTPException(429, "AI request limit reached; try again later")
        if not _slots.acquire(blocking=False):
            raise HTTPException(429, "AI is busy; try again later")
        history.append(now)
        _active[uid] = _active.get(uid, 0) + 1
    try:
        yield
    finally:
        with _lock:
            count = _active[uid] - 1
            if count:
                _active[uid] = count
            else:
                _active.pop(uid, None)
        _slots.release()
