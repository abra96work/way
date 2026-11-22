import pytest
from httpx import AsyncClient

from tests.conftest import login
from tests.test_search import make_driver, publish
from tests.test_trips import slot, trip_payload

BOOKINGS = "/api/v1/bookings"


async def make_passenger(client: AsyncClient, phone: str, name: str = "Мария") -> dict:
    data = await login(client, phone=phone)
    data["headers"] = {"Authorization": f"Bearer {data['access_token']}"}
    await client.patch("/api/v1/me", headers=data["headers"], json={"first_name": name})
    return data


@pytest.fixture
async def world(client: AsyncClient) -> dict:
    """Driver with a published manual trip Екатеринбург → Берёзовский → Асбест (3 seats)."""
    driver = await make_driver(client, "+79005550001", "Виктор")
    trip = await publish(client, driver)
    passenger = await make_passenger(client, "+79001110001")
    return {"driver": driver, "trip": trip, "passenger": passenger}


def request(world: dict, **overrides) -> dict:
    payload = {"trip_id": world["trip"]["id"], "from_position": 0, "to_position": 2, "seats": 1}
    payload.update(overrides)
    return payload


async def book(client: AsyncClient, who: dict, payload: dict, expected: int = 201) -> dict:
    response = await client.post(BOOKINGS, headers=who["headers"], json=payload)
    assert response.status_code == expected, response.text
    return response.json()


async def act(client: AsyncClient, who: dict, booking: dict, action: str, expected: int = 200):
    response = await client.post(f"{BOOKINGS}/{booking['id']}/{action}", headers=who["headers"])
    assert response.status_code == expected, response.text
    return response.json()


async def notification_types(client: AsyncClient, who: dict) -> list[str]:
    response = await client.get("/api/v1/notifications", headers=who["headers"])
    return [n["type"] for n in response.json()]


