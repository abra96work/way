from datetime import UTC, date, datetime, time, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

from sqlalchemy import Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload

from app.core.config import get_settings
from app.core.errors import AppError, ConflictError, ForbiddenError, NotFoundError
from app.core.security import as_utc, utcnow
from app.models.booking import ACTIVE_BOOKING_STATUSES, Booking, BookingStatus, CancelledBy
from app.models.car import Car, CarModel
from app.models.city import City
from app.models.feedback import ParticipantRole
from app.models.trip import (
    Trip,
    TripExtra,
    TripParcelPrice,
    TripSegmentPrice,
    TripStatus,
    TripStop,
)
from app.models.user import FacePhotoStatus, User
from app.schemas.city import CityRead
from app.schemas.feedback import SanctionInfo
from app.schemas.search import SegmentQuote
from app.schemas.trip import (
    PARCEL_LIMITS,
    ExtraIn,
    ExtraRead,
    LimitUsage,
    ParcelPriceIn,
    ParcelPriceRead,
    PriceRead,
    PublishLimits,
    ReverseTripCreate,
    SegmentPriceIn,
    SegmentPriceRead,
    StopIn,
    StopRead,
    TripCreate,
    TripListFilter,
    TripRead,
    TripRequests,
    TripStatusView,
    TripWrite,
)
from app.services import sanctions
from app.services.availability import (
    active_bookings_count,
    free_seats,
    seat_bookings,
    segment_occupancy,
)
from app.services.cars import to_read as car_to_read
from app.services.media import media_url
from app.services.notifications import NotificationType, notify
from app.services.pricing import route_price, with_commission
from app.services.rating import driver_stats
from app.services.users import to_rated

# ---------- loading ----------


def with_details(query: Select) -> Select:
    return query.options(
        joinedload(Trip.driver),
        joinedload(Trip.car).joinedload(Car.model).joinedload(CarModel.brand),
        selectinload(Trip.stops),
        selectinload(Trip.segment_prices),
        selectinload(Trip.extras),
        selectinload(Trip.parcel_prices),
    ).execution_options(populate_existing=True)


async def load_trip(db: AsyncSession, trip_id: UUID) -> Trip | None:
    return await db.scalar(with_details(select(Trip).where(Trip.id == trip_id)))


async def get_visible_trip(db: AsyncSession, user: User, trip_id: UUID) -> Trip:
    """Published trips are visible to everyone; drafts and cancelled ones only to the driver."""
    trip = await load_trip(db, trip_id)
    if trip is None or (trip.driver_id != user.id and trip.status != TripStatus.published):
        raise NotFoundError("Поездка не найдена")
    return trip


async def get_own_trip(db: AsyncSession, driver: User, trip_id: UUID) -> Trip:
    trip = await load_trip(db, trip_id)
    if trip is None or trip.driver_id != driver.id:
        raise NotFoundError("Поездка не найдена")
    return trip


# ---------- status ----------


def finish_threshold(now: datetime) -> datetime:
    return now - timedelta(hours=get_settings().trip_complete_after_hours)


def segment_driver_price(trip: Trip, from_position: int, to_position: int) -> int:
    """Driver's price for one seat between two stops of the trip."""
    return route_price(
        from_position,
        to_position,
        stops_count=len(trip.stops),
        full_price=trip.full_price,
        min_price=trip.min_price,
        pair_prices={(p.from_position, p.to_position): p.price for p in trip.segment_prices},
    )


async def quote(db: AsyncSession, trip: Trip, from_position: int, to_position: int) -> SegmentQuote:
    if not 0 <= from_position < to_position < len(trip.stops):
        raise AppError("Неверные остановки посадки и высадки", code="invalid_segment")
    free = await segment_free_seats(db, trip, from_position, to_position)
    return SegmentQuote(
        from_position=from_position,
        to_position=to_position,
        price=price_read(segment_driver_price(trip, from_position, to_position)),
        seats_available=free,
    )


