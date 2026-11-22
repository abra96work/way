from datetime import datetime, timedelta

import pytest
from httpx import AsyncClient

from app.services.search import haversine_km
from tests.conftest import login
from tests.test_cars import _create_car
from tests.test_trips import LOCAL, _cities, slot, trip_payload

SEARCH = "/api/v1/search/trips"


async def make_driver(client: AsyncClient, phone: str, name: str) -> dict:
    data = await login(client, phone=phone)
    data["headers"] = {"Authorization": f"Bearer {data['access_token']}"}
    await client.patch("/api/v1/me", headers=data["headers"], json={"first_name": name})
    data["car"] = await _create_car(client, data["headers"])
    data["cities"] = await _cities(client)
    return data


async def publish(client: AsyncClient, driver: dict, **overrides) -> dict:
    response = await client.post(
        "/api/v1/trips", headers=driver["headers"], json=trip_payload(driver, **overrides)
    )
    assert response.status_code == 201, response.text
    return response.json()


@pytest.fixture
async def setup(client: AsyncClient, auth: dict) -> dict:
    """One published trip Екатеринбург → Берёзовский → Асбест; `auth` is the passenger."""
    driver = await make_driver(client, "+79005550001", "Виктор")
    trip = await publish(client, driver)
    return {"driver": driver, "trip": trip, "passenger": auth, "cities": driver["cities"]}


async def find(client: AsyncClient, setup: dict, **params) -> dict:
    response = await client.get(SEARCH, headers=setup["passenger"]["headers"], params=params)
    assert response.status_code == 200, response.text
    return response.json()


def test_haversine_known_distance() -> None:
    # Екатеринбург — Берёзовский, about 13 km.
    assert 10 < haversine_km(56.8389, 60.6057, 56.9097, 60.8058) < 16


async def test_whole_route(client: AsyncClient, setup: dict) -> None:
    c = setup["cities"]
    body = await find(client, setup, from_city_id=c["Екатеринбург"], to_city_id=c["Асбест"])

    assert body["total"] == 1
    item = body["items"][0]
    assert item["trip_id"] == setup["trip"]["id"]
    assert (item["board"]["position"], item["alight"]["position"]) == (0, 2)
    assert item["price"]["passenger_price"] == 1100
    assert item["driver"]["rating"] == 5.0
    assert item["driver"]["reviews_count"] == 0
    assert item["car"]["brand"] == "Toyota"
    assert item["is_registration_open"] is True
    assert item["accepts_parcels"] is True


@pytest.mark.parametrize(
    ("origin", "destination", "positions", "passenger_price"),
    [
        ("Берёзовский", "Асбест", (1, 2), 770),
        ("Екатеринбург", "Берёзовский", (0, 1), 440),
    ],
)
async def test_part_of_route(
    client: AsyncClient,
    setup: dict,
    origin: str,
    destination: str,
    positions: tuple[int, int],
    passenger_price: int,
) -> None:
    c = setup["cities"]
    body = await find(client, setup, from_city_id=c[origin], to_city_id=c[destination])

    item = body["items"][0]
    assert (item["board"]["position"], item["alight"]["position"]) == positions
    assert item["price"]["passenger_price"] == passenger_price


async def test_opposite_direction_does_not_match(client: AsyncClient, setup: dict) -> None:
    c = setup["cities"]
    body = await find(client, setup, from_city_id=c["Асбест"], to_city_id=c["Екатеринбург"])

    assert body["total"] == 0


async def test_search_by_name(client: AsyncClient, setup: dict) -> None:
    body = await find(client, setup, from_query="березов", to_query="асб")

    assert body["total"] == 1
    assert body["items"][0]["board"]["city"]["name"] == "Берёзовский"


async def test_unknown_name_finds_nothing(client: AsyncClient, setup: dict) -> None:
    assert (await find(client, setup, from_query="Москва"))["total"] == 0


async def test_nearby_by_geolocation(client: AsyncClient, setup: dict) -> None:
    near_berezovsky = {"lat": 56.91, "lng": 60.80, "radius_km": 5}

    body = await find(client, setup, **near_berezovsky)

    assert body["total"] == 1
    item = body["items"][0]
    assert item["board"]["city"]["name"] == "Берёзовский"
    assert item["distance_km"] < 5
    far = await find(client, setup, lat=55.75, lng=37.61, radius_km=50)
    assert far["total"] == 0


async def test_vehicle_type_tabs(client: AsyncClient, setup: dict) -> None:
    assert (await find(client, setup, vehicle_type="car"))["total"] == 1
    assert (await find(client, setup, vehicle_type="bus"))["total"] == 0


