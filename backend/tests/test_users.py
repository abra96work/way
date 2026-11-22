from httpx import AsyncClient

from app.core.config import get_settings
from tests.conftest import login

PNG_1PX = bytes.fromhex(
    "89504e470d0a1a0a0000000d4948445200000001000000010806000000"
    "1f15c4890000000d49444154789c6360000002000154a24f5d0000000049454e44ae426082"
)


async def test_complete_profile(client: AsyncClient, auth: dict) -> None:
    cities = (await client.get("/api/v1/cities")).json()

    response = await client.patch(
        "/api/v1/me",
        headers=auth["headers"],
        json={"first_name": "  Иван ", "last_name": "Петров", "city_id": cities[0]["id"]},
    )

    assert response.status_code == 200
    me = response.json()
    assert me["first_name"] == "Иван"
    assert me["city"]["id"] == cities[0]["id"]
    assert me["is_profile_complete"] is True
    assert me["created_at"].endswith(("Z", "+00:00"))


async def test_unknown_city_rejected(client: AsyncClient, auth: dict) -> None:
    response = await client.patch("/api/v1/me", headers=auth["headers"], json={"city_id": 99999})

    assert response.status_code == 400
    assert response.json()["code"] == "city_not_available"


async def test_blank_first_name_rejected(client: AsyncClient, auth: dict) -> None:
    response = await client.patch("/api/v1/me", headers=auth["headers"], json={"first_name": "   "})

    assert response.status_code == 400
    assert response.json()["code"] == "first_name_required"


async def test_avatar_upload_and_replace(client: AsyncClient, auth: dict) -> None:
    media_dir = get_settings().media_dir
    first = await client.put(
        "/api/v1/me/avatar",
        headers=auth["headers"],
        files={"file": ("a.png", PNG_1PX, "image/png")},
    )
    assert first.status_code == 200
    first_url = first.json()["avatar_url"]
    assert first_url.startswith("/media/avatars/") and first_url.endswith(".png")
    assert (await client.get(first_url)).status_code == 200

    second = await client.put(
        "/api/v1/me/avatar",
        headers=auth["headers"],
        files={"file": ("b.png", PNG_1PX, "image/png")},
    )
    second_url = second.json()["avatar_url"]
    assert second_url != first_url
    assert not (media_dir / first_url.removeprefix("/media/")).exists()


async def test_avatar_rejects_non_image(client: AsyncClient, auth: dict) -> None:
    response = await client.put(
        "/api/v1/me/avatar",
        headers=auth["headers"],
        files={"file": ("a.png", b"not an image at all", "image/png")},
    )

    assert response.status_code == 415
    assert response.json()["code"] == "unsupported_file_type"


async def test_face_photo_goes_to_review(client: AsyncClient, auth: dict) -> None:
    response = await client.put(
        "/api/v1/me/face-photo",
        headers=auth["headers"],
        files={"file": ("f.png", PNG_1PX, "image/png")},
    )

    assert response.status_code == 200
    assert response.json()["face_photo_status"] == "pending"


async def test_public_profile_hides_phone(client: AsyncClient, auth: dict) -> None:
    other = await login(client, phone="+79007654321")

    response = await client.get(f"/api/v1/users/{other['user']['id']}", headers=auth["headers"])

    assert response.status_code == 200
    assert "phone" not in response.json()


async def test_cities_search_is_case_and_yo_insensitive(client: AsyncClient) -> None:
    response = await client.get("/api/v1/cities", params={"query": "березов"})

    assert response.status_code == 200
    assert [city["name"] for city in response.json()] == ["Берёзовский"]


async def test_cities_list_sorted(client: AsyncClient) -> None:
    names = [city["name"] for city in (await client.get("/api/v1/cities")).json()]

    assert names == sorted(names)
    assert len(names) >= 20
