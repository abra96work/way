from datetime import timedelta
from uuid import UUID

import pytest
from httpx import AsyncClient
from sqlalchemy import update

from app.core.config import get_settings
from app.core.security import utcnow
from app.db.session import SessionLocal
from app.models.feedback import Cancellation, ParticipantRole, Review
from app.models.trip import Trip
from tests.test_bookings import act, book, make_passenger, notification_types, request
from tests.test_search import make_driver, publish
from tests.test_trips import slot


@pytest.fixture
async def world(client: AsyncClient) -> dict:
    driver = await make_driver(client, "+79005550001", "Виктор")
    trips = [
        await publish(client, driver, departure_at=slot(days=1)),
        await publish(client, driver, departure_at=slot(days=2)),
    ]
    passenger = await make_passenger(client, "+79001110001")
    return {"driver": driver, "trips": trips, "passenger": passenger}


async def registered_booking(client: AsyncClient, world: dict, trip: dict, who: dict) -> dict:
    booking = await book(client, who, request({"trip": trip}))
    await act(client, world["driver"], booking, "confirm")
    return booking


async def finish_trip(trip_id: str) -> None:
    """Move a trip into the past so it counts as completed."""
    async with SessionLocal() as session:
        await session.execute(
            update(Trip)
            .where(Trip.id == UUID(trip_id))
            .values(departure_at=utcnow() - timedelta(hours=12))
        )
        await session.commit()


async def me(client: AsyncClient, who: dict) -> dict:
    return (await client.get("/api/v1/me", headers=who["headers"])).json()


# ---------- sanctions ----------


async def test_pending_cancel_is_not_a_violation(client: AsyncClient, world: dict) -> None:
    booking = await book(client, world["passenger"], request({"trip": world["trips"][0]}))

    preview = await client.get(
        f"/api/v1/bookings/{booking['id']}/cancel-preview", headers=world["passenger"]["headers"]
    )
    assert preview.json()["is_violation"] is False
    result = await act(client, world["passenger"], booking, "cancel")
    assert result["sanction"]["is_violation"] is False
    assert (await me(client, world["passenger"]))["cancellations_count"] == 0


async def test_two_passenger_violations_block_account(client: AsyncClient, world: dict) -> None:
    passenger = world["passenger"]
    first = await registered_booking(client, world, world["trips"][0], passenger)
    second = await registered_booking(client, world, world["trips"][1], passenger)

    preview = await client.get(
        f"/api/v1/bookings/{first['id']}/cancel-preview", headers=passenger["headers"]
    )
    assert preview.json()["is_violation"] is True
    assert "правила сообщества" in preview.json()["warning"]
    assert preview.json()["blocks_account"] is False

    warned = (await act(client, passenger, first, "cancel"))["sanction"]
    assert warned["is_violation"] is True
    assert warned["violations_last_period"] == 1
    assert warned["blocked_until"] is None

    last_chance = await client.get(
        f"/api/v1/bookings/{second['id']}/cancel-preview", headers=passenger["headers"]
    )
    assert last_chance.json()["blocks_account"] is True

    blocked = (await act(client, passenger, second, "cancel"))["sanction"]
    assert blocked["blocks_account"] is True
    assert blocked["blocked_until"] is not None
    assert "account_blocked" in await notification_types(client, passenger)
    profile = await me(client, passenger)
    assert profile["blocked_until"] is not None
    assert profile["cancellations_count"] == 2

    third_trip = await publish(
        client, await make_driver(client, "+79005550002", "Олег"), departure_at=slot()
    )
    denied = await book(client, passenger, request({"trip": third_trip}), expected=403)
    assert denied["code"] == "user_blocked"


async def test_paid_booking_cancellation_refunds_commission(
    client: AsyncClient, world: dict
) -> None:
    booking = await registered_booking(client, world, world["trips"][0], world["passenger"])
    await act(client, world["passenger"], booking, "pay")

    cancelled = await act(client, world["passenger"], booking, "cancel")

    assert cancelled["booking"]["status"] == "cancelled"
    assert cancelled["booking"]["payment"]["is_refunded"] is True


