from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest
from httpx import AsyncClient

from tests.conftest import login
from tests.test_cars import _create_car

LOCAL = ZoneInfo("Asia/Yekaterinburg")


def slot(days: int = 1, hour: int = 9, minute: int = 0) -> str:
    """A departure time in the local zone, `days` from today, as ISO string."""
    day = datetime.now(LOCAL).date() + timedelta(days=days)
    return datetime(day.year, day.month, day.day, hour, minute, tzinfo=LOCAL).isoformat()


async def _cities(client: AsyncClient) -> dict[str, int]:
    return {c["name"]: c["id"] for c in (await client.get("/api/v1/cities")).json()}


@pytest.fixture
async def driver(client: AsyncClient, auth: dict) -> dict:
    """Logged-in driver with a filled profile and a 4-seat car."""
    await client.patch("/api/v1/me", headers=auth["headers"], json={"first_name": "Виктор"})
    auth["car"] = await _create_car(client, auth["headers"])
    auth["cities"] = await _cities(client)
    return auth


def trip_payload(driver: dict, **overrides) -> dict:
    c = driver["cities"]
    payload = {
        "car_id": driver["car"]["id"],
        "departure_at": slot(),
        "seats_total": 3,
        "stops": [
            {"city_id": c["Екатеринбург"], "address": "ул. Победителей, 1"},
            {"city_id": c["Берёзовский"], "address": "ул. Комсомольская, 15"},
            {"city_id": c["Асбест"], "address": "Рынок"},
        ],
        "full_price": 1000,
        "min_price": 150,
        "segment_prices": [
            {"from_position": 0, "to_position": 1, "price": 400},
            {"from_position": 1, "to_position": 2, "price": 700},
        ],
        "extras": [{"kind": "child_seat", "price": 100}, {"kind": "luggage", "price": 50}],
        "parcel_prices": [{"size": "S", "price": 200}, {"size": "M", "price": 300}],
        "publish": True,
    }
    payload.update(overrides)
    return payload


async def _create(client: AsyncClient, driver: dict, **overrides) -> dict:
    response = await client.post(
        "/api/v1/trips", headers=driver["headers"], json=trip_payload(driver, **overrides)
    )
    assert response.status_code == 201, response.text
    return response.json()


async def test_create_published_trip(client: AsyncClient, driver: dict) -> None:
    trip = await _create(client, driver)

    assert trip["status"] == "published"
    assert trip["driver"]["first_name"] == "Виктор"
    assert trip["vehicle_type"] == "car"
    assert trip["seats_available"] == 3
    assert [s["position"] for s in trip["stops"]] == [0, 1, 2]
    assert trip["stops"][0]["city"]["name"] == "Екатеринбург"
    assert trip["full_price"] == {"driver_price": 1000, "commission": 100, "passenger_price": 1100}
    assert trip["min_price"]["passenger_price"] == 165
    assert [e["kind"] for e in trip["extras"]] == ["child_seat", "luggage"]
    assert trip["parcel_prices"][0]["max_weight_kg"] == 5
    assert trip["is_editable"] is True
    assert trip["departure_at"].endswith(("Z", "+00:00"))


async def test_draft_then_publish(client: AsyncClient, driver: dict) -> None:
    draft = await _create(client, driver, publish=False)
    assert draft["status"] == "draft"
    assert draft["published_at"] is None

    response = await client.post(f"/api/v1/trips/{draft['id']}/publish", headers=driver["headers"])
    assert response.status_code == 200
    assert response.json()["status"] == "published"

    again = await client.post(f"/api/v1/trips/{draft['id']}/publish", headers=driver["headers"])
    assert again.status_code == 409


@pytest.mark.parametrize(
    ("overrides", "message_part"),
    [
        ({"departure_at": slot(minute=15)}, "кратно 30"),
        ({"min_price": 2000}, "Минимальная стоимость"),
        ({"segment_prices": [{"from_position": 0, "to_position": 1, "price": 400}]}, "соседними"),
        (
            {
                "segment_prices": [
                    {"from_position": 0, "to_position": 1, "price": 400},
                    {"from_position": 1, "to_position": 2, "price": 700},
                    {"from_position": 0, "to_position": 2, "price": 900},
                ]
            },
            "full_price",
        ),
        ({"extras": [{"kind": "pets", "price": 1}, {"kind": "pets", "price": 2}]}, "дважды"),
        ({"departure_at": "2030-01-01T10:00:00"}, "часовой пояс"),
    ],
)
async def test_payload_validation(
    client: AsyncClient, driver: dict, overrides: dict, message_part: str
) -> None:
    response = await client.post(
        "/api/v1/trips", headers=driver["headers"], json=trip_payload(driver, **overrides)
    )

    assert response.status_code == 422
    assert message_part in response.json()["message"]