def is_finished(trip: Trip, now: datetime | None = None) -> bool:
    return as_utc(trip.departure_at) <= finish_threshold(now or utcnow())


def effective_status(trip: Trip, now: datetime | None = None) -> TripStatusView:
    if trip.status == TripStatus.published and is_finished(trip, now):
        return TripStatusView.completed
    return TripStatusView(trip.status.value)


async def count_active_bookings(db: AsyncSession, trip: Trip) -> int:
    """Pending, awaiting payment and paid bookings (seats and parcels)."""
    return await active_bookings_count(db, trip.id)


async def _occupancy(db: AsyncSession, trip: Trip) -> list[int]:
    bookings = (await seat_bookings(db, [trip.id]))[trip.id]
    return segment_occupancy(len(trip.stops), bookings)


async def booked_seats(db: AsyncSession, trip: Trip) -> int:
    """The most seats taken on any segment: the floor for `seats_total`."""
    return max(await _occupancy(db, trip), default=0)


async def segment_free_seats(db: AsyncSession, trip: Trip, start: int, end: int) -> int:
    return free_seats(trip.seats_total, await _occupancy(db, trip), start, end)


async def _ensure_editable(db: AsyncSession, trip: Trip) -> None:
    if trip.status == TripStatus.cancelled:
        raise ConflictError("Поездка отменена", code="trip_cancelled")
    if effective_status(trip) == TripStatusView.completed:
        raise ConflictError("Поездка уже завершена", code="trip_completed")
    if await count_active_bookings(db, trip):
        raise ConflictError(
            "Поездку нельзя изменить: к ней уже присоединились пассажиры", code="trip_has_bookings"
        )


# ---------- serialization ----------


def price_read(driver_price: int) -> PriceRead:
    price = with_commission(driver_price)
    return PriceRead(
        driver_price=price.driver, commission=price.commission, passenger_price=price.passenger
    )


def stop_read(stop: TripStop) -> StopRead:
    return StopRead(
        position=stop.position,
        city=CityRead.model_validate(stop.city),
        address=stop.address,
        lat=stop.lat,
        lng=stop.lng,
    )


async def to_read(db: AsyncSession, trip: Trip) -> TripRead:
    seats_taken = await booked_seats(db, trip)
    editable = trip.status != TripStatus.cancelled and not is_finished(trip)
    if editable:
        editable = not await count_active_bookings(db, trip)
    stats = (await driver_stats(db, [trip.driver_id]))[trip.driver_id]
    return TripRead(
        id=trip.id,
        number=trip.number,
        status=effective_status(trip),
        driver=to_rated(trip.driver, stats),
        car=car_to_read(trip.car),
        vehicle_type=trip.car.vehicle_type,
        departure_at=as_utc(trip.departure_at),
        arrival_at=as_utc(trip.arrival_at) if trip.arrival_at else None,
        seats_total=trip.seats_total,
        seats_available=max(trip.seats_total - seats_taken, 0),
        booking_mode=trip.booking_mode,
        stops=[stop_read(stop) for stop in trip.stops],
        full_price=price_read(trip.full_price),
        min_price=price_read(trip.min_price),
        segment_prices=[
            SegmentPriceRead(
                from_position=sp.from_position,
                to_position=sp.to_position,
                price=price_read(sp.price),
            )
            for sp in sorted(trip.segment_prices, key=lambda s: (s.from_position, s.to_position))
        ],
        extras=[
            ExtraRead(kind=extra.kind, price=price_read(extra.price))
            for extra in sorted(trip.extras, key=lambda e: e.kind.value)
        ],
        parcel_prices=[
            ParcelPriceRead(
                size=parcel.size,
                max_dimensions_cm=PARCEL_LIMITS[parcel.size][0],
                max_weight_kg=PARCEL_LIMITS[parcel.size][1],
                price=price_read(parcel.price),
            )
            for parcel in sorted(
                trip.parcel_prices, key=lambda p: list(PARCEL_LIMITS).index(p.size)
            )
        ],
        return_of_trip_id=trip.return_of_trip_id,
        is_editable=editable,
        created_at=as_utc(trip.created_at),
        published_at=as_utc(trip.published_at) if trip.published_at else None,
    )


