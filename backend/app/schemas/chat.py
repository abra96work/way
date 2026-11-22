from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.models.feedback import ParticipantRole
from app.schemas.trip import TripStatusView
from app.schemas.user import PublicUser


class ChatOpen(BaseModel):
    booking_id: UUID = Field(description="Бронь, по которой водитель и пассажир общаются")


class MessageCreate(BaseModel):
    text: str = Field(min_length=1, max_length=2000)

    @field_validator("text")
    @classmethod
    def _not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Сообщение не может быть пустым")
        return value


class ChatMessageRead(BaseModel):
    id: int = Field(description="Растущий номер: курсор для догрузки и отметок прочтения")
    chat_id: UUID
    sender_id: UUID
    text: str
    created_at: datetime
    is_mine: bool


class ChatTripBrief(BaseModel):
    id: UUID
    status: TripStatusView
    departure_at: datetime
    origin: str
    destination: str


class ChatRead(BaseModel):
    id: UUID
    trip: ChatTripBrief
    my_role: ParticipantRole
    counterpart: PublicUser
    last_message: ChatMessageRead | None
    unread_count: int
    counterpart_read_id: int = Field(description="До этого id собеседник всё прочитал (галочки)")
    can_write: bool = Field(description="Писать можно, пока поездка не завершена и бронь активна")


class ChatUnread(BaseModel):
    unread: int
