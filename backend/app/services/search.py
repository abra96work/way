"""Passenger trip search.

A trip matches when the passenger can board at one of its stops and get off at a later
one. Candidates are narrowed in SQL (published, upcoming, date, vehicle type) and the
route/geo matching happens in Python: trips of the coming three days are few.
"""

import math
from collections import defaultdict
from dataclasses import dataclass
from datetime import UTC, datetime, time, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.security import as_utc, utcnow
from app.core.text import fold
from app.models.car import Car
from app.models.city import City
from app.models.trip import Trip, TripStatus, TripStop
from app.models.user import User
from app.schemas.city import CityRead
from app.schemas.search import CarBrief, SearchParams, SearchResult, SearchResultItem
from app.schemas.trip import StopRead
from app.services import trips as trip_service
from app.services.media import media_url
from app.services.rating import DriverStats, driver_stats
from app.services.users import to_rated

EARTH_RADIUS_KM = 6371.0


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi, d_lambda = math.radians(lat2 - lat1), math.radians(lng2 - lng1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(a))


def _stop_coords(stop: TripStop) -> tuple[float, float]:
    if stop.lat is not None and stop.lng is not None:
        return stop.lat, stop.lng
    return stop.city.lat, stop.city.lng


@dataclass
class _Match:
    trip: Trip
    board: int
    alight: int
    distance_km: float | None
    seats_available: int
    stats: DriverStats
    is_open: bool = False


async def _city_ids(db: AsyncSession, city_id: int | None, query: str | None) -> set[int] | None:
    """None means "any city"; an empty set means nothing can match."""
    if city_id is not None:
        return {city_id}
    if query and query.strip():
        needle = fold(query.strip())
        cities = await db.scalars(select(City).where(City.is_active.is_(True)))
        return {c.id for c in cities if needle in fold(c.name)}
    return None


def _match_route(
    trip: Trip,
    from_ids: set[int] | None,
    to_ids: set[int] | None,
    geo: tuple[float, float, float] | None,
) -> tuple[int, int, float | None] | None:
    stops = trip.stops
    last = len(stops) - 1
    for board in range(last):
        stop = stops[board]
        if from_ids is not None and stop.city_id not in from_ids:
            continue
        distance = None
        if geo is not None:
            lat, lng, radius = geo
            distance = haversine_km(lat, lng, *_stop_coords(stop))
            if distance > radius:
                continue
        if to_ids is None:
            return board, last, distance
        for alight in range(board + 1, last + 1):
            if stops[alight].city_id in to_ids:
                return board, alight, distance
    return None


def _mark_open_queues(matches: list[_Match]) -> None:
    """Same route at the same time: only the top-priority car that still has seats is open."""
    groups: dict[tuple, list[_Match]] = defaultdict(list)
    for m in matches:
        stops = m.trip.stops
        key = (stops[0].city_id, stops[-1].city_id, as_utc(m.trip.departure_at))
        groups[key].append(m)
    for group in groups.values():
        group.sort(
            key=lambda m: (-m.stats.priority, as_utc(m.trip.published_at or m.trip.created_at))
        )
        for m in group:
            if m.seats_available > 0:
                m.is_open = True
                break


def _stop_read(stop: TripStop) -> StopRead:
    return StopRead(
        position=stop.position,
        city=CityRead.model_validate(stop.city),
        address=stop.address,
        lat=stop.lat,
        lng=stop.lng,
    )


def _to_item(m: _Match) -> SearchResultItem:
    trip = m.trip
    return SearchResultItem(
        trip_id=trip.id,
        departure_at=as_utc(trip.departure_at),
        vehicle_type=trip.car.vehicle_type,
        booking_mode=trip.booking_mode,
        driver=to_rated(trip.driver, m.stats),
        car=CarBrief(
            brand=trip.car.model.brand.name,
            model=trip.car.model.name,
            photo_url=media_url(trip.car.photo_path),
            plate=trip.car.plate,
        ),
        origin=_stop_read(trip.stops[0]),
        destination=_stop_read(trip.stops[-1]),
        board=_stop_read(trip.stops[m.board]),
        alight=_stop_read(trip.stops[m.alight]),
        stops_count=len(trip.stops),
        distance_km=round(m.distance_km, 1) if m.distance_km is not None else None,
        price=trip_service.price_read(trip_service.segment_driver_price(trip, m.board, m.alight)),
        seats_available=m.seats_available,
        extras=sorted((e.kind for e in trip.extras), key=lambda k: k.value),
        accepts_parcels=bool(trip.parcel_prices),
        is_registration_open=m.is_open,
    )


async def search_trips(db: AsyncSession, passenger: User, params: SearchParams) -> SearchResult:
    now = utcnow()
    query = (
        select(Trip)
        .join(Car, Car.id == Trip.car_id)
        .where(
            Trip.status == TripStatus.published,
            Trip.departure_at > now,
            Trip.driver_id != passenger.id,
        )
    )
    if params.vehicle_type is not None:
        query = query.where(Car.vehicle_type == params.vehicle_type)
    if params.date is not None:
        zone = ZoneInfo(get_settings().local_timezone)
        start = datetime.combine(params.date, time.min, tzinfo=zone).astimezone(UTC)
        query = query.where(
            Trip.departure_at >= start, Trip.departure_at < start + timedelta(days=1)
        )
    trips = list(await db.scalars(trip_service.with_details(query)))

    from_ids = await _city_ids(db, params.from_city_id, params.from_query)
    to_ids = await _city_ids(db, params.to_city_id, params.to_query)
    geo = (
        (params.lat, params.lng, params.radius_km)
        if params.lat is not None and params.lng is not None
        else None
    )
    stats = await driver_stats(db, {t.driver_id for t in trips})

    matches: list[_Match] = []
    for trip in trips:
        route = _match_route(trip, from_ids, to_ids, geo)
        if route is None:
            continue
        board, alight, distance = route
        # TODO(stage 5): free seats on the board→alight segment.
        free = trip.seats_total - await trip_service.booked_seats(db, trip)
        if free < params.seats:
            continue
        matches.append(_Match(trip, board, alight, distance, free, stats[trip.driver_id]))

    # Ranking: driver priority first, then the nearest departure (and the nearest stop).
    _mark_open_queues(matches)
    matches.sort(
        key=lambda m: (
            -m.stats.priority,
            as_utc(m.trip.departure_at),
            m.distance_km if m.distance_km is not None else 0.0,
        )
    )
    page = matches[params.offset : params.offset + params.limit]
    return SearchResult(items=[_to_item(m) for m in page], total=len(matches))
