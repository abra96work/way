"""Driver rating.

Two numbers are shown/used:
* `rating` — stars from reviews; without reviews it is 5.0 with `reviews_count = 0`
  ("5 звёзд, нет отзывов"). Reviews arrive in stage 6.
* `priority` — ranking score for search: more finished trips and fewer cancellations
  rank higher (profile rules: "чем больше поездок и чем меньше отмен, тем выше рейтинг").
"""

from collections.abc import Iterable
from dataclasses import dataclass
from uuid import UUID

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import utcnow
from app.models.trip import Trip, TripStatus

CANCELLATION_WEIGHT = 3
NO_REVIEWS_RATING = 5.0


@dataclass(frozen=True)
class DriverStats:
    rating: float = NO_REVIEWS_RATING
    reviews_count: int = 0
    completed_trips: int = 0
    cancelled_trips: int = 0

    @property
    def priority(self) -> int:
        return self.completed_trips - CANCELLATION_WEIGHT * self.cancelled_trips


async def driver_stats(db: AsyncSession, driver_ids: Iterable[UUID]) -> dict[UUID, DriverStats]:
    from app.services.trips import finish_threshold  # trips imports this module

    ids = set(driver_ids)
    if not ids:
        return {}
    finished = (Trip.status == TripStatus.published) & (
        Trip.departure_at <= finish_threshold(utcnow())
    )
    rows = await db.execute(
        select(
            Trip.driver_id,
            func.sum(case((finished, 1), else_=0)),
            func.sum(case((Trip.status == TripStatus.cancelled, 1), else_=0)),
        )
        .where(Trip.driver_id.in_(ids))
        .group_by(Trip.driver_id)
    )
    # TODO(stage 6): rating/reviews_count from reviews; cancellations from the cancellations log.
    stats = {driver_id: DriverStats() for driver_id in ids}
    for driver_id, completed, cancelled in rows:
        stats[driver_id] = DriverStats(
            completed_trips=int(completed or 0), cancelled_trips=int(cancelled or 0)
        )
    return stats
