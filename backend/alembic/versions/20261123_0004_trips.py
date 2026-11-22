"""replace prototype trips with full trip model

Revision ID: 20261123_0004
Revises: 20261122_0003
Create Date: 2026-11-23

The prototype `trips` table (origin/destination strings) was never used by the client,
so it is dropped instead of migrated.
"""

import sqlalchemy as sa

from alembic import op

revision = "20261123_0004"
down_revision = "20261122_0003"
branch_labels = None
depends_on = None


def _enum(name: str, *values: str, length: int = 16) -> sa.Enum:
    return sa.Enum(*values, name=name, native_enum=False, length=length)


def upgrade() -> None:
    op.drop_index("ix_trips_departure_at", table_name="trips")
    op.drop_index("ix_trips_destination", table_name="trips")
    op.drop_index("ix_trips_origin", table_name="trips")
    op.drop_table("trips")

    op.create_table(
        "trips",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("driver_id", sa.Uuid(), nullable=False),
        sa.Column("car_id", sa.Uuid(), nullable=False),
        sa.Column(
            "status", _enum("trip_status", "draft", "published", "cancelled"), nullable=False
        ),
        sa.Column("departure_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("seats_total", sa.SmallInteger(), nullable=False),
        sa.Column("booking_mode", _enum("booking_mode", "manual", "instant"), nullable=False),
        sa.Column("full_price", sa.Integer(), nullable=False),
        sa.Column("min_price", sa.Integer(), nullable=False),
        sa.Column("return_of_trip_id", sa.Uuid(), nullable=True),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("seats_total > 0", name=op.f("ck_trips_seats_positive")),
        sa.CheckConstraint(
            "min_price >= 0 AND min_price <= full_price", name=op.f("ck_trips_min_price_range")
        ),
        sa.ForeignKeyConstraint(
            ["driver_id"], ["users.id"], name=op.f("fk_trips_driver_id_users"), ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["car_id"], ["cars.id"], name=op.f("fk_trips_car_id_cars"), ondelete="RESTRICT"
        ),
        sa.ForeignKeyConstraint(
            ["return_of_trip_id"],
            ["trips.id"],
            name=op.f("fk_trips_return_of_trip_id_trips"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_trips")),
    )
    op.create_index(op.f("ix_trips_driver_id"), "trips", ["driver_id"])
    op.create_index(op.f("ix_trips_car_id"), "trips", ["car_id"])
    op.create_index(op.f("ix_trips_status"), "trips", ["status"])
    op.create_index(op.f("ix_trips_departure_at"), "trips", ["departure_at"])

    op.create_table(
        "trip_stops",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("position", sa.SmallInteger(), nullable=False),
        sa.Column("city_id", sa.Integer(), nullable=False),
        sa.Column("address", sa.String(length=200), nullable=False),
        sa.Column("lat", sa.Float(), nullable=True),
        sa.Column("lng", sa.Float(), nullable=True),
        sa.ForeignKeyConstraint(
            ["trip_id"], ["trips.id"], name=op.f("fk_trip_stops_trip_id_trips"), ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["city_id"],
            ["cities.id"],
            name=op.f("fk_trip_stops_city_id_cities"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_trip_stops")),
        sa.UniqueConstraint("trip_id", "position", name="uq_trip_stops_trip_position"),
    )
    op.create_index(op.f("ix_trip_stops_trip_id"), "trip_stops", ["trip_id"])
    op.create_index(op.f("ix_trip_stops_city_id"), "trip_stops", ["city_id"])

    op.create_table(
        "trip_segment_prices",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("from_position", sa.SmallInteger(), nullable=False),
        sa.Column("to_position", sa.SmallInteger(), nullable=False),
        sa.Column("price", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ["trip_id"],
            ["trips.id"],
            name=op.f("fk_trip_segment_prices_trip_id_trips"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_trip_segment_prices")),
        sa.UniqueConstraint("trip_id", "from_position", "to_position", name="uq_trip_segment_pair"),
    )
    op.create_index(op.f("ix_trip_segment_prices_trip_id"), "trip_segment_prices", ["trip_id"])

    op.create_table(
        "trip_extras",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("kind", _enum("extra_kind", "child_seat", "pets", "luggage"), nullable=False),
        sa.Column("price", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ["trip_id"], ["trips.id"], name=op.f("fk_trip_extras_trip_id_trips"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_trip_extras")),
        sa.UniqueConstraint("trip_id", "kind", name="uq_trip_extras_trip_kind"),
    )
    op.create_index(op.f("ix_trip_extras_trip_id"), "trip_extras", ["trip_id"])

    op.create_table(
        "trip_parcel_prices",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("size", _enum("parcel_size", "S", "M", "L", length=2), nullable=False),
        sa.Column("price", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ["trip_id"],
            ["trips.id"],
            name=op.f("fk_trip_parcel_prices_trip_id_trips"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_trip_parcel_prices")),
        sa.UniqueConstraint("trip_id", "size", name="uq_trip_parcel_trip_size"),
    )
    op.create_index(op.f("ix_trip_parcel_prices_trip_id"), "trip_parcel_prices", ["trip_id"])


def downgrade() -> None:
    op.drop_index(op.f("ix_trip_parcel_prices_trip_id"), table_name="trip_parcel_prices")
    op.drop_table("trip_parcel_prices")
    op.drop_index(op.f("ix_trip_extras_trip_id"), table_name="trip_extras")
    op.drop_table("trip_extras")
    op.drop_index(op.f("ix_trip_segment_prices_trip_id"), table_name="trip_segment_prices")
    op.drop_table("trip_segment_prices")
    op.drop_index(op.f("ix_trip_stops_city_id"), table_name="trip_stops")
    op.drop_index(op.f("ix_trip_stops_trip_id"), table_name="trip_stops")
    op.drop_table("trip_stops")
    op.drop_index(op.f("ix_trips_departure_at"), table_name="trips")
    op.drop_index(op.f("ix_trips_status"), table_name="trips")
    op.drop_index(op.f("ix_trips_car_id"), table_name="trips")
    op.drop_index(op.f("ix_trips_driver_id"), table_name="trips")
    op.drop_table("trips")

    # Restore the prototype table from revision 20261122_0001.
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
