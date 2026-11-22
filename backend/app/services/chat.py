"""Driver ↔ passenger chat.

A chat belongs to a trip and one passenger. Either side can open it from a booking.
Writing is allowed while the trip is upcoming (not cancelled or finished) and the
passenger still has an active booking ("только по незавершённым поездкам"); the history
stays readable. New messages and read receipts are pushed live to both participants.
"""

from uuid import UUID

from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ConflictError, ForbiddenError, NotFoundError
from app.core.security import as_utc, utcnow
from app.models.booking import ACTIVE_BOOKING_STATUSES, Booking
from app.models.chat import Chat, ChatMessage
from app.models.feedback import ParticipantRole
from app.models.trip import Trip, TripStatus, TripStop
from app.models.user import User
from app.schemas.chat import ChatMessageRead, ChatRead, ChatTripBrief
from app.services import trips as trip_service
from app.services.realtime import hub
from app.services.users import to_public

# ---------- access ----------


def _role(chat: Chat, user: User) -> ParticipantRole:
    if user.id == chat.driver_id:
        return ParticipantRole.driver
    if user.id == chat.passenger_id:
        return ParticipantRole.passenger
    raise NotFoundError("Чат не найден")


async def get_chat(db: AsyncSession, user: User, chat_id: UUID) -> Chat:
    chat = await db.get(Chat, chat_id)
    if chat is None:
        raise NotFoundError("Чат не найден")
    _role(chat, user)
    return chat


async def _writable(db: AsyncSession, trip_id: UUID, passenger_id: UUID) -> bool:
    trip = await db.get(Trip, trip_id)
    if trip is None or trip.status != TripStatus.published or trip_service.is_finished(trip):
        return False
    active = await db.scalar(
        select(Booking.id)
        .where(
            Booking.trip_id == trip_id,
            Booking.passenger_id == passenger_id,
            Booking.status.in_(ACTIVE_BOOKING_STATUSES),
        )
        .limit(1)
    )
    return active is not None


async def can_write(db: AsyncSession, chat: Chat) -> bool:
    return await _writable(db, chat.trip_id, chat.passenger_id)


async def open_chat(db: AsyncSession, user: User, booking_id: UUID) -> Chat:
    """Get or create the chat for a booking; only its passenger and driver may open it."""
    booking = await db.get(Booking, booking_id)
    trip = await db.get(Trip, booking.trip_id) if booking else None
    if booking is None or trip is None or user.id not in (booking.passenger_id, trip.driver_id):
        raise NotFoundError("Бронь не найдена")
    query = select(Chat).where(Chat.trip_id == trip.id, Chat.passenger_id == booking.passenger_id)
    chat = await db.scalar(query)
    if chat is not None:
        return chat  # existing history stays readable even after the trip
    if not await _writable(db, trip.id, booking.passenger_id):
        raise ConflictError("Чат доступен только по незавершённым поездкам", code="chat_closed")
    chat = Chat(trip_id=trip.id, driver_id=trip.driver_id, passenger_id=booking.passenger_id)
    db.add(chat)
    try:
        await db.commit()
    except IntegrityError:  # opened concurrently by the other side
        await db.rollback()
        chat = await db.scalar(query)
    return chat


# ---------- serialization ----------


def message_read(message: ChatMessage, viewer_id: UUID) -> ChatMessageRead:
    return ChatMessageRead(
        id=message.id,
        chat_id=message.chat_id,
        sender_id=message.sender_id,
        text=message.text,
        created_at=as_utc(message.created_at),
        is_mine=message.sender_id == viewer_id,
    )


async def _unread(db: AsyncSession, chat: Chat, user: User) -> int:
    read_id = (
        chat.driver_read_id
        if _role(chat, user) == ParticipantRole.driver
        else (chat.passenger_read_id)
    )
    count = await db.scalar(
        select(func.count())
        .select_from(ChatMessage)
        .where(
            ChatMessage.chat_id == chat.id,
            ChatMessage.sender_id != user.id,
            ChatMessage.id > read_id,
        )
    )
    return count or 0


