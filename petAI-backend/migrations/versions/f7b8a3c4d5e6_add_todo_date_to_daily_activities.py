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


def _table_exists(inspector, table_name: str) -> bool:
    return table_name in inspector.get_table_names()


def _column_exists(inspector, table_name: str, column_name: str) -> bool:
    return any(col["name"] == column_name for col in inspector.get_columns(table_name))


def _index_exists(inspector, table_name: str, index_name: str) -> bool:
    return any(index["name"] == index_name for index in inspector.get_indexes(table_name))


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if not _table_exists(inspector, "daily_activities"):
        return

    column_exists = _column_exists(inspector, "daily_activities", "todo_date")
    if not column_exists:
        op.add_column("daily_activities", sa.Column("todo_date", sa.Date(), nullable=True))
        column_exists = True

    todo_index = op.f("ix_daily_activities_todo_date")
    if not _index_exists(inspector, "daily_activities", todo_index):
        op.create_index(
            todo_index,
            "daily_activities",
            ["todo_date"],
            unique=False,
        )

    conn = bind
    if column_exists:
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
