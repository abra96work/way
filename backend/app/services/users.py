from fastapi import UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.core.security import as_utc
from app.models.city import City
from app.models.user import FacePhotoStatus, User
from app.schemas.city import CityRead
from app.schemas.user import MeRead, MeUpdate, PublicUser, RatedUser
from app.services.media import delete_media, media_url, save_image
from app.services.rating import DriverStats, driver_stats


def to_public(user: User) -> PublicUser:
    return PublicUser(
        id=user.id,
        first_name=user.first_name,
        last_name=user.last_name,
        avatar_url=media_url(user.avatar_path),
    )


def to_rated(user: User, stats: DriverStats) -> RatedUser:
    return RatedUser(
        **to_public(user).model_dump(),
        rating=stats.rating,
        reviews_count=stats.reviews_count,
        completed_trips=stats.completed_trips,
    )


def to_me(user: User, stats: DriverStats) -> MeRead:
    return MeRead(
        **to_rated(user, stats).model_dump(),
        cancellations_count=stats.cancellations,
        phone=user.phone,
        city=CityRead.model_validate(user.city) if user.city else None,
        face_photo_status=user.face_photo_status,
        is_profile_complete=user.is_profile_complete,
        blocked_until=as_utc(user.blocked_until) if user.blocked_until else None,
        created_at=as_utc(user.created_at),
    )


async def me_read(db: AsyncSession, user: User) -> MeRead:
    stats = (await driver_stats(db, [user.id]))[user.id]
    return to_me(user, stats)


async def update_profile(db: AsyncSession, user: User, payload: MeUpdate) -> User:
    data = payload.model_dump(exclude_unset=True)
    if "first_name" in data and data["first_name"] is None:
        raise AppError("Имя не может быть пустым", code="first_name_required")
    if "city_id" in data and data["city_id"] is not None:
        city = await db.get(City, data["city_id"])
        if city is None or not city.is_active:
            raise AppError("Город недоступен", code="city_not_available")
    for field, value in data.items():
        setattr(user, field, value)
    await db.commit()
    await db.refresh(user, attribute_names=["city"])
    return user


async def set_avatar(db: AsyncSession, user: User, upload: UploadFile) -> User:
    new_path = await save_image(upload, "avatars")
    old_path, user.avatar_path = user.avatar_path, new_path
    await db.commit()
    delete_media(old_path)
    return user


async def set_face_photo(db: AsyncSession, user: User, upload: UploadFile) -> User:
    """Driver's frontal face photo; goes to administrator review."""
    new_path = await save_image(upload, "faces")
    old_path, user.face_photo_path = user.face_photo_path, new_path
    user.face_photo_status = FacePhotoStatus.pending
    await db.commit()
    delete_media(old_path)
    return user
