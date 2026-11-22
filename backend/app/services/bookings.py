"""Booking flow.

manual mode:  pending --driver confirms--> awaiting_payment --passenger pays--> paid
              pending --driver rejects--> rejected
instant mode: awaiting_payment --pays--> paid
any active state --passenger cancels--> cancelled; the driver cancelling the trip cancels
all active bookings. Pending bookings already hold their seats.
"""

from dataclasses import dataclass
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload

from app.core.errors import AppError, ConflictError, ForbiddenError, NotFoundError
from app.core.security import as_utc, utcnow
from app.models.booking import (
    ACTIVE_BOOKING_STATUSES,
    Booking,
    BookingExtra,
    BookingKind,
    BookingStatus,
    CancelledBy,
    Payment,
)
from app.models.trip import BookingMode, ExtraKind, Trip, TripStatus
from app.models.user import User
from app.schemas.booking import (
    BookingListFilter,
    BookingQuote,
    BookingRead,
    BookingRequest,
    BookingStatusView,
    BookingTrip,
    PaymentInfo,
)
from app.schemas.search import CarBrief
from app.schemas.trip import ExtraRead
from app.services import trips as trip_service
from app.services.media import media_url
from app.services.notifications import NotificationType, notify
from app.services.pricing import commission_for
from app.services.rating import driver_stats
from app.services.search import is_registration_open
from app.services.users import to_rated

# ---------- pricing ----------


@dataclass
class _Priced:
    driver_price: int
    commission: int
    seat_price: int | None
    extras: list[tuple[ExtraKind, int]]


def _price(trip: Trip, request: BookingRequest) -> _Priced:
    last = len(trip.stops) - 1
    if request.to_position > last:
        raise AppError("Неверные остановки посадки и высадки", code="invalid_segment")
    if request.kind == BookingKind.parcel:
        offered = {p.size: p.price for p in trip.parcel_prices}
        if request.parcel_size not in offered:
            raise AppError(
                "Водитель не принимает посылки такого размера", code="parcel_not_accepted"
            )
        driver_price = offered[request.parcel_size]
        return _Priced(driver_price, commission_for(driver_price), None, [])

    seat_price = trip_service.segment_driver_price(trip, request.from_position, request.to_position)
    offered_extras = {e.kind: e.price for e in trip.extras}
    missing = [kind for kind in request.extras if kind not in offered_extras]
    if missing:
        raise AppError("Водитель не предлагает эту доп. услугу", code="extra_not_offered")
    extras = [(kind, offered_extras[kind]) for kind in sorted(request.extras)]
    driver_price = seat_price * request.seats + sum(price for _, price in extras)
    return _Priced(driver_price, commission_for(driver_price), seat_price, extras)


async def quote(db: AsyncSession, passenger: User, request: BookingRequest) -> BookingQuote:
    trip = await trip_service.get_visible_trip(db, passenger, request.trip_id)
    priced = _price(trip, request)
    free = await trip_service.segment_free_seats(
        db, trip, request.from_position, request.to_position
    )
    return BookingQuote(
        price=trip_service.price_read(priced.driver_price),
        seat_price=trip_service.price_read(priced.seat_price)
        if priced.seat_price is not None
        else None,
        extras=[ExtraRead(kind=k, price=trip_service.price_read(p)) for k, p in priced.extras],
        seats_available=free,
        is_registration_open=await is_registration_open(
            db, trip, request.from_position, request.to_position
        ),
    )


# ---------- loading & serialization ----------


async def _load(db: AsyncSession, booking_id: UUID) -> Booking | None:
    return await db.scalar(
        select(Booking)
        .where(Booking.id == booking_id)
        .options(selectinload(Booking.extras), joinedload(Booking.passenger))
        .execution_options(populate_existing=True)
    )


def _effective_status(booking: Booking, trip: Trip) -> BookingStatusView:
    if booking.status == BookingStatus.paid and trip_service.is_finished(trip):
        return BookingStatusView.completed
    return BookingStatusView(booking.status.value)


def _departed(trip: Trip) -> bool:
    return as_utc(trip.departure_at) <= utcnow()


