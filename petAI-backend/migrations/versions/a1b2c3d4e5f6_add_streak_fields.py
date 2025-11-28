"""Add streak tracking fields to users

Revision ID: a1b2c3d4e5f6
Revises: 9d3fff186e78
Create Date: 2025-11-26 07:00:00.000000
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "a1b2c3d4e5f6"
down_revision = "9d3fff186e78"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.add_column(sa.Column("streak_current", sa.Integer(), nullable=False, server_default="0"))
        batch_op.add_column(sa.Column("streak_best", sa.Integer(), nullable=False, server_default="0"))
        batch_op.add_column(sa.Column("last_activity_at", sa.DateTime(timezone=True), nullable=True))
    # Clear server_default after creation to avoid future default changes
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.alter_column("streak_current", server_default=None)
        batch_op.alter_column("streak_best", server_default=None)


def downgrade():
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.drop_column("last_activity_at")
        batch_op.drop_column("streak_best")
        batch_op.drop_column("streak_current")
