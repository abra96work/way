from dataclasses import dataclass
from datetime import timedelta

from fastapi import status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError, UnauthorizedError
from app.core.security import (
    as_utc,
    create_access_token,
    hash_secret,
    new_refresh_token,
    secrets_equal,
    utcnow,
)
from app.models.user import AuthCode, RefreshToken, User


@dataclass
class IssuedTokens:
    access_token: str
    refresh_token: str
    expires_in: int


async def request_code(db: AsyncSession, phone: str) -> int:
    """Create a login code for the phone. SMS is disabled: the code is the fixed test value."""
    settings = get_settings()
    now = utcnow()
    # Invalidate previously requested codes so only the latest one works.
    await db.execute(
        update(AuthCode)
        .where(AuthCode.phone == phone, AuthCode.used_at.is_(None))
        .values(used_at=now)
    )
    db.add(
        AuthCode(
            phone=phone,
            code_hash=hash_secret(settings.auth_fixed_code),
            expires_at=now + timedelta(seconds=settings.auth_code_ttl_seconds),
        )
    )
    await db.commit()
    return settings.auth_code_ttl_seconds


async def verify_code(db: AsyncSession, phone: str, code: str) -> tuple[User, bool]:
    settings = get_settings()
    now = utcnow()
    auth_code = await db.scalar(
        select(AuthCode)
        .where(AuthCode.phone == phone, AuthCode.used_at.is_(None))
        .order_by(AuthCode.created_at.desc())
        .limit(1)
    )
    if auth_code is None or as_utc(auth_code.expires_at) <= now:
        raise AppError("Код истёк, запросите новый", code="code_expired")
    if auth_code.attempts >= settings.auth_code_max_attempts:
        raise AppError(
            "Слишком много попыток, запросите новый код",
            code="too_many_attempts",
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    auth_code.attempts += 1
    if not secrets_equal(auth_code.code_hash, hash_secret(code)):
        await db.commit()
        raise AppError("Неверный код", code="invalid_code")

    auth_code.used_at = now
    user = await db.scalar(select(User).where(User.phone == phone))
    is_new = user is None
    if user is None:
        user = User(phone=phone)
        db.add(user)
    await db.commit()
    await db.refresh(user)
    return user, is_new


async def issue_tokens(db: AsyncSession, user: User) -> IssuedTokens:
    settings = get_settings()
    access_token, expires_in = create_access_token(user.id)
    refresh_token = new_refresh_token()
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_secret(refresh_token),
            expires_at=utcnow() + timedelta(days=settings.refresh_token_ttl_days),
        )
    )
    await db.commit()
    return IssuedTokens(access_token, refresh_token, expires_in)


async def rotate_refresh_token(db: AsyncSession, refresh_token: str) -> IssuedTokens:
    now = utcnow()
    stored = await db.scalar(
        select(RefreshToken).where(RefreshToken.token_hash == hash_secret(refresh_token))
    )
    if stored is None:
        raise UnauthorizedError("Сессия недействительна", code="invalid_refresh_token")
    if stored.revoked_at is not None:
        # A revoked token was reused: treat as theft and end every session of the user.
        await _revoke_all(db, stored.user_id)
        await db.commit()
        raise UnauthorizedError("Сессия недействительна", code="invalid_refresh_token")
    if as_utc(stored.expires_at) <= now:
        raise UnauthorizedError("Сессия истекла", code="refresh_token_expired")

    user = await db.get(User, stored.user_id)
    if user is None:
        raise UnauthorizedError("Сессия недействительна", code="invalid_refresh_token")
    stored.revoked_at = now
    return await issue_tokens(db, user)


async def revoke_refresh_token(db: AsyncSession, refresh_token: str) -> None:
    await db.execute(
        update(RefreshToken)
        .where(
            RefreshToken.token_hash == hash_secret(refresh_token),
            RefreshToken.revoked_at.is_(None),
        )
        .values(revoked_at=utcnow())
    )
    await db.commit()


async def _revoke_all(db: AsyncSession, user_id) -> None:  # noqa: ANN001
    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == user_id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=utcnow())
    )