async def to_read(
    db: AsyncSession, booking: Booking, trip: Trip, viewer: User | None = None
) -> BookingRead:
    stats = await driver_stats(db, {trip.driver_id, booking.passenger_id})
    status = _effective_status(booking, trip)
    active = booking.status in ACTIVE_BOOKING_STATUSES
    is_passenger = viewer is None or viewer.id == booking.passenger_id
    stops = trip.stops
    return BookingRead(
        id=booking.id,
        status=status,
        kind=booking.kind,
        trip=BookingTrip(
            id=trip.id,
            status=trip_service.effective_status(trip),
            departure_at=as_utc(trip.departure_at),
            booking_mode=trip.booking_mode,
            vehicle_type=trip.car.vehicle_type,
            origin=trip_service.stop_read(stops[0]),
            destination=trip_service.stop_read(stops[-1]),
            driver=to_rated(trip.driver, stats[trip.driver_id]),
            car=CarBrief(
                brand=trip.car.model.brand.name,
                model=trip.car.model.name,
                photo_url=media_url(trip.car.photo_path),
                plate=trip.car.plate,
            ),
        ),
        passenger=to_rated(booking.passenger, stats[booking.passenger_id]),
        board=trip_service.stop_read(stops[booking.from_position]),
        alight=trip_service.stop_read(stops[booking.to_position]),
        seats=booking.seats,
        parcel_size=booking.parcel_size,
        extras=[
            ExtraRead(kind=e.kind, price=trip_service.price_read(e.price))
            for e in sorted(booking.extras, key=lambda e: e.kind.value)
        ],
        price=trip_service.price_read(booking.driver_price),
        payment=PaymentInfo(
            pay_online=booking.commission,
            pay_to_driver=booking.driver_price,
            is_paid=booking.paid_at is not None,
        ),
        can_pay=is_passenger and booking.status == BookingStatus.awaiting_payment,
        can_cancel=is_passenger and active and not _departed(trip),
        created_at=as_utc(booking.created_at),
        confirmed_at=as_utc(booking.confirmed_at) if booking.confirmed_at else None,
        paid_at=as_utc(booking.paid_at) if booking.paid_at else None,
        cancelled_at=as_utc(booking.cancelled_at) if booking.cancelled_at else None,
        cancelled_by=booking.cancelled_by,
    )


async def read_many(db: AsyncSession, bookings: list[Booking], viewer: User) -> list[BookingRead]:
    trip_ids = {b.trip_id for b in bookings}
    trips = {
        t.id: t
        for t in await db.scalars(
            trip_service.with_details(select(Trip).where(Trip.id.in_(trip_ids)))
        )
    }
    return [await to_read(db, b, trips[b.trip_id], viewer) for b in bookings]


async def get_for_user(db: AsyncSession, user: User, booking_id: UUID) -> tuple[Booking, Trip]:
    """The passenger and the trip's driver can see a booking."""
    booking = await _load(db, booking_id)
    trip = await trip_service.load_trip(db, booking.trip_id) if booking else None
    if booking is None or trip is None or user.id not in (booking.passenger_id, trip.driver_id):
        raise NotFoundError("Бронь не найдена")
    return booking, trip


# ---------- creating ----------


async def _lock_trip(db: AsyncSession, trip_id: UUID) -> None:
    """Serialize concurrent bookings of one trip (row lock on PostgreSQL)."""
    await db.execute(select(Trip.id).where(Trip.id == trip_id).with_for_update())