async def test_date_filter(client: AsyncClient, setup: dict) -> None:
    tomorrow = (datetime.now(LOCAL) + timedelta(days=1)).date().isoformat()
    later = (datetime.now(LOCAL) + timedelta(days=2)).date().isoformat()

    assert (await find(client, setup, date=tomorrow))["total"] == 1
    assert (await find(client, setup, date=later))["total"] == 0


async def test_seats_filter(client: AsyncClient, setup: dict) -> None:
    assert (await find(client, setup, seats=3))["total"] == 1
    assert (await find(client, setup, seats=4))["total"] == 0


async def test_own_and_draft_trips_hidden(client: AsyncClient, setup: dict) -> None:
    driver = setup["driver"]
    await publish(client, driver, departure_at=slot(days=2), publish=False)

    own = await client.get(SEARCH, headers=driver["headers"])
    assert own.json()["total"] == 0
    assert (await find(client, setup))["total"] == 1


async def test_same_route_same_time_queue(client: AsyncClient, setup: dict) -> None:
    second = await make_driver(client, "+79005550002", "Олег")
    await publish(client, second)

    items = (await find(client, setup))["items"]

    assert len(items) == 2
    open_ids = [i["trip_id"] for i in items if i["is_registration_open"]]
    assert open_ids == [setup["trip"]["id"]]


async def test_queue_and_ranking_prefer_reliable_driver(client: AsyncClient, setup: dict) -> None:
    unreliable = await make_driver(client, "+79005550003", "Пётр")
    # A cancelled trip on another day lowers this driver's priority.
    # Cancelling a trip with a registered passenger is a rules violation: lower priority.
    old = await publish(client, unreliable, departure_at=slot(days=2))
    rider = await login(client, phone="+79005559999")
    rider_headers = {"Authorization": f"Bearer {rider['access_token']}"}
    await client.patch("/api/v1/me", headers=rider_headers, json={"first_name": "Лев"})
    booking = await client.post(
        "/api/v1/bookings",
        headers=rider_headers,
        json={"trip_id": old["id"], "from_position": 0, "to_position": 2},
    )
    await client.post(
        f"/api/v1/bookings/{booking.json()['id']}/confirm", headers=unreliable["headers"]
    )
    cancel = await client.post(f"/api/v1/trips/{old['id']}/cancel", headers=unreliable["headers"])
    assert cancel.json()["sanction"]["is_violation"] is True
    earlier_trip = await publish(client, unreliable, departure_at=slot(hour=7))
    same_time = await publish(
        client, await make_driver(client, "+79005550004", "Анна"), departure_at=slot()
    )

    items = (await find(client, setup))["items"]
    order = [i["trip_id"] for i in items]

    # Reliable drivers first even though Пётр leaves earlier.
    assert order[-1] == earlier_trip["id"]
    assert order.index(setup["trip"]["id"]) < order.index(earlier_trip["id"])
    flags = {i["trip_id"]: i["is_registration_open"] for i in items}
    assert flags[setup["trip"]["id"]] is True
    assert flags[same_time["id"]] is False


async def test_pagination(client: AsyncClient, setup: dict) -> None:
    await publish(client, await make_driver(client, "+79005550005", "Ира"))

    page = await find(client, setup, limit=1, offset=1)

    assert page["total"] == 2
    assert len(page["items"]) == 1


async def test_segment_price_endpoint(client: AsyncClient, setup: dict) -> None:
    url = f"/api/v1/trips/{setup['trip']['id']}/price"
    headers = setup["passenger"]["headers"]

    ok = await client.get(url, headers=headers, params={"from_position": 1, "to_position": 2})
    assert ok.status_code == 200
    assert ok.json()["price"] == {"driver_price": 700, "commission": 70, "passenger_price": 770}
    assert ok.json()["seats_available"] == 3

    bad = await client.get(url, headers=headers, params={"from_position": 2, "to_position": 5})
    assert bad.status_code == 400
    assert bad.json()["code"] == "invalid_segment"


async def test_departure_is_stored_in_utc(client: AsyncClient, setup: dict) -> None:
    local_nine = datetime.fromisoformat(slot())  # 09:00 Asia/Yekaterinburg = 04:00 UTC

    stored = datetime.fromisoformat(setup["trip"]["departure_at"].replace("Z", "+00:00"))

    assert stored == local_nine
    assert stored.utcoffset() == timedelta(0)
    assert stored.hour == 4
