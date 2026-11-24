"""human-friendly trip numbers («Заказ №1231»)

Revision ID: 20261123_0010
Revises: 20261123_0009
Create Date: 2026-11-23
"""

import sqlalchemy as sa

from alembic import op

revision = "20261123_0010"
down_revision = "20261123_0009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("trips") as batch:
        batch.add_column(sa.Column("number", sa.Integer(), nullable=True))
        batch.create_unique_constraint("uq_trips_number", ["number"])
    # Existing trips get numbers in creation order, starting at 1001.
    bind = op.get_bind()
    ids = bind.execute(sa.text("SELECT id FROM trips ORDER BY created_at, id")).scalars().all()
    for offset, trip_id in enumerate(ids, start=1001):
        bind.execute(
            sa.text("UPDATE trips SET number = :number WHERE id = :id"),
            {"number": offset, "id": trip_id},
        )


def downgrade() -> None:
    with op.batch_alter_table("trips") as batch:
        batch.drop_constraint("uq_trips_number", type_="unique")
        batch.drop_column("number")
