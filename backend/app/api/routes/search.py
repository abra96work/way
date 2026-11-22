from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, DbSession
from app.core.errors import ErrorResponse
from app.schemas.search import SearchParams, SearchResult
from app.services.search import search_trips

router = APIRouter(prefix="/search", tags=["search"])


@router.get(
    "/trips",
    response_model=SearchResult,
    responses={401: {"model": ErrorResponse}, 422: {"model": ErrorResponse}},
)
async def search(
    params: Annotated[SearchParams, Query()], user: CurrentUser, db: DbSession
) -> SearchResult:
    """Поиск поездок для пассажира.

    Пункты можно задать id города (`from_city_id`/`to_city_id`), названием
    (`from_query`/`to_query`) или геопозицией (`lat`, `lng`, `radius_km`) — «поблизости».
    Пассажир может сесть и выйти на промежуточных остановках; цена в карточке — за его отрезок.
    Сортировка: приоритет водителя (больше поездок, меньше отмен), затем ближайшее время.
    """
    return await search_trips(db, user, params)
