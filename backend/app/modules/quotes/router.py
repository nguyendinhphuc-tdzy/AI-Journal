"""Owner-only saved quote CRUD. Quotes are supplied by the client, not invented by AI."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.models.saved_quote import SavedQuote
from app.schemas.analysis import SavedQuoteCreate, SavedQuoteRead, SavedQuotePage

router = APIRouter(prefix="/saved-quotes", tags=["saved quotes"])


@router.get("", response_model=SavedQuotePage)
def list_quotes(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0, le=100000),
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    records = list(db.scalars(
        select(SavedQuote).where(SavedQuote.user_id == user.user_id)
        .order_by(SavedQuote.saved_at.desc(), SavedQuote.id.desc())
        .offset(offset).limit(limit + 1)
    ))
    return {
        "items": [SavedQuoteRead.model_validate({
            "id": row.id, "text": row.text, "author": row.author,
            "source": row.source, "saved_at": row.saved_at,
        }).model_dump(mode="json") for row in records[:limit]],
        "next_offset": offset + limit if len(records) > limit else None,
    }


@router.post("", response_model=SavedQuoteRead, status_code=status.HTTP_201_CREATED)
def save_quote(
    payload: SavedQuoteCreate,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    text = payload.text.strip()
    author = payload.author.strip()
    if not text or not author:
        raise HTTPException(422, "Quote text and author must not be blank")
    saved = db.scalar(select(SavedQuote).where(
        SavedQuote.user_id == user.user_id,
        SavedQuote.text == text,
    ))
    if saved:
        # Idempotent as far as the user's saved-list is concerned.
        saved.author = author
        saved.source = payload.source
    else:
        saved = SavedQuote(user_id=user.user_id, text=text,
                           author=author, source=payload.source)
        db.add(saved)
    try:
        db.commit()
        db.refresh(saved)
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(409, "Quote was saved concurrently; retry") from exc
    return SavedQuoteRead(id=saved.id, text=saved.text, author=saved.author,
                          source=saved.source, saved_at=saved.saved_at)


@router.delete("/{quote_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_quote(
    quote_id: UUID,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    quote = db.scalar(select(SavedQuote).where(
        SavedQuote.id == quote_id, SavedQuote.user_id == user.user_id,
    ))
    if quote is None:
        raise HTTPException(404, "Saved quote not found")
    db.delete(quote)
    db.commit()
    return Response(status_code=204)
