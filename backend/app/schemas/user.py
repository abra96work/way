from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.models.user import FacePhotoStatus
from app.schemas.city import CityRead


class PublicUser(BaseModel):
    id: UUID
    first_name: str | None
    last_name: str | None
    avatar_url: str | None


class RatedUser(PublicUser):
    rating: float = Field(description="Звёзды по отзывам; без отзывов — 5.0")
    reviews_count: int = Field(description="0 — показывать «5 звёзд, нет отзывов»")
    completed_trips: int


class MeRead(PublicUser):
    phone: str
    city: CityRead | None
    face_photo_status: FacePhotoStatus
    is_profile_complete: bool
    blocked_until: datetime | None
    created_at: datetime


class MeUpdate(BaseModel):
    first_name: str | None = Field(default=None, min_length=1, max_length=60)
    last_name: str | None = Field(default=None, max_length=60)
    city_id: int | None = None

    @field_validator("first_name", "last_name")
    @classmethod
    def _strip(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = " ".join(value.split())
        return value or None