async def requests_summary(db: AsyncSession, trip: Trip) -> TripRequests:
    """Active bookings of the trip and the first passengers' avatars."""
    bookings = list(
        await db.scalars(
            select(Booking)
            .where(Booking.trip_id == trip.id, Booking.status.in_(ACTIVE_BOOKING_STATUSES))
            .options(joinedload(Booking.passenger))
            .order_by(Booking.created_at)
        )
    )
    avatars: list[str] = []
    for booking in bookings:
        url = media_url(booking.passenger.avatar_path)
        if url and url not in avatars:
            avatars.append(url)
    return TripRequests(count=len(bookings), avatars=avatars[:2])


# ---------- validation ----------


async def _get_driver_car(db: AsyncSession, driver: User, car_id: UUID) -> Car:
    car = await db.get(Car, car_id)
    if car is None or car.owner_id != driver.id or car.deleted_at is not None:
        raise AppError("Автомобиль не найден в «Мои автомобили»", code="car_not_found")
    return car


async def _check_payload(db: AsyncSession, driver: User, payload: TripWrite) -> Car:
    settings = get_settings()
    if len(payload.stops) > settings.trip_max_stops:
        raise AppError(
            f"Не больше {settings.trip_max_stops} пунктов маршрута", code="too_many_stops"
        )
    car = await _get_driver_car(db, driver, payload.car_id)
    if payload.seats_total > car.seats:
        raise AppError(
            f"В этом автомобиле только {car.seats} пассажирских мест", code="seats_exceed_car"
        )
    city_ids = {stop.city_id for stop in payload.stops}
    active = set(
        await db.scalars(select(City.id).where(City.id.in_(city_ids), City.is_active.is_(True)))
    )
    if active != city_ids:
        raise AppError("Один из городов маршрута недоступен", code="city_not_available")
    return car


def _days_word(n: int) -> str:
    """Russian plural of «день»: 1 день, 3 дня, 7 дней."""
    if n % 10 == 1 and n % 100 != 11:
        return "день"
    if 2 <= n % 10 <= 4 and not 12 <= n % 100 <= 14:
        return "дня"
    return "дней"


def local_today() -> date:
    return _local_date(utcnow())


def _local_date(moment: datetime) -> date:
    return moment.astimezone(ZoneInfo(get_settings().local_timezone)).date()


def _local_day_bounds(moment: datetime) -> tuple[datetime, datetime]:
    zone = ZoneInfo(get_settings().local_timezone)
    day = _local_date(moment)
    start = datetime.combine(day, time.min, tzinfo=zone)
    return start.astimezone(UTC), (start + timedelta(days=1)).astimezone(UTC)


def _local_week_bounds(moment: datetime) -> tuple[datetime, datetime]:
    """Monday 00:00 to next Monday 00:00 of the local calendar week, in UTC."""
    zone = ZoneInfo(get_settings().local_timezone)
    day = _local_date(moment)
    start = datetime.combine(day - timedelta(days=day.weekday()), time.min, tzinfo=zone)
    return start.astimezone(UTC), (start + timedelta(days=7)).astimezone(UTC)


async def _count_published(
    db: AsyncSession, driver: User, start: datetime, end: datetime, exclude: UUID | None = None
) -> int:
    query = select(func.count(Trip.id)).where(
        Trip.driver_id == driver.id,
        Trip.status == TripStatus.published,
        Trip.departure_at >= start,
        Trip.departure_at < end,
    )
    if exclude is not None:
        query = query.where(Trip.id != exclude)
    return await db.scalar(query) or 0


