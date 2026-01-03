from alembic import op
import sqlalchemy as sa


revision = "e8708d57f4f0"
down_revision = "f13ddde07aa7"


def _table_exists(inspector, table_name: str) -> bool:
    return table_name in inspector.get_table_names()


def _index_exists(inspector, table_name: str, index_name: str) -> bool:
    return any(index["name"] == index_name for index in inspector.get_indexes(table_name))


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if not _table_exists(inspector, "subscriptions"):
        op.create_table(
            "subscriptions",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("provider", sa.String(length=32), nullable=False, server_default="app_store"),
            sa.Column("product_id", sa.String(length=120), nullable=False),
            sa.Column("status", sa.String(length=20), nullable=False, server_default="active"),
            sa.Column("is_trial", sa.Boolean(), nullable=False, server_default=sa.text("false")),
            sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("expires_at", sa.DateTime(timezone=True)),
            sa.Column("original_transaction_id", sa.String(length=64)),
            sa.Column("latest_transaction_id", sa.String(length=64)),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        )
        op.create_index("ix_subscriptions_user_id", "subscriptions", ["user_id"])
        return

    if not _index_exists(inspector, "subscriptions", "ix_subscriptions_user_id"):
        op.create_index("ix_subscriptions_user_id", "subscriptions", ["user_id"])


def downgrade():
    op.drop_index("ix_subscriptions_user_id", table_name="subscriptions")
    op.drop_table("subscriptions")
