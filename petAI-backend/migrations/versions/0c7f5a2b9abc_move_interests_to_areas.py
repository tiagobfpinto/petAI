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
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = set(inspector.get_table_names())

    # Render already had this rename applied, so guard it.
    if "areas" not in tables and "interests" in tables:
        op.rename_table("interests", "areas")

    # Reinspect after potential rename.
    inspector = sa.inspect(conn)
    tables = set(inspector.get_table_names())

    if "activity_types" not in tables:
        # Nothing to do if the table isn't there (shouldn't happen in normal flow).
        return

    activity_columns = {col["name"] for col in inspector.get_columns("activity_types")}
    with op.batch_alter_table("activity_types") as batch_op:
        if "level" not in activity_columns:
            batch_op.add_column(sa.Column("level", sa.String(length=32), nullable=False, server_default="sometimes"))
        if "goal" not in activity_columns:
            batch_op.add_column(sa.Column("goal", sa.String(length=255), nullable=True))
        if "weekly_goal_value" not in activity_columns:
            batch_op.add_column(sa.Column("weekly_goal_value", sa.Float(), nullable=True))
        if "weekly_goal_unit" not in activity_columns:
            batch_op.add_column(sa.Column("weekly_goal_unit", sa.String(length=32), nullable=True))
        if "weekly_schedule" not in activity_columns:
            batch_op.add_column(sa.Column("weekly_schedule", sa.String(length=255), nullable=True))
        if "rrule" not in activity_columns:
            batch_op.add_column(sa.Column("rrule", sa.String(length=255), nullable=True))

    if "areas" not in tables:
        # If the rename didn't leave us with an areas table, bail out to avoid errors.
        return

    area_columns = {col["name"] for col in inspector.get_columns("areas")}
    selectable_columns = ["id", "user_id", "name"]
    for col_name in ["level", "goal", "weekly_goal_value", "weekly_goal_unit", "weekly_schedule"]:
        if col_name in area_columns:
            selectable_columns.append(col_name)

    areas = conn.execute(sa.text(f"SELECT {', '.join(selectable_columns)} FROM areas")).fetchall()
    for area in areas:
        mapping = area._mapping
        existing = conn.execute(
            sa.text("SELECT id FROM activity_types WHERE interest_id=:interest_id ORDER BY id LIMIT 1"),
            {"interest_id": mapping["id"]},
        ).fetchone()
        params = {
            "user_id": mapping["user_id"],
            "interest_id": mapping["id"],
            "name": mapping["name"],
            "level": mapping.get("level") or "sometimes",
            "goal": mapping.get("goal"),
            "wgv": mapping.get("weekly_goal_value"),
            "wgu": mapping.get("weekly_goal_unit"),
            "ws": mapping.get("weekly_schedule"),
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

    columns_to_drop = [
        "rrule",
        "weekly_schedule",
        "weekly_goal_unit",
        "weekly_goal_value",
        "goal",
        "level",
    ]
    columns_present_to_drop = [col for col in columns_to_drop if col in area_columns]
    if columns_present_to_drop:
        with op.batch_alter_table("areas") as batch_op:
            for column_name in columns_present_to_drop:
                batch_op.drop_column(column_name)


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