async def publish_limits(db: AsyncSession, driver: User, day: date) -> PublishLimits:
    """How much of the daily and weekly publishing limits is used for [day]."""
    zone = ZoneInfo(get_settings().local_timezone)
    moment = datetime.combine(day, time(12), tzinfo=zone)
    day_start, day_end = _local_day_bounds(moment)
    week_start, week_end = _local_week_bounds(moment)
    monday = _local_date(week_start)
    return PublishLimits(
        date=day,
        day=LimitUsage(used=await _count_published(db, driver, day_start, day_end), limit=2),
        week=LimitUsage(
            used=await _count_published(db, driver, week_start, week_end),
            limit=get_settings().trip_week_limit,
        ),
        week_start=monday,
        week_end=monday + timedelta(days=6),
    )


def _endpoints(trip: Trip) -> tuple[int, int]:
    return trip.stops[0].city_id, trip.stops[-1].city_id


async def _check_publishable(db: AsyncSession, driver: User, trip: Trip) -> None:
    settings = get_settings()
    now = utcnow()
    if driver.blocked_until and as_utc(driver.blocked_until) > now:
        raise ForbiddenError(
            "Аккаунт временно заблокирован за нарушение правил сообщества", code="user_blocked"
        )
    if not driver.first_name:
        raise AppError("Заполните имя в профиле", code="profile_incomplete")
    if (
        settings.require_driver_face_approval
        and driver.face_photo_status != FacePhotoStatus.approved
    ):
        raise ForbiddenError(
            "Фото водителя ещё не подтверждено администратором", code="face_photo_not_approved"
        )

    departure = as_utc(trip.departure_at)
    if departure <= now:
        raise AppError("Время отправления уже прошло", code="departure_in_past")
    days = settings.trip_publish_days_ahead
    if departure > now + timedelta(days=days):
        raise AppError(
            f"Публиковать поездки можно не дальше чем на {days} {_days_word(days)} вперёд",
            code="departure_too_far",
        )

    # Limit: one trip a day plus one trip back in the opposite direction.
    day_start, day_end = _local_day_bounds(departure)
    same_day = list(
        await db.scalars(
            select(Trip)
            .where(
                Trip.driver_id == driver.id,
                Trip.id != trip.id,
                Trip.status == TripStatus.published,
                Trip.departure_at >= day_start,
                Trip.departure_at < day_end,
            )
            .options(selectinload(Trip.stops))
        )
    )
    origin, destination = _endpoints(trip)
    reverse_ok = len(same_day) == 1 and _endpoints(same_day[0]) == (destination, origin)
    if same_day and not reverse_ok:
        # Only a trip and its reverse can share a day, so a second one is "back".
        raise ConflictError(
            "В сутки можно опубликовать одну поездку и одну в обратном направлении",
            code="daily_trip_limit",
            details={
                "date": _local_date(departure).isoformat(),
                "published": len(same_day),
                "there": {"used": 1, "limit": 1},
                "back": {"used": 1 if len(same_day) > 1 else 0, "limit": 1},
            },
        )

    week_start, week_end = _local_week_bounds(departure)
    week_limit = settings.trip_week_limit
    used = await _count_published(db, driver, week_start, week_end, exclude=trip.id)
    if used >= week_limit:
        raise ConflictError(
            f"За неделю можно опубликовать не больше {week_limit} поездок",
            code="weekly_trip_limit",
            details={"used": used, "limit": week_limit},
        )


# ---------- mutations ----------


def _apply(trip: Trip, payload: TripWrite) -> None:
    trip.car_id = payload.car_id
    trip.departure_at = payload.departure_at
    trip.arrival_at = payload.arrival_at
    trip.seats_total = payload.seats_total
    trip.booking_mode = payload.booking_mode
    trip.full_price = payload.full_price
    trip.min_price = payload.min_price
    trip.stops = [
        TripStop(position=i, city_id=s.city_id, address=s.address.strip(), lat=s.lat, lng=s.lng)
        for i, s in enumerate(payload.stops)
    ]
    trip.segment_prices = [
        TripSegmentPrice(from_position=p.from_position, to_position=p.to_position, price=p.price)
        for p in payload.segment_prices
    ]
    trip.extras = [TripExtra(kind=e.kind, price=e.price) for e in payload.extras]
    trip.parcel_prices = [
        TripParcelPrice(size=p.size, price=p.price) for p in payload.parcel_prices
    ]