async def test_quote(client: AsyncClient, world: dict) -> None:
    response = await client.post(
        f"{BOOKINGS}/quote",
        headers=world["passenger"]["headers"],
        json=request(world, seats=2, extras=["child_seat"]),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["seat_price"]["passenger_price"] == 1100
    assert body["price"] == {"driver_price": 2100, "commission": 210, "passenger_price": 2310}
    assert body["seats_available"] == 3
    assert body["is_registration_open"] is True


async def test_manual_flow_request_confirm_pay(client: AsyncClient, world: dict) -> None:
    passenger, driver = world["passenger"], world["driver"]

    booking = await book(client, passenger, request(world, extras=["luggage"]))
    assert booking["status"] == "pending"
    assert booking["price"]["passenger_price"] == 1155  # (1000 + 50) * 1.1
    assert booking["payment"] == {"pay_online": 105, "pay_to_driver": 1050, "is_paid": False}
    assert booking["can_pay"] is False
    assert "booking_requested" in await notification_types(client, driver)

    requests = await client.get(
        f"/api/v1/trips/{world['trip']['id']}/bookings", headers=driver["headers"]
    )
    assert [b["id"] for b in requests.json()] == [booking["id"]]
    assert requests.json()[0]["passenger"]["first_name"] == "Мария"

    confirmed = await act(client, driver, booking, "confirm")
    assert confirmed["status"] == "awaiting_payment"
    assert "booking_confirmed" in await notification_types(client, passenger)

    mine = await client.get(f"{BOOKINGS}/{booking['id']}", headers=passenger["headers"])
    assert mine.json()["can_pay"] is True

    paid = await act(client, passenger, booking, "pay")
    assert paid["status"] == "paid"
    assert paid["payment"]["is_paid"] is True
    assert paid["paid_at"] is not None
    assert "booking_paid" in await notification_types(client, driver)

    active = await client.get(
        f"{BOOKINGS}/mine", headers=passenger["headers"], params={"status": "active"}
    )
    assert [b["id"] for b in active.json()] == [booking["id"]]


async def test_instant_mode_goes_straight_to_payment(client: AsyncClient) -> None:
    driver = await make_driver(client, "+79005550009", "Олег")
    trip = await publish(client, driver, booking_mode="instant")
    passenger = await make_passenger(client, "+79001110009")

    booking = await book(client, passenger, request({"trip": trip}))

    assert booking["status"] == "awaiting_payment"
    assert booking["can_pay"] is True
    assert "booking_created" in await notification_types(client, driver)


async def test_reject_frees_seats(client: AsyncClient, world: dict) -> None:
    first = await book(client, world["passenger"], request(world, seats=3))
    other = await make_passenger(client, "+79001110002", "Ольга")

    full = await book(client, other, request(world), expected=409)
    assert full["code"] == "not_enough_seats"

    rejected = await act(client, world["driver"], first, "reject")
    assert rejected["status"] == "rejected"
    assert "booking_rejected" in await notification_types(client, world["passenger"])
    await book(client, other, request(world))


async def test_seats_are_counted_per_segment(client: AsyncClient, world: dict) -> None:
    await book(client, world["passenger"], request(world, to_position=1, seats=3))
    second = await make_passenger(client, "+79001110002", "Ольга")
    third = await make_passenger(client, "+79001110003", "Ира")

    # Seats free up at Берёзовский: the second leg can be sold again.
    await book(client, second, request(world, from_position=1, seats=3))
    whole = await book(client, third, request(world), expected=409)
    assert whole["code"] == "not_enough_seats"

    trip = await client.get(
        f"/api/v1/trips/{world['trip']['id']}", headers=world["driver"]["headers"]
    )
    assert trip.json()["seats_available"] == 0


async def test_search_uses_segment_seats(client: AsyncClient, world: dict) -> None:
    await book(client, world["passenger"], request(world, to_position=1, seats=3))
    searcher = await make_passenger(client, "+79001110004", "Анна")

    async def total(**params) -> int:
        response = await client.get(
            "/api/v1/search/trips", headers=searcher["headers"], params=params
        )
        return response.json()["total"]

    assert await total(from_query="Берёзовский", to_query="Асбест") == 1
    assert await total(from_query="Екатеринбург", to_query="Асбест") == 0


async def test_trip_with_bookings_is_locked(client: AsyncClient, world: dict) -> None:
    await book(client, world["passenger"], request(world, seats=2))
    driver, trip_url = world["driver"], f"/api/v1/trips/{world['trip']['id']}"

    trip = (await client.get(trip_url, headers=driver["headers"])).json()
    assert trip["seats_available"] == 1
    assert trip["is_editable"] is False

    payload = trip_payload(driver)
    payload.pop("publish")
    edit = await client.put(trip_url, headers=driver["headers"], json=payload)
    assert edit.status_code == 409
    assert edit.json()["code"] == "trip_has_bookings"

    shrink = await client.patch(
        f"{trip_url}/seats", headers=driver["headers"], json={"seats_total": 1}
    )
    assert shrink.status_code == 409
    assert shrink.json()["code"] == "seats_below_booked"
    grow = await client.patch(
        f"{trip_url}/seats", headers=driver["headers"], json={"seats_total": 4}
    )
    assert grow.status_code == 200

    delete = await client.delete(trip_url, headers=driver["headers"])
    assert delete.status_code == 409


async def test_passenger_cancels(client: AsyncClient, world: dict) -> None:
    booking = await book(client, world["passenger"], request(world, seats=3))

    result = await act(client, world["passenger"], booking, "cancel")
    cancelled = result["booking"]
    assert result["sanction"]["is_violation"] is False  # still pending: not registered

    assert cancelled["status"] == "cancelled"
    assert cancelled["cancelled_by"] == "passenger"
    assert cancelled["can_cancel"] is False
    assert "booking_cancelled" in await notification_types(client, world["driver"])
    again = await act(client, world["passenger"], booking, "cancel", expected=409)
    assert again["code"] == "booking_inactive"
    # Seats are free again and the same passenger may book anew.
    await book(client, world["passenger"], request(world, seats=3))

    history = await client.get(
        f"{BOOKINGS}/mine", headers=world["passenger"]["headers"], params={"status": "cancelled"}
    )
    assert [b["id"] for b in history.json()] == [booking["id"]]


async def test_driver_cancelling_trip_cancels_bookings(client: AsyncClient, world: dict) -> None:
    booking = await book(client, world["passenger"], request(world))

    response = await client.post(
        f"/api/v1/trips/{world['trip']['id']}/cancel", headers=world["driver"]["headers"]
    )
    assert response.status_code == 200

    after = await client.get(f"{BOOKINGS}/{booking['id']}", headers=world["passenger"]["headers"])
    assert after.json()["status"] == "cancelled"
    assert after.json()["cancelled_by"] == "driver"
    assert "trip_cancelled" in await notification_types(client, world["passenger"])


@pytest.mark.parametrize(
    ("overrides", "status", "code"),
    [
        ({"extras": ["pets"]}, 400, "extra_not_offered"),
        ({"kind": "parcel", "parcel_size": "L"}, 400, "parcel_not_accepted"),
        ({"to_position": 5}, 400, "invalid_segment"),
        ({"seats": 4}, 409, "not_enough_seats"),
        ({"kind": "parcel"}, 422, "validation_error"),
        ({"from_position": 2, "to_position": 1}, 422, "validation_error"),
    ],
)
async def test_invalid_requests(
    client: AsyncClient, world: dict, overrides: dict, status: int, code: str
) -> None:
    body = await book(client, world["passenger"], request(world, **overrides), expected=status)

    assert body["code"] == code


async def test_parcel_does_not_take_seats(client: AsyncClient, world: dict) -> None:
    parcel = await book(
        client, world["passenger"], request(world, kind="parcel", parcel_size="S", seats=1)
    )

    assert parcel["seats"] == 0
    assert parcel["price"]["driver_price"] == 200
    assert parcel["parcel_size"] == "S"
    # A seat in the same trip is a separate booking.
    await book(client, world["passenger"], request(world, seats=3))


async def test_duplicate_booking(client: AsyncClient, world: dict) -> None:
    await book(client, world["passenger"], request(world))

    duplicate = await book(client, world["passenger"], request(world), expected=409)

    assert duplicate["code"] == "already_booked"


async def test_own_trip_and_incomplete_profile(client: AsyncClient, world: dict) -> None:
    own = await book(client, world["driver"], request(world), expected=403)
    assert own["code"] == "own_trip"

    nameless = await login(client, phone="+79001110005")
    headers = {"headers": {"Authorization": f"Bearer {nameless['access_token']}"}}
    incomplete = await book(client, headers, request(world), expected=400)
    assert incomplete["code"] == "profile_incomplete"


async def test_roles_are_enforced(client: AsyncClient, world: dict) -> None:
    booking = await book(client, world["passenger"], request(world))
    stranger = await make_passenger(client, "+79001110006", "Пётр")

    assert (await act(client, world["passenger"], booking, "confirm", 403))["code"] == (
        "not_trip_driver"
    )
    await act(client, world["driver"], booking, "confirm")
    assert (await act(client, world["driver"], booking, "pay", 403))["code"] == (
        "not_booking_passenger"
    )
    hidden = await client.get(f"{BOOKINGS}/{booking['id']}", headers=stranger["headers"])
    assert hidden.status_code == 404
    foreign = await client.get(
        f"/api/v1/trips/{world['trip']['id']}/bookings", headers=stranger["headers"]
    )
    assert foreign.status_code == 404


async def test_queue_is_enforced_on_booking(client: AsyncClient, world: dict) -> None:
    second_driver = await make_driver(client, "+79005550002", "Олег")
    second_trip = await publish(client, second_driver)
    second = {"trip": second_trip}

    closed = await book(client, world["passenger"], request(second), expected=409)
    assert closed["code"] == "registration_closed"

    await book(client, world["passenger"], request(world, seats=3))
    other = await make_passenger(client, "+79001110007", "Ольга")
    opened = await book(client, other, request(second))
    assert opened["status"] == "pending"


async def test_cannot_pay_twice_or_before_confirmation(client: AsyncClient, world: dict) -> None:
    booking = await book(client, world["passenger"], request(world))

    early = await act(client, world["passenger"], booking, "pay", expected=409)
    assert early["code"] == "booking_not_payable"

    await act(client, world["driver"], booking, "confirm")
    await act(client, world["passenger"], booking, "pay")
    twice = await act(client, world["passenger"], booking, "pay", expected=409)
    assert twice["code"] == "booking_not_payable"


async def test_notifications_read_flow(client: AsyncClient, world: dict) -> None:
    await book(client, world["passenger"], request(world))
    headers = world["driver"]["headers"]

    count = await client.get("/api/v1/notifications/unread-count", headers=headers)
    assert count.json() == {"unread": 1}
    items = (await client.get("/api/v1/notifications", headers=headers)).json()
    assert items[0]["trip_id"] == world["trip"]["id"]
    assert items[0]["booking_id"] is not None

    read = await client.post(f"/api/v1/notifications/{items[0]['id']}/read", headers=headers)
    assert read.json()["is_read"] is True
    unread = await client.get(
        "/api/v1/notifications", headers=headers, params={"unread_only": True}
    )
    assert unread.json() == []

    await book(client, await make_passenger(client, "+79001110008", "Ира"), request(world))
    await client.post("/api/v1/notifications/read-all", headers=headers)
    count = await client.get("/api/v1/notifications/unread-count", headers=headers)
    assert count.json() == {"unread": 0}

    foreign = await client.post(
        f"/api/v1/notifications/{items[0]['id']}/read", headers=world["passenger"]["headers"]
    )
    assert foreign.status_code == 404


async def test_booking_another_day_trip(client: AsyncClient, world: dict) -> None:
    later = await publish(client, world["driver"], departure_at=slot(days=2))

    booking = await book(client, world["passenger"], request({"trip": later}))

    assert booking["trip"]["id"] == later["id"]
    assert booking["board"]["city"]["name"] == "Екатеринбург"
    assert booking["alight"]["city"]["name"] == "Асбест"
