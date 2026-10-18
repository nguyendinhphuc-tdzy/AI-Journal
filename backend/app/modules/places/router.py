"""Private places CRUD: each operation scopes resources to JWT user_id."""
import base64
import binascii
import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import and_, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.models.saved_place import SavedPlace
from app.schemas.place import PlaceCreate, PlacePage, PlaceRead, PlaceUpdate


router = APIRouter(prefix="/places", tags=["places"])


def _as_utc(at: datetime) -> datetime:
    if at.tzinfo is None:
        return at.replace(tzinfo=timezone.utc)
    return at.astimezone(timezone.utc)


def _encode_cursor(place: SavedPlace) -> str:
    value = {"at": _as_utc(place.created_at).isoformat(), "id": place.id}
    return base64.urlsafe_b64encode(
        json.dumps(value, separators=(",", ":")).encode()
    ).decode().rstrip("=")


def _decode_cursor(value: str) -> tuple[datetime, int]:
    try:
        if not value or len(value) > 512:
            raise ValueError("Invalid length")
        raw = base64.b64decode(
            value + "=" * (-len(value) % 4), altchars=b"-_", validate=True
        )
        data = json.loads(raw)
        if not isinstance(data, dict) or set(data) != {"at", "id"}:
            raise ValueError("Invalid cursor")
        if type(data["id"]) is not int or data["id"] < 1:
            raise ValueError("Invalid ID")
        timestamp = datetime.fromisoformat(data["at"])
        if timestamp.tzinfo is None:
            raise ValueError("Missing timezone")
        return _as_utc(timestamp), data["id"]
    except (ValueError, TypeError, KeyError, UnicodeDecodeError, binascii.Error, OverflowError) as exc:
        raise HTTPException(status_code=400, detail="Invalid saved places cursor") from exc


def _owned_or_404(place_id: int, user_id, db: Session) -> SavedPlace:
    item = db.scalar(
        select(SavedPlace).where(
            SavedPlace.id == place_id, SavedPlace.user_id == user_id
        )
    )
    if item is None:
        raise HTTPException(status_code=404, detail="Saved place not found")
    return item


@router.get("", response_model=PlacePage)
def list_places(
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None, max_length=512),
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    stmt = select(SavedPlace).where(SavedPlace.user_id == user.user_id)
    if cursor is not None:
        at, item_id = _decode_cursor(cursor)
        stmt = stmt.where(or_(
            SavedPlace.created_at < at,
            and_(SavedPlace.created_at == at, SavedPlace.id < item_id),
        ))
    result = list(db.scalars(
        stmt.order_by(SavedPlace.created_at.desc(), SavedPlace.id.desc())
        .limit(limit + 1)
    ).all())
    items = result[:limit]
    return PlacePage(
        items=items,
        next_cursor=_encode_cursor(items[-1]) if len(result) > limit else None,
    )


@router.post("", response_model=PlaceRead, status_code=status.HTTP_201_CREATED)
def create_place(
    payload: PlaceCreate,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    place = SavedPlace(**payload.model_dump(), user_id=user.user_id)
    db.add(place)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        # A repeated Geoapify provider ID is a conflict, not a second pin.
        raise HTTPException(
            status_code=409, detail="Saved place already exists or is invalid"
        ) from exc
    db.refresh(place)
    return place


@router.get("/{place_id}", response_model=PlaceRead)
def get_place(
    place_id: int,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _owned_or_404(place_id, user.user_id, db)


@router.patch("/{place_id}", response_model=PlaceRead)
def update_place(
    place_id: int,
    payload: PlaceUpdate,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    place = _owned_or_404(place_id, user.user_id, db)
    changes = payload.model_dump(exclude_unset=True)
    if (
        place.provider != "manual"
        and ("latitude" in changes or "longitude" in changes)
    ):
        raise HTTPException(
            status_code=422,
            detail="Provider place coordinates are immutable; save a new place",
        )
    if changes.get("latitude") is None and "latitude" in changes:
        raise HTTPException(status_code=422, detail="latitude must not be null")
    if changes.get("longitude") is None and "longitude" in changes:
        raise HTTPException(status_code=422, detail="longitude must not be null")
    for name, value in changes.items():
        setattr(place, name, value)
    db.commit()
    db.refresh(place)
    return place


@router.delete("/{place_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_place(
    place_id: int,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    place = _owned_or_404(place_id, user.user_id, db)
    db.delete(place)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
