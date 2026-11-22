import pytest
from httpx import AsyncClient

from app.schemas.auth import normalize_phone
from tests.conftest import TEST_CODE, login

PHONE = "+79001234567"


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("+7 (900) 123-45-67", "+79001234567"),
        ("89001234567", "+79001234567"),
        ("79001234567", "+79001234567"),
        ("9001234567", "+79001234567"),
        ("+375291234567", "+375291234567"),
    ],
)
def test_normalize_phone(raw: str, expected: str) -> None:
    assert normalize_phone(raw) == expected


@pytest.mark.parametrize("raw", ["123", "+7900abc4567", "", "+0123456789"])
def test_normalize_phone_rejects_garbage(raw: str) -> None:
    with pytest.raises(ValueError):
        normalize_phone(raw)


async def test_new_user_login_flow(client: AsyncClient) -> None:
    response = await client.post("/api/v1/auth/request-code", json={"phone": "8 900 123 45 67"})
    assert response.status_code == 200
    assert response.json()["phone"] == PHONE

    response = await client.post("/api/v1/auth/verify", json={"phone": PHONE, "code": TEST_CODE})
    assert response.status_code == 200
    body = response.json()
    assert body["is_new_user"] is True
    assert body["token_type"] == "bearer"
    assert body["user"]["phone"] == PHONE
    assert body["user"]["is_profile_complete"] is False


async def test_second_login_is_not_new_user(client: AsyncClient) -> None:
    first = await login(client)
    second = await login(client)

    assert first["user"]["id"] == second["user"]["id"]
    assert second["is_new_user"] is False


async def test_wrong_code(client: AsyncClient) -> None:
    await client.post("/api/v1/auth/request-code", json={"phone": PHONE})
    response = await client.post("/api/v1/auth/verify", json={"phone": PHONE, "code": "000000"})

    assert response.status_code == 400
    assert response.json()["code"] == "invalid_code"


async def test_verify_without_request(client: AsyncClient) -> None:
    response = await client.post("/api/v1/auth/verify", json={"phone": PHONE, "code": TEST_CODE})

    assert response.status_code == 400
    assert response.json()["code"] == "code_expired"


async def test_code_cannot_be_reused(client: AsyncClient) -> None:
    await login(client)
    response = await client.post("/api/v1/auth/verify", json={"phone": PHONE, "code": TEST_CODE})

    assert response.status_code == 400
    assert response.json()["code"] == "code_expired"


async def test_too_many_attempts(client: AsyncClient) -> None:
    await client.post("/api/v1/auth/request-code", json={"phone": PHONE})
    for _ in range(5):
        await client.post("/api/v1/auth/verify", json={"phone": PHONE, "code": "000000"})
    response = await client.post("/api/v1/auth/verify", json={"phone": PHONE, "code": TEST_CODE})

    assert response.status_code == 429
    assert response.json()["code"] == "too_many_attempts"


async def test_invalid_phone_is_validation_error(client: AsyncClient) -> None:
    response = await client.post("/api/v1/auth/request-code", json={"phone": "abc"})

    assert response.status_code == 422
    assert response.json()["code"] == "validation_error"


async def test_refresh_rotates_tokens(client: AsyncClient) -> None:
    tokens = await login(client)

    response = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert response.status_code == 200
    rotated = response.json()
    assert rotated["refresh_token"] != tokens["refresh_token"]

    me = await client.get(
        "/api/v1/me", headers={"Authorization": f"Bearer {rotated['access_token']}"}
    )
    assert me.status_code == 200


async def test_reused_refresh_token_revokes_all_sessions(client: AsyncClient) -> None:
    tokens = await login(client)
    rotated = (
        await client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    ).json()

    reuse = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert reuse.status_code == 401
    assert reuse.json()["code"] == "invalid_refresh_token"

    after = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": rotated["refresh_token"]}
    )
    assert after.status_code == 401


async def test_logout_revokes_refresh_token(client: AsyncClient) -> None:
    tokens = await login(client)

    response = await client.post(
        "/api/v1/auth/logout", json={"refresh_token": tokens["refresh_token"]}
    )
    assert response.status_code == 204

    response = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert response.status_code == 401


async def test_me_requires_token(client: AsyncClient) -> None:
    response = await client.get("/api/v1/me")

    assert response.status_code == 401
    assert response.json()["code"] == "unauthorized"


async def test_me_rejects_garbage_token(client: AsyncClient) -> None:
    response = await client.get("/api/v1/me", headers={"Authorization": "Bearer nonsense"})

    assert response.status_code == 401
    assert response.json()["code"] == "invalid_token"
