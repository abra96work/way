"""Chat between two real accounts: a driver and a passenger of the same trip."""

import pytest
from fastapi.testclient import TestClient
from httpx import AsyncClient
from starlette.websockets import WebSocketDisconnect

from app.main import app
from tests.test_bookings import act, book, make_passenger, request
from tests.test_feedback import finish_trip
from tests.test_search import make_driver, publish

CHATS = "/api/v1/chats"


@pytest.fixture
async def world(client: AsyncClient) -> dict:
    driver = await make_driver(client, "+79005550001", "Виктор")
    trip = await publish(client, driver)
    passenger = await make_passenger(client, "+79001110001", "Мария")
    booking = await book(client, passenger, request({"trip": trip}))
    return {"driver": driver, "passenger": passenger, "trip": trip, "booking": booking}


async def open_chat(client: AsyncClient, who: dict, booking_id: str) -> dict:
    response = await client.post(CHATS, headers=who["headers"], json={"booking_id": booking_id})
    assert response.status_code == 200, response.text
    return response.json()


async def say(client: AsyncClient, who: dict, chat_id: str, text: str, expected: int = 201):
    response = await client.post(
        f"{CHATS}/{chat_id}/messages", headers=who["headers"], json={"text": text}
    )
    assert response.status_code == expected, response.text
    return response.json()


async def test_two_accounts_exchange_messages(client: AsyncClient, world: dict) -> None:
    driver, passenger = world["driver"], world["passenger"]

    by_passenger = await open_chat(client, passenger, world["booking"]["id"])
    by_driver = await open_chat(client, driver, world["booking"]["id"])
    assert by_passenger["id"] == by_driver["id"]
    chat_id = by_passenger["id"]
    assert by_passenger["my_role"] == "passenger"
    assert by_passenger["counterpart"]["first_name"] == "Виктор"
    assert by_driver["counterpart"]["first_name"] == "Мария"
    assert by_passenger["can_write"] is True

    first = await say(client, passenger, chat_id, "  Здравствуйте! Где встречаемся?  ")
    assert first["text"] == "Здравствуйте! Где встречаемся?"
    assert first["is_mine"] is True
    await say(client, driver, chat_id, "У входа в вокзал, белая Camry")
    await say(client, passenger, chat_id, "Спасибо!")

    seen_by_driver = (
        await client.get(f"{CHATS}/{chat_id}/messages", headers=driver["headers"])
    ).json()
    assert [m["text"] for m in seen_by_driver] == [
        "Здравствуйте! Где встречаемся?",
        "У входа в вокзал, белая Camry",
        "Спасибо!",
    ]
    assert [m["is_mine"] for m in seen_by_driver] == [False, True, False]

    driver_list = (await client.get(CHATS, headers=driver["headers"])).json()
    # Replying marks earlier messages as read (like in messengers): only "Спасибо!" is new.
    assert driver_list[0]["unread_count"] == 1
    assert driver_list[0]["last_message"]["text"] == "Спасибо!"
    unread = await client.get(f"{CHATS}/unread-count", headers=driver["headers"])
    assert unread.json() == {"unread": 1}

    read = await client.post(f"{CHATS}/{chat_id}/read", headers=driver["headers"])
    assert read.json()["unread_count"] == 0
    passenger_view = (await client.get(f"{CHATS}/{chat_id}", headers=passenger["headers"])).json()
    assert passenger_view["counterpart_read_id"] == seen_by_driver[-1]["id"]


async def test_pagination(client: AsyncClient, world: dict) -> None:
    chat = await open_chat(client, world["passenger"], world["booking"]["id"])
    sent = [await say(client, world["passenger"], chat["id"], f"#{i}") for i in range(5)]
    url, headers = f"{CHATS}/{chat['id']}/messages", world["driver"]["headers"]

    latest = (await client.get(url, headers=headers, params={"limit": 2})).json()
    assert [m["text"] for m in latest] == ["#3", "#4"]
    older = (
        await client.get(url, headers=headers, params={"limit": 2, "before_id": latest[0]["id"]})
    ).json()
    assert [m["text"] for m in older] == ["#1", "#2"]
    newer = (await client.get(url, headers=headers, params={"after_id": sent[2]["id"]})).json()
    assert [m["text"] for m in newer] == ["#3", "#4"]


