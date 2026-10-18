"""Same-owner links between journals and saved places.

Both endpoints verify owner scope before querying/creating join rows. Composite
FKs guarantee the restriction even against accidental future unscoped writes.
"""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query, Response, status
from pydantic import BaseModel
from sqlalchemy import and_, delete, or_, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.orm import Session

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.models.journal import JournalEntry
from app.models.journal_place import JournalPlace
from app.models.saved_place import SavedPlace
from app.modules.journal.router import _decode_cursor, _encode_cursor, _owned_or_404 as journal_owned
from app.modules.places.router import _owned_or_404 as place_owned
from app.schemas.journal import JournalPage
from app.schemas.place import PlaceRead


journal_links_router = APIRouter(prefix="/journals", tags=["journal-places"])
place_links_router = APIRouter(prefix="/places", tags=["journal-places"])


class LinkedPlaces(BaseModel):
    items: list[PlaceRead]


@journal_links_router.put(
    "/{journal_id}/places/{place_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def attach_place(
    journal_id: int,
    place_id: int,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    journal_owned(journal_id, user.user_id, db)
    place_owned(place_id, user.user_id, db)
    values = {
        "user_id": user.user_id,
        "journal_id": journal_id,
        "place_id": place_id,
        "created_at": datetime.now(timezone.utc),
    }
    table = JournalPlace.__table__
    dialect = db.get_bind().dialect.name
    if dialect == "postgresql":
        stmt = pg_insert(table).values(**values).on_conflict_do_nothing(
            index_elements=["user_id", "journal_id", "place_id"]
        )
    elif dialect == "sqlite":
        stmt = sqlite_insert(table).values(**values).on_conflict_do_nothing(
            index_elements=["user_id", "journal_id", "place_id"]
        )
    else:
        raise RuntimeError("Unsupported linking database")
    db.execute(stmt)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@journal_links_router.delete(
    "/{journal_id}/places/{place_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def detach_place(
    journal_id: int,
    place_id: int,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    journal_owned(journal_id, user.user_id, db)
    place_owned(place_id, user.user_id, db)
    db.execute(
        delete(JournalPlace).where(
            JournalPlace.user_id == user.user_id,
            JournalPlace.journal_id == journal_id,
            JournalPlace.place_id == place_id,
        )
    )
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@journal_links_router.get(
    "/{journal_id}/places", response_model=LinkedPlaces,
)
def journal_places(
    journal_id: int,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    journal_owned(journal_id, user.user_id, db)
    stmt = (
        select(SavedPlace)
        .join(
            JournalPlace,
            and_(
                JournalPlace.place_id == SavedPlace.id,
                JournalPlace.user_id == SavedPlace.user_id,
            ),
        )
        .where(
            JournalPlace.journal_id == journal_id,
            JournalPlace.user_id == user.user_id,
        )
        .order_by(SavedPlace.created_at.desc(), SavedPlace.id.desc())
    )
    return LinkedPlaces(items=list(db.scalars(stmt).all()))


@place_links_router.get(
    "/{place_id}/journals", response_model=JournalPage,
)
def place_journals(
    place_id: int,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None, max_length=512),
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    place_owned(place_id, user.user_id, db)
    stmt = (
        select(JournalEntry)
        .join(
            JournalPlace,
            and_(
                JournalPlace.journal_id == JournalEntry.id,
                JournalPlace.user_id == JournalEntry.user_id,
            ),
        )
        .where(
            JournalPlace.place_id == place_id,
            JournalPlace.user_id == user.user_id,
        )
    )
    if cursor is not None:
        at, journal_id = _decode_cursor(cursor)
        stmt = stmt.where(
            or_(
                JournalEntry.created_at < at,
                and_(
                    JournalEntry.created_at == at,
                    JournalEntry.id < journal_id,
                ),
            )
        )
    journals = list(
        db.scalars(
            stmt.order_by(JournalEntry.created_at.desc(), JournalEntry.id.desc())
            .limit(limit + 1)
        ).all()
    )
    page = journals[:limit]
    return JournalPage(
        items=page,
        next_cursor=_encode_cursor(page[-1]) if len(journals) > limit else None,
    )
