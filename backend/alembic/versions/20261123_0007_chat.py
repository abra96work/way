"""driver-passenger chat

Revision ID: 20261123_0007
Revises: 20261123_0006
Create Date: 2026-11-23
"""

import sqlalchemy as sa

from alembic import op

revision = "20261123_0007"
down_revision = "20261123_0006"
branch_labels = None
depends_on = None

MessageId = sa.BigInteger().with_variant(sa.Integer(), "sqlite")


def upgrade() -> None:
    op.create_table(
        "chats",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("driver_id", sa.Uuid(), nullable=False),
        sa.Column("passenger_id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_message_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("driver_read_id", MessageId, server_default="0", nullable=False),
        sa.Column("passenger_read_id", MessageId, server_default="0", nullable=False),
        sa.ForeignKeyConstraint(
            ["trip_id"], ["trips.id"], name=op.f("fk_chats_trip_id_trips"), ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["driver_id"], ["users.id"], name=op.f("fk_chats_driver_id_users"), ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["passenger_id"],
            ["users.id"],
            name=op.f("fk_chats_passenger_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_chats")),
        sa.UniqueConstraint("trip_id", "passenger_id", name="uq_chats_trip_passenger"),
    )
    for column in ("trip_id", "driver_id", "passenger_id", "last_message_at"):
        op.create_index(op.f(f"ix_chats_{column}"), "chats", [column])

    op.create_table(
        "chat_messages",
        sa.Column("id", MessageId, autoincrement=True, nullable=False),
        sa.Column("chat_id", sa.Uuid(), nullable=False),
        sa.Column("sender_id", sa.Uuid(), nullable=False),
        sa.Column("text", sa.String(length=2000), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["chat_id"],
            ["chats.id"],
            name=op.f("fk_chat_messages_chat_id_chats"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["sender_id"],
            ["users.id"],
            name=op.f("fk_chat_messages_sender_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_chat_messages")),
    )
    op.create_index(op.f("ix_chat_messages_chat_id"), "chat_messages", ["chat_id"])


def downgrade() -> None:
    op.drop_index(op.f("ix_chat_messages_chat_id"), table_name="chat_messages")
    op.drop_table("chat_messages")
    for column in ("trip_id", "driver_id", "passenger_id", "last_message_at"):
        op.drop_index(op.f(f"ix_chats_{column}"), table_name="chats")
    op.drop_table("chats")
