from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.journal import JournalEntry
from app.schemas.journal import JournalCreate, JournalRead, JournalUpdate

router = APIRouter(prefix="/journals", tags=["journals"])


@router.get("", response_model=list[JournalRead])
def list_journals(db: Session = Depends(get_db)):
    statement = select(JournalEntry).order_by(JournalEntry.created_at.desc())
    return list(db.scalars(statement).all())


@router.post("", response_model=JournalRead, status_code=status.HTTP_201_CREATED)
def create_journal(payload: JournalCreate, db: Session = Depends(get_db)):
    journal = JournalEntry(**payload.model_dump())
    db.add(journal)
    db.commit()
    db.refresh(journal)
    return journal


def _get_or_404(journal_id: int, db: Session) -> JournalEntry:
    journal = db.get(JournalEntry, journal_id)
    if journal is None:
        raise HTTPException(status_code=404, detail="Journal entry not found")
    return journal


@router.get("/{journal_id}", response_model=JournalRead)
def get_journal(journal_id: int, db: Session = Depends(get_db)):
    return _get_or_404(journal_id, db)


@router.put("/{journal_id}", response_model=JournalRead)
def update_journal(journal_id: int, payload: JournalUpdate, db: Session = Depends(get_db)):
    journal = _get_or_404(journal_id, db)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(journal, field, value)
    db.commit()
    db.refresh(journal)
    return journal


@router.delete("/{journal_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_journal(journal_id: int, db: Session = Depends(get_db)):
    journal = _get_or_404(journal_id, db)
    db.delete(journal)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
