"""Add friend requests table

Revision ID: c7c6f8a1b2d3
Revises: a1b2c3d4e5f6
Create Date: 2025-11-26 17:30:00.000000
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "c7c6f8a1b2d3"
down_revision = "a1b2c3d4e5f6"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "friend_requests",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("requester_id", sa.Integer(), nullable=False),
        sa.Column("receiver_id", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="pending"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("responded_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint("requester_id <> receiver_id", name="ck_friend_request_not_self"),
        sa.ForeignKeyConstraint(["receiver_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["requester_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("requester_id", "receiver_id", name="uq_friend_request_pair"),
    )
    with op.batch_alter_table("friend_requests", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_friend_requests_requester_id"), ["requester_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_friend_requests_receiver_id"), ["receiver_id"], unique=False)

    with op.batch_alter_table("friend_requests", schema=None) as batch_op:
        batch_op.alter_column("status", server_default=None)
        batch_op.alter_column("created_at", server_default=None)


def downgrade():
    with op.batch_alter_table("friend_requests", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_friend_requests_receiver_id"))
        batch_op.drop_index(batch_op.f("ix_friend_requests_requester_id"))

    op.drop_table("friend_requests")
