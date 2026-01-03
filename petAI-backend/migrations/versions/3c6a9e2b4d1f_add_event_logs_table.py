from alembic import op
import sqlalchemy as sa


revision = "3c6a9e2b4d1f"
down_revision = "21b9173ef62f"


def _table_exists(inspector, table_name: str) -> bool:
    return table_name in inspector.get_table_names()


def _index_exists(inspector, table_name: str, index_name: str) -> bool:
    return any(index["name"] == index_name for index in inspector.get_indexes(table_name))


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if not _table_exists(inspector, "event_logs"):
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
        return

    if not _index_exists(inspector, "event_logs", "ix_event_logs_user_id"):
        op.create_index("ix_event_logs_user_id", "event_logs", ["user_id"])
    if not _index_exists(inspector, "event_logs", "ix_event_logs_event_name"):
        op.create_index("ix_event_logs_event_name", "event_logs", ["event_name"])


def downgrade():
    op.drop_index("ix_event_logs_event_name", table_name="event_logs")
    op.drop_index("ix_event_logs_user_id", table_name="event_logs")
    op.drop_table("event_logs")
