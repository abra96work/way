from uuid import UUID

from fastapi import UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.core.errors import AppError, ConflictError, NotFoundError
from app.core.security import as_utc, utcnow
from app.models.car import Car, CarBrand, CarModel, VehicleType
from app.models.user import User
from app.schemas.car import MAX_SEATS, CarBrandRead, CarCreate, CarModelRead, CarRead, CarUpdate
from app.services.media import delete_media, media_url, save_image


def to_read(car: Car) -> CarRead:
    return CarRead(
        id=car.id,
        brand=CarBrandRead.model_validate(car.model.brand),
        model=CarModelRead.model_validate(car.model),
        vehicle_type=car.vehicle_type,
        seats=car.seats,
        plate=car.plate,
        photo_url=media_url(car.photo_path),
        has_sts=car.sts_photo_path is not None,
        created_at=as_utc(car.created_at),
    )


async def list_brands(db: AsyncSession) -> list[CarBrand]:
    return list(await db.scalars(select(CarBrand).order_by(CarBrand.name)))


async def list_models(db: AsyncSession, brand_id: int) -> list[CarModel]:
    if await db.get(CarBrand, brand_id) is None:
        raise NotFoundError("Марка не найдена")
    return list(
        await db.scalars(
            select(CarModel).where(CarModel.brand_id == brand_id).order_by(CarModel.name)
        )
    )


async def list_cars(db: AsyncSession, owner: User) -> list[Car]:
    return list(
        await db.scalars(
            select(Car)
            .where(Car.owner_id == owner.id, Car.deleted_at.is_(None))
            .options(joinedload(Car.model).joinedload(CarModel.brand))
            .order_by(Car.created_at)
        )
    )


async def get_own_car(db: AsyncSession, owner: User, car_id: UUID) -> Car:
    car = await db.scalar(
        select(Car)
        .where(Car.id == car_id)
        .options(joinedload(Car.model).joinedload(CarModel.brand))
        # Reload relationships even if the car is already in the session (after updates).
        .execution_options(populate_existing=True)
    )
    # Someone else's car looks exactly like a missing one.
    if car is None or car.owner_id != owner.id or car.deleted_at is not None:
        raise NotFoundError("Автомобиль не найден")
    return car


async def _get_model(db: AsyncSession, model_id: int) -> CarModel:
    model = await db.get(CarModel, model_id)
    if model is None:
        raise AppError("Модель не найдена в справочнике", code="car_model_not_found")
    return model


async def _has_active_trips(db: AsyncSession, car_id: UUID, *, seats_above: int = 0) -> bool:
    from app.services.trips import car_has_active_trips  # trips imports this module

    return await car_has_active_trips(db, car_id, seats_above=seats_above)


def _check_seats(vehicle_type: VehicleType, seats: int) -> None:
    limit = MAX_SEATS[vehicle_type]
    if seats > limit:
        kind = "легкового автомобиля" if vehicle_type is VehicleType.car else "автобуса"
        raise AppError(
            f"Для {kind} не больше {limit} пассажирских мест", code="too_many_seats"
        )


async def create_car(db: AsyncSession, owner: User, payload: CarCreate) -> Car:
    await _get_model(db, payload.model_id)
    _check_seats(payload.vehicle_type, payload.seats)
    car = Car(owner_id=owner.id, **payload.model_dump())
    db.add(car)
    await db.commit()
    return await get_own_car(db, owner, car.id)


async def update_car(db: AsyncSession, owner: User, car_id: UUID, payload: CarUpdate) -> Car:
    car = await get_own_car(db, owner, car_id)
    data = payload.model_dump(exclude_unset=True)
    for required in ("model_id", "vehicle_type", "seats"):
        if required in data and data[required] is None:
            raise AppError("Поле не может быть пустым", code=f"{required}_required")
    if "model_id" in data:
        await _get_model(db, data["model_id"])
    _check_seats(data.get("vehicle_type", car.vehicle_type), data.get("seats", car.seats))
    if "seats" in data and await _has_active_trips(db, car.id, seats_above=data["seats"]):
        raise ConflictError(
            "В активных поездках на этом автомобиле указано больше мест",
            code="car_seats_used_by_trips",
        )
    for field, value in data.items():
        setattr(car, field, value)
    await db.commit()
    return await get_own_car(db, owner, car_id)


async def delete_car(db: AsyncSession, owner: User, car_id: UUID) -> None:
    car = await get_own_car(db, owner, car_id)
    if await _has_active_trips(db, car.id):
        raise ConflictError(
            "Автомобиль используется в активной поездке", code="car_used_by_trips"
        )
    car.deleted_at = utcnow()
    await db.commit()


async def set_sts_photo(
    db: AsyncSession, owner: User, car_id: UUID, upload: UploadFile
) -> Car:
    car = await get_own_car(db, owner, car_id)
    new_path = await save_image(upload, "sts")
    old_path, car.sts_photo_path = car.sts_photo_path, new_path
    await db.commit()
    delete_media(old_path)
    return car


async def set_photo(db: AsyncSession, owner: User, car_id: UUID, upload: UploadFile) -> Car:
    car = await get_own_car(db, owner, car_id)
    new_path = await save_image(upload, "cars")
    old_path, car.photo_path = car.photo_path, new_path
    await db.commit()
    delete_media(old_path)
    return car
