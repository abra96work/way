import enum
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, SmallInteger, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin


class VehicleType(enum.StrEnum):
    car = "car"
    bus = "bus"


class CarBrand(Base):
    __tablename__ = "car_brands"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(60), unique=True)


class CarModel(Base):
    __tablename__ = "car_models"
    __table_args__ = (UniqueConstraint("brand_id", "name", name="uq_car_models_brand_id_name"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    brand_id: Mapped[int] = mapped_column(
        ForeignKey("car_brands.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(60))

    brand: Mapped[CarBrand] = relationship(lazy="joined")


class Car(TimestampMixin, Base):
    """A vehicle attached to a driver's account ("Мои автомобили")."""

    __tablename__ = "cars"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    model_id: Mapped[int] = mapped_column(ForeignKey("car_models.id", ondelete="RESTRICT"))
    vehicle_type: Mapped[VehicleType] = mapped_column(
        Enum(VehicleType, name="vehicle_type", native_enum=False, length=8)
    )
    seats: Mapped[int] = mapped_column(SmallInteger)
    plate: Mapped[str | None] = mapped_column(String(12))
    photo_path: Mapped[str | None] = mapped_column(String(255))
    # Soft delete: trips keep pointing at the car they were made with.
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    model: Mapped[CarModel] = relationship(lazy="joined")
