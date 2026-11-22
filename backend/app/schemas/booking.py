import enum
from datetime import datetime
from typing import Self
from uuid import UUID

from pydantic import BaseModel, Field, model_validator

from app.models.booking import BookingKind, CancelledBy
from app.models.car import VehicleType
from app.models.trip import BookingMode, ExtraKind, ParcelSize
from app.schemas.search import CarBrief
from app.schemas.trip import ExtraRead, PriceRead, StopRead, TripStatusView
from app.schemas.user import RatedUser


class BookingStatusView(enum.StrEnum):
    pending = "pending"
    awaiting_payment = "awaiting_payment"
    paid = "paid"
    completed = "completed"
    rejected = "rejected"
    cancelled = "cancelled"


class BookingListFilter(enum.StrEnum):
    active = "active"  # pending, awaiting_payment, paid of upcoming trips
    completed = "completed"
    cancelled = "cancelled"  # cancelled and rejected


class BookingRequest(BaseModel):
    trip_id: UUID
    kind: BookingKind = BookingKind.seat
    from_position: int = Field(ge=0, description="Остановка посадки (или отправки посылки)")
    to_position: int = Field(ge=1, description="Остановка высадки (или получения посылки)")
    seats: int = Field(default=1, ge=1, le=60, description="Только для kind=seat")
    extras: list[ExtraKind] = Field(default_factory=list, description="Только для kind=seat")
    parcel_size: ParcelSize | None = Field(default=None, description="Только для kind=parcel")

    @model_validator(mode="after")
    def _validate(self) -> Self:
        if self.from_position >= self.to_position:
            raise ValueError("Остановка высадки должна быть после остановки посадки")
        if len(set(self.extras)) != len(self.extras):
            raise ValueError("Доп. услуга указана дважды")
        if self.kind == BookingKind.parcel:
            if self.parcel_size is None:
                raise ValueError("Выберите размер посылки")
            if self.extras:
                raise ValueError("Доп. услуги доступны только при бронировании места")
        elif self.parcel_size is not None:
            raise ValueError("Размер посылки указывается только для отправки посылки")
        return self


class BookingQuote(BaseModel):
    price: PriceRead = Field(description="Итого: водителю + комиссия сервиса")
    seat_price: PriceRead | None = Field(description="За одно место на выбранном отрезке")
    extras: list[ExtraRead]
    seats_available: int
    is_registration_open: bool


class PaymentInfo(BaseModel):
    pay_online: int = Field(description="Комиссия сервиса, оплачивается в приложении")
    pay_to_driver: int = Field(description="Оплачивается водителю")
    is_paid: bool


class BookingTrip(BaseModel):
    id: UUID
    status: TripStatusView
    departure_at: datetime
    booking_mode: BookingMode
    vehicle_type: VehicleType
    origin: StopRead
    destination: StopRead
    driver: RatedUser
    car: CarBrief


class BookingRead(BaseModel):
    id: UUID
    status: BookingStatusView
    kind: BookingKind
    trip: BookingTrip
    passenger: RatedUser
    board: StopRead
    alight: StopRead
    seats: int
    parcel_size: ParcelSize | None
    extras: list[ExtraRead]
    price: PriceRead
    payment: PaymentInfo
    can_pay: bool
    can_cancel: bool
    created_at: datetime
    confirmed_at: datetime | None
    paid_at: datetime | None
    cancelled_at: datetime | None
    cancelled_by: CancelledBy | None


class NotificationRead(BaseModel):
    id: UUID
    type: str
    title: str
    body: str
    trip_id: UUID | None
    booking_id: UUID | None
    is_read: bool
    created_at: datetime


class UnreadCount(BaseModel):
    unread: int
