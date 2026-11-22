import pytest
from httpx import AsyncClient

from app.schemas.car import normalize_plate
from tests.conftest import login
from tests.test_users import PNG_1PX


async def _model_id(client: AsyncClient, brand: str = "Toyota", model: str = "Camry") -> int:
    brands = (await client.get("/api/v1/cars/brands", params={"query": brand})).json()
    brand_id = next(b["id"] for b in brands if b["name"] == brand)
    models = (await client.get(f"/api/v1/cars/brands/{brand_id}/models")).json()
    return next(m["id"] for m in models if m["name"] == model)


async def _create_car(client: AsyncClient, headers: dict, **overrides) -> dict:
    payload = {"model_id": await _model_id(client), "seats": 4, "plate": "а 777 аа 66"}
    payload.update(overrides)
    response = await client.post("/api/v1/cars", headers=headers, json=payload)
    assert response.status_code == 201, response.text
    return response.json()


@pytest.mark.parametrize(
    ("raw", "expected"),
    [("а 777 аа 66", "А777АА66"), (" ", None), (None, None), ("x123ab", "X123AB")],
)
def test_normalize_plate(raw: str | None, expected: str | None) -> None:
    assert normalize_plate(raw) == expected


def test_normalize_plate_rejects_foreign_letters() -> None:
    with pytest.raises(ValueError):
        normalize_plate("Ж777ЖЖ66")


async def test_brand_search_and_models(client: AsyncClient) -> None:
    brands = (await client.get("/api/v1/cars/brands", params={"query": "газ"})).json()
    assert [b["name"] for b in brands] == ["ГАЗ"]

    models = (await client.get(f"/api/v1/cars/brands/{brands[0]['id']}/models")).json()
    assert "ГАЗель Next" in [m["name"] for m in models]


async def test_models_of_unknown_brand(client: AsyncClient) -> None:
    response = await client.get("/api/v1/cars/brands/9999/models")

    assert response.status_code == 404


async def test_create_and_list_car(client: AsyncClient, auth: dict) -> None:
    car = await _create_car(client, auth["headers"])

    assert car["brand"]["name"] == "Toyota"
    assert car["model"]["name"] == "Camry"
    assert car["vehicle_type"] == "car"
    assert car["plate"] == "А777АА66"
    assert car["photo_url"] is None

    listed = (await client.get("/api/v1/cars", headers=auth["headers"])).json()
    assert [c["id"] for c in listed] == [car["id"]]


async def test_cars_require_auth(client: AsyncClient) -> None:
    assert (await client.get("/api/v1/cars")).status_code == 401


async def test_seat_limits_depend_on_type(client: AsyncClient, auth: dict) -> None:
    model_id = await _model_id(client, "ПАЗ", "3205")

    too_many = await client.post(
        "/api/v1/cars", headers=auth["headers"], json={"model_id": model_id, "seats": 20}
    )
    assert too_many.status_code == 400
    assert too_many.json()["code"] == "too_many_seats"

    bus = await _create_car(
        client, auth["headers"], model_id=model_id, seats=20, vehicle_type="bus"
    )
    assert bus["seats"] == 20

    back_to_car = await client.patch(
        f"/api/v1/cars/{bus['id']}", headers=auth["headers"], json={"vehicle_type": "car"}
    )
    assert back_to_car.status_code == 400


async def test_unknown_model_rejected(client: AsyncClient, auth: dict) -> None:
    response = await client.post(
        "/api/v1/cars", headers=auth["headers"], json={"model_id": 99999, "seats": 3}
    )

    assert response.status_code == 400
    assert response.json()["code"] == "car_model_not_found"


async def test_update_car(client: AsyncClient, auth: dict) -> None:
    car = await _create_car(client, auth["headers"])
    new_model = await _model_id(client, "Infiniti", "Q30")

    response = await client.patch(
        f"/api/v1/cars/{car['id']}",
        headers=auth["headers"],
        json={"model_id": new_model, "seats": 6, "plate": None},
    )

    assert response.status_code == 200
    body = response.json()
    assert (body["brand"]["name"], body["model"]["name"]) == ("Infiniti", "Q30")
    assert body["seats"] == 6
    assert body["plate"] is None


async def test_other_users_car_is_hidden(client: AsyncClient, auth: dict) -> None:
    car = await _create_car(client, auth["headers"])
    other = await login(client, phone="+79007654321")
    headers = {"Authorization": f"Bearer {other['access_token']}"}

    assert (await client.get(f"/api/v1/cars/{car['id']}", headers=headers)).status_code == 404
    patch = await client.patch(f"/api/v1/cars/{car['id']}", headers=headers, json={"seats": 2})
    assert patch.status_code == 404
    assert (await client.delete(f"/api/v1/cars/{car['id']}", headers=headers)).status_code == 404
    assert (await client.get("/api/v1/cars", headers=headers)).json() == []


async def test_delete_car_hides_it(client: AsyncClient, auth: dict) -> None:
    car = await _create_car(client, auth["headers"])

    response = await client.delete(f"/api/v1/cars/{car['id']}", headers=auth["headers"])

    assert response.status_code == 204
    assert (await client.get("/api/v1/cars", headers=auth["headers"])).json() == []
    gone = await client.get(f"/api/v1/cars/{car['id']}", headers=auth["headers"])
    assert gone.status_code == 404


async def test_car_photo(client: AsyncClient, auth: dict) -> None:
    car = await _create_car(client, auth["headers"])

    response = await client.put(
        f"/api/v1/cars/{car['id']}/photo",
        headers=auth["headers"],
        files={"file": ("car.png", PNG_1PX, "image/png")},
    )

    assert response.status_code == 200
    photo_url = response.json()["photo_url"]
    assert photo_url.startswith("/media/cars/")
    assert (await client.get(photo_url)).status_code == 200
