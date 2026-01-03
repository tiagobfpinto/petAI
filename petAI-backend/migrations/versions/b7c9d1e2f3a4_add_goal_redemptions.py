"""add goal redemption tracking and milestone redemptions

Revision ID: b7c9d1e2f3a4
Revises: f13ddde07aa7
Create Date: 2025-12-24 19:30:00.000000
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "b7c9d1e2f3a4"
down_revision = "f13ddde07aa7"
branch_labels = None
depends_on = None


def _column_exists(inspector, table_name: str, column_name: str) -> bool:
    return any(col["name"] == column_name for col in inspector.get_columns(table_name))


def _index_exists(inspector, table_name: str, index_name: str) -> bool:
    return any(index["name"] == index_name for index in inspector.get_indexes(table_name))


def _table_exists(inspector, table_name: str) -> bool:
    return table_name in inspector.get_table_names()


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if not _table_exists(inspector, "goals"):
        return

    if not _column_exists(inspector, "goals", "completed_at"):
        op.add_column("goals", sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True))
    if not _column_exists(inspector, "goals", "redeemed_at"):
        op.add_column("goals", sa.Column("redeemed_at", sa.DateTime(timezone=True), nullable=True))

    completed_index = op.f("ix_goals_completed_at")
    redeemed_index = op.f("ix_goals_redeemed_at")
    if not _index_exists(inspector, "goals", completed_index):
        op.create_index(completed_index, "goals", ["completed_at"], unique=False)
    if not _index_exists(inspector, "goals", redeemed_index):
        op.create_index(redeemed_index, "goals", ["redeemed_at"], unique=False)

    milestone_user_index = op.f("ix_milestone_redemptions_user_id")
    table_exists = "milestone_redemptions" in inspector.get_table_names()
    if not table_exists:
        op.create_table(
            "milestone_redemptions",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("user_id", sa.Integer(), nullable=False),
            sa.Column("milestone_id", sa.String(length=64), nullable=False),
            sa.Column("redeemed_at", sa.DateTime(timezone=True), nullable=False),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("user_id", "milestone_id", name="uq_user_milestone_redemption"),
        )
        op.create_index(
            milestone_user_index,
            "milestone_redemptions",
            ["user_id"],
            unique=False,
        )
    elif not _index_exists(inspector, "milestone_redemptions", milestone_user_index):
        op.create_index(
            milestone_user_index,
            "milestone_redemptions",
            ["user_id"],
            unique=False,
        )


def downgrade():
    op.drop_index(op.f("ix_milestone_redemptions_user_id"), table_name="milestone_redemptions")
    op.drop_table("milestone_redemptions")

    conn = op.get_bind()
    if conn.dialect.name == "sqlite":
        with op.batch_alter_table("goals") as batch_op:
            batch_op.drop_index(op.f("ix_goals_completed_at"))
            batch_op.drop_index(op.f("ix_goals_redeemed_at"))
            batch_op.drop_column("redeemed_at")
            batch_op.drop_column("completed_at")
    else:
        op.drop_index(op.f("ix_goals_completed_at"), table_name="goals")
        op.drop_index(op.f("ix_goals_redeemed_at"), table_name="goals")
        op.drop_column("goals", "redeemed_at")
        op.drop_column("goals", "completed_at")
