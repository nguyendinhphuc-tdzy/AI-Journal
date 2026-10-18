"""Provider-neutral private saved-place request and response contracts."""
from datetime import datetime, timezone
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator, field_validator

Latitude = Annotated[float, Field(ge=-90, le=90, allow_inf_nan=False)]
Longitude = Annotated[float, Field(ge=-180, le=180, allow_inf_nan=False)]


class PlaceCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    label: str = Field(min_length=1, max_length=160)
    latitude: Latitude
    longitude: Longitude
    address_text: str | None = Field(default=None, max_length=2000)
    provider: Literal["manual", "geoapify"] = "manual"
    external_place_id: str | None = Field(default=None, max_length=2048)

    @field_validator("label")
    @classmethod
    def label_nonempty(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("label must not be blank")
        return value

    @model_validator(mode="after")
    def consistent_source(self) -> "PlaceCreate":
        if self.provider == "manual" and self.external_place_id is not None:
            raise ValueError("manual pin cannot have external_place_id")
        if self.provider == "geoapify":
            if not self.external_place_id or not self.external_place_id.strip():
                raise ValueError("Geoapify result requires external_place_id")
            self.external_place_id = self.external_place_id.strip()
        return self


class PlaceUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    label: str | None = Field(default=None, min_length=1, max_length=160)
    address_text: str | None = Field(default=None, max_length=2000)
    latitude: Latitude | None = None
    longitude: Longitude | None = None

    @field_validator("label")
    @classmethod
    def label_nonempty(cls, value: str | None) -> str:
        if value is None or not value.strip():
            raise ValueError("label cannot be empty or null")
        return value.strip()


class PlaceRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    label: str
    latitude: float
    longitude: float
    address_text: str | None
    provider: Literal["manual", "geoapify"]
    external_place_id: str | None
    created_at: datetime
    updated_at: datetime

    @field_validator("created_at", "updated_at")
    @classmethod
    def as_utc(cls, value: datetime) -> datetime:
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


class PlacePage(BaseModel):
    items: list[PlaceRead]
    next_cursor: str | None
