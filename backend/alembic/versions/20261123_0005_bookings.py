"""bookings, payments, notifications

Revision ID: 20261123_0005
Revises: 20261123_0004
Create Date: 2026-11-23
"""

import sqlalchemy as sa

from alembic import op

revision = "20261123_0005"
down_revision = "20261123_0004"
branch_labels = None
depends_on = None


def _enum(name: str, *values: str, length: int = 20) -> sa.Enum:
    return sa.Enum(*values, name=name, native_enum=False, length=length)


def _created_at() -> sa.Column:
    return sa.Column(
        "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
    )


def upgrade() -> None:
    op.create_table(
        "bookings",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("passenger_id", sa.Uuid(), nullable=False),
        sa.Column("kind", _enum("booking_kind", "seat", "parcel", length=8), nullable=False),
        sa.Column(
            "status",
            _enum("booking_status", "pending", "awaiting_payment", "paid", "rejected", "cancelled"),
            nullable=False,
        ),
        sa.Column("from_position", sa.SmallInteger(), nullable=False),
        sa.Column("to_position", sa.SmallInteger(), nullable=False),
        sa.Column("seats", sa.SmallInteger(), nullable=False),
        sa.Column("parcel_size", _enum("parcel_size", "S", "M", "L", length=2), nullable=True),
        sa.Column("driver_price", sa.Integer(), nullable=False),
        sa.Column("commission", sa.Integer(), nullable=False),
        sa.Column("confirmed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "cancelled_by", _enum("cancelled_by", "passenger", "driver", length=12), nullable=True
        ),
        _created_at(),
        sa.CheckConstraint("from_position < to_position", name=op.f("ck_bookings_segment_order")),
        sa.CheckConstraint("seats >= 0", name=op.f("ck_bookings_seats_non_negative")),
        sa.ForeignKeyConstraint(
            ["trip_id"], ["trips.id"], name=op.f("fk_bookings_trip_id_trips"), ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["passenger_id"],
            ["users.id"],
            name=op.f("fk_bookings_passenger_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_bookings")),
    )
    op.create_index(op.f("ix_bookings_trip_id"), "bookings", ["trip_id"])
    op.create_index(op.f("ix_bookings_passenger_id"), "bookings", ["passenger_id"])
    op.create_index(op.f("ix_bookings_status"), "bookings", ["status"])

    op.create_table(
        "booking_extras",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("booking_id", sa.Uuid(), nullable=False),
        sa.Column(
            "kind", _enum("extra_kind", "child_seat", "pets", "luggage", length=16), nullable=False
        ),
        sa.Column("price", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ["booking_id"],
            ["bookings.id"],
            name=op.f("fk_booking_extras_booking_id_bookings"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_booking_extras")),
        sa.UniqueConstraint("booking_id", "kind", name="uq_booking_extras_kind"),
    )
    op.create_index(op.f("ix_booking_extras_booking_id"), "booking_extras", ["booking_id"])

    op.create_table(
        "payments",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("booking_id", sa.Uuid(), nullable=False),
        sa.Column("amount", sa.Integer(), nullable=False),
        sa.Column("provider", sa.String(length=20), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        _created_at(),
        sa.ForeignKeyConstraint(
            ["booking_id"],
            ["bookings.id"],
            name=op.f("fk_payments_booking_id_bookings"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_payments")),
    )
    op.create_index(op.f("ix_payments_booking_id"), "payments", ["booking_id"])

    op.create_table(
        "notifications",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("type", sa.String(length=40), nullable=False),
        sa.Column("title", sa.String(length=120), nullable=False),
        sa.Column("body", sa.String(length=500), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        _created_at(),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_notifications_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_notifications")),
    )
    op.create_index(op.f("ix_notifications_user_id"), "notifications", ["user_id"])


def downgrade() -> None:
    op.drop_index(op.f("ix_notifications_user_id"), table_name="notifications")
    op.drop_table("notifications")
    op.drop_index(op.f("ix_payments_booking_id"), table_name="payments")
    op.drop_table("payments")
    op.drop_index(op.f("ix_booking_extras_booking_id"), table_name="booking_extras")
    op.drop_table("booking_extras")
    op.drop_index(op.f("ix_bookings_status"), table_name="bookings")
    op.drop_index(op.f("ix_bookings_passenger_id"), table_name="bookings")
    op.drop_index(op.f("ix_bookings_trip_id"), table_name="bookings")
    op.drop_table("bookings")