async def test_instant_booking_counts_as_registered(client: AsyncClient) -> None:
    driver = await make_driver(client, "+79005550003", "Пётр")
    trip = await publish(client, driver, booking_mode="instant")
    passenger = await make_passenger(client, "+79001110003")
    booking = await book(client, passenger, request({"trip": trip}))

    result = await act(client, passenger, booking, "cancel")

    assert result["sanction"]["is_violation"] is True


async def test_old_violations_expire(client: AsyncClient, world: dict) -> None:
    passenger = world["passenger"]
    async with SessionLocal() as session:
        old = Cancellation(user_id=UUID(passenger["user"]["id"]), role=ParticipantRole.passenger)
        session.add(old)
        await session.flush()
        old.created_at = utcnow() - timedelta(days=31)
        await session.commit()
    booking = await registered_booking(client, world, world["trips"][0], passenger)

    sanction = (await act(client, passenger, booking, "cancel"))["sanction"]

    assert sanction["violations_last_period"] == 1
    assert sanction["blocked_until"] is None


async def test_driver_violations_block_publishing(client: AsyncClient, world: dict) -> None:
    driver = world["driver"]
    for trip in world["trips"]:
        await registered_booking(client, world, trip, world["passenger"])

    preview = await client.get(
        f"/api/v1/trips/{world['trips'][0]['id']}/cancel-preview", headers=driver["headers"]
    )
    assert preview.json()["is_violation"] is True
    for trip in world["trips"]:
        result = await client.post(f"/api/v1/trips/{trip['id']}/cancel", headers=driver["headers"])
        assert result.json()["sanction"]["is_violation"] is True
    assert result.json()["sanction"]["blocks_account"] is True

    denied = await client.post(
        "/api/v1/trips",
        headers=driver["headers"],
        json={**_payload(driver), "departure_at": slot(days=3)},
    )
    assert denied.status_code == 403
    assert denied.json()["code"] == "user_blocked"


def _payload(driver: dict) -> dict:
    from tests.test_trips import trip_payload

    return trip_payload(driver)


# ---------- rating & reviews ----------


async def test_no_reviews_means_five_stars(client: AsyncClient, world: dict) -> None:
    driver_id = world["driver"]["user"]["id"]
    headers = world["passenger"]["headers"]

    profile = (await client.get(f"/api/v1/users/{driver_id}", headers=headers)).json()
    reviews = (await client.get(f"/api/v1/users/{driver_id}/reviews", headers=headers)).json()

    assert (profile["rating"], profile["reviews_count"]) == (5.0, 0)
    assert reviews == []
    own = await me(client, world["driver"])
    assert (own["rating"], own["reviews_count"], own["completed_trips"]) == (5.0, 0, 0)


async def test_reviews_disabled_in_test_build(client: AsyncClient, world: dict) -> None:
    response = await client.post(
        "/api/v1/reviews",
        headers=world["passenger"]["headers"],
        json={
            "trip_id": world["trips"][0]["id"],
            "target_id": world["driver"]["user"]["id"],
            "rating": 5,
        },
    )

    assert response.status_code == 403
    assert response.json()["code"] == "reviews_disabled"


@pytest.fixture
def reviews_on(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "reviews_enabled", True)


async def _paid_finished_trip(client: AsyncClient, world: dict) -> dict:
    trip = world["trips"][0]
    booking = await registered_booking(client, world, trip, world["passenger"])
    await act(client, world["passenger"], booking, "pay")
    await finish_trip(trip["id"])
    return trip


