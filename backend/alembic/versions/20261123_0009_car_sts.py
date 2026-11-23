"""photo of the car registration certificate (СТС)

Revision ID: 20261123_0009
Revises: 20261123_0008
Create Date: 2026-11-23
"""

import sqlalchemy as sa

from alembic import op

revision = "20261123_0009"
down_revision = "20261123_0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("cars", sa.Column("sts_photo_path", sa.String(255), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("cars") as batch:
        batch.drop_column("sts_photo_path")
