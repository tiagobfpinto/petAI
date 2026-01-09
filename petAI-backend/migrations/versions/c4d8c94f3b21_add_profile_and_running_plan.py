"""Add profile demographics and running plan fields

Revision ID: c4d8c94f3b21
Revises: f3c5b8c9da2a
Create Date: 2025-12-01 12:00:00.000000
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "c4d8c94f3b21"
down_revision = "f3c5b8c9da2a"
branch_labels = None
depends_on = None


def _column_exists(inspector, table_name: str, column_name: str) -> bool:
    return any(col["name"] == column_name for col in inspector.get_columns(table_name))


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if "users" in inspector.get_table_names():
        with op.batch_alter_table("users", schema=None) as batch_op:
            if not _column_exists(inspector, "users", "age"):
                batch_op.add_column(sa.Column("age", sa.Integer(), nullable=True))
            if not _column_exists(inspector, "users", "gender"):
                batch_op.add_column(sa.Column("gender", sa.String(length=32), nullable=True))

    if "interests" in inspector.get_table_names():
        with op.batch_alter_table("interests", schema=None) as batch_op:
            if not _column_exists(inspector, "interests", "weekly_goal_value"):
                batch_op.add_column(sa.Column("weekly_goal_value", sa.Float(), nullable=True))
            if not _column_exists(inspector, "interests", "weekly_goal_unit"):
                batch_op.add_column(sa.Column("weekly_goal_unit", sa.String(length=32), nullable=True))
            if not _column_exists(inspector, "interests", "weekly_schedule"):
                batch_op.add_column(sa.Column("weekly_schedule", sa.String(length=255), nullable=True))


def downgrade():
    with op.batch_alter_table("interests", schema=None) as batch_op:
        batch_op.drop_column("weekly_schedule")
        batch_op.drop_column("weekly_goal_unit")
        batch_op.drop_column("weekly_goal_value")

    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.drop_column("gender")
        batch_op.drop_column("age")
