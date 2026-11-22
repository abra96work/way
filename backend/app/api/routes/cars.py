from uuid import UUID

from fastapi import APIRouter, Query, status

from app.api.deps import CurrentUser, DbSession, ImageFile
from app.core.errors import ErrorResponse
from app.core.text import filter_by_name
from app.models.car import CarBrand, CarModel
from app.schemas.car import CarBrandRead, CarCreate, CarModelRead, CarRead, CarUpdate
from app.services import cars as car_service

router = APIRouter(prefix="/cars", tags=["cars"])

_errors = {
    400: {"model": ErrorResponse},
    401: {"model": ErrorResponse},
    404: {"model": ErrorResponse},
    413: {"model": ErrorResponse},
    415: {"model": ErrorResponse},
}


@router.get("/brands", response_model=list[CarBrandRead])
async def list_brands(
    db: DbSession,
    query: str | None = Query(default=None, max_length=60, description="Поиск по названию"),
) -> list[CarBrand]:
    """Справочник марок для выбора «Марка»."""
    return filter_by_name(await car_service.list_brands(db), query, lambda brand: brand.name)


@router.get("/brands/{brand_id}/models", response_model=list[CarModelRead], responses=_errors)
async def list_models(
    brand_id: int,
    db: DbSession,
    query: str | None = Query(default=None, max_length=60),
) -> list[CarModel]:
    """Модели выбранной марки для выбора «Модель»."""
    models = await car_service.list_models(db, brand_id)
    return filter_by_name(models, query, lambda model: model.name)


@router.get("", response_model=list[CarRead], responses=_errors)
async def list_my_cars(user: CurrentUser, db: DbSession) -> list[CarRead]:
    """«Мои автомобили» текущего водителя."""
    return [car_service.to_read(car) for car in await car_service.list_cars(db, user)]


@router.post("", response_model=CarRead, status_code=status.HTTP_201_CREATED, responses=_errors)
async def create_car(payload: CarCreate, user: CurrentUser, db: DbSession) -> CarRead:
    """Добавить ТС. Фото загружается отдельно: `PUT /cars/{id}/photo`."""
    return car_service.to_read(await car_service.create_car(db, user, payload))


@router.get("/{car_id}", response_model=CarRead, responses=_errors)
async def get_car(car_id: UUID, user: CurrentUser, db: DbSession) -> CarRead:
    return car_service.to_read(await car_service.get_own_car(db, user, car_id))


@router.patch("/{car_id}", response_model=CarRead, responses=_errors)
async def update_car(
    car_id: UUID, payload: CarUpdate, user: CurrentUser, db: DbSession
) -> CarRead:
    return car_service.to_read(await car_service.update_car(db, user, car_id, payload))


@router.delete("/{car_id}", status_code=status.HTTP_204_NO_CONTENT, responses=_errors)
async def delete_car(car_id: UUID, user: CurrentUser, db: DbSession) -> None:
    await car_service.delete_car(db, user, car_id)


@router.put("/{car_id}/photo", response_model=CarRead, responses=_errors)
async def upload_car_photo(
    car_id: UUID, user: CurrentUser, db: DbSession, file: ImageFile
) -> CarRead:
    """Фото автомобиля: JPEG/PNG/WebP до 5 МБ."""
    return car_service.to_read(await car_service.set_photo(db, user, car_id, file))
