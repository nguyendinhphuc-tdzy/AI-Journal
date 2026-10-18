"""Multiple owner-only notes on each saved place."""
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import and_, or_, select
from sqlalchemy.orm import Session

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.models.place_note import PlaceNote
from app.modules.places.router import _as_utc, _decode_cursor, _encode_cursor, _owned_or_404
from app.schemas.place_note import NoteContent, NotePage, NoteRead


router = APIRouter(prefix="/places", tags=["place-notes"])


def _note_or_404(note_id: int, place_id: int, user_id, db: Session) -> PlaceNote:
    note = db.scalar(
        select(PlaceNote).where(
            PlaceNote.id == note_id,
            PlaceNote.place_id == place_id,
            PlaceNote.user_id == user_id,
        )
    )
    if note is None:
        raise HTTPException(status_code=404, detail="Place note not found")
    return note


@router.post(
    "/{place_id}/notes",
    response_model=NoteRead,
    status_code=status.HTTP_201_CREATED,
)
def create_note(
    place_id: int,
    payload: NoteContent,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _owned_or_404(place_id, user.user_id, db)
    note = PlaceNote(
        place_id=place_id,
        user_id=user.user_id,
        content=payload.content,
    )
    db.add(note)
    db.commit()
    db.refresh(note)
    return note


@router.get("/{place_id}/notes", response_model=NotePage)
def list_notes(
    place_id: int,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None, max_length=512),
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _owned_or_404(place_id, user.user_id, db)
    stmt = select(PlaceNote).where(
        PlaceNote.user_id == user.user_id,
        PlaceNote.place_id == place_id,
    )
    if cursor is not None:
        at, note_id = _decode_cursor(cursor)
        stmt = stmt.where(
            or_(
                PlaceNote.created_at < at,
                and_(PlaceNote.created_at == at, PlaceNote.id < note_id),
            )
        )
    notes = list(
        db.scalars(
            stmt.order_by(PlaceNote.created_at.desc(), PlaceNote.id.desc())
            .limit(limit + 1)
        ).all()
    )
    page = notes[:limit]
    return NotePage(
        items=page,
        next_cursor=_encode_cursor(page[-1]) if len(notes) > limit else None,
    )


@router.patch(
    "/{place_id}/notes/{note_id}",
    response_model=NoteRead,
)
def update_note(
    place_id: int,
    note_id: int,
    payload: NoteContent,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _owned_or_404(place_id, user.user_id, db)
    note = _note_or_404(note_id, place_id, user.user_id, db)
    note.content = payload.content
    db.commit()
    db.refresh(note)
    return note


@router.delete(
    "/{place_id}/notes/{note_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_note(
    place_id: int,
    note_id: int,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _owned_or_404(place_id, user.user_id, db)
    note = _note_or_404(note_id, place_id, user.user_id, db)
    db.delete(note)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
