from fastapi import APIRouter, Query
from sqlalchemy import select

from app.api.deps import DbSession
from app.core.errors import ErrorResponse, NotFoundError
from app.core.text import filter_by_name
from app.models.city import City
from app.schemas.city import CityRead

router = APIRouter(prefix="/cities", tags=["cities"])


@router.get("", response_model=list[CityRead])
async def list_cities(
    db: DbSession,
    query: str | None = Query(default=None, max_length=60, description="Поиск по названию"),
) -> list[City]:
    """Доступные населённые пункты (публичный список, авторизация не нужна)."""
    cities = list(
        await db.scalars(select(City).where(City.is_active.is_(True)).order_by(City.name))
    )
    return filter_by_name(cities, query, lambda city: city.name)


@router.get("/{city_id}", response_model=CityRead, responses={404: {"model": ErrorResponse}})
async def get_city(city_id: int, db: DbSession) -> City:
    city = await db.get(City, city_id)
    if city is None or not city.is_active:
        raise NotFoundError("Город не найден")
    return city
