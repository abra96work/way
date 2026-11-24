"""Chat API: REST for history and sending, WebSocket for live delivery.

WebSocket protocol (`/api/v1/chats/ws?token=<access_token>`), JSON frames:
  server → client: {"type": "ready"}
                   {"type": "message", "chat_id", "message": ChatMessageRead}
                   {"type": "read", "chat_id", "reader_id", "read_id"}
                   {"type": "pong"} | {"type": "error", "code", "message"}
  client → server: {"type": "ping"}
                   {"type": "message", "chat_id", "text"}   (same as POST …/messages)
                   {"type": "read", "chat_id"}               (same as POST …/read)
"""

import logging
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, status
from pydantic import ValidationError

from app.api.deps import CurrentUser, DbSession
from app.core.errors import AppError, ErrorResponse, UnauthorizedError
from app.core.security import decode_access_token
from app.db.session import SessionLocal
from app.models.user import User
from app.schemas.chat import ChatMessageRead, ChatOpen, ChatRead, ChatUnread, MessageCreate
from app.services import chat as chat_service
from app.services.realtime import hub

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/chats", tags=["chat"])

_errors = {
    401: {"model": ErrorResponse},
    403: {"model": ErrorResponse},
    404: {"model": ErrorResponse},
    409: {"model": ErrorResponse},
}


@router.post("", response_model=ChatRead, responses=_errors)
async def open_chat(payload: ChatOpen, user: CurrentUser, db: DbSession) -> ChatRead:
    """Открыть (или создать) чат по брони. Доступно её пассажиру и водителю поездки."""
    chat = await chat_service.open_chat(db, user, payload.booking_id)
    return await chat_service.chat_read(db, chat, user)


@router.get("", response_model=list[ChatRead], responses=_errors)
async def list_chats(user: CurrentUser, db: DbSession) -> list[ChatRead]:
    """Все чаты пользователя, свежие сверху, с последним сообщением и счётчиком непрочитанных."""
    return [
        await chat_service.chat_read(db, c, user) for c in await chat_service.list_chats(db, user)
    ]


@router.get("/unread-count", response_model=ChatUnread, responses=_errors)
async def unread_count(user: CurrentUser, db: DbSession) -> ChatUnread:
    return ChatUnread(unread=await chat_service.unread_total(db, user))


@router.get("/{chat_id}", response_model=ChatRead, responses=_errors)
async def get_chat(chat_id: UUID, user: CurrentUser, db: DbSession) -> ChatRead:
    chat = await chat_service.get_chat(db, user, chat_id)
    return await chat_service.chat_read(db, chat, user)


@router.get("/{chat_id}/messages", response_model=list[ChatMessageRead], responses=_errors)
async def messages(
    chat_id: UUID,
    user: CurrentUser,
    db: DbSession,
    after_id: Annotated[int | None, Query(ge=0, description="Только новее этого id")] = None,
    before_id: Annotated[int | None, Query(ge=1, description="Страница до этого id")] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> list[ChatMessageRead]:
    """Сообщения от старых к новым. Без параметров — последняя страница."""
    chat = await chat_service.get_chat(db, user, chat_id)
    items = await chat_service.list_messages(
        db, chat, after_id=after_id, before_id=before_id, limit=limit
    )
    return [chat_service.message_read(m, user.id) for m in items]


@router.post(
    "/{chat_id}/messages",
    response_model=ChatMessageRead,
    status_code=status.HTTP_201_CREATED,
    responses=_errors,
)
async def send(
    chat_id: UUID, payload: MessageCreate, user: CurrentUser, db: DbSession
) -> ChatMessageRead:
    """Отправить сообщение. Собеседник получает его сразу по WebSocket."""
    message = await chat_service.send_message(db, user, chat_id, payload.text)
    return chat_service.message_read(message, user.id)


@router.post("/{chat_id}/read", response_model=ChatRead, responses=_errors)
async def mark_read(chat_id: UUID, user: CurrentUser, db: DbSession) -> ChatRead:
    """Отметить всё прочитанным; собеседник получает событие `read`."""
    chat = await chat_service.mark_read(db, user, chat_id)
    return await chat_service.chat_read(db, chat, user)


# ---------- WebSocket ----------


async def _ws_user(websocket: WebSocket, token: str | None) -> User | None:
    auth = websocket.headers.get("authorization", "")
    if not token and auth.lower().startswith("bearer "):
        token = auth[7:]
    if not token:
        return None
    try:
        user_id = decode_access_token(token)
    except UnauthorizedError:
        return None
    async with SessionLocal() as db:
        return await db.get(User, user_id)


async def _handle(user: User, frame: dict[str, Any]) -> dict[str, Any] | None:
    kind = frame.get("type")
    if kind == "ping":
        return {"type": "pong"}
    async with SessionLocal() as db:
        fresh_user = await db.get(User, user.id)
        if kind == "message":
            text = MessageCreate(text=str(frame.get("text", ""))).text
            await chat_service.send_message(db, fresh_user, UUID(str(frame["chat_id"])), text)
            return None  # the message itself is pushed to both sides by the service
        if kind == "read":
            await chat_service.mark_read(db, fresh_user, UUID(str(frame["chat_id"])))
            return None
    return {"type": "error", "code": "unknown_type", "message": "Неизвестный тип события"}


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str | None = None) -> None:
    """Живой канал: новые сообщения и отметки прочтения. Токен — `?token=` или Bearer."""
    user = await _ws_user(websocket, token)
    if user is None:
        await websocket.close(code=4401, reason="unauthorized")
        return
    await websocket.accept()
    hub.connect(user.id, websocket)
    try:
        await websocket.send_json({"type": "ready"})
        while True:
            frame = await websocket.receive_json()
            try:
                reply = await _handle(user, frame if isinstance(frame, dict) else {})
            except AppError as exc:
                reply = {"type": "error", "code": exc.code, "message": exc.message}
            except (ValidationError, KeyError, ValueError):
                reply = {"type": "error", "code": "bad_frame", "message": "Некорректное событие"}
            if reply is not None:
                await websocket.send_json(reply)
    except WebSocketDisconnect:
        pass
    finally:
        hub.disconnect(user.id, websocket)
