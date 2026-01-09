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


def _column_exists(inspector, table_name: str, column_name: str) -> bool:
    return any(col["name"] == column_name for col in inspector.get_columns(table_name))


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "users" not in inspector.get_table_names():
        return
    streak_current_exists = _column_exists(inspector, "users", "streak_current")
    streak_best_exists = _column_exists(inspector, "users", "streak_best")
    with op.batch_alter_table("users", schema=None) as batch_op:
        if not streak_current_exists:
            batch_op.add_column(sa.Column("streak_current", sa.Integer(), nullable=False, server_default="0"))
            streak_current_exists = True
        if not streak_best_exists:
            batch_op.add_column(sa.Column("streak_best", sa.Integer(), nullable=False, server_default="0"))
            streak_best_exists = True
        if not _column_exists(inspector, "users", "last_activity_at"):
            batch_op.add_column(sa.Column("last_activity_at", sa.DateTime(timezone=True), nullable=True))
    # Clear server_default after creation to avoid future default changes
    with op.batch_alter_table("users", schema=None) as batch_op:
        if streak_current_exists:
            batch_op.alter_column("streak_current", server_default=None)
        if streak_best_exists:
            batch_op.alter_column("streak_best", server_default=None)


def downgrade():
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.drop_column("last_activity_at")
        batch_op.drop_column("streak_best")
        batch_op.drop_column("streak_current")
