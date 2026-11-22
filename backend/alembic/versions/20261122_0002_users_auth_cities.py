"""users, auth and cities

Revision ID: 20261122_0002
Revises: 20261122_0001
Create Date: 2026-11-22
"""

import sqlalchemy as sa

from alembic import op
from app.data.cities import CITIES, REGION

revision = "20261122_0002"
down_revision = "20261122_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    cities = op.create_table(
        "cities",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("region", sa.String(length=120), nullable=False),
        sa.Column("lat", sa.Float(), nullable=False),
        sa.Column("lng", sa.Float(), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_cities")),
    )
    op.create_index(op.f("ix_cities_name"), "cities", ["name"])

    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("phone", sa.String(length=16), nullable=False),
        sa.Column("first_name", sa.String(length=60), nullable=True),
        sa.Column("last_name", sa.String(length=60), nullable=True),
        sa.Column("avatar_path", sa.String(length=255), nullable=True),
        sa.Column("face_photo_path", sa.String(length=255), nullable=True),
        sa.Column(
            "face_photo_status",
            sa.Enum(
                "none", "pending", "approved", "rejected",
                name="face_photo_status", native_enum=False, length=16,
            ),
            server_default="none",
            nullable=False,
        ),
        sa.Column("city_id", sa.Integer(), nullable=True),
        sa.Column("blocked_until", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_admin", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(
            ["city_id"], ["cities.id"],
            name=op.f("fk_users_city_id_cities"), ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_users")),
    )
    op.create_index(op.f("ix_users_phone"), "users", ["phone"], unique=True)

    op.create_table(
        "auth_codes",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("phone", sa.String(length=16), nullable=False),
        sa.Column("code_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("attempts", sa.Integer(), server_default="0", nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_auth_codes")),
    )
    op.create_index(op.f("ix_auth_codes_phone"), "auth_codes", ["phone"])

    op.create_table(
        "refresh_tokens",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"],
            name=op.f("fk_refresh_tokens_user_id_users"), ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_refresh_tokens")),
        sa.UniqueConstraint("token_hash", name=op.f("uq_refresh_tokens_token_hash")),
    )
    op.create_index(op.f("ix_refresh_tokens_user_id"), "refresh_tokens", ["user_id"])

    op.bulk_insert(
        cities,
        [
            {"name": name, "region": REGION, "lat": lat, "lng": lng, "is_active": True}
            for name, lat, lng in CITIES
        ],
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_refresh_tokens_user_id"), table_name="refresh_tokens")
    op.drop_table("refresh_tokens")
    op.drop_index(op.f("ix_auth_codes_phone"), table_name="auth_codes")
    op.drop_table("auth_codes")
    op.drop_index(op.f("ix_users_phone"), table_name="users")
    op.drop_table("users")
    op.drop_index(op.f("ix_cities_name"), table_name="cities")
    op.drop_table("cities")
