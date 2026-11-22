from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Query, status

from app.api.deps import CurrentUser, DbSession
from app.core.errors import ErrorResponse
from app.schemas.booking import (
    BookingCancelResult,
    BookingListFilter,
    BookingQuote,
    BookingRead,
    BookingRequest,
)
from app.schemas.feedback import SanctionInfo
from app.services import bookings as booking_service

router = APIRouter(prefix="/bookings", tags=["bookings"])

_errors = {
    400: {"model": ErrorResponse},
    401: {"model": ErrorResponse},
    403: {"model": ErrorResponse},
    404: {"model": ErrorResponse},
    409: {"model": ErrorResponse},
}


@router.post("/quote", response_model=BookingQuote, responses=_errors)
async def quote(payload: BookingRequest, user: CurrentUser, db: DbSession) -> BookingQuote:
    """Расчёт стоимости до бронирования: итог, цена места, доп. услуги, свободные места."""
    return await booking_service.quote(db, user, payload)


@router.post("", response_model=BookingRead, status_code=status.HTTP_201_CREATED, responses=_errors)
async def create(payload: BookingRequest, user: CurrentUser, db: DbSession) -> BookingRead:
    """Присоединиться к поездке: место(а) на отрезке или посылка.

    Стандартный режим — заявка `pending`, ждёт водителя; быстрый — сразу `awaiting_payment`.
    """
    booking = await booking_service.create_booking(db, user, payload)
    _, trip = await booking_service.get_for_user(db, user, booking.id)
    return await booking_service.to_read(db, booking, trip, user)


@router.get("/mine", response_model=list[BookingRead], responses=_errors)
async def my_bookings(
    user: CurrentUser,
    db: DbSession,
    status_filter: Annotated[BookingListFilter | None, Query(alias="status")] = None,
) -> list[BookingRead]:
    """«Мои поездки» пассажира. `status`: active | completed | cancelled."""
    bookings = await booking_service.list_passenger_bookings(db, user, status_filter)
    return await booking_service.read_many(db, bookings, user)


@router.get("/{booking_id}", response_model=BookingRead, responses=_errors)
async def get_booking(booking_id: UUID, user: CurrentUser, db: DbSession) -> BookingRead:
    booking, trip = await booking_service.get_for_user(db, user, booking_id)
    return await booking_service.to_read(db, booking, trip, user)


@router.post("/{booking_id}/confirm", response_model=BookingRead, responses=_errors)
async def confirm(booking_id: UUID, user: CurrentUser, db: DbSession) -> BookingRead:
    """Водитель подтверждает заявку — пассажир получает запрос на оплату."""
    booking, trip = await booking_service.confirm(db, user, booking_id)
    return await booking_service.to_read(db, booking, trip, user)


@router.post("/{booking_id}/reject", response_model=BookingRead, responses=_errors)
async def reject(booking_id: UUID, user: CurrentUser, db: DbSession) -> BookingRead:
    booking, trip = await booking_service.reject(db, user, booking_id)
    return await booking_service.to_read(db, booking, trip, user)


@router.post("/{booking_id}/pay", response_model=BookingRead, responses=_errors)
async def pay(booking_id: UUID, user: CurrentUser, db: DbSession) -> BookingRead:
    """Оплата-заглушка: комиссия сервиса сразу считается оплаченной."""
    booking, trip = await booking_service.pay(db, user, booking_id)
    return await booking_service.to_read(db, booking, trip, user)


@router.get("/{booking_id}/cancel-preview", response_model=SanctionInfo, responses=_errors)
async def cancel_preview(booking_id: UUID, user: CurrentUser, db: DbSession) -> SanctionInfo:
    """Перед отменой: нарушает ли она правила сообщества и приведёт ли к блокировке."""
    return await booking_service.cancel_preview(db, user, booking_id)


@router.post("/{booking_id}/cancel", response_model=BookingCancelResult, responses=_errors)
async def cancel(booking_id: UUID, user: CurrentUser, db: DbSession) -> BookingCancelResult:
    """Отмена пассажиром. После регистрации (подтверждена/оплачена) — предупреждение,
    2 такие отмены за 30 дней блокируют аккаунт на 30 дней."""
    booking, trip, sanction = await booking_service.cancel(db, user, booking_id)
    return BookingCancelResult(
        booking=await booking_service.to_read(db, booking, trip, user), sanction=sanction
    )