async def _publish(db: AsyncSession, driver: User, trip: Trip) -> None:
    await db.flush()
    await _check_publishable(db, driver, trip)
    trip.status = TripStatus.published
    trip.published_at = trip.published_at or utcnow()


async def create_trip(
    db: AsyncSession, driver: User, payload: TripCreate, *, return_of: UUID | None = None
) -> Trip:
    await _check_payload(db, driver, payload)
    trip = Trip(driver_id=driver.id, status=TripStatus.draft, return_of_trip_id=return_of)
    trip.number = (await db.scalar(select(func.max(Trip.number))) or 1000) + 1
    _apply(trip, payload)
    db.add(trip)
    if payload.publish:
        await _publish(db, driver, trip)
    await db.commit()
    return await get_own_trip(db, driver, trip.id)


async def replace_trip(db: AsyncSession, driver: User, trip_id: UUID, payload: TripWrite) -> Trip:
    trip = await get_own_trip(db, driver, trip_id)
    await _ensure_editable(db, trip)
    await _check_payload(db, driver, payload)
    # Drop old child rows in a separate flush so new (trip, position) rows don't clash.
    trip.stops, trip.segment_prices, trip.extras, trip.parcel_prices = [], [], [], []
    await db.flush()
    _apply(trip, payload)
    if trip.status == TripStatus.published:
        await _publish(db, driver, trip)
    await db.commit()
    return await get_own_trip(db, driver, trip.id)


async def update_seats(db: AsyncSession, driver: User, trip_id: UUID, seats_total: int) -> Trip:
    """Free seats can be changed even after passengers joined."""
    trip = await get_own_trip(db, driver, trip_id)
    if effective_status(trip) in (TripStatusView.cancelled, TripStatusView.completed):
        raise ConflictError("Поездка уже неактивна", code="trip_inactive")
    if seats_total > trip.car.seats:
        raise AppError(
            f"В этом автомобиле только {trip.car.seats} пассажирских мест", code="seats_exceed_car"
        )
    taken = await booked_seats(db, trip)
    if seats_total < taken:
        raise ConflictError(f"Уже забронировано {taken} мест", code="seats_below_booked")
    trip.seats_total = seats_total
    await db.commit()
    return await get_own_trip(db, driver, trip.id)


async def publish_trip(db: AsyncSession, driver: User, trip_id: UUID) -> Trip:
    trip = await get_own_trip(db, driver, trip_id)
    if trip.status != TripStatus.draft:
        raise ConflictError("Опубликовать можно только черновик", code="trip_not_draft")
    await _get_driver_car(db, driver, trip.car_id)
    await _publish(db, driver, trip)
    await db.commit()
    return await get_own_trip(db, driver, trip.id)


async def _cancellable_trip(db: AsyncSession, driver: User, trip_id: UUID) -> Trip:
    trip = await get_own_trip(db, driver, trip_id)
    if effective_status(trip) != TripStatusView.published:
        raise ConflictError("Отменить можно только активную поездку", code="trip_not_active")
    return trip


async def cancel_preview(db: AsyncSession, driver: User, trip_id: UUID) -> SanctionInfo:
    trip = await _cancellable_trip(db, driver, trip_id)
    violation = await sanctions.trip_has_registered_passengers(db, trip.id)
    return await sanctions.preview(db, driver, is_violation=violation)


