"""Add activity count to users

Revision ID: d2e4f6a8b9c0
Revises: b7c9d1e2f3a4
Create Date: 2025-12-26 12:00:00.000000
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "d2e4f6a8b9c0"
down_revision = "b7c9d1e2f3a4"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column("activity_count", sa.Integer(), nullable=False, server_default="0")
        )
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.alter_column("activity_count", server_default=None)


def downgrade():
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.drop_column("activity_count")
