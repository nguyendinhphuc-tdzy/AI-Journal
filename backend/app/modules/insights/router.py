"""Weekly Insights aggregation from private, version-valid saved analyses."""
from collections import Counter
from datetime import date, datetime, time, timedelta, timezone
from hashlib import sha256
import json

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import and_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.models.journal import JournalEntry
from app.models.journal_analysis import JournalAnalysis
from app.models.weekly_insight import WeeklyInsight
from app.modules.ai.quota import enforce_ai_quota
from app.modules.ai.service import AIProvider, get_ai_provider
from app.modules.journal.router import _user_timezone
from app.schemas.insights import EmotionCount, InsightDay, WeekInsights

router = APIRouter(prefix="/insights", tags=["insights"])

MOOD_IDS = frozenset({
    "joy", "grateful", "calm", "hopeful", "mixed",
    "tired", "anxious", "afraid", "angry", "sad",
})


@router.get("/week", response_model=WeekInsights)
def get_week(
    start: date = Query(..., description="Monday, YYYY-MM-DD, in user's timezone"),
    generate_summary: bool = Query(default=False,
        description="Explicitly allow sending aggregates to Ollama (no raw entries)"),
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if start.weekday() != 0:
        raise HTTPException(422, "start must be a Monday")
    tz = _user_timezone(db, user.user_id)
    end = start + timedelta(days=7)
    utc_start = datetime.combine(start, time.min, tzinfo=tz).astimezone(timezone.utc)
    utc_end = datetime.combine(end, time.min, tzinfo=tz).astimezone(timezone.utc)
    rows = db.execute(
        select(JournalEntry, JournalAnalysis)
        .outerjoin(JournalAnalysis, and_(
            JournalAnalysis.journal_id == JournalEntry.id,
            JournalAnalysis.user_id == JournalEntry.user_id,
        ))
        .where(JournalEntry.user_id == user.user_id,
               JournalEntry.created_at >= utc_start,
               JournalEntry.created_at < utc_end)
    ).all()
    stats = [
        {"date": start + timedelta(days=i), "journal_count": 0,
         "analyzed_count": 0, "scores": []}
        for i in range(7)
    ]
    totals = Counter()
    fingerprint_rows = []
    for entry, analysis in rows:
        at = entry.created_at
        if at.tzinfo is None:
            at = at.replace(tzinfo=timezone.utc)
        idx = (at.astimezone(tz).date() - start).days
        if idx < 0 or idx > 6:
            continue
        day = stats[idx]
        day["journal_count"] += 1
        valid = analysis is not None and analysis.body_version == entry.body_version
        fingerprint_rows.append((
            entry.id, entry.body_version, analysis.id.hex if analysis else "",
            analysis.body_version if analysis else None,
            analysis.updated_at.isoformat() if analysis else "",
        ))
        if not valid:
            continue
        day["analyzed_count"] += 1
        group = analysis.result.get("mood_group")
        score = analysis.result.get("mood_score")
        if group in MOOD_IDS:
            totals[group] += 1
        if type(score) is int and 0 <= score <= 100:
            day["scores"].append(score)
    days = [
        InsightDay(
            date=day["date"], journal_count=day["journal_count"],
            analyzed_count=day["analyzed_count"],
            score=round(sum(day["scores"]) / len(day["scores"]), 1)
                  if day["scores"] else None,
        )
        for day in stats
    ]
    top = [EmotionCount(mood_group=key, count=count)
           for key, count in sorted(totals.items(), key=lambda item: (-item[1], item[0]))]
    summary = None
    status = "no_data" if not any(d.analyzed_count for d in days) else "not_requested"
    if status != "no_data":
        fingerprint = sha256(json.dumps(sorted(fingerprint_rows),
                              separators=(",", ":")).encode()).hexdigest()
        cached = db.scalar(select(WeeklyInsight).where(
            WeeklyInsight.user_id == user.user_id,
            WeeklyInsight.monday == start,
        ))
        if cached and cached.fingerprint == fingerprint:
            summary, status = cached.summary, "ready"
        elif generate_summary:
            # Only when explicitly requested, count inference against the
            # same user quota as /ai/reflection and /journals/{id}/analysis.
            gate = enforce_ai_quota(user)
            try:
                next(gate)
                try:
                    aggregate = json.dumps({
                        "days": [d.model_dump(mode="json") for d in days],
                        "top_emotions": [e.model_dump() for e in top],
                    }, ensure_ascii=False)
                    # Provider selection is lazy: existing chart data must
                    # still work when Ollama is offline or not configured.
                    generated = get_ai_provider().summarize_week(aggregate)
                finally:
                    gate.close()
            except HTTPException as exc:
                if exc.status_code == 429:
                    raise
                generated = None
            if generated and generated.strip():
                if cached is None:
                    cached = WeeklyInsight(user_id=user.user_id, monday=start,
                                           fingerprint=fingerprint,
                                           summary=generated.strip()[:1200])
                    db.add(cached)
                else:
                    cached.fingerprint = fingerprint
                    cached.summary = generated.strip()[:1200]
                try:
                    db.commit()
                except IntegrityError:
                    db.rollback()  # Concurrent generation; avoid losing chart.
                summary, status = generated.strip()[:1200], "ready"
            else:
                status = "unavailable"

    return WeekInsights(start=start, end=end - timedelta(days=1),
                        days=days, top_emotions=top,
                        summary=summary, summary_status=status)
