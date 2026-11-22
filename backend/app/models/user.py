import enum
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, String, false
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin
from app.models.city import City


class FacePhotoStatus(enum.StrEnum):
    """Drivers must upload a frontal face photo that an administrator approves."""

    none = "none"
    pending = "pending"
    approved = "approved"
    rejected = "rejected"


class User(TimestampMixin, Base):
    __tablename__ = "users"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    phone: Mapped[str] = mapped_column(String(16), unique=True, index=True)
    first_name: Mapped[str | None] = mapped_column(String(60))
    last_name: Mapped[str | None] = mapped_column(String(60))
    avatar_path: Mapped[str | None] = mapped_column(String(255))
    face_photo_path: Mapped[str | None] = mapped_column(String(255))
    face_photo_status: Mapped[FacePhotoStatus] = mapped_column(
        Enum(FacePhotoStatus, name="face_photo_status", native_enum=False, length=16),
        default=FacePhotoStatus.none,
        server_default=FacePhotoStatus.none.value,
    )
    city_id: Mapped[int | None] = mapped_column(ForeignKey("cities.id", ondelete="SET NULL"))
    blocked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())

    city: Mapped[City | None] = relationship(lazy="joined")

    @property
    def is_profile_complete(self) -> bool:
        return bool(self.first_name and self.city_id)


class AuthCode(TimestampMixin, Base):
    """A requested login code. With SMS disabled the code is the fixed test value."""

    __tablename__ = "auth_codes"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    phone: Mapped[str] = mapped_column(String(16), index=True)
    code_hash: Mapped[str] = mapped_column(String(64))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    attempts: Mapped[int] = mapped_column(default=0, server_default="0")
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class RefreshToken(TimestampMixin, Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
