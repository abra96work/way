"""Local file storage for user images. Swap for S3 later behind the same functions."""

from pathlib import PurePosixPath
from uuid import uuid4

from fastapi import UploadFile, status

from app.core.config import get_settings
from app.core.errors import AppError

_SIGNATURES: list[tuple[bytes, str]] = [
    (b"\xff\xd8\xff", "jpg"),
    (b"\x89PNG\r\n\x1a\n", "png"),
]


def _detect_extension(head: bytes) -> str | None:
    for signature, ext in _SIGNATURES:
        if head.startswith(signature):
            return ext
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return "webp"
    return None


async def save_image(upload: UploadFile, folder: str) -> str:
    """Validate and store an image; returns its path relative to the media dir."""
    settings = get_settings()
    data = await upload.read(settings.max_upload_bytes + 1)
    if len(data) > settings.max_upload_bytes:
        raise AppError(
            f"Файл больше {settings.max_upload_bytes // (1024 * 1024)} МБ",
            code="file_too_large",
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
        )
    ext = _detect_extension(data[:16])
    if ext is None:
        raise AppError(
            "Поддерживаются только изображения JPEG, PNG или WebP",
            code="unsupported_file_type",
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
        )

    relative = PurePosixPath(folder) / f"{uuid4().hex}.{ext}"
    target = settings.media_dir / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    return str(relative)


def delete_media(relative_path: str | None) -> None:
    if not relative_path:
        return
    settings = get_settings()
    target = (settings.media_dir / relative_path).resolve()
    if settings.media_dir.resolve() in target.parents:
        target.unlink(missing_ok=True)


def media_url(relative_path: str | None) -> str | None:
    """URL relative to the API host, e.g. /media/avatars/abc.jpg."""
    if not relative_path:
        return None
    return f"{get_settings().media_url_prefix}/{relative_path}"
