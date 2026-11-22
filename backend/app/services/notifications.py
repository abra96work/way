"""In-app notifications. The client polls them; push (FCM) can be added on top later."""

import enum
from uuid import UUID

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFoundError
from app.core.security import utcnow
from app.models.booking import Notification
from app.models.user import User


class NotificationType(enum.StrEnum):
    booking_requested = "booking_requested"  # driver: a passenger asks to join
    booking_created = "booking_created"  # driver: instant booking, passenger goes to pay
    booking_confirmed = "booking_confirmed"  # passenger: confirmed, please pay
    booking_rejected = "booking_rejected"  # passenger
    booking_paid = "booking_paid"  # driver
    booking_cancelled = "booking_cancelled"  # driver: passenger cancelled
    trip_cancelled = "trip_cancelled"  # passenger: driver cancelled the trip


def notify(
    db: AsyncSession,
    user_id: UUID,
    type_: NotificationType,
    title: str,
    body: str,
    *,
    trip_id: UUID | None = None,
    booking_id: UUID | None = None,
) -> None:
    """Queue a notification in the current transaction; the caller commits."""
    payload = {
        key: str(value)
        for key, value in (("trip_id", trip_id), ("booking_id", booking_id))
        if value is not None
    }
    db.add(Notification(user_id=user_id, type=type_.value, title=title, body=body, payload=payload))


async def list_notifications(
    db: AsyncSession, user: User, *, unread_only: bool, limit: int, offset: int
) -> list[Notification]:
    query = select(Notification).where(Notification.user_id == user.id)
    if unread_only:
        query = query.where(Notification.read_at.is_(None))
    query = query.order_by(Notification.created_at.desc(), Notification.id).limit(limit)
    return list(await db.scalars(query.offset(offset)))


async def unread_count(db: AsyncSession, user: User) -> int:
    return (
        await db.scalar(
            select(func.count())
            .select_from(Notification)
            .where(Notification.user_id == user.id, Notification.read_at.is_(None))
        )
        or 0
    )


async def mark_read(db: AsyncSession, user: User, notification_id: UUID) -> Notification:
    item = await db.get(Notification, notification_id)
    if item is None or item.user_id != user.id:
        raise NotFoundError("Уведомление не найдено")
    if item.read_at is None:
        item.read_at = utcnow()
        await db.commit()
    return item


async def mark_all_read(db: AsyncSession, user: User) -> None:
    await db.execute(
        update(Notification)
        .where(Notification.user_id == user.id, Notification.read_at.is_(None))
        .values(read_at=utcnow())
    )
    await db.commit()