async def cancel_trip(db: AsyncSession, driver: User, trip_id: UUID) -> tuple[Trip, SanctionInfo]:
    """Cancel the trip and all its bookings; a violation if passengers were registered."""
    trip = await _cancellable_trip(db, driver, trip_id)
    if await sanctions.trip_has_registered_passengers(db, trip.id):
        sanction = await sanctions.record_violation(
            db, driver, ParticipantRole.driver, trip_id=trip.id
        )
    else:
        sanction = await sanctions.preview(db, driver, is_violation=False)
    now = utcnow()
    trip.status = TripStatus.cancelled
    trip.cancelled_at = now
    bookings = await db.scalars(
        select(Booking).where(
            Booking.trip_id == trip.id, Booking.status.in_(ACTIVE_BOOKING_STATUSES)
        )
    )
    for booking in bookings:
        booking.status = BookingStatus.cancelled
        booking.cancelled_by = CancelledBy.driver
        booking.cancelled_at = now
        notify(
            db,
            booking.passenger_id,
            NotificationType.trip_cancelled,
            "Поездка отменена",
            "Водитель отменил поездку, бронь аннулирована",
            trip_id=trip.id,
            booking_id=booking.id,
        )
    await db.commit()
    return await get_own_trip(db, driver, trip.id), sanction


async def delete_trip(db: AsyncSession, driver: User, trip_id: UUID) -> None:
    trip = await get_own_trip(db, driver, trip_id)
    if await count_active_bookings(db, trip):
        raise ConflictError(
            "Поездку с пассажирами нельзя удалить, только отменить", code="trip_has_bookings"
        )
    await db.delete(trip)
    await db.commit()


async def reverse_trip(
    db: AsyncSession, driver: User, trip_id: UUID, payload: ReverseTripCreate
) -> Trip:
    """Same trip in the opposite direction: stops and pair prices mirrored."""
    source = await get_own_trip(db, driver, trip_id)
    last = len(source.stops) - 1
    mirrored = TripCreate(
        car_id=source.car_id,
        departure_at=payload.departure_at,
        # Keep the same trip duration for the way back.
        arrival_at=payload.arrival_at
        or (
            payload.departure_at + (as_utc(source.arrival_at) - as_utc(source.departure_at))
            if source.arrival_at
            else None
        ),
        seats_total=source.seats_total,
        booking_mode=source.booking_mode,
        stops=[
            StopIn(city_id=s.city_id, address=s.address, lat=s.lat, lng=s.lng)
            for s in reversed(source.stops)
        ],
        full_price=source.full_price,
        min_price=source.min_price,
        segment_prices=[
            SegmentPriceIn(
                from_position=last - p.to_position,
                to_position=last - p.from_position,
                price=p.price,
            )
            for p in source.segment_prices
        ],
        extras=[ExtraIn(kind=e.kind, price=e.price) for e in source.extras],
        parcel_prices=[ParcelPriceIn(size=p.size, price=p.price) for p in source.parcel_prices],
        publish=payload.publish,
    )
    return await create_trip(db, driver, mirrored, return_of=source.id)


async def list_driver_trips(
    db: AsyncSession, driver: User, trip_filter: TripListFilter | None
) -> list[Trip]:
    threshold = finish_threshold(utcnow())
    query = select(Trip).where(Trip.driver_id == driver.id)
    match trip_filter:
        case TripListFilter.active:
            query = query.where(Trip.status == TripStatus.published, Trip.departure_at > threshold)
        case TripListFilter.completed:
            query = query.where(Trip.status == TripStatus.published, Trip.departure_at <= threshold)
        case TripListFilter.draft:
            query = query.where(Trip.status == TripStatus.draft)
        case TripListFilter.cancelled:
            query = query.where(Trip.status == TripStatus.cancelled)
    descending = trip_filter in (TripListFilter.completed, TripListFilter.cancelled)
    order = Trip.departure_at.desc() if descending else Trip.departure_at
    return list(await db.scalars(with_details(query.order_by(order))))


async def car_has_active_trips(db: AsyncSession, car_id: UUID, *, seats_above: int = 0) -> bool:
    """Published, unfinished trips of the car (optionally only those needing more seats)."""
    query = select(Trip.id).where(
        Trip.car_id == car_id,
        Trip.status == TripStatus.published,
        Trip.departure_at > finish_threshold(utcnow()),
        Trip.seats_total > seats_above,
    )
    return await db.scalar(query.limit(1)) is not None
