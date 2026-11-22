"""Reviews and complaints between participants of the same trip."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, ConflictError, ForbiddenError, NotFoundError
from app.core.security import as_utc
from app.models.booking import Booking, BookingStatus
from app.models.feedback import Complaint, ParticipantRole, Review
from app.models.trip import Trip, TripStatus
from app.models.user import User
from app.schemas.feedback import ComplaintCreate, ComplaintRead, ReviewCreate, ReviewRead
from app.services import trips as trip_service
from app.services.users import to_public


async def _passenger_booking(db: AsyncSession, trip_id: UUID, user_id: UUID) -> Booking | None:
    """The user's paid booking in the trip: they actually travelled (or sent a parcel)."""
    return await db.scalar(
        select(Booking)
        .where(
            Booking.trip_id == trip_id,
            Booking.passenger_id == user_id,
            Booking.status == BookingStatus.paid,
        )
        .limit(1)
    )


# ---------- reviews ----------


async def create_review(db: AsyncSession, author: User, payload: ReviewCreate) -> Review:
    """Driver ↔ passenger of a finished trip, once per trip and direction."""
    if payload.target_id == author.id:
        raise AppError("Нельзя оставить отзыв о себе", code="review_self")
    trip = await db.get(Trip, payload.trip_id)
    if trip is None:
        raise NotFoundError("Поездка не найдена")
    if trip.status != TripStatus.published or not trip_service.is_finished(trip):
        raise ConflictError(
            "Отзыв можно оставить после завершения поездки", code="trip_not_completed"
        )

    if author.id == trip.driver_id:
        booking = await _passenger_booking(db, trip.id, payload.target_id)
        target_role = ParticipantRole.passenger
    else:
        booking = await _passenger_booking(db, trip.id, author.id)
        target_role = ParticipantRole.driver
        if payload.target_id != trip.driver_id:
            booking = None
    if booking is None:
        raise ForbiddenError(
            "Отзыв могут оставить только водитель и пассажир этой поездки",
            code="not_trip_participants",
        )

    review = Review(
        trip_id=trip.id,
        booking_id=booking.id,
        author_id=author.id,
        target_id=payload.target_id,
        target_role=target_role,
        rating=payload.rating,
        text=payload.text.strip() if payload.text and payload.text.strip() else None,
    )
    db.add(review)
    try:
        await db.commit()
    except IntegrityError as exc:
        await db.rollback()
        raise ConflictError("Вы уже оставили отзыв по этой поездке", code="review_exists") from exc
    return review


async def list_reviews(db: AsyncSession, target_id: UUID, *, limit: int, offset: int) -> list:
    rows = await db.execute(
        select(Review, User)
        .join(User, User.id == Review.author_id)
        .where(Review.target_id == target_id, Review.is_hidden.is_(False))
        .order_by(Review.created_at.desc(), Review.id)
        .limit(limit)
        .offset(offset)
    )
    return [
        ReviewRead(
            id=review.id,
            trip_id=review.trip_id,
            author=to_public(author),
            target_role=review.target_role,
            rating=review.rating,
            text=review.text,
            created_at=as_utc(review.created_at),
        )
        for review, author in rows
    ]


# ---------- complaints ----------


async def _participants(db: AsyncSession, trip: Trip) -> set[UUID]:
    passengers = await db.scalars(
        select(Booking.passenger_id).where(
            Booking.trip_id == trip.id,
            Booking.status.in_(
                (
                    BookingStatus.pending,
                    BookingStatus.awaiting_payment,
                    BookingStatus.paid,
                    BookingStatus.cancelled,
                )
            ),
        )
    )
    return {trip.driver_id, *passengers}


async def create_complaint(db: AsyncSession, author: User, payload: ComplaintCreate) -> Complaint:
    """Only people who met in a trip (driver and its passengers) can complain about each other."""
    if payload.target_id == author.id:
        raise AppError("Нельзя пожаловаться на себя", code="complaint_self")
    trip = await db.get(Trip, payload.trip_id)
    if trip is None:
        raise NotFoundError("Поездка не найдена")
    participants = await _participants(db, trip)
    if {author.id, payload.target_id} - participants or trip.driver_id not in (
        author.id,
        payload.target_id,
    ):
        raise ForbiddenError(
            "Жалобу можно подать только на участника вашей поездки",
            code="not_trip_participants",
        )
    complaint = Complaint(
        author_id=author.id,
        target_id=payload.target_id,
        trip_id=trip.id,
        reason=payload.reason,
        text=payload.text.strip() if payload.text and payload.text.strip() else None,
    )
    db.add(complaint)
    await db.commit()
    return complaint


def complaint_read(complaint: Complaint) -> ComplaintRead:
    return ComplaintRead(
        id=complaint.id,
        trip_id=complaint.trip_id,
        reason=complaint.reason,
        text=complaint.text,
        status=complaint.status,
        created_at=as_utc(complaint.created_at),
    )


async def received_complaints(db: AsyncSession, user: User) -> list[Complaint]:
    """Complaints about the user (profile section "Жалобы")."""
    return list(
        await db.scalars(
            select(Complaint)
            .where(Complaint.target_id == user.id)
            .order_by(Complaint.created_at.desc(), Complaint.id)
        )
    )
