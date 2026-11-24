"""Добавить Челябинск в доступные населённые пункты.

Revision ID: 20261124_0012
Revises: 20261124_0011
Create Date: 2026-11-24
"""

import sqlalchemy as sa

from alembic import op

revision = "20261124_0012"
down_revision = "20261124_0011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    cities = sa.table(
        "cities",
        sa.column("name", sa.String()),
        sa.column("region", sa.String()),
        sa.column("lat", sa.Float()),
        sa.column("lng", sa.Float()),
        sa.column("is_active", sa.Boolean()),
    )
    op.bulk_insert(
        cities,
        [
            {
                "name": "Челябинск",
                "region": "Челябинская область",
                "lat": 55.1644,
                "lng": 61.4368,
                "is_active": True,
            }
        ],
    )


def downgrade() -> None:
    op.execute(sa.text("DELETE FROM cities WHERE name = 'Челябинск'"))
