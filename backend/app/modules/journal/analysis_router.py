"""Private, version-aware AI analysis of SAVED journal content only."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.models.journal_analysis import JournalAnalysis
from app.modules.ai.emotions import classify_emotion
from app.modules.ai.quota import enforce_ai_quota
from app.modules.ai.service import AIProvider, get_ai_provider
from app.modules.journal.router import _owned_or_404
from app.schemas.ai import ReflectionResponse
from app.schemas.analysis import AnalysisRead, AnalyzeRequest, FeedbackUpdate

router = APIRouter(prefix="/journals", tags=["journal analysis"])


def to_read(saved: JournalAnalysis, body_version: int) -> AnalysisRead:
    return AnalysisRead(
        id=saved.id, journal_id=saved.journal_id, body_version=saved.body_version,
        saved_at=saved.created_at, stale=saved.body_version != body_version,
        analysis=saved.result, feedback=saved.feedback,
    )


@router.get("/{journal_id}/analysis", response_model=AnalysisRead)
def get_analysis(
    journal_id: int,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    entry = _owned_or_404(journal_id, user.user_id, db)
    saved = db.scalar(select(JournalAnalysis).where(
        JournalAnalysis.user_id == user.user_id,
        JournalAnalysis.journal_id == journal_id,
    ))
    if saved is None:
        raise HTTPException(404, "Journal analysis not found")
    return to_read(saved, entry.body_version)


@router.post("/{journal_id}/analysis", response_model=AnalysisRead)
def generate_analysis(
    journal_id: int,
    payload: AnalyzeRequest | None = None,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
    provider: AIProvider = Depends(get_ai_provider),
    _quota: None = Depends(enforce_ai_quota),
):
    # Never accept journal text, user IDs or body_version from client. Only
    # the persisted, owner-scoped entry may be sent to Ollama.
    entry = _owned_or_404(journal_id, user.user_id, db)
    saved = db.scalar(select(JournalAnalysis).where(
        JournalAnalysis.user_id == user.user_id,
        JournalAnalysis.journal_id == journal_id,
    ))
    if saved is not None and saved.body_version == entry.body_version and not (
        payload and payload.force
    ):
        return to_read(saved, entry.body_version)
    content = entry.content.strip()
    if not content or len(content) > 8000:
        raise HTTPException(422, "Saved journal content must be 1–8000 characters")
    version = entry.body_version
    result = provider.reflect(content, entry.mood)
    group, score = classify_emotion(result.emotion)
    normalized = result.model_copy(update={"mood_group": group, "mood_score": score})
    # Re-read the persisted body_version to avoid saving output for an entry
    # that was edited while slow Ollama inference was running.
    db.expire(entry)
    db.refresh(entry)
    if entry.body_version != version:
        raise HTTPException(409, "Journal changed while being analyzed; retry")

    if saved is None:
        saved = JournalAnalysis(
            journal_id=entry.id, user_id=user.user_id, body_version=version,
            result=normalized.model_dump(mode="json"),
        )
        db.add(saved)
    else:
        saved.body_version = version
        saved.result = normalized.model_dump(mode="json")
        saved.feedback = None  # Feedback belongs to the previous analysis.
    try:
        db.commit()
        db.refresh(saved)
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(409, "Analysis was updated concurrently; retry") from exc
    return to_read(saved, entry.body_version)


@router.put("/{journal_id}/analysis/feedback", response_model=AnalysisRead)
def set_feedback(
    journal_id: int,
    payload: FeedbackUpdate,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    entry = _owned_or_404(journal_id, user.user_id, db)
    saved = db.scalar(select(JournalAnalysis).where(
        JournalAnalysis.user_id == user.user_id,
        JournalAnalysis.journal_id == journal_id,
    ))
    if saved is None:
        raise HTTPException(404, "Journal analysis not found")
    if saved.body_version != entry.body_version:
        raise HTTPException(409, "Analysis is for an older journal version")
    saved.feedback = payload.rating
    db.commit()
    db.refresh(saved)
    return to_read(saved, entry.body_version)