async def test_strangers_cannot_read_or_write(client: AsyncClient, world: dict) -> None:
    chat = await open_chat(client, world["passenger"], world["booking"]["id"])
    stranger = await make_passenger(client, "+79001110009", "Ира")

    assert (
        await client.get(f"{CHATS}/{chat['id']}", headers=stranger["headers"])
    ).status_code == 404
    await say(client, stranger, chat["id"], "привет", expected=404)
    response = await client.post(
        CHATS, headers=stranger["headers"], json={"booking_id": world["booking"]["id"]}
    )
    assert response.status_code == 404
    assert (await client.get(CHATS, headers=stranger["headers"])).json() == []


async def test_chat_closes_with_booking_but_history_stays(client: AsyncClient, world: dict) -> None:
    chat = await open_chat(client, world["passenger"], world["booking"]["id"])
    await say(client, world["passenger"], chat["id"], "Буду через 5 минут")

    await act(client, world["passenger"], world["booking"], "cancel")

    closed = await say(client, world["driver"], chat["id"], "Ок", expected=409)
    assert closed["code"] == "chat_closed"
    history = (
        await client.get(f"{CHATS}/{chat['id']}/messages", headers=world["driver"]["headers"])
    ).json()
    assert [m["text"] for m in history] == ["Буду через 5 минут"]
    reopened = await open_chat(client, world["driver"], world["booking"]["id"])
    assert reopened["can_write"] is False


async def test_no_new_chats_for_finished_trips(client: AsyncClient, world: dict) -> None:
    await finish_trip(world["trip"]["id"])

    response = await client.post(
        CHATS, headers=world["passenger"]["headers"], json={"booking_id": world["booking"]["id"]}
    )

    assert response.status_code == 409
    assert response.json()["code"] == "chat_closed"


async def test_blank_message_rejected(client: AsyncClient, world: dict) -> None:
    chat = await open_chat(client, world["passenger"], world["booking"]["id"])

    body = await say(client, world["passenger"], chat["id"], "   ", expected=422)

    assert body["message"] == "Сообщение не может быть пустым"


# ---------- live delivery over WebSocket ----------


async def test_live_delivery_between_two_accounts(client: AsyncClient, world: dict) -> None:
    chat = await open_chat(client, world["passenger"], world["booking"]["id"])
    driver_token = world["driver"]["access_token"]
    passenger_token = world["passenger"]["access_token"]

    with TestClient(app) as live:
        with (
            live.websocket_connect(f"{CHATS}/ws?token={driver_token}") as driver_ws,
            live.websocket_connect(
                f"{CHATS}/ws", headers={"Authorization": f"Bearer {passenger_token}"}
            ) as passenger_ws,
        ):
            assert driver_ws.receive_json() == {"type": "ready"}
            assert passenger_ws.receive_json() == {"type": "ready"}

            # Passenger sends over REST → the driver gets it instantly over the socket.
            live.post(
                f"{CHATS}/{chat['id']}/messages",
                headers={"Authorization": f"Bearer {passenger_token}"},
                json={"text": "Я на месте"},
            )
            event = driver_ws.receive_json()
            assert event["type"] == "message"
            assert event["chat_id"] == chat["id"]
            assert event["message"]["text"] == "Я на месте"
            assert event["message"]["is_mine"] is False
            echo = passenger_ws.receive_json()
            assert echo["message"]["is_mine"] is True

            # Driver answers over the socket itself → the passenger receives it.
            driver_ws.send_json({"type": "message", "chat_id": chat["id"], "text": "Выхожу"})
            reply = passenger_ws.receive_json()
            assert reply["message"]["text"] == "Выхожу"
            assert reply["message"]["is_mine"] is False
            assert driver_ws.receive_json()["message"]["is_mine"] is True

            # Read receipt reaches the other side.
            passenger_ws.send_json({"type": "read", "chat_id": chat["id"]})
            receipt = driver_ws.receive_json()
            assert receipt["type"] == "read"
            assert receipt["read_id"] == reply["message"]["id"]

            driver_ws.send_json({"type": "ping"})
            assert driver_ws.receive_json() == {"type": "pong"}
            driver_ws.send_json({"type": "message", "chat_id": chat["id"], "text": " "})
            assert driver_ws.receive_json()["type"] == "error"

        history = live.get(
            f"{CHATS}/{chat['id']}/messages", headers={"Authorization": f"Bearer {driver_token}"}
        ).json()
        assert [m["text"] for m in history] == ["Я на месте", "Выхожу"]


async def test_websocket_requires_token(client: AsyncClient) -> None:
    with TestClient(app) as live:
        for url in (f"{CHATS}/ws", f"{CHATS}/ws?token=garbage"):
            with pytest.raises(WebSocketDisconnect) as closed, live.websocket_connect(url):
                pass
            assert closed.value.code == 4401