@pytest.mark.usefixtures("reviews_on")
async def test_review_flow_and_rating(client: AsyncClient, world: dict) -> None:
    trip = await _paid_finished_trip(client, world)
    driver_id = world["driver"]["user"]["id"]
    passenger_id = world["passenger"]["user"]["id"]

    async def review(who: dict, target: str, rating: int, expected: int = 201) -> dict:
        response = await client.post(
            "/api/v1/reviews",
            headers=who["headers"],
            json={"trip_id": trip["id"], "target_id": target, "rating": rating, "text": " Ок "},
        )
        assert response.status_code == expected, response.text
        return response.json()

    about_driver = await review(world["passenger"], driver_id, 4)
    assert about_driver["target_role"] == "driver"
    assert about_driver["text"] == "Ок"
    about_passenger = await review(world["driver"], passenger_id, 5)
    assert about_passenger["target_role"] == "passenger"
    assert (await review(world["passenger"], driver_id, 1, 409))["code"] == "review_exists"

    headers = world["passenger"]["headers"]
    driver = (await client.get(f"/api/v1/users/{driver_id}", headers=headers)).json()
    assert (driver["rating"], driver["reviews_count"], driver["completed_trips"]) == (4.0, 1, 1)
    assert (await me(client, world["passenger"]))["completed_trips"] == 1
    listed = (await client.get(f"/api/v1/users/{driver_id}/reviews", headers=headers)).json()
    assert [r["rating"] for r in listed] == [4]
    assert listed[0]["author"]["first_name"] == "Мария"

    # Moderation: hidden reviews disappear from the rating.
    async with SessionLocal() as session:
        await session.execute(update(Review).values(is_hidden=True))
        await session.commit()
    driver = (await client.get(f"/api/v1/users/{driver_id}", headers=headers)).json()
    assert (driver["rating"], driver["reviews_count"]) == (5.0, 0)


@pytest.mark.usefixtures("reviews_on")
async def test_review_rules(client: AsyncClient, world: dict) -> None:
    driver_id = world["driver"]["user"]["id"]
    upcoming = world["trips"][1]
    await registered_booking(client, world, upcoming, world["passenger"])

    async def review(who: dict, trip_id: str, target: str) -> dict:
        response = await client.post(
            "/api/v1/reviews",
            headers=who["headers"],
            json={"trip_id": trip_id, "target_id": target, "rating": 5},
        )
        return response.json()

    early = await review(world["passenger"], upcoming["id"], driver_id)
    assert early["code"] == "trip_not_completed"

    trip = await _paid_finished_trip(client, world)
    stranger = await make_passenger(client, "+79001110009", "Ира")
    assert (await review(stranger, trip["id"], driver_id))["code"] == "not_trip_participants"
    own = await review(world["driver"], trip["id"], driver_id)
    assert own["code"] == "review_self"


# ---------- complaints ----------


async def test_complaints(client: AsyncClient, world: dict) -> None:
    trip = world["trips"][0]
    await book(client, world["passenger"], request({"trip": trip}))
    driver_id = world["driver"]["user"]["id"]

    async def complain(who: dict, target: str) -> tuple[int, dict]:
        response = await client.post(
            "/api/v1/complaints",
            headers=who["headers"],
            json={"trip_id": trip["id"], "target_id": target, "reason": "late", "text": "Опоздал"},
        )
        return response.status_code, response.json()

    status, created = await complain(world["passenger"], driver_id)
    assert status == 201
    assert created["status"] == "new"

    received = (
        await client.get("/api/v1/me/complaints", headers=world["driver"]["headers"])
    ).json()
    assert [(c["reason"], c["text"]) for c in received] == [("late", "Опоздал")]
    assert "author" not in received[0]
    assert (
        await client.get("/api/v1/me/complaints", headers=world["passenger"]["headers"])
    ).json() == []

    stranger = await make_passenger(client, "+79001110008", "Ира")
    assert (await complain(stranger, driver_id))[1]["code"] == "not_trip_participants"
    assert (await complain(world["driver"], driver_id))[1]["code"] == "complaint_self"
    other = await make_passenger(client, "+79001110007", "Ольга")
    await book(client, other, request({"trip": trip}))
    passenger_id = world["passenger"]["user"]["id"]
    assert (await complain(other, passenger_id))[1]["code"] == "not_trip_participants"
