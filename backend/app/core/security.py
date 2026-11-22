import hashlib
import hmac
import secrets
from datetime import UTC, datetime, timedelta
from uuid import UUID

import jwt

from app.core.config import get_settings
from app.core.errors import UnauthorizedError


def utcnow() -> datetime:
    return datetime.now(UTC)


def as_utc(value: datetime) -> datetime:
    """SQLite returns naive datetimes; treat them as UTC."""
    return value if value.tzinfo else value.replace(tzinfo=UTC)


def hash_secret(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def secrets_equal(a: str, b: str) -> bool:
    return hmac.compare_digest(a.encode(), b.encode())


def create_access_token(user_id: UUID) -> tuple[str, int]:
    settings = get_settings()
    now = utcnow()
    ttl = settings.access_token_ttl_seconds
    payload = {
        "sub": str(user_id),
        "type": "access",
        "iat": now,
        "exp": now + timedelta(seconds=ttl),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm), ttl


def decode_access_token(token: str) -> UUID:
    settings = get_settings()
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    except jwt.ExpiredSignatureError as exc:
        raise UnauthorizedError("Сессия истекла", code="token_expired") from exc
    except jwt.InvalidTokenError as exc:
        raise UnauthorizedError("Недействительный токен", code="invalid_token") from exc
    if payload.get("type") != "access":
        raise UnauthorizedError("Недействительный токен", code="invalid_token")
    try:
        return UUID(payload["sub"])
    except (KeyError, ValueError) as exc:
        raise UnauthorizedError("Недействительный токен", code="invalid_token") from exc


def new_refresh_token() -> str:
    return secrets.token_urlsafe(48)
