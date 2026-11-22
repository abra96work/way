from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Query, status

from app.api.deps import CurrentUser, DbSession
from app.core.errors import ErrorResponse
from app.schemas.booking import BookingRead
from app.schemas.feedback import SanctionInfo, TripCancelResult
from app.schemas.search import SegmentQuote
from app.schemas.trip import (
    PARCEL_LIMITS,
    ParcelSizeRead,
    ReverseTripCreate,
    SeatsUpdate,
    TripCreate,
    TripListFilter,
    TripRead,
    TripWrite,
)
from app.services import bookings as booking_service
from app.services import trips as trip_service

router = APIRouter(prefix="/trips", tags=["trips"])

_errors = {
    400: {"model": ErrorResponse},
    401: {"model": ErrorResponse},
    403: {"model": ErrorResponse},
    404: {"model": ErrorResponse},
    409: {"model": ErrorResponse},
}


@router.get("/parcel-sizes", response_model=list[ParcelSizeRead])
async def parcel_sizes() -> list[ParcelSizeRead]:
    """Справочник размеров посылок S/M/L с максимальными габаритами и весом."""
    return [
        ParcelSizeRead(size=size, max_dimensions_cm=dims, max_weight_kg=weight)
        for size, (dims, weight) in PARCEL_LIMITS.items()
    ]


@router.post("", response_model=TripRead, status_code=status.HTTP_201_CREATED, responses=_errors)
async def create_trip(payload: TripCreate, user: CurrentUser, db: DbSession) -> TripRead:
    """Создать поездку: черновик (`publish: false`) или сразу опубликовать.

    Цены — без комиссии, в целых рублях; в ответе каждая цена расписана как
    `driver_price` / `commission` / `passenger_price`.
    """
    trip = await trip_service.create_trip(db, user, payload)
    return await trip_service.to_read(db, trip)


@router.get("/mine", response_model=list[TripRead], responses=_errors)
async def my_trips(
    user: CurrentUser,
    db: DbSession,
    status_filter: Annotated[TripListFilter | None, Query(alias="status")] = None,
) -> list[TripRead]:
    """«Мои поездки» водителя. `status`: active | completed | draft | cancelled."""
    trips = await trip_service.list_driver_trips(db, user, status_filter)
    return [await trip_service.to_read(db, trip) for trip in trips]


@router.get("/{trip_id}", response_model=TripRead, responses=_errors)
async def get_trip(trip_id: UUID, user: CurrentUser, db: DbSession) -> TripRead:
    trip = await trip_service.get_visible_trip(db, user, trip_id)
    return await trip_service.to_read(db, trip)


@router.get("/{trip_id}/price", response_model=SegmentQuote, responses=_errors)
async def segment_price(
    trip_id: UUID,
    user: CurrentUser,
    db: DbSession,
    from_position: Annotated[int, Query(ge=0, description="Остановка посадки")],
    to_position: Annotated[int, Query(ge=1, description="Остановка высадки")],
) -> SegmentQuote:
    """Цена и свободные места за одно место между двумя остановками поездки."""
    trip = await trip_service.get_visible_trip(db, user, trip_id)
    return await trip_service.quote(db, trip, from_position, to_position)


@router.get("/{trip_id}/bookings", response_model=list[BookingRead], responses=_errors)
async def trip_bookings(
    trip_id: UUID, user: CurrentUser, db: DbSession, active_only: bool = False
) -> list[BookingRead]:
    """Заявки и пассажиры поездки — только для её водителя."""
    bookings = await booking_service.list_trip_bookings(db, user, trip_id, active_only=active_only)
    return await booking_service.read_many(db, bookings, user)


@router.put("/{trip_id}", response_model=TripRead, responses=_errors)
async def replace_trip(
    trip_id: UUID, payload: TripWrite, user: CurrentUser, db: DbSession
) -> TripRead:
    """Изменить поездку целиком. Нельзя, если к ней уже присоединились пассажиры."""
    trip = await trip_service.replace_trip(db, user, trip_id, payload)
    return await trip_service.to_read(db, trip)


@router.patch("/{trip_id}/seats", response_model=TripRead, responses=_errors)
async def update_seats(
    trip_id: UUID, payload: SeatsUpdate, user: CurrentUser, db: DbSession
) -> TripRead:
    """Изменить количество мест — можно и после бронирований."""
    trip = await trip_service.update_seats(db, user, trip_id, payload.seats_total)
    return await trip_service.to_read(db, trip)


@router.post("/{trip_id}/publish", response_model=TripRead, responses=_errors)
async def publish_trip(trip_id: UUID, user: CurrentUser, db: DbSession) -> TripRead:
    trip = await trip_service.publish_trip(db, user, trip_id)
    return await trip_service.to_read(db, trip)


@router.get("/{trip_id}/cancel-preview", response_model=SanctionInfo, responses=_errors)
async def cancel_preview(trip_id: UUID, user: CurrentUser, db: DbSession) -> SanctionInfo:
    """Перед отменой: нарушает ли она правила сообщества и приведёт ли к блокировке."""
    return await trip_service.cancel_preview(db, user, trip_id)


@router.post("/{trip_id}/cancel", response_model=TripCancelResult, responses=_errors)
async def cancel_trip(trip_id: UUID, user: CurrentUser, db: DbSession) -> TripCancelResult:
    """Отменить поездку и все её брони. Если пассажиры уже зарегистрированы —
    предупреждение и учёт в блокировке (2 отмены за 30 дней → блок на 30 дней)."""
    trip, sanction = await trip_service.cancel_trip(db, user, trip_id)
    return TripCancelResult(trip=await trip_service.to_read(db, trip), sanction=sanction)


@router.delete("/{trip_id}", status_code=status.HTTP_204_NO_CONTENT, responses=_errors)
async def delete_trip(trip_id: UUID, user: CurrentUser, db: DbSession) -> None:
    """Удалить поездку, пока к ней никто не присоединился."""
    await trip_service.delete_trip(db, user, trip_id)


@router.post(
    "/{trip_id}/reverse",
    response_model=TripRead,
    status_code=status.HTTP_201_CREATED,
    responses=_errors,
)
async def reverse_trip(
    trip_id: UUID, payload: ReverseTripCreate, user: CurrentUser, db: DbSession
) -> TripRead:
    """Создать «обратную» поездку: маршрут в обратном порядке, нужно только время старта."""
    trip = await trip_service.reverse_trip(db, user, trip_id, payload)
    return await trip_service.to_read(db, trip)
