import re
from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import AfterValidator, BaseModel, ConfigDict, Field

from app.models.car import VehicleType

MAX_SEATS = {VehicleType.car: 8, VehicleType.bus: 60}
# Russian plates use only letters that look the same in Latin and Cyrillic.
_PLATE = re.compile(r"^[0-9ABEKMHOPCTYXАВЕКМНОРСТУХ\-]{4,12}$")


def normalize_plate(value: str | None) -> str | None:
    if value is None:
        return None
    plate = "".join(value.split()).upper()
    if not plate:
        return None
    if not _PLATE.match(plate):
        raise ValueError("Некорректный госномер")
    return plate


Plate = Annotated[
    str | None,
    Field(max_length=20, examples=["А777АА 66"]),
    AfterValidator(normalize_plate),
]


class CarBrandRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str


class CarModelRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str


class CarRead(BaseModel):
    id: UUID
    brand: CarBrandRead
    model: CarModelRead
    vehicle_type: VehicleType
    seats: int = Field(description="Пассажирских мест (без водителя)")
    plate: str | None
    photo_url: str | None
    created_at: datetime


class CarCreate(BaseModel):
    model_id: int
    vehicle_type: VehicleType = VehicleType.car
    seats: int = Field(ge=1, le=60, description="Пассажирских мест: легковой до 8, автобус до 60")
    plate: Plate = None


class CarUpdate(BaseModel):
    model_id: int | None = None
    vehicle_type: VehicleType | None = None
    seats: int | None = Field(default=None, ge=1, le=60)
    plate: Plate = None
