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


def upgrade():
    op.add_column("goals", sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("goals", sa.Column("redeemed_at", sa.DateTime(timezone=True), nullable=True))
    op.create_index(op.f("ix_goals_completed_at"), "goals", ["completed_at"], unique=False)
    op.create_index(op.f("ix_goals_redeemed_at"), "goals", ["redeemed_at"], unique=False)

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
        op.f("ix_milestone_redemptions_user_id"),
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
