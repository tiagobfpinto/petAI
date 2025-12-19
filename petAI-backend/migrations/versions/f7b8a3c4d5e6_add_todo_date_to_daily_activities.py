"""add todo_date to daily_activities

Revision ID: f7b8a3c4d5e6
Revises: e1c2d3f4a5b6
Create Date: 2025-12-01 13:45:00.000000
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "f7b8a3c4d5e6"
down_revision = "e1c2d3f4a5b6"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("daily_activities", sa.Column("todo_date", sa.Date(), nullable=True))
    op.create_index(
        op.f("ix_daily_activities_todo_date"),
        "daily_activities",
        ["todo_date"],
        unique=False,
    )

    conn = op.get_bind()
    conn.execute(
        sa.text(
            "UPDATE daily_activities SET todo_date = scheduled_for WHERE todo_date IS NULL"
        )
    )

    if conn.dialect.name == "sqlite":
        with op.batch_alter_table("daily_activities") as batch_op:
            batch_op.alter_column("todo_date", nullable=False)
    else:
        op.alter_column("daily_activities", "todo_date", nullable=False)


def downgrade():
    conn = op.get_bind()
    if conn.dialect.name == "sqlite":
        with op.batch_alter_table("daily_activities") as batch_op:
            batch_op.alter_column("todo_date", nullable=True)
            batch_op.drop_index(op.f("ix_daily_activities_todo_date"))
            batch_op.drop_column("todo_date")
    else:
        op.alter_column("daily_activities", "todo_date", nullable=True)
        op.drop_index(op.f("ix_daily_activities_todo_date"), table_name="daily_activities")
        op.drop_column("daily_activities", "todo_date")
