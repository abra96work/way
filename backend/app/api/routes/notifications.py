from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Query, status

from app.api.deps import CurrentUser, DbSession
from app.core.errors import ErrorResponse
from app.core.security import as_utc
from app.models.booking import Notification
from app.schemas.booking import NotificationRead, UnreadCount
from app.services import notifications as notification_service

router = APIRouter(prefix="/notifications", tags=["notifications"])


def _read(item: Notification) -> NotificationRead:
    payload = item.payload or {}
    return NotificationRead(
        id=item.id,
        type=item.type,
        title=item.title,
        body=item.body,
        trip_id=payload.get("trip_id"),
        booking_id=payload.get("booking_id"),
        is_read=item.read_at is not None,
        created_at=as_utc(item.created_at),
    )


@router.get("", response_model=list[NotificationRead], responses={401: {"model": ErrorResponse}})
async def list_notifications(
    user: CurrentUser,
    db: DbSession,
    unread_only: bool = False,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[NotificationRead]:
    """Уведомления пользователя, новые сверху. Клиент опрашивает этот список."""
    items = await notification_service.list_notifications(
        db, user, unread_only=unread_only, limit=limit, offset=offset
    )
    return [_read(item) for item in items]


@router.get("/unread-count", response_model=UnreadCount)
async def unread_count(user: CurrentUser, db: DbSession) -> UnreadCount:
    """Для бейджа на иконке."""
    return UnreadCount(unread=await notification_service.unread_count(db, user))


@router.post("/{notification_id}/read", response_model=NotificationRead)
async def mark_read(notification_id: UUID, user: CurrentUser, db: DbSession) -> NotificationRead:
    return _read(await notification_service.mark_read(db, user, notification_id))


@router.post("/read-all", status_code=status.HTTP_204_NO_CONTENT)
async def mark_all_read(user: CurrentUser, db: DbSession) -> None:
    await notification_service.mark_all_read(db, user)
