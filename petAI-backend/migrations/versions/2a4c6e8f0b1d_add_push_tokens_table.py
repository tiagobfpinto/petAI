from alembic import op
import sqlalchemy as sa


revision = "2a4c6e8f0b1d"
down_revision = "1f2a3b4c5d6e"


def _table_exists(inspector, table_name: str) -> bool:
    return table_name in inspector.get_table_names()


def _index_exists(inspector, table_name: str, index_name: str) -> bool:
    return any(index["name"] == index_name for index in inspector.get_indexes(table_name))


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if not _table_exists(inspector, "push_tokens"):
        op.create_table(
            "push_tokens",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("platform", sa.String(length=20), nullable=False),
            sa.Column("token", sa.String(length=255), nullable=False),
            sa.Column("device_id", sa.String(length=64)),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=False),
        )
        op.create_index("ix_push_tokens_user_id", "push_tokens", ["user_id"])
        op.create_index("ix_push_tokens_token", "push_tokens", ["token"], unique=True)
        return

    if not _index_exists(inspector, "push_tokens", "ix_push_tokens_user_id"):
        op.create_index("ix_push_tokens_user_id", "push_tokens", ["user_id"])
    if not _index_exists(inspector, "push_tokens", "ix_push_tokens_token"):
        op.create_index("ix_push_tokens_token", "push_tokens", ["token"], unique=True)


def downgrade():
    op.drop_index("ix_push_tokens_token", table_name="push_tokens")
    op.drop_index("ix_push_tokens_user_id", table_name="push_tokens")
    op.drop_table("push_tokens")
