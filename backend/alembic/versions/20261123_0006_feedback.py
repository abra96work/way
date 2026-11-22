"""reviews, complaints, cancellations

Revision ID: 20261123_0006
Revises: 20261123_0005
Create Date: 2026-11-23
"""

import sqlalchemy as sa

from alembic import op

revision = "20261123_0006"
down_revision = "20261123_0005"
branch_labels = None
depends_on = None


def _enum(name: str, *values: str, length: int = 20) -> sa.Enum:
    return sa.Enum(*values, name=name, native_enum=False, length=length)


def _role() -> sa.Enum:
    return _enum("participant_role", "driver", "passenger", length=10)


def _created_at() -> sa.Column:
    return sa.Column(
        "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
    )


def _fk(table: str, column: str, target: str, ondelete: str) -> sa.ForeignKeyConstraint:
    return sa.ForeignKeyConstraint(
        [column],
        [f"{target}.id"],
        name=op.f(f"fk_{table}_{column}_{target}"),
        ondelete=ondelete,
    )


def upgrade() -> None:
    op.create_table(
        "reviews",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("booking_id", sa.Uuid(), nullable=True),
        sa.Column("author_id", sa.Uuid(), nullable=False),
        sa.Column("target_id", sa.Uuid(), nullable=False),
        sa.Column("target_role", _role(), nullable=False),
        sa.Column("rating", sa.SmallInteger(), nullable=False),
        sa.Column("text", sa.String(length=1000), nullable=True),
        sa.Column("is_hidden", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        _created_at(),
        sa.CheckConstraint("rating BETWEEN 1 AND 5", name=op.f("ck_reviews_rating_range")),
        sa.CheckConstraint("author_id <> target_id", name=op.f("ck_reviews_not_self")),
        _fk("reviews", "trip_id", "trips", "CASCADE"),
        _fk("reviews", "booking_id", "bookings", "SET NULL"),
        _fk("reviews", "author_id", "users", "CASCADE"),
        _fk("reviews", "target_id", "users", "CASCADE"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_reviews")),
        sa.UniqueConstraint(
            "trip_id", "author_id", "target_id", name="uq_reviews_trip_author_target"
        ),
    )
    for column in ("trip_id", "booking_id", "author_id", "target_id"):
        op.create_index(op.f(f"ix_reviews_{column}"), "reviews", [column])

    op.create_table(
        "complaints",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("author_id", sa.Uuid(), nullable=False),
        sa.Column("target_id", sa.Uuid(), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=True),
        sa.Column(
            "reason",
            _enum(
                "complaint_reason",
                "no_show",
                "late",
                "rude",
                "unsafe_driving",
                "vehicle_mismatch",
                "fraud",
                "other",
            ),
            nullable=False,
        ),
        sa.Column("text", sa.String(length=1000), nullable=True),
        sa.Column(
            "status",
            _enum("complaint_status", "new", "in_review", "resolved", "rejected", length=12),
            server_default="new",
            nullable=False,
        ),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        _created_at(),
        sa.CheckConstraint("author_id <> target_id", name=op.f("ck_complaints_not_self")),
        _fk("complaints", "author_id", "users", "CASCADE"),
        _fk("complaints", "target_id", "users", "CASCADE"),
        _fk("complaints", "trip_id", "trips", "SET NULL"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_complaints")),
    )
    for column in ("author_id", "target_id", "trip_id"):
        op.create_index(op.f(f"ix_complaints_{column}"), "complaints", [column])

    op.create_table(
        "cancellations",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("role", _role(), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=True),
        sa.Column("booking_id", sa.Uuid(), nullable=True),
        sa.Column("blocked_until", sa.DateTime(timezone=True), nullable=True),
        _created_at(),
        _fk("cancellations", "user_id", "users", "CASCADE"),
        _fk("cancellations", "trip_id", "trips", "SET NULL"),
        _fk("cancellations", "booking_id", "bookings", "SET NULL"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_cancellations")),
    )
    op.create_index(op.f("ix_cancellations_user_id"), "cancellations", ["user_id"])


def downgrade() -> None:
    op.drop_index(op.f("ix_cancellations_user_id"), table_name="cancellations")
    op.drop_table("cancellations")
    for column in ("author_id", "target_id", "trip_id"):
        op.drop_index(op.f(f"ix_complaints_{column}"), table_name="complaints")
    op.drop_table("complaints")
    for column in ("trip_id", "booking_id", "author_id", "target_id"):
        op.drop_index(op.f(f"ix_reviews_{column}"), table_name="reviews")
    op.drop_table("reviews")
