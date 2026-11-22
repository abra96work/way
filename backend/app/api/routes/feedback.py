from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Query, status

from app.api.deps import CurrentUser, DbSession
from app.core.config import get_settings
from app.core.errors import ErrorResponse, ForbiddenError, NotFoundError
from app.core.security import as_utc
from app.models.user import User
from app.schemas.feedback import ComplaintCreate, ComplaintRead, ReviewCreate, ReviewRead
from app.services import feedback as feedback_service
from app.services.users import to_public

router = APIRouter(tags=["reviews & complaints"])

_errors = {
    400: {"model": ErrorResponse},
    401: {"model": ErrorResponse},
    403: {"model": ErrorResponse},
    404: {"model": ErrorResponse},
    409: {"model": ErrorResponse},
}


@router.get("/users/{user_id}/reviews", response_model=list[ReviewRead], responses=_errors)
async def user_reviews(
    user_id: UUID,
    _: CurrentUser,
    db: DbSession,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[ReviewRead]:
    """Отзывы о пользователе. Пустой список — показывать «5 звёзд, нет отзывов»."""
    if await db.get(User, user_id) is None:
        raise NotFoundError("Пользователь не найден")
    return await feedback_service.list_reviews(db, user_id, limit=limit, offset=offset)


@router.post(
    "/reviews", response_model=ReviewRead, status_code=status.HTTP_201_CREATED, responses=_errors
)
async def create_review(payload: ReviewCreate, user: CurrentUser, db: DbSession) -> ReviewRead:
    """Оставить отзыв участнику завершённой поездки.

    В тестовой сборке выключено (`PUT_REVIEWS_ENABLED=false`): по ТЗ функционала
    оставления отзывов нет, но модель данных и логика заложены полностью.
    """
    if not get_settings().reviews_enabled:
        raise ForbiddenError("Отзывы пока недоступны", code="reviews_disabled")
    review = await feedback_service.create_review(db, user, payload)
    return ReviewRead(
        id=review.id,
        trip_id=review.trip_id,
        author=to_public(user),
        target_role=review.target_role,
        rating=review.rating,
        text=review.text,
        created_at=as_utc(review.created_at),
    )


@router.post(
    "/complaints",
    response_model=ComplaintRead,
    status_code=status.HTTP_201_CREATED,
    responses=_errors,
)
async def create_complaint(
    payload: ComplaintCreate, user: CurrentUser, db: DbSession
) -> ComplaintRead:
    """Пожаловаться на водителя или пассажира своей поездки."""
    complaint = await feedback_service.create_complaint(db, user, payload)
    return feedback_service.complaint_read(complaint)


@router.get("/me/complaints", response_model=list[ComplaintRead], responses=_errors)
async def my_complaints(user: CurrentUser, db: DbSession) -> list[ComplaintRead]:
    """Жалобы, которые получил пользователь (раздел профиля). Автор не раскрывается."""
    return [
        feedback_service.complaint_read(c)
        for c in await feedback_service.received_complaints(db, user)
    ]