async def create_booking(db: AsyncSession, passenger: User, request: BookingRequest) -> Booking:
    await _lock_trip(db, request.trip_id)
    trip = await trip_service.load_trip(db, request.trip_id)
    if trip is None or trip.status == TripStatus.draft:
        raise NotFoundError("Поездка не найдена")
    if trip.status == TripStatus.cancelled:
        raise ConflictError("Поездка отменена", code="trip_cancelled")
    if _departed(trip):
        raise ConflictError("Поездка уже отправилась", code="trip_departed")
    if trip.driver_id == passenger.id:
        raise ForbiddenError("Нельзя забронировать свою поездку", code="own_trip")
    if passenger.blocked_until and as_utc(passenger.blocked_until) > utcnow():
        raise ForbiddenError(
            "Аккаунт временно заблокирован за нарушение правил сообщества", code="user_blocked"
        )
    if not passenger.first_name:
        raise AppError("Заполните имя в профиле", code="profile_incomplete")

    priced = _price(trip, request)
    duplicate = await db.scalar(
        select(Booking.id).where(
            Booking.trip_id == trip.id,
            Booking.passenger_id == passenger.id,
            Booking.kind == request.kind,
            Booking.status.in_(ACTIVE_BOOKING_STATUSES),
        )
    )
    if duplicate:
        raise ConflictError("У вас уже есть бронь в этой поездке", code="already_booked")

    seats = 0
    if request.kind == BookingKind.seat:
        seats = request.seats
        if not await is_registration_open(db, trip, request.from_position, request.to_position):
            raise ConflictError(
                "Регистрация на эту машину откроется после заполнения предыдущей",
                code="registration_closed",
            )
        free = await trip_service.segment_free_seats(
            db, trip, request.from_position, request.to_position
        )
        if free < seats:
            raise ConflictError(f"Свободных мест на этом участке: {free}", code="not_enough_seats")

    instant = trip.booking_mode == BookingMode.instant
    booking = Booking(
        trip_id=trip.id,
        passenger_id=passenger.id,
        kind=request.kind,
        status=BookingStatus.awaiting_payment if instant else BookingStatus.pending,
        from_position=request.from_position,
        to_position=request.to_position,
        seats=seats,
        parcel_size=request.parcel_size,
        driver_price=priced.driver_price,
        commission=priced.commission,
        extras=[BookingExtra(kind=kind, price=price) for kind, price in priced.extras],
    )
    db.add(booking)
    await db.flush()
    what = "посылку" if request.kind == BookingKind.parcel else f"мест: {seats}"
    if instant:
        notify(
            db,
            trip.driver_id,
            NotificationType.booking_created,
            "Новое бронирование",
            f"{passenger.first_name} забронировал(а) {what}, ожидается оплата",
            trip_id=trip.id,
            booking_id=booking.id,
        )
    else:
        notify(
            db,
            trip.driver_id,
            NotificationType.booking_requested,
            "Заявка на поездку",
            f"{passenger.first_name} хочет присоединиться ({what}). Подтвердите или отклоните",
            trip_id=trip.id,
            booking_id=booking.id,
        )
    await db.commit()
    return await _load(db, booking.id)


# ---------- transitions ----------


async def _driver_booking(db: AsyncSession, driver: User, booking_id: UUID) -> tuple[Booking, Trip]:
    booking, trip = await get_for_user(db, driver, booking_id)
    if trip.driver_id != driver.id:
        raise ForbiddenError("Это может сделать только водитель", code="not_trip_driver")
    if booking.status != BookingStatus.pending:
        raise ConflictError("Заявка уже обработана", code="booking_not_pending")
    return booking, trip


async def confirm(db: AsyncSession, driver: User, booking_id: UUID) -> tuple[Booking, Trip]:
    booking, trip = await _driver_booking(db, driver, booking_id)
    booking.status = BookingStatus.awaiting_payment
    booking.confirmed_at = utcnow()
    notify(
        db,
        booking.passenger_id,
        NotificationType.booking_confirmed,
        "Бронь подтверждена",
        f"Водитель подтвердил бронь. Оплатите бронирование: {booking.commission} ₽",
        trip_id=trip.id,
        booking_id=booking.id,
    )
    await db.commit()
    return booking, trip


async def reject(db: AsyncSession, driver: User, booking_id: UUID) -> tuple[Booking, Trip]:
    booking, trip = await _driver_booking(db, driver, booking_id)
    booking.status = BookingStatus.rejected
    booking.cancelled_at = utcnow()
    notify(
        db,
        booking.passenger_id,
        NotificationType.booking_rejected,
        "Бронь отклонена",
        "Водитель отклонил заявку на поездку",
        trip_id=trip.id,
        booking_id=booking.id,
    )
    await db.commit()
    return booking, trip


