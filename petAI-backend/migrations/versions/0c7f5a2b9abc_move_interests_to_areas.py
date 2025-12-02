"""move interest fields to activity_types and rename table

Revision ID: 0c7f5a2b9abc
Revises: f7b8a3c4d5e6
Create Date: 2025-12-02 15:30:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '0c7f5a2b9abc'
down_revision = 'f7b8a3c4d5e6'
branch_labels = None
depends_on = None


def upgrade():
    op.rename_table("interests", "areas")

    with op.batch_alter_table("activity_types") as batch_op:
        batch_op.add_column(sa.Column("level", sa.String(length=32), nullable=False, server_default="sometimes"))
        batch_op.add_column(sa.Column("goal", sa.String(length=255), nullable=True))
        batch_op.add_column(sa.Column("weekly_goal_value", sa.Float(), nullable=True))
        batch_op.add_column(sa.Column("weekly_goal_unit", sa.String(length=32), nullable=True))
        batch_op.add_column(sa.Column("weekly_schedule", sa.String(length=255), nullable=True))
        batch_op.add_column(sa.Column("rrule", sa.String(length=255), nullable=True))

    conn = op.get_bind()
    areas = conn.execute(
        sa.text(
            "SELECT id, user_id, name, level, goal, weekly_goal_value, weekly_goal_unit, weekly_schedule FROM areas"
        )
    ).fetchall()
    for area in areas:
        existing = conn.execute(
            sa.text("SELECT id FROM activity_types WHERE interest_id=:interest_id ORDER BY id LIMIT 1"),
            {"interest_id": area.id},
        ).fetchone()
        params = {
            "user_id": area.user_id,
            "interest_id": area.id,
            "name": area.name,
            "level": area.level or "sometimes",
            "goal": area.goal,
            "wgv": area.weekly_goal_value,
            "wgu": area.weekly_goal_unit,
            "ws": area.weekly_schedule,
        }
        if existing:
            conn.execute(
                sa.text(
                    """
                    UPDATE activity_types
                    SET level=:level,
                        goal=:goal,
                        weekly_goal_value=:wgv,
                        weekly_goal_unit=:wgu,
                        weekly_schedule=:ws
                    WHERE id=:id
                    """
                ),
                {"id": existing.id, **params},
            )
        else:
            conn.execute(
                sa.text(
                    """
                    INSERT INTO activity_types
                    (user_id, interest_id, name, description, created_at, updated_at, level, goal, weekly_goal_value, weekly_goal_unit, weekly_schedule, rrule)
                    VALUES (:user_id, :interest_id, :name, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, :level, :goal, :wgv, :wgu, :ws, NULL)
                    """
                ),
                params,
            )

    with op.batch_alter_table("areas") as batch_op:
        batch_op.drop_column("rrule")
        batch_op.drop_column("weekly_schedule")
        batch_op.drop_column("weekly_goal_unit")
        batch_op.drop_column("weekly_goal_value")
        batch_op.drop_column("goal")
        batch_op.drop_column("level")


def downgrade():
    with op.batch_alter_table("areas") as batch_op:
        batch_op.add_column(sa.Column("level", sa.String(length=32), nullable=False, server_default="sometimes"))
        batch_op.add_column(sa.Column("goal", sa.String(length=255), nullable=True))
        batch_op.add_column(sa.Column("weekly_goal_value", sa.Float(), nullable=True))
        batch_op.add_column(sa.Column("weekly_goal_unit", sa.String(length=32), nullable=True))
        batch_op.add_column(sa.Column("weekly_schedule", sa.String(length=255), nullable=True))

    conn = op.get_bind()
    areas = conn.execute(sa.text("SELECT id FROM areas")).fetchall()
    for area in areas:
        activity_type = conn.execute(
            sa.text(
                """
                SELECT level, goal, weekly_goal_value, weekly_goal_unit, weekly_schedule
                FROM activity_types
                WHERE interest_id=:interest_id
                ORDER BY id
                LIMIT 1
                """
            ),
            {"interest_id": area.id},
        ).fetchone()
        if activity_type:
            conn.execute(
                sa.text(
                    """
                    UPDATE areas
                    SET level=:level,
                        goal=:goal,
                        weekly_goal_value=:wgv,
                        weekly_goal_unit=:wgu,
                        weekly_schedule=:ws
                    WHERE id=:id
                    """
                ),
                {
                    "id": area.id,
                    "level": activity_type.level or "sometimes",
                    "goal": activity_type.goal,
                    "wgv": activity_type.weekly_goal_value,
                    "wgu": activity_type.weekly_goal_unit,
                    "ws": activity_type.weekly_schedule,
                },
            )

    with op.batch_alter_table("activity_types") as batch_op:
        batch_op.drop_column("weekly_schedule")
        batch_op.drop_column("weekly_goal_unit")
        batch_op.drop_column("weekly_goal_value")
        batch_op.drop_column("goal")
        batch_op.drop_column("level")

    op.rename_table("areas", "interests")
