"""cars and car catalog

Revision ID: 20261122_0003
Revises: 20261122_0002
Create Date: 2026-11-22
"""

import sqlalchemy as sa

from alembic import op
from app.data.car_catalog import CAR_CATALOG

revision = "20261122_0003"
down_revision = "20261122_0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    brands = op.create_table(
        "car_brands",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=60), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_car_brands")),
        sa.UniqueConstraint("name", name=op.f("uq_car_brands_name")),
    )
    models = op.create_table(
        "car_models",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("brand_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=60), nullable=False),
        sa.ForeignKeyConstraint(
            ["brand_id"], ["car_brands.id"],
            name=op.f("fk_car_models_brand_id_car_brands"), ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_car_models")),
        sa.UniqueConstraint("brand_id", "name", name="uq_car_models_brand_id_name"),
    )
    op.create_index(op.f("ix_car_models_brand_id"), "car_models", ["brand_id"])

    op.create_table(
        "cars",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("owner_id", sa.Uuid(), nullable=False),
        sa.Column("model_id", sa.Integer(), nullable=False),
        sa.Column(
            "vehicle_type",
            sa.Enum("car", "bus", name="vehicle_type", native_enum=False, length=8),
            nullable=False,
        ),
        sa.Column("seats", sa.SmallInteger(), nullable=False),
        sa.Column("plate", sa.String(length=12), nullable=True),
        sa.Column("photo_path", sa.String(length=255), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(
            ["owner_id"], ["users.id"],
            name=op.f("fk_cars_owner_id_users"), ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["model_id"], ["car_models.id"],
            name=op.f("fk_cars_model_id_car_models"), ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_cars")),
    )
    op.create_index(op.f("ix_cars_owner_id"), "cars", ["owner_id"])

    brand_names = list(CAR_CATALOG)
    op.bulk_insert(brands, [{"id": i, "name": n} for i, n in enumerate(brand_names, start=1)])
    rows = []
    for brand_id, brand in enumerate(brand_names, start=1):
        rows.extend({"brand_id": brand_id, "name": model} for model in CAR_CATALOG[brand])
    op.bulk_insert(models, rows)
    if op.get_bind().dialect.name == "postgresql":
        # Explicit ids were inserted: move the sequence past them.
        op.execute(
            "SELECT setval(pg_get_serial_sequence('car_brands', 'id'), "
            "(SELECT MAX(id) FROM car_brands))"
        )


def downgrade() -> None:
    op.drop_index(op.f("ix_cars_owner_id"), table_name="cars")
    op.drop_table("cars")
    op.drop_index(op.f("ix_car_models_brand_id"), table_name="car_models")
    op.drop_table("car_models")
    op.drop_table("car_brands")