async def test_same_origin_and_destination_rejected(client: AsyncClient, driver: dict) -> None:
    c = driver["cities"]
    stops = [
        {"city_id": c["Екатеринбург"], "address": "Вокзал"},
        {"city_id": c["Екатеринбург"], "address": "Рынок"},
    ]

    response = await client.post(
        "/api/v1/trips",
        headers=driver["headers"],
        json=trip_payload(driver, stops=stops, segment_prices=[]),
    )

    assert response.status_code == 422


async def test_two_stop_trip_needs_no_segment_prices(client: AsyncClient, driver: dict) -> None:
    c = driver["cities"]
    trip = await _create(
        client,
        driver,
        stops=[
            {"city_id": c["Екатеринбург"], "address": "Вокзал"},
            {"city_id": c["Асбест"], "address": "Рынок"},
        ],
        segment_prices=[],
    )

    assert trip["segment_prices"] == []


async def test_seats_cannot_exceed_car(client: AsyncClient, driver: dict) -> None:
    response = await client.post(
        "/api/v1/trips", headers=driver["headers"], json=trip_payload(driver, seats_total=5)
    )

    assert response.status_code == 400
    assert response.json()["code"] == "seats_exceed_car"


async def test_foreign_car_rejected(client: AsyncClient, driver: dict) -> None:
    other = await login(client, phone="+79007654321")
    headers = {"Authorization": f"Bearer {other['access_token']}"}

    response = await client.post(
        "/api/v1/trips", headers=headers, json=trip_payload(driver, publish=False)
    )

    assert response.status_code == 400
    assert response.json()["code"] == "car_not_found"


async def test_publish_requires_first_name(client: AsyncClient, auth: dict) -> None:
    car = await _create_car(client, auth["headers"])
    payload = trip_payload({"car": car, "cities": await _cities(client)})

    response = await client.post("/api/v1/trips", headers=auth["headers"], json=payload)

    assert response.status_code == 400
    assert response.json()["code"] == "profile_incomplete"


@pytest.mark.parametrize(
    ("departure", "code"),
    [(slot(days=-1), "departure_in_past"), (slot(days=5), "departure_too_far")],
)
async def test_publish_time_window(
    client: AsyncClient, driver: dict, departure: str, code: str
) -> None:
    response = await client.post(
        "/api/v1/trips",
        headers=driver["headers"],
        json=trip_payload(driver, departure_at=departure),
    )

    assert response.status_code == 400
    assert response.json()["code"] == code


async def test_far_future_draft_is_allowed(client: AsyncClient, driver: dict) -> None:
    draft = await _create(client, driver, departure_at=slot(days=10), publish=False)

    assert draft["status"] == "draft"


async def test_daily_limit_allows_one_trip_and_one_back(client: AsyncClient, driver: dict) -> None:
    first = await _create(client, driver, departure_at=slot(hour=8))

    same_direction = await client.post(
        "/api/v1/trips",
        headers=driver["headers"],
        json=trip_payload(driver, departure_at=slot(hour=12)),
    )
    assert same_direction.status_code == 409
    assert same_direction.json()["code"] == "daily_trip_limit"

    back = await client.post(
        f"/api/v1/trips/{first['id']}/reverse",
        headers=driver["headers"],
        json={"departure_at": slot(hour=18), "publish": True},
    )
    assert back.status_code == 201, back.text

    third = await client.post(
        f"/api/v1/trips/{first['id']}/reverse",
        headers=driver["headers"],
        json={"departure_at": slot(hour=20), "publish": True},
    )
    assert third.status_code == 409

    next_day = await _create(client, driver, departure_at=slot(days=2, hour=8))
    assert next_day["status"] == "published"


async def test_reverse_trip_mirrors_route_and_prices(client: AsyncClient, driver: dict) -> None:
    source = await _create(
        client,
        driver,
        segment_prices=[
            {"from_position": 0, "to_position": 1, "price": 400},
            {"from_position": 1, "to_position": 2, "price": 700},
        ],
    )

    response = await client.post(
        f"/api/v1/trips/{source['id']}/reverse",
        headers=driver["headers"],
        json={"departure_at": slot(hour=18)},
    )

    assert response.status_code == 201
    back = response.json()
    assert back["status"] == "draft"
    assert back["return_of_trip_id"] == source["id"]
    assert [s["city"]["name"] for s in back["stops"]] == ["Асбест", "Берёзовский", "Екатеринбург"]
    prices = {
        (p["from_position"], p["to_position"]): p["price"]["driver_price"]
        for p in back["segment_prices"]
    }
    assert prices == {(0, 1): 700, (1, 2): 400}
    assert [e["kind"] for e in back["extras"]] == [e["kind"] for e in source["extras"]]


