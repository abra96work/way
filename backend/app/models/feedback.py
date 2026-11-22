"""Reviews, complaints and the cancellation log that drives sanctions and rating."""

import enum
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    SmallInteger,
    String,
    UniqueConstraint,
    false,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin


def _enum(cls: type[enum.StrEnum], name: str, length: int = 20) -> Enum:
    return Enum(cls, name=name, native_enum=False, length=length)


class ParticipantRole(enum.StrEnum):
    driver = "driver"
    passenger = "passenger"


class Review(TimestampMixin, Base):
    """A 1–5 star review one trip participant leaves about another.

    The test build has no UI for leaving reviews ("5 звёзд, нет отзывов"), but the data
    model and service are complete and the endpoint is behind `PUT_REVIEWS_ENABLED`.
    """

    __tablename__ = "reviews"
    __table_args__ = (
        UniqueConstraint("trip_id", "author_id", "target_id", name="uq_reviews_trip_author_target"),
        CheckConstraint("rating BETWEEN 1 AND 5", name="rating_range"),
        CheckConstraint("author_id <> target_id", name="not_self"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    trip_id: Mapped[UUID] = mapped_column(ForeignKey("trips.id", ondelete="CASCADE"), index=True)
    booking_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("bookings.id", ondelete="SET NULL"), index=True
    )
    author_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    target_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    target_role: Mapped[ParticipantRole] = mapped_column(
        _enum(ParticipantRole, "participant_role", 10)
    )
    rating: Mapped[int] = mapped_column(SmallInteger)
    text: Mapped[str | None] = mapped_column(String(1000))
    # Moderation: hidden reviews don't count toward the rating.
    is_hidden: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class ComplaintReason(enum.StrEnum):
    no_show = "no_show"
    late = "late"
    rude = "rude"
    unsafe_driving = "unsafe_driving"
    vehicle_mismatch = "vehicle_mismatch"
    fraud = "fraud"
    other = "other"


class ComplaintStatus(enum.StrEnum):
    new = "new"
    in_review = "in_review"
    resolved = "resolved"
    rejected = "rejected"


class Complaint(TimestampMixin, Base):
    __tablename__ = "complaints"
    __table_args__ = (CheckConstraint("author_id <> target_id", name="not_self"),)

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    author_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    target_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    trip_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("trips.id", ondelete="SET NULL"), index=True
    )
    reason: Mapped[ComplaintReason] = mapped_column(_enum(ComplaintReason, "complaint_reason"))
    text: Mapped[str | None] = mapped_column(String(1000))
    status: Mapped[ComplaintStatus] = mapped_column(
        _enum(ComplaintStatus, "complaint_status", 12),
        default=ComplaintStatus.new,
        server_default=ComplaintStatus.new.value,
    )
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Cancellation(TimestampMixin, Base):
    """A cancellation that breaks community rules (after the passenger was registered).

    Two of these within 30 days block the user for 30 days.
    """

    __tablename__ = "cancellations"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    role: Mapped[ParticipantRole] = mapped_column(_enum(ParticipantRole, "participant_role", 10))
    trip_id: Mapped[UUID | None] = mapped_column(ForeignKey("trips.id", ondelete="SET NULL"))
    booking_id: Mapped[UUID | None] = mapped_column(ForeignKey("bookings.id", ondelete="SET NULL"))
    # Set when this cancellation triggered a block.
    blocked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
