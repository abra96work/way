from fastapi import APIRouter

from app.api.routes import (
    auth,
    bookings,
    cars,
    cities,
    health,
    notifications,
    search,
    trips,
    users,
)

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(cities.router)
api_router.include_router(cars.router)
api_router.include_router(trips.router)
api_router.include_router(search.router)
api_router.include_router(bookings.router)
api_router.include_router(notifications.router)
