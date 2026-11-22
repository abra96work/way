import os
import tempfile
from collections.abc import AsyncIterator
from pathlib import Path

# Configure an isolated database and media dir before the app is imported.
_TMP = Path(tempfile.mkdtemp(prefix="put-tests-"))
os.environ["PUT_DATABASE_URL"] = f"sqlite+aiosqlite:///{(_TMP / 'test.db').as_posix()}"
os.environ["PUT_MEDIA_DIR"] = str(_TMP / "media")
os.environ["PUT_ENVIRONMENT"] = "test"

import pytest  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402

import app.models  # noqa: E402, F401
from app.data.car_catalog import CAR_CATALOG  # noqa: E402
from app.data.cities import CITIES, REGION  # noqa: E402
from app.db.base import Base  # noqa: E402
from app.db.session import SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.models.car import CarBrand, CarModel  # noqa: E402
from app.models.city import City  # noqa: E402

TEST_CODE = "111111"


@pytest.fixture(autouse=True)
async def _database() -> AsyncIterator[None]:
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.drop_all)
        await connection.run_sync(Base.metadata.create_all)
    async with SessionLocal() as session:
        session.add_all(
            City(name=name, region=REGION, lat=lat, lng=lng) for name, lat, lng in CITIES
        )
        for brand_name, model_names in CAR_CATALOG.items():
            brand = CarBrand(name=brand_name)
            session.add(brand)
            await session.flush()
            session.add_all(CarModel(brand_id=brand.id, name=name) for name in model_names)
        await session.commit()
    yield
    # Each test has its own event loop; don't keep pooled connections across loops.
    await engine.dispose()


@pytest.fixture
async def client() -> AsyncIterator[AsyncClient]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as http:
        yield http


async def login(client: AsyncClient, phone: str = "+79001234567") -> dict:
    response = await client.post("/api/v1/auth/request-code", json={"phone": phone})
    assert response.status_code == 200, response.text
    response = await client.post("/api/v1/auth/verify", json={"phone": phone, "code": TEST_CODE})
    assert response.status_code == 200, response.text
    return response.json()


@pytest.fixture
async def auth(client: AsyncClient) -> dict:
    """Logged-in user: tokens, user payload and ready Authorization header."""
    data = await login(client)
    data["headers"] = {"Authorization": f"Bearer {data['access_token']}"}
    return data
