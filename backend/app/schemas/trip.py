import enum
from datetime import UTC, datetime, timedelta
from datetime import date as Date
from typing import Annotated, Self
from uuid import UUID

from pydantic import BaseModel, Field, model_validator

from app.models.car import VehicleType
from app.models.trip import BookingMode, ExtraKind, ParcelSize
from app.schemas.car import CarRead
from app.schemas.city import CityRead
from app.schemas.user import RatedUser

Rubles = Annotated[int, Field(ge=0, le=100_000, description="Целые рубли")]
PositiveRubles = Annotated[int, Field(ge=1, le=100_000, description="Целые рубли")]

# Maximum dimensions (cm) and weight (kg) for each parcel size.
PARCEL_LIMITS: dict[ParcelSize, tuple[tuple[int, int, int], int]] = {
    ParcelSize.S: ((30, 30, 20), 5),
    ParcelSize.M: ((50, 40, 30), 10),
    ParcelSize.L: ((80, 60, 50), 30),
}


class TripStatusView(enum.StrEnum):
    draft = "draft"
    published = "published"
    cancelled = "cancelled"
    completed = "completed"


class TripListFilter(enum.StrEnum):
    active = "active"
    completed = "completed"
    draft = "draft"
    cancelled = "cancelled"


# ---------- input ----------


class StopIn(BaseModel):
    city_id: int
    address: str = Field(min_length=2, max_length=200, examples=["ул. Победителей, 1"])
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)


class SegmentPriceIn(BaseModel):
    from_position: int = Field(ge=0)
    to_position: int = Field(ge=1)
    price: PositiveRubles


class ExtraIn(BaseModel):
    kind: ExtraKind
    price: Rubles


class ParcelPriceIn(BaseModel):
    size: ParcelSize
    price: Rubles


class TripWrite(BaseModel):
    car_id: UUID
    departure_at: datetime = Field(description="С часовым поясом, минуты кратны 30")
    arrival_at: datetime | None = Field(
        default=None, description="Примерное время прибытия, с часовым поясом"
    )
    seats_total: int = Field(ge=1, le=60)
    booking_mode: BookingMode = BookingMode.manual
    stops: list[StopIn] = Field(min_length=2, description="Отправление, остановки, прибытие")
    full_price: PositiveRubles = Field(description="Цена всего маршрута (без комиссии)")
    min_price: Rubles = Field(default=0, description="Минимальная стоимость «за посадку»")
    segment_prices: list[SegmentPriceIn] = Field(
        default_factory=list,
        description="Цены между соседними остановками (обязательны при 3+ остановках) "
        "и необязательные цены для других пар",
    )
    extras: list[ExtraIn] = Field(default_factory=list)
    parcel_prices: list[ParcelPriceIn] = Field(
        default_factory=list, description="Пусто — посылки не принимаются"
    )

    @model_validator(mode="after")
    def _validate(self) -> Self:
        if self.departure_at.tzinfo is None:
            raise ValueError("departure_at должен содержать часовой пояс")
        # SQLite drops the offset when storing, so keep every timestamp in UTC.
        self.departure_at = self.departure_at.astimezone(UTC)
        if (
            self.departure_at.minute % 30
            or self.departure_at.second
            or self.departure_at.microsecond
        ):
            raise ValueError("Время отправления должно быть кратно 30 минутам")
        if self.arrival_at is not None:
            if self.arrival_at.tzinfo is None:
                raise ValueError("arrival_at должен содержать часовой пояс")
            self.arrival_at = self.arrival_at.astimezone(UTC)
            if self.arrival_at <= self.departure_at:
                raise ValueError("Время прибытия должно быть позже времени отправления")
            if self.arrival_at - self.departure_at > timedelta(hours=48):
                raise ValueError("Поездка не может длиться больше 48 часов")
        if self.min_price > self.full_price:
            raise ValueError("Минимальная стоимость больше цены всего маршрута")
        if self.stops[0].city_id == self.stops[-1].city_id:
            raise ValueError("Пункты отправления и прибытия должны быть в разных городах")

        last = len(self.stops) - 1
        pairs = [(p.from_position, p.to_position) for p in self.segment_prices]
        if len(set(pairs)) != len(pairs):
            raise ValueError("Цена для пары остановок указана дважды")
        for start, end in pairs:
            if not start < end <= last:
                raise ValueError(f"Неверная пара остановок {start}→{end}")
            if (start, end) == (0, last):
                raise ValueError("Цена всего маршрута задаётся полем full_price")
        if last > 1:
            missing = [i for i in range(last) if (i, i + 1) not in pairs]
            if missing:
                raise ValueError("Укажите цены между всеми соседними остановками")

        if len({e.kind for e in self.extras}) != len(self.extras):
            raise ValueError("Доп. услуга указана дважды")
        if len({p.size for p in self.parcel_prices}) != len(self.parcel_prices):
            raise ValueError("Размер посылки указан дважды")
        return self


class TripCreate(TripWrite):
    publish: bool = Field(default=False, description="false — сохранить черновик")


class SeatsUpdate(BaseModel):
    seats_total: int = Field(ge=1, le=60)


class ReverseTripCreate(BaseModel):
    departure_at: datetime
    arrival_at: datetime | None = Field(
        default=None,
        description="Своё время прибытия; если не задано — длительность как у исходной поездки",
    )
    publish: bool = False


class LimitUsage(BaseModel):
    used: int
    limit: int


class PublishLimits(BaseModel):
    """Счётчики лимитов публикации для дня отправления и его недели."""

    date: Date
    day: LimitUsage = Field(description="Поездка и обратная в одни сутки")
    week: LimitUsage = Field(description="Календарная неделя пн–вс")
    week_start: Date
    week_end: Date


# ---------- output ----------


class PriceRead(BaseModel):
    driver_price: int = Field(description="Получает водитель")
    commission: int = Field(description="Комиссия сервиса, оплачивается онлайн")
    passenger_price: int = Field(description="Видит пассажир: цена водителя + комиссия")


class StopRead(BaseModel):
    position: int
    city: CityRead
    address: str
    lat: float | None
    lng: float | None


class SegmentPriceRead(BaseModel):
    from_position: int
    to_position: int
    price: PriceRead


class ExtraRead(BaseModel):
    kind: ExtraKind
    price: PriceRead


class ParcelSizeRead(BaseModel):
    size: ParcelSize
    max_dimensions_cm: tuple[int, int, int]
    max_weight_kg: int


class ParcelPriceRead(ParcelSizeRead):
    price: PriceRead


class TripRequests(BaseModel):
    """Bookings of the driver's own trip, for the «Мои заказы» card."""

    count: int = Field(description="Активные заявки и брони (места и посылки)")
    avatars: list[str] = Field(description="Аватары первых пассажиров, не больше двух")


class TripRead(BaseModel):
    id: UUID
    number: int | None = Field(default=None, description="Номер заказа для показа")
    status: TripStatusView
    driver: RatedUser
    car: CarRead
    vehicle_type: VehicleType
    departure_at: datetime
    arrival_at: datetime | None
    seats_total: int
    seats_available: int
    booking_mode: BookingMode
    stops: list[StopRead]
    full_price: PriceRead
    min_price: PriceRead
    segment_prices: list[SegmentPriceRead]
    extras: list[ExtraRead]
    parcel_prices: list[ParcelPriceRead]
    return_of_trip_id: UUID | None
    is_editable: bool = Field(description="Можно менять маршрут, время и цены")
    created_at: datetime
    published_at: datetime | None
    requests: TripRequests | None = Field(
        default=None, description="Только в «Мои поездки» водителя (GET /trips/mine)"
    )
