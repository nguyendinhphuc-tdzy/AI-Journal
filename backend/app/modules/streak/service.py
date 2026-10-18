"""Server-verified, transactionally recorded journal-completion streaks."""
from datetime import date, datetime, timedelta, timezone
from uuid import UUID
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.orm import Session

from app.models.journal_action_day import JournalActionDay
from app.models.user_profile import UserProfile


DEFAULT_TIMEZONE = "Asia/Ho_Chi_Minh"


def utc_now() -> datetime:
    """Patchable clock used only on successful writes, not app opens."""
    return datetime.now(timezone.utc)


def user_timezone(db: Session, user_id: UUID) -> str:
    profile = db.get(UserProfile, user_id)
    return profile.timezone if profile is not None else DEFAULT_TIMEZONE


def local_activity_date(db: Session, user_id: UUID, at: datetime) -> date:
    if at.tzinfo is None:
        raise ValueError("Completion timestamp must include a timezone")
    return at.astimezone(ZoneInfo(user_timezone(db, user_id))).date()


def record_journal_completion(db: Session, user_id: UUID) -> bool:
    """Record at most one achievement per day, atomically with journal writing.

    Called by verified journal POST or meaningful content PUT only. The caller
    owns the surrounding transaction and must commit both writes together.
    True means a previously unrecorded day was inserted.
    """
    completed_at = utc_now()
    activity_date = local_activity_date(db, user_id, completed_at)
    data = {
        "user_id": user_id,
        "activity_date": activity_date,
        "first_completed_at": completed_at,
        "action_type": "journal_written",
    }
    table = JournalActionDay.__table__
    dialect = db.get_bind().dialect.name
    if dialect == "postgresql":
        statement = pg_insert(table).values(**data).on_conflict_do_nothing(
            index_elements=["user_id", "activity_date"]
        )
    elif dialect == "sqlite":
        statement = sqlite_insert(table).values(**data).on_conflict_do_nothing(
            index_elements=["user_id", "activity_date"]
        )
    else:
        raise RuntimeError("Journal streak requires PostgreSQL or test SQLite")
    result = db.execute(statement)
    # Rowcount=0 means another successful write already completed this day.
    return result.rowcount == 1


def get_streak(db: Session, user_id: UUID, days: int = 30) -> dict:
    """Calculate current and longest sequences from completed-action dates."""
    if not 1 <= days <= 365:
        raise ValueError("days must be between 1 and 365")

    tz_name = user_timezone(db, user_id)
    today = utc_now().astimezone(ZoneInfo(tz_name)).date()
    completed_dates = set(
        db.scalars(
            select(JournalActionDay.activity_date).where(
                JournalActionDay.user_id == user_id
            )
        ).all()
    )

    current = 0
    target = today if today in completed_dates else today - timedelta(days=1)
    while target in completed_dates:
        current += 1
        target -= timedelta(days=1)

    longest = 0
    run = 0
    previous = None
    for item in sorted(completed_dates):
        if previous is not None and item == previous + timedelta(days=1):
            run += 1
        else:
            run = 1
        longest = max(longest, run)
        previous = item

    start = today - timedelta(days=days - 1)
    history = [
        item.isoformat() for item in sorted(completed_dates)
        if start <= item <= today
    ]
    return {
        "current_streak": current,
        "longest_streak": longest,
        "today_completed": today in completed_dates,
        "timezone": tz_name,
        "activity_dates": history,
    }
