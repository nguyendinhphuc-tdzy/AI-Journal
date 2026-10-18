"""Owner-scoped journal CRUD and cursor-paginated archive."""
import base64
import binascii
import json
from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import and_, or_, select
from sqlalchemy.orm import Session

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.models.journal import JournalEntry
from app.models.user_profile import UserProfile
from app.modules.streak.service import record_journal_completion
from app.schemas.journal import JournalCreate, JournalPage, JournalRead, JournalUpdate


router = APIRouter(prefix="/journals", tags=["journals"])


def _utc(value: datetime) -> datetime:
    # SQLite strips tzinfo in isolated tests; application timestamps are UTC.
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _encode_cursor(entry: JournalEntry) -> str:
    data = {"at": _utc(entry.created_at).isoformat(), "id": entry.id}
    return base64.urlsafe_b64encode(
        json.dumps(data, separators=(",", ":")).encode("utf-8")
    ).decode("ascii").rstrip("=")


def _decode_cursor(cursor: str) -> tuple[datetime, int]:
    try:
        if len(cursor) > 512 or not cursor:
            raise ValueError("Invalid cursor length")
        raw = base64.urlsafe_b64decode(cursor + "=" * (-len(cursor) % 4))
        value = json.loads(raw)
        if not isinstance(value, dict) or set(value) != {"at", "id"}:
            raise ValueError("Invalid cursor shape")
        if type(value["id"]) is not int or value["id"] < 1:
            raise ValueError("Invalid cursor id")
        at = datetime.fromisoformat(value["at"])
        if at.tzinfo is None:
            raise ValueError("Missing timezone in cursor")
        return _utc(at), value["id"]
    except (binascii.Error, ValueError, TypeError, UnicodeDecodeError, KeyError, OverflowError) as exc:
        raise HTTPException(status_code=400, detail="Invalid journal cursor") from exc


def _user_timezone(db: Session, user_id) -> ZoneInfo:
    profile = db.get(UserProfile, user_id)
    return ZoneInfo(profile.timezone if profile else "Asia/Ho_Chi_Minh")


@router.get("", response_model=JournalPage)
def list_journals(
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None, max_length=512),
    mood: str | None = Query(default=None, max_length=64),
    from_date: date | None = Query(default=None, alias="from"),
    to_date: date | None = Query(default=None, alias="to"),
    q: str | None = Query(default=None, max_length=120),
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if from_date is not None and to_date is not None and from_date > to_date:
        raise HTTPException(status_code=422, detail="from must be on or before to")

    statement = select(JournalEntry).where(JournalEntry.user_id == user.user_id)
    if mood is not None:
        statement = statement.where(JournalEntry.mood == mood)
    if q is not None and q.strip():
        # Escape LIKE metacharacters so the search term is treated literally.
        pattern = "%" + q.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"
        statement = statement.where(
            or_(
                JournalEntry.title.ilike(pattern, escape="\\"),
                JournalEntry.content.ilike(pattern, escape="\\"),
            )
        )
    if from_date is not None or to_date is not None:
        tz = _user_timezone(db, user.user_id)
        if from_date is not None:
            start = datetime.combine(from_date, time.min, tzinfo=tz).astimezone(timezone.utc)
            statement = statement.where(JournalEntry.created_at >= start)
        if to_date is not None and to_date != date.max:
            next_date = to_date + timedelta(days=1)
            end = datetime.combine(next_date, time.min, tzinfo=tz).astimezone(timezone.utc)
            statement = statement.where(JournalEntry.created_at < end)

    if cursor is not None:
        at, entry_id = _decode_cursor(cursor)
        statement = statement.where(
            or_(
                JournalEntry.created_at < at,
                and_(JournalEntry.created_at == at, JournalEntry.id < entry_id),
            )
        )

    statement = statement.order_by(
        JournalEntry.created_at.desc(), JournalEntry.id.desc()
    ).limit(limit + 1)
    results = list(db.scalars(statement).all())
    has_more = len(results) > limit
    items = results[:limit]
    return JournalPage(
        items=items,
        next_cursor=_encode_cursor(items[-1]) if has_more else None,
    )


@router.post("", response_model=JournalRead, status_code=status.HTTP_201_CREATED)
def create_journal(
    payload: JournalCreate,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    journal = JournalEntry(**payload.model_dump(), user_id=user.user_id)
    db.add(journal)
    # Completion is recorded only when a valid journal is successfully saved.
    # One DB transaction covers BOTH journal and daily streak entry.
    record_journal_completion(db, user.user_id)
    db.commit()
    db.refresh(journal)
    return journal


def _owned_or_404(journal_id: int, user_id, db: Session) -> JournalEntry:
    journal = db.scalar(
        select(JournalEntry).where(
            JournalEntry.id == journal_id,
            JournalEntry.user_id == user_id,
        )
    )
    if journal is None:
        raise HTTPException(status_code=404, detail="Journal entry not found")
    return journal


@router.get("/{journal_id}", response_model=JournalRead)
def get_journal(
    journal_id: int,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _owned_or_404(journal_id, user.user_id, db)


@router.put("/{journal_id}", response_model=JournalRead)
def update_journal(
    journal_id: int,
    payload: JournalUpdate,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    journal = _owned_or_404(journal_id, user.user_id, db)
    changes = payload.model_dump(exclude_unset=True)
    # Editing a title, mood or prompt alone is not a writing completion.
    # Resubmitting unchanged content must not manufacture a streak event.
    wrote_new_content = (
        "content" in changes and changes["content"].strip() != journal.content.strip()
    )
    for field, value in changes.items():
        setattr(journal, field, value)
    if wrote_new_content:
        record_journal_completion(db, user.user_id)
    db.commit()
    db.refresh(journal)
    return journal


@router.delete("/{journal_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_journal(
    journal_id: int,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    journal = _owned_or_404(journal_id, user.user_id, db)
    db.delete(journal)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
