import enum
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    SmallInteger,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin
from app.models.car import Car
from app.models.city import City
from app.models.user import User


class TripStatus(enum.StrEnum):
    draft = "draft"
    published = "published"
    cancelled = "cancelled"
    # "completed" is derived from departure time, see services.trips.effective_status.


class BookingMode(enum.StrEnum):
    manual = "manual"  # driver confirms every request, then the passenger pays
    instant = "instant"  # passenger pays right away, no confirmation


class ExtraKind(enum.StrEnum):
    child_seat = "child_seat"
    pets = "pets"
    luggage = "luggage"


class ParcelSize(enum.StrEnum):
    S = "S"
    M = "M"
    L = "L"


def _enum(cls: type[enum.StrEnum], name: str, length: int = 16) -> Enum:
    return Enum(cls, name=name, native_enum=False, length=length)


class Trip(TimestampMixin, Base):
    """A ride published by a driver. Prices are the driver's, in whole rubles."""

    __tablename__ = "trips"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    driver_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    car_id: Mapped[UUID] = mapped_column(ForeignKey("cars.id", ondelete="RESTRICT"), index=True)
    status: Mapped[TripStatus] = mapped_column(_enum(TripStatus, "trip_status"), index=True)
    departure_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    # Approximate arrival the driver states; informational, optional.
    arrival_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    seats_total: Mapped[int] = mapped_column(SmallInteger)
    booking_mode: Mapped[BookingMode] = mapped_column(_enum(BookingMode, "booking_mode"))
    full_price: Mapped[int] = mapped_column(Integer)
    min_price: Mapped[int] = mapped_column(Integer)
    return_of_trip_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("trips.id", ondelete="SET NULL")
    )
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    driver: Mapped[User] = relationship(lazy="raise")
    car: Mapped[Car] = relationship(lazy="raise")
    stops: Mapped[list["TripStop"]] = relationship(
        order_by="TripStop.position", cascade="all, delete-orphan", lazy="raise"
    )
    segment_prices: Mapped[list["TripSegmentPrice"]] = relationship(
        cascade="all, delete-orphan", lazy="raise"
    )
    extras: Mapped[list["TripExtra"]] = relationship(cascade="all, delete-orphan", lazy="raise")
    parcel_prices: Mapped[list["TripParcelPrice"]] = relationship(
        cascade="all, delete-orphan", lazy="raise"
    )

    __table_args__ = (
        CheckConstraint("seats_total > 0", name="seats_positive"),
        CheckConstraint("min_price >= 0 AND min_price <= full_price", name="min_price_range"),
    )


class TripStop(Base):
    __tablename__ = "trip_stops"
    __table_args__ = (UniqueConstraint("trip_id", "position", name="uq_trip_stops_trip_position"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    trip_id: Mapped[UUID] = mapped_column(ForeignKey("trips.id", ondelete="CASCADE"), index=True)
    position: Mapped[int] = mapped_column(SmallInteger)
    city_id: Mapped[int] = mapped_column(ForeignKey("cities.id", ondelete="RESTRICT"), index=True)
    address: Mapped[str] = mapped_column(String(200))
    lat: Mapped[float | None] = mapped_column(Float)
    lng: Mapped[float | None] = mapped_column(Float)

    city: Mapped[City] = relationship(lazy="joined")


class TripSegmentPrice(Base):
    """Driver's price from stop `from_position` to stop `to_position`.

    Consecutive segments are always stored; any other pair is an optional override.
    The whole route lives in Trip.full_price.
    """

    __tablename__ = "trip_segment_prices"
    __table_args__ = (
        UniqueConstraint("trip_id", "from_position", "to_position", name="uq_trip_segment_pair"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    trip_id: Mapped[UUID] = mapped_column(ForeignKey("trips.id", ondelete="CASCADE"), index=True)
    from_position: Mapped[int] = mapped_column(SmallInteger)
    to_position: Mapped[int] = mapped_column(SmallInteger)
    price: Mapped[int] = mapped_column(Integer)


class TripExtra(Base):
    __tablename__ = "trip_extras"
    __table_args__ = (UniqueConstraint("trip_id", "kind", name="uq_trip_extras_trip_kind"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    trip_id: Mapped[UUID] = mapped_column(ForeignKey("trips.id", ondelete="CASCADE"), index=True)
    kind: Mapped[ExtraKind] = mapped_column(_enum(ExtraKind, "extra_kind"))
    price: Mapped[int] = mapped_column(Integer)


class TripParcelPrice(Base):
    __tablename__ = "trip_parcel_prices"
    __table_args__ = (UniqueConstraint("trip_id", "size", name="uq_trip_parcel_trip_size"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    trip_id: Mapped[UUID] = mapped_column(ForeignKey("trips.id", ondelete="CASCADE"), index=True)
    size: Mapped[ParcelSize] = mapped_column(_enum(ParcelSize, "parcel_size", length=2))
    price: Mapped[int] = mapped_column(Integer)
