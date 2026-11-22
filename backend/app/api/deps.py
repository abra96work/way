from typing import Annotated

from fastapi import Depends, File, UploadFile
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import UnauthorizedError
from app.core.security import decode_access_token
from app.db.session import get_db
from app.models.user import User

DbSession = Annotated[AsyncSession, Depends(get_db)]
ImageFile = Annotated[UploadFile, File(description="JPEG, PNG или WebP до 5 МБ")]

_bearer = HTTPBearer(auto_error=False, description="Access token из /auth/verify")


async def get_current_user(
    db: DbSession,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> User:
    if credentials is None:
        raise UnauthorizedError()
    user_id = decode_access_token(credentials.credentials)
    user = await db.get(User, user_id)
    if user is None:
        raise UnauthorizedError("Пользователь не найден", code="invalid_token")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
