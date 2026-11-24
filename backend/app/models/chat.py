from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.security import utcnow
from app.db.base import Base

# Integer on SQLite so the primary key autoincrements there too.
MessageId = BigInteger().with_variant(Integer(), "sqlite")


class Chat(Base):
    """Driver ↔ passenger conversation about one trip (one chat per passenger per trip)."""

    __tablename__ = "chats"
    __table_args__ = (UniqueConstraint("trip_id", "passenger_id", name="uq_chats_trip_passenger"),)

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    trip_id: Mapped[UUID] = mapped_column(ForeignKey("trips.id", ondelete="CASCADE"), index=True)
    driver_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    passenger_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    last_message_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    # Read receipts: everything up to this message id is read by that side.
    driver_read_id: Mapped[int] = mapped_column(MessageId, default=0, server_default="0")
    passenger_read_id: Mapped[int] = mapped_column(MessageId, default=0, server_default="0")


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    # Monotonic id doubles as the pagination cursor and the read-receipt marker.
    id: Mapped[int] = mapped_column(MessageId, primary_key=True, autoincrement=True)
    chat_id: Mapped[UUID] = mapped_column(ForeignKey("chats.id", ondelete="CASCADE"), index=True)
    sender_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    text: Mapped[str] = mapped_column(String(2000))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
