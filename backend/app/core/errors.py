"""Unified API error format: {"code": "...", "message": "...", "details": ...}.

`code` is a stable machine-readable identifier for the client, `message` is a
Russian text the client may show to the user as is.
"""

from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from starlette.exceptions import HTTPException as StarletteHTTPException


class ErrorResponse(BaseModel):
    code: str
    message: str
    details: Any | None = None


class AppError(Exception):
    status_code: int = status.HTTP_400_BAD_REQUEST
    code: str = "bad_request"
    message: str = "Некорректный запрос"

    def __init__(
        self,
        message: str | None = None,
        *,
        code: str | None = None,
        status_code: int | None = None,
        details: Any | None = None,
    ) -> None:
        self.message = message or self.message
        self.code = code or self.code
        self.status_code = status_code or self.status_code
        self.details = details
        super().__init__(self.message)


class NotFoundError(AppError):
    status_code = status.HTTP_404_NOT_FOUND
    code = "not_found"
    message = "Не найдено"


class UnauthorizedError(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED
    code = "unauthorized"
    message = "Требуется авторизация"


class ForbiddenError(AppError):
    status_code = status.HTTP_403_FORBIDDEN
    code = "forbidden"
    message = "Недостаточно прав"


class ConflictError(AppError):
    status_code = status.HTTP_409_CONFLICT
    code = "conflict"
    message = "Конфликт состояния"


_HTTP_CODES = {
    400: ("bad_request", "Некорректный запрос: тело должно быть JSON в UTF-8"),
    401: ("unauthorized", "Требуется авторизация"),
    403: ("forbidden", "Недостаточно прав"),
    404: ("not_found", "Не найдено"),
    405: ("method_not_allowed", "Метод не поддерживается"),
}


def _response(status_code: int, body: ErrorResponse, headers: dict | None = None) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content=jsonable_encoder(body, exclude_none=True),
        headers=headers,
    )


async def app_error_handler(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, AppError)
    headers = {"WWW-Authenticate": "Bearer"} if exc.status_code == 401 else None
    return _response(
        exc.status_code,
        ErrorResponse(code=exc.code, message=exc.message, details=exc.details),
        headers,
    )


async def validation_error_handler(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, RequestValidationError)
    details = [
        {"loc": list(err.get("loc", ())), "msg": err.get("msg"), "type": err.get("type")}
        for err in exc.errors()
    ]
    # Business-rule messages from our validators are Russian and ready to show.
    message = "Проверьте введённые данные"
    value_errors = [err for err in exc.errors() if err.get("type") == "value_error"]
    if value_errors:
        message = str(value_errors[0]["ctx"]["error"])
    return _response(
        status.HTTP_422_UNPROCESSABLE_CONTENT,
        ErrorResponse(code="validation_error", message=message, details=details),
    )


async def http_error_handler(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, StarletteHTTPException)
    code, message = _HTTP_CODES.get(exc.status_code, ("http_error", str(exc.detail)))
    return _response(
        exc.status_code,
        ErrorResponse(code=code, message=message),
        getattr(exc, "headers", None),
    )


def register_error_handlers(app: FastAPI) -> None:
    app.add_exception_handler(AppError, app_error_handler)
    app.add_exception_handler(RequestValidationError, validation_error_handler)
    app.add_exception_handler(StarletteHTTPException, http_error_handler)