async def pay(db: AsyncSession, passenger: User, booking_id: UUID) -> tuple[Booking, Trip]:
    """Mock payment: the commission is "charged" instantly, no provider involved."""
    booking, trip = await get_for_user(db, passenger, booking_id)
    if booking.passenger_id != passenger.id:
        raise ForbiddenError("Оплатить может только пассажир", code="not_booking_passenger")
    if booking.status != BookingStatus.awaiting_payment:
        raise ConflictError("Бронь сейчас нельзя оплатить", code="booking_not_payable")
    if trip.status != TripStatus.published or _departed(trip):
        raise ConflictError("Поездка уже недоступна", code="trip_inactive")
    now = utcnow()
    db.add(Payment(booking_id=booking.id, amount=booking.commission, provider="mock"))
    booking.status = BookingStatus.paid
    booking.paid_at = now
    notify(
        db,
        trip.driver_id,
        NotificationType.booking_paid,
        "Бронь оплачена",
        f"{passenger.first_name} оплатил(а) бронирование. К оплате вам: {booking.driver_price} ₽",
        trip_id=trip.id,
        booking_id=booking.id,
    )
    await db.commit()
    return booking, trip


async def cancel(db: AsyncSession, passenger: User, booking_id: UUID) -> tuple[Booking, Trip]:
    booking, trip = await get_for_user(db, passenger, booking_id)
    if booking.passenger_id != passenger.id:
        raise ForbiddenError("Отменить бронь может только пассажир", code="not_booking_passenger")
    if booking.status not in ACTIVE_BOOKING_STATUSES:
        raise ConflictError("Бронь уже неактивна", code="booking_inactive")
    if _departed(trip):
        raise ConflictError("Поездка уже отправилась", code="trip_departed")
    # TODO(stage 6): warn about community rules and count toward the 2-in-30-days block.
    booking.status = BookingStatus.cancelled
    booking.cancelled_by = CancelledBy.passenger
    booking.cancelled_at = utcnow()
    notify(
        db,
        trip.driver_id,
        NotificationType.booking_cancelled,
        "Бронь отменена",
        f"{passenger.first_name} отменил(а) бронь",
        trip_id=trip.id,
        booking_id=booking.id,
    )
    await db.commit()
    return booking, trip


# ---------- lists ----------


async def list_passenger_bookings(
    db: AsyncSession, passenger: User, booking_filter: BookingListFilter | None
) -> list[Booking]:
    query = (
        select(Booking)
        .join(Trip, Trip.id == Booking.trip_id)
        .where(Booking.passenger_id == passenger.id)
        .options(selectinload(Booking.extras), joinedload(Booking.passenger))
    )
    threshold = trip_service.finish_threshold(utcnow())
    match booking_filter:
        case BookingListFilter.active:
            query = query.where(
                Booking.status.in_(ACTIVE_BOOKING_STATUSES), Trip.departure_at > threshold
            )
        case BookingListFilter.completed:
            query = query.where(
                Booking.status == BookingStatus.paid, Trip.departure_at <= threshold
            )
        case BookingListFilter.cancelled:
            query = query.where(
                Booking.status.in_((BookingStatus.cancelled, BookingStatus.rejected))
            )
    newest_first = booking_filter in (BookingListFilter.completed, BookingListFilter.cancelled)
    order = Trip.departure_at.desc() if newest_first else Trip.departure_at
    return list(await db.scalars(query.order_by(order, Booking.created_at)))


async def list_trip_bookings(
    db: AsyncSession, driver: User, trip_id: UUID, *, active_only: bool
) -> list[Booking]:
    """Requests and passengers of the driver's trip."""
    await trip_service.get_own_trip(db, driver, trip_id)
    query = (
        select(Booking)
        .where(Booking.trip_id == trip_id)
        .options(selectinload(Booking.extras), joinedload(Booking.passenger))
        .order_by(Booking.created_at)
    )
    if active_only:
        query = query.where(Booking.status.in_(ACTIVE_BOOKING_STATUSES))
    return list(await db.scalars(query))
