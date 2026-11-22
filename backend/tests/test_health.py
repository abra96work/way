from httpx import AsyncClient


async def test_health(client: AsyncClient) -> None:
    response = await client.get("/api/v1/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "put-api"}


async def test_unknown_route_uses_error_format(client: AsyncClient) -> None:
    response = await client.get("/api/v1/nope")

    assert response.status_code == 404
    assert response.json() == {"code": "not_found", "message": "Не найдено"}


async def test_non_utf8_body_gets_russian_error(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/request-code",
        content='{"phone": "Тест"}'.encode("cp1251"),
        headers={"Content-Type": "application/json"},
    )

    assert response.status_code in (400, 422)
    assert response.json()["code"] in ("bad_request", "validation_error")
    assert response.json()["message"].isascii() is False