async def chat_read(db: AsyncSession, chat: Chat, user: User) -> ChatRead:
    role = _role(chat, user)
    trip = await db.get(Trip, chat.trip_id)
    stops = list(
        await db.scalars(
            select(TripStop).where(TripStop.trip_id == trip.id).order_by(TripStop.position)
        )
    )
    counterpart_id = chat.passenger_id if role == ParticipantRole.driver else chat.driver_id
    counterpart = await db.get(User, counterpart_id)
    last = await db.scalar(
        select(ChatMessage)
        .where(ChatMessage.chat_id == chat.id)
        .order_by(ChatMessage.id.desc())
        .limit(1)
    )
    return ChatRead(
        id=chat.id,
        trip=ChatTripBrief(
            id=trip.id,
            status=trip_service.effective_status(trip),
            departure_at=as_utc(trip.departure_at),
            origin=stops[0].city.name,
            destination=stops[-1].city.name,
        ),
        my_role=role,
        counterpart=to_public(counterpart),
        last_message=message_read(last, user.id) if last else None,
        unread_count=await _unread(db, chat, user),
        counterpart_read_id=(
            chat.passenger_read_id if role == ParticipantRole.driver else chat.driver_read_id
        ),
        can_write=await can_write(db, chat),
    )


# ---------- reading ----------


async def list_chats(db: AsyncSession, user: User) -> list[Chat]:
    return list(
        await db.scalars(
            select(Chat)
            .where(or_(Chat.driver_id == user.id, Chat.passenger_id == user.id))
            .order_by(Chat.last_message_at.desc().nulls_last(), Chat.created_at.desc())
        )
    )


async def unread_total(db: AsyncSession, user: User) -> int:
    return sum([await _unread(db, chat, user) for chat in await list_chats(db, user)])


async def list_messages(
    db: AsyncSession,
    chat: Chat,
    *,
    after_id: int | None,
    before_id: int | None,
    limit: int,
) -> list[ChatMessage]:
    """Oldest-first page. `after_id` fetches what's new; otherwise the latest page
    (or the one before `before_id`) for scrolling up through history."""
    query = select(ChatMessage).where(ChatMessage.chat_id == chat.id)
    if after_id is not None:
        rows = await db.scalars(
            query.where(ChatMessage.id > after_id).order_by(ChatMessage.id).limit(limit)
        )
        return list(rows)
    if before_id is not None:
        query = query.where(ChatMessage.id < before_id)
    rows = await db.scalars(query.order_by(ChatMessage.id.desc()).limit(limit))
    return list(reversed(list(rows)))


# ---------- writing ----------


async def send_message(db: AsyncSession, user: User, chat_id: UUID, text: str) -> ChatMessage:
    chat = await get_chat(db, user, chat_id)
    if not await can_write(db, chat):
        raise ConflictError(
            "Писать можно только по незавершённым поездкам с активной бронью", code="chat_closed"
        )
    if user.blocked_until and as_utc(user.blocked_until) > utcnow():
        raise ForbiddenError("Аккаунт временно заблокирован", code="user_blocked")
    message = ChatMessage(chat_id=chat.id, sender_id=user.id, text=text)
    db.add(message)
    await db.flush()
    chat.last_message_at = message.created_at
    # The sender has obviously read everything up to their own message.
    if _role(chat, user) == ParticipantRole.driver:
        chat.driver_read_id = message.id
    else:
        chat.passenger_read_id = message.id
    await db.commit()
    for participant in (chat.driver_id, chat.passenger_id):
        await hub.send(
            participant,
            {
                "type": "message",
                "chat_id": str(chat.id),
                "message": message_read(message, participant).model_dump(mode="json"),
            },
        )
    return message


async def mark_read(db: AsyncSession, user: User, chat_id: UUID) -> Chat:
    chat = await get_chat(db, user, chat_id)
    last_id = await db.scalar(
        select(func.max(ChatMessage.id)).where(ChatMessage.chat_id == chat.id)
    )
    last_id = last_id or 0
    role = _role(chat, user)
    current = chat.driver_read_id if role == ParticipantRole.driver else chat.passenger_read_id
    if last_id > current:
        if role == ParticipantRole.driver:
            chat.driver_read_id = last_id
        else:
            chat.passenger_read_id = last_id
        await db.commit()
        counterpart = chat.passenger_id if role == ParticipantRole.driver else chat.driver_id
        await hub.send(
            counterpart,
            {
                "type": "read",
                "chat_id": str(chat.id),
                "reader_id": str(user.id),
                "read_id": last_id,
            },
        )
    return chat
