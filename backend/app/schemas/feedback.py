from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.feedback import ComplaintReason, ComplaintStatus, ParticipantRole
from app.schemas.trip import TripRead
from app.schemas.user import PublicUser


class SanctionInfo(BaseModel):
    is_violation: bool = Field(description="Отмена нарушает правила сообщества")
    warning: str | None = Field(default=None, description="Текст предупреждения для пользователя")
    violations_last_period: int = Field(description="Нарушений за последние 30 дней")
    blocks_account: bool = Field(
        default=False, description="В превью — заблокирует ли отмена; после — заблокировала ли"
    )
    blocked_until: datetime | None = None


class ReviewCreate(BaseModel):
    trip_id: UUID
    target_id: UUID
    rating: int = Field(ge=1, le=5)
    text: str | None = Field(default=None, max_length=1000)


class ReviewRead(BaseModel):
    id: UUID
    trip_id: UUID
    author: PublicUser
    target_role: ParticipantRole
    rating: int
    text: str | None
    created_at: datetime


class ComplaintCreate(BaseModel):
    target_id: UUID
    trip_id: UUID
    reason: ComplaintReason
    text: str | None = Field(default=None, max_length=1000)


class ComplaintRead(BaseModel):
    """A complaint as seen by its target: the author is not disclosed."""

    id: UUID
    trip_id: UUID | None
    reason: ComplaintReason
    text: str | None
    status: ComplaintStatus
    created_at: datetime


class TripCancelResult(BaseModel):
    trip: TripRead
    sanction: SanctionInfo
