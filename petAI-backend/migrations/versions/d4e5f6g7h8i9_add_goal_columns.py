"""Add goal tracking fields to interests and activities

Revision ID: d4e5f6g7h8i9
Revises: c7c6f8a1b2d3
Create Date: 2025-11-28 14:30:00.000000
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "d4e5f6g7h8i9"
down_revision = "c7c6f8a1b2d3"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("interests", schema=None) as batch_op:
        batch_op.add_column(sa.Column("monthly_goal", sa.Float(), nullable=True))
        batch_op.add_column(sa.Column("month_progress", sa.Float(), nullable=True, server_default="0"))
        batch_op.add_column(sa.Column("target_unit", sa.String(length=32), nullable=True, server_default="units"))
        batch_op.add_column(sa.Column("last_suggestions_generated_at", sa.DateTime(timezone=True), nullable=True))

    with op.batch_alter_table("interests", schema=None) as batch_op:
        batch_op.alter_column("month_progress", server_default=None)
        batch_op.alter_column("target_unit", server_default=None)

    with op.batch_alter_table("activity_logs", schema=None) as batch_op:
        batch_op.add_column(sa.Column("amount", sa.Float(), nullable=True))


def downgrade():
    with op.batch_alter_table("activity_logs", schema=None) as batch_op:
        batch_op.drop_column("amount")

    with op.batch_alter_table("interests", schema=None) as batch_op:
        batch_op.drop_column("last_suggestions_generated_at")
        batch_op.drop_column("target_unit")
        batch_op.drop_column("month_progress")
        batch_op.drop_column("monthly_goal")
