"""create trips table

Revision ID: 20261122_0001
Revises:
Create Date: 2026-11-22
"""

import sqlalchemy as sa

from alembic import op

revision = "20261122_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "trips",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("origin", sa.String(length=120), nullable=False),
        sa.Column("destination", sa.String(length=120), nullable=False),
        sa.Column("departure_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("available_seats", sa.Integer(), nullable=False),
        sa.Column("price_per_seat", sa.Numeric(10, 2), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_trips_origin", "trips", ["origin"])
    op.create_index("ix_trips_destination", "trips", ["destination"])
    op.create_index("ix_trips_departure_at", "trips", ["departure_at"])


def downgrade() -> None:
    op.drop_index("ix_trips_departure_at", table_name="trips")
    op.drop_index("ix_trips_destination", table_name="trips")
    op.drop_index("ix_trips_origin", table_name="trips")
    op.drop_table("trips")

