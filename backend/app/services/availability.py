"""Seats per route segment.

Segment k is the stretch between stop k and stop k+1. A passenger riding from stop i to
stop j occupies segments i..j-1, so the same seat can be sold A→B and then B→C.
"""

from collections.abc import Iterable
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.booking import ACTIVE_BOOKING_STATUSES, Booking, BookingKind


def segment_occupancy(stops_count: int, bookings: Iterable[tuple[int, int, int]]) -> list[int]:
    """Taken seats on each segment. `bookings` are (from_position, to_position, seats)."""
    occupancy = [0] * max(stops_count - 1, 0)
    for start, end, seats in bookings:
        for segment in range(start, end):
            occupancy[segment] += seats
    return occupancy


def free_seats(seats_total: int, occupancy: list[int], start: int, end: int) -> int:
    taken = max(occupancy[start:end], default=0)
    return max(seats_total - taken, 0)


async def seat_bookings(
    db: AsyncSession, trip_ids: Iterable[UUID]
) -> dict[UUID, list[tuple[int, int, int]]]:
    """Active seat bookings per trip as (from_position, to_position, seats)."""
    ids = set(trip_ids)
    result: dict[UUID, list[tuple[int, int, int]]] = {trip_id: [] for trip_id in ids}
    if not ids:
        return result
    rows = await db.execute(
        select(Booking.trip_id, Booking.from_position, Booking.to_position, Booking.seats).where(
            Booking.trip_id.in_(ids),
            Booking.kind == BookingKind.seat,
            Booking.status.in_(ACTIVE_BOOKING_STATUSES),
        )
    )
    for trip_id, start, end, seats in rows:
        result[trip_id].append((start, end, seats))
    return result


async def active_bookings_count(db: AsyncSession, trip_id: UUID) -> int:
    return (
        await db.scalar(
            select(func.count())
            .select_from(Booking)
            .where(Booking.trip_id == trip_id, Booking.status.in_(ACTIVE_BOOKING_STATUSES))
        )
        or 0
    )
