"""User rating.

Two numbers are shown/used:
* `rating` — average stars of visible reviews about the user, one decimal. Without
  reviews it is 5.0 with `reviews_count = 0`, i.e. "5 звёзд, нет отзывов" (ТЗ).
* `priority` — search ranking score from the profile rule "чем больше поездок и чем
  меньше отмен, тем выше рейтинг": finished trips (as driver or passenger) minus
  rule-breaking cancellations from the `cancellations` log, weighted.
"""

from collections.abc import Iterable
from dataclasses import dataclass
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import utcnow
from app.models.booking import Booking, BookingStatus
from app.models.feedback import Cancellation, Review
from app.models.trip import Trip, TripStatus

CANCELLATION_WEIGHT = 3
NO_REVIEWS_RATING = 5.0


@dataclass(frozen=True)
class DriverStats:
    rating: float = NO_REVIEWS_RATING
    reviews_count: int = 0
    completed_trips: int = 0
    cancellations: int = 0

    @property
    def priority(self) -> int:
        return self.completed_trips - CANCELLATION_WEIGHT * self.cancellations


async def driver_stats(db: AsyncSession, user_ids: Iterable[UUID]) -> dict[UUID, DriverStats]:
    """Rating numbers for each user (works for drivers and passengers alike)."""
    from app.services.trips import finish_threshold  # trips imports this module

    ids = set(user_ids)
    if not ids:
        return {}
    finished_before = finish_threshold(utcnow())

    reviews = {
        user_id: (float(avg), int(count))
        for user_id, avg, count in await db.execute(
            select(Review.target_id, func.avg(Review.rating), func.count())
            .where(Review.target_id.in_(ids), Review.is_hidden.is_(False))
            .group_by(Review.target_id)
        )
    }
    as_driver = dict(
        (
            await db.execute(
                select(Trip.driver_id, func.count())
                .where(
                    Trip.driver_id.in_(ids),
                    Trip.status == TripStatus.published,
                    Trip.departure_at <= finished_before,
                )
                .group_by(Trip.driver_id)
            )
        ).all()
    )
    as_passenger = dict(
        (
            await db.execute(
                select(Booking.passenger_id, func.count(func.distinct(Booking.trip_id)))
                .join(Trip, Trip.id == Booking.trip_id)
                .where(
                    Booking.passenger_id.in_(ids),
                    Booking.status == BookingStatus.paid,
                    Trip.departure_at <= finished_before,
                )
                .group_by(Booking.passenger_id)
            )
        ).all()
    )
    cancellations = dict(
        (
            await db.execute(
                select(Cancellation.user_id, func.count())
                .where(Cancellation.user_id.in_(ids))
                .group_by(Cancellation.user_id)
            )
        ).all()
    )

    stats: dict[UUID, DriverStats] = {}
    for user_id in ids:
        avg, count = reviews.get(user_id, (NO_REVIEWS_RATING, 0))
        stats[user_id] = DriverStats(
            rating=round(avg, 1) if count else NO_REVIEWS_RATING,
            reviews_count=count,
            completed_trips=as_driver.get(user_id, 0) + as_passenger.get(user_id, 0),
            cancellations=cancellations.get(user_id, 0),
        )
    return stats
