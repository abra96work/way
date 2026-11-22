from uuid import UUID

from fastapi import APIRouter

from app.api.deps import CurrentUser, DbSession, ImageFile
from app.core.errors import ErrorResponse, NotFoundError
from app.models.user import User
from app.schemas.user import MeRead, MeUpdate, RatedUser
from app.services import users as user_service
from app.services.rating import driver_stats

router = APIRouter(tags=["users"])

_errors = {
    400: {"model": ErrorResponse},
    401: {"model": ErrorResponse},
    413: {"model": ErrorResponse},
    404: {"model": ErrorResponse},
    415: {"model": ErrorResponse},
}


@router.get("/me", response_model=MeRead, responses=_errors)
async def get_me(user: CurrentUser, db: DbSession) -> MeRead:
    return await user_service.me_read(db, user)


@router.patch("/me", response_model=MeRead, responses=_errors)
async def update_me(payload: MeUpdate, user: CurrentUser, db: DbSession) -> MeRead:
    """Заполнить или изменить имя, фамилию и город."""
    user = await user_service.update_profile(db, user, payload)
    return await user_service.me_read(db, user)


@router.put("/me/avatar", response_model=MeRead, responses=_errors)
async def upload_avatar(user: CurrentUser, db: DbSession, file: ImageFile) -> MeRead:
    """Аватар: JPEG/PNG/WebP до 5 МБ. `avatar_url` относителен хосту API."""
    user = await user_service.set_avatar(db, user, file)
    return await user_service.me_read(db, user)


@router.put("/me/face-photo", response_model=MeRead, responses=_errors)
async def upload_face_photo(user: CurrentUser, db: DbSession, file: ImageFile) -> MeRead:
    """Фото лица водителя в анфас; уходит на проверку администратору."""
    user = await user_service.set_face_photo(db, user, file)
    return await user_service.me_read(db, user)


@router.get("/users/{user_id}", response_model=RatedUser, responses=_errors)
async def get_user(user_id: UUID, _: CurrentUser, db: DbSession) -> RatedUser:
    """Публичный профиль: имя, фото, рейтинг (без телефона)."""
    other = await db.get(User, user_id)
    if other is None:
        raise NotFoundError("Пользователь не найден")
    stats = (await driver_stats(db, [other.id]))[other.id]
    return user_service.to_rated(other, stats)