async def test_replace_trip(client: AsyncClient, driver: dict) -> None:
    trip = await _create(client, driver)
    c = driver["cities"]
    payload = trip_payload(
        driver,
        departure_at=slot(hour=10, minute=30),
        stops=[
            {"city_id": c["Екатеринбург"], "address": "Вокзал"},
            {"city_id": c["Реж"], "address": "Площадь"},
        ],
        segment_prices=[],
        extras=[],
    )
    payload.pop("publish")

    response = await client.put(
        f"/api/v1/trips/{trip['id']}", headers=driver["headers"], json=payload
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert [s["address"] for s in body["stops"]] == ["Вокзал", "Площадь"]
    assert body["segment_prices"] == []
    assert body["extras"] == []
    assert body["status"] == "published"


async def test_update_seats(client: AsyncClient, driver: dict) -> None:
    trip = await _create(client, driver)

    ok = await client.patch(
        f"/api/v1/trips/{trip['id']}/seats", headers=driver["headers"], json={"seats_total": 4}
    )
    assert ok.status_code == 200
    assert ok.json()["seats_available"] == 4

    too_many = await client.patch(
        f"/api/v1/trips/{trip['id']}/seats", headers=driver["headers"], json={"seats_total": 6}
    )
    assert too_many.status_code == 400


async def test_cancel_and_delete(client: AsyncClient, driver: dict) -> None:
    trip = await _create(client, driver)

    cancelled = await client.post(f"/api/v1/trips/{trip['id']}/cancel", headers=driver["headers"])
    assert cancelled.status_code == 200
    assert cancelled.json()["trip"]["status"] == "cancelled"
    assert cancelled.json()["trip"]["is_editable"] is False
    # Nobody was registered: no rules violation.
    assert cancelled.json()["sanction"]["is_violation"] is False

    edit = await client.patch(
        f"/api/v1/trips/{trip['id']}/seats", headers=driver["headers"], json={"seats_total": 2}
    )
    assert edit.status_code == 409

    deleted = await client.delete(f"/api/v1/trips/{trip['id']}", headers=driver["headers"])
    assert deleted.status_code == 204
    gone = await client.get(f"/api/v1/trips/{trip['id']}", headers=driver["headers"])
    assert gone.status_code == 404


async def test_my_trips_filters(client: AsyncClient, driver: dict) -> None:
    published = await _create(client, driver)
    draft = await _create(client, driver, departure_at=slot(days=2), publish=False)

    async def ids(status: str | None = None) -> list[str]:
        params = {"status": status} if status else {}
        response = await client.get("/api/v1/trips/mine", headers=driver["headers"], params=params)
        return [t["id"] for t in response.json()]

    assert set(await ids()) == {published["id"], draft["id"]}
    assert await ids("active") == [published["id"]]
    assert await ids("draft") == [draft["id"]]
    assert await ids("completed") == []


async def test_visibility_for_other_users(client: AsyncClient, driver: dict) -> None:
    published = await _create(client, driver)
    draft = await _create(client, driver, departure_at=slot(days=2), publish=False)
    other = await login(client, phone="+79007654321")
    headers = {"Authorization": f"Bearer {other['access_token']}"}

    seen = await client.get(f"/api/v1/trips/{published['id']}", headers=headers)
    assert seen.status_code == 200
    hidden = await client.get(f"/api/v1/trips/{draft['id']}", headers=headers)
    assert hidden.status_code == 404
    cancel = await client.post(f"/api/v1/trips/{published['id']}/cancel", headers=headers)
    assert cancel.status_code == 404


async def test_car_in_active_trip_is_protected(client: AsyncClient, driver: dict) -> None:
    await _create(client, driver)
    car_url = f"/api/v1/cars/{driver['car']['id']}"

    delete = await client.delete(car_url, headers=driver["headers"])
    assert delete.status_code == 409
    assert delete.json()["code"] == "car_used_by_trips"

    shrink = await client.patch(car_url, headers=driver["headers"], json={"seats": 2})
    assert shrink.status_code == 409
    assert (await client.patch(car_url, headers=driver["headers"], json={"seats": 3})).is_success


async def test_parcel_sizes_reference(client: AsyncClient) -> None:
    sizes = (await client.get("/api/v1/trips/parcel-sizes")).json()

    assert [s["size"] for s in sizes] == ["S", "M", "L"]


def test_slot_helper_is_utc_convertible() -> None:
    assert datetime.fromisoformat(slot()).astimezone(UTC).minute in (0, 30)
