from alembic import op
import sqlalchemy as sa


revision = "3c6a9e2b4d1f"
down_revision = "21b9173ef62f"


def upgrade():
    op.create_table(
        "event_logs",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE")),
        sa.Column("event_name", sa.String(length=120), nullable=False),
        sa.Column("payload", sa.JSON()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_event_logs_user_id", "event_logs", ["user_id"])
    op.create_index("ix_event_logs_event_name", "event_logs", ["event_name"])


def downgrade():
    op.drop_index("ix_event_logs_event_name", table_name="event_logs")
    op.drop_index("ix_event_logs_user_id", table_name="event_logs")
    op.drop_table("event_logs")
