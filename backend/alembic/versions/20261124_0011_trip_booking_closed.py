"""«Завершить приём пассажиров»: trips.booking_closed_at

Revision ID: 20261124_0011
Revises: 20261123_0010
Create Date: 2026-11-24
"""

import sqlalchemy as sa

from alembic import op

revision = "20261124_0011"
down_revision = "20261123_0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "trips", sa.Column("booking_closed_at", sa.DateTime(timezone=True), nullable=True)
    )


def downgrade() -> None:
    with op.batch_alter_table("trips") as batch:
        batch.drop_column("booking_closed_at")
