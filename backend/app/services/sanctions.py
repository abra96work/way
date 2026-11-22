"""Community-rules sanctions for cancellations.

A cancellation breaks the rules when someone was already registered for the ride:
the passenger cancels a confirmed (awaiting payment) or paid booking, or the driver
cancels a trip that has such bookings. The user gets a warning; the 2nd violation
within 30 days blocks the account for 30 days (visible to the admin via
`users.blocked_until` and the `cancellations` log).
"""

from datetime import timedelta
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.security import utcnow
from app.models.booking import Booking, BookingStatus
from app.models.feedback import Cancellation, ParticipantRole
from app.models.user import User
from app.schemas.feedback import SanctionInfo
from app.services.notifications import NotificationType, notify

REGISTERED_STATUSES = (BookingStatus.awaiting_payment, BookingStatus.paid)


def is_registered(booking: Booking) -> bool:
    return booking.status in REGISTERED_STATUSES


async def trip_has_registered_passengers(db: AsyncSession, trip_id: UUID) -> bool:
    found = await db.scalar(
        select(Booking.id)
        .where(Booking.trip_id == trip_id, Booking.status.in_(REGISTERED_STATUSES))
        .limit(1)
    )
    return found is not None


async def _recent_violations(db: AsyncSession, user_id: UUID) -> int:
    since = utcnow() - timedelta(days=get_settings().cancellation_window_days)
    count = await db.scalar(
        select(func.count())
        .select_from(Cancellation)
        .where(Cancellation.user_id == user_id, Cancellation.created_at >= since)
    )
    return count or 0


def _warning() -> str:
    s = get_settings()
    return (
        "Отмена после регистрации пассажира нарушает правила сообщества. "
        f"При {s.cancellations_to_block} таких отменах за {s.cancellation_window_days} дней "
        f"аккаунт блокируется на {s.block_duration_days} дней."
    )


async def preview(db: AsyncSession, user: User, *, is_violation: bool) -> SanctionInfo:
    """What would happen if the user cancelled now (for the confirmation dialog)."""
    recent = await _recent_violations(db, user.id)
    if not is_violation:
        return SanctionInfo(is_violation=False, violations_last_period=recent)
    return SanctionInfo(
        is_violation=True,
        warning=_warning(),
        violations_last_period=recent,
        blocks_account=recent + 1 >= get_settings().cancellations_to_block,
    )


async def record_violation(
    db: AsyncSession,
    user: User,
    role: ParticipantRole,
    *,
    trip_id: UUID,
    booking_id: UUID | None = None,
) -> SanctionInfo:
    """Log a rule-breaking cancellation and block the user if it is one too many.

    Runs in the caller's transaction; the caller commits.
    """
    settings = get_settings()
    entry = Cancellation(user_id=user.id, role=role, trip_id=trip_id, booking_id=booking_id)
    db.add(entry)
    await db.flush()
    recent = await _recent_violations(db, user.id)
    blocked_until = None
    if recent >= settings.cancellations_to_block:
        blocked_until = utcnow() + timedelta(days=settings.block_duration_days)
        user.blocked_until = blocked_until
        entry.blocked_until = blocked_until
        notify(
            db,
            user.id,
            NotificationType.account_blocked,
            "Аккаунт заблокирован",
            f"Из-за {recent} отмен за {settings.cancellation_window_days} дней аккаунт "
            f"заблокирован на {settings.block_duration_days} дней",
            trip_id=trip_id,
            booking_id=booking_id,
        )
    return SanctionInfo(
        is_violation=True,
        warning=_warning(),
        violations_last_period=recent,
        blocks_account=blocked_until is not None,
        blocked_until=blocked_until,
    )
