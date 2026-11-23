"""approximate arrival time of a trip

Revision ID: 20261123_0008
Revises: 20261123_0007
Create Date: 2026-11-23
"""

import sqlalchemy as sa

from alembic import op

revision = "20261123_0008"
down_revision = "20261123_0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("trips", sa.Column("arrival_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("trips") as batch:
        batch.drop_column("arrival_at")
