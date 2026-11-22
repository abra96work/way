from datetime import date as Date
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.car import VehicleType
from app.models.trip import BookingMode, ExtraKind
from app.schemas.trip import PriceRead, StopRead
from app.schemas.user import RatedUser


class SearchParams(BaseModel):
    from_city_id: int | None = Field(default=None, description="Город посадки")
    to_city_id: int | None = Field(default=None, description="Город высадки")
    from_query: str | None = Field(
        default=None, max_length=60, description="Название пункта посадки"
    )
    to_query: str | None = Field(default=None, max_length=60, description="Название пункта высадки")
    lat: float | None = Field(default=None, ge=-90, le=90, description="Геопозиция пассажира")
    lng: float | None = Field(default=None, ge=-180, le=180)
    radius_km: float = Field(default=30, gt=0, le=300, description="Радиус «поблизости»")
    date: Date | None = Field(default=None, description="Дата отправления (местное время)")
    vehicle_type: VehicleType | None = Field(
        default=None, description="Вкладка «Автомобили/Автобусы»"
    )
    seats: int = Field(default=1, ge=1, le=60)
    limit: int = Field(default=20, ge=1, le=100)
    offset: int = Field(default=0, ge=0)


class CarBrief(BaseModel):
    brand: str
    model: str
    photo_url: str | None
    plate: str | None


class SearchResultItem(BaseModel):
    trip_id: UUID
    departure_at: datetime
    vehicle_type: VehicleType
    booking_mode: BookingMode
    driver: RatedUser
    car: CarBrief
    origin: StopRead = Field(description="Начало всего маршрута")
    destination: StopRead = Field(description="Конец всего маршрута")
    board: StopRead = Field(description="Где сядет пассажир")
    alight: StopRead = Field(description="Где выйдет пассажир")
    stops_count: int
    distance_km: float | None = Field(
        description="От пассажира до посадки, если передана геопозиция"
    )
    price: PriceRead = Field(description="Цена отрезка board→alight за одно место")
    seats_available: int
    extras: list[ExtraKind]
    accepts_parcels: bool
    is_registration_open: bool = Field(
        description="Можно бронировать сейчас. На одном маршруте в одно время открыта только "
        "первая машина, следующая — после её заполнения"
    )


class SearchResult(BaseModel):
    items: list[SearchResultItem]
    total: int


class SegmentQuote(BaseModel):
    from_position: int
    to_position: int
    price: PriceRead
    seats_available: int
