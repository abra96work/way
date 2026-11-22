from fastapi import APIRouter, status

from app.api.deps import DbSession
from app.core.errors import ErrorResponse
from app.schemas.auth import (
    AuthResult,
    CodeRequest,
    CodeRequestResult,
    CodeVerify,
    RefreshRequest,
    TokenPair,
)
from app.services import auth as auth_service
from app.services.users import me_read

router = APIRouter(prefix="/auth", tags=["auth"])

_errors = {
    400: {"model": ErrorResponse},
    401: {"model": ErrorResponse},
    429: {"model": ErrorResponse},
}


@router.post("/request-code", response_model=CodeRequestResult, responses=_errors)
async def request_code(payload: CodeRequest, db: DbSession) -> CodeRequestResult:
    """Отправить код подтверждения. СМС отключены: код всегда `111111`."""
    expires_in = await auth_service.request_code(db, payload.phone)
    return CodeRequestResult(phone=payload.phone, expires_in=expires_in)


@router.post("/verify", response_model=AuthResult, responses=_errors)
async def verify(payload: CodeVerify, db: DbSession) -> AuthResult:
    """Проверить код и войти. Новый пользователь создаётся автоматически."""
    user, is_new = await auth_service.verify_code(db, payload.phone, payload.code)
    tokens = await auth_service.issue_tokens(db, user)
    return AuthResult(
        access_token=tokens.access_token,
        refresh_token=tokens.refresh_token,
        expires_in=tokens.expires_in,
        is_new_user=is_new,
        user=await me_read(db, user),
    )


@router.post("/refresh", response_model=TokenPair, responses=_errors)
async def refresh(payload: RefreshRequest, db: DbSession) -> TokenPair:
    """Обменять refresh-токен на новую пару. Старый refresh-токен перестаёт работать."""
    tokens = await auth_service.rotate_refresh_token(db, payload.refresh_token)
    return TokenPair(
        access_token=tokens.access_token,
        refresh_token=tokens.refresh_token,
        expires_in=tokens.expires_in,
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(payload: RefreshRequest, db: DbSession) -> None:
    await auth_service.revoke_refresh_token(db, payload.refresh_token)
