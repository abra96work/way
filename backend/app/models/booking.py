import enum
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    JSON,
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    SmallInteger,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin
from app.models.trip import ExtraKind, ParcelSize, Trip
from app.models.user import User


class BookingKind(enum.StrEnum):
    seat = "seat"  # passenger rides
    parcel = "parcel"  # only a parcel travels, no passenger


class BookingStatus(enum.StrEnum):
    pending = "pending"  # manual mode: waits for the driver
    awaiting_payment = "awaiting_payment"  # confirmed (or instant): passenger must pay
    paid = "paid"
    rejected = "rejected"
    cancelled = "cancelled"
    # "completed" is derived: a paid booking of a finished trip.


ACTIVE_BOOKING_STATUSES = (
    BookingStatus.pending,
    BookingStatus.awaiting_payment,
    BookingStatus.paid,
)


class CancelledBy(enum.StrEnum):
    passenger = "passenger"
    driver = "driver"


def _enum(cls: type[enum.StrEnum], name: str, length: int = 20) -> Enum:
    return Enum(cls, name=name, native_enum=False, length=length)


class Booking(TimestampMixin, Base):
    """A passenger's seat(s) or a parcel on part of a trip. Money is in whole rubles.

    `driver_price` goes to the driver in cash; `commission` is paid online (mocked).
    """

    __tablename__ = "bookings"
    __table_args__ = (
        CheckConstraint("from_position < to_position", name="segment_order"),
        CheckConstraint("seats >= 0", name="seats_non_negative"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    trip_id: Mapped[UUID] = mapped_column(ForeignKey("trips.id", ondelete="CASCADE"), index=True)
    passenger_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    kind: Mapped[BookingKind] = mapped_column(_enum(BookingKind, "booking_kind", 8))
    status: Mapped[BookingStatus] = mapped_column(
        _enum(BookingStatus, "booking_status"), index=True
    )
    from_position: Mapped[int] = mapped_column(SmallInteger)
    to_position: Mapped[int] = mapped_column(SmallInteger)
    seats: Mapped[int] = mapped_column(SmallInteger)
    parcel_size: Mapped[ParcelSize | None] = mapped_column(_enum(ParcelSize, "parcel_size", 2))
    driver_price: Mapped[int] = mapped_column(Integer)
    commission: Mapped[int] = mapped_column(Integer)
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_by: Mapped[CancelledBy | None] = mapped_column(_enum(CancelledBy, "cancelled_by", 12))

    trip: Mapped[Trip] = relationship(lazy="raise")
    passenger: Mapped[User] = relationship(lazy="raise")
    extras: Mapped[list["BookingExtra"]] = relationship(cascade="all, delete-orphan", lazy="raise")

    @property
    def total(self) -> int:
        return self.driver_price + self.commission


class BookingExtra(Base):
    __tablename__ = "booking_extras"
    __table_args__ = (UniqueConstraint("booking_id", "kind", name="uq_booking_extras_kind"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    booking_id: Mapped[UUID] = mapped_column(
        ForeignKey("bookings.id", ondelete="CASCADE"), index=True
    )
    kind: Mapped[ExtraKind] = mapped_column(_enum(ExtraKind, "extra_kind", 16))
    price: Mapped[int] = mapped_column(Integer)


class Payment(TimestampMixin, Base):
    """Online payment of the service commission. The provider is a mock in the test build."""

    __tablename__ = "payments"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    booking_id: Mapped[UUID] = mapped_column(
        ForeignKey("bookings.id", ondelete="CASCADE"), index=True
    )
    amount: Mapped[int] = mapped_column(Integer)
    provider: Mapped[str] = mapped_column(String(20), default="mock")
    status: Mapped[str] = mapped_column(String(20), default="succeeded")


class Notification(TimestampMixin, Base):
    __tablename__ = "notifications"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    type: Mapped[str] = mapped_column(String(40))
    title: Mapped[str] = mapped_column(String(120))
    body: Mapped[str] = mapped_column(String(500))
    payload: Mapped[dict] = mapped_column(JSON, default=dict)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
