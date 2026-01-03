"""Add access codes.

Revision ID: 7d2c9a5b1f2c
Revises: 4f6b1c2d3e4a
Create Date: 2026-01-03 12:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "7d2c9a5b1f2c"
down_revision = "4f6b1c2d3e4a"
branch_labels = None
depends_on = None


def _table_exists(inspector, table_name: str) -> bool:
    return table_name in inspector.get_table_names()


def _index_exists(inspector, table_name: str, index_name: str) -> bool:
    return any(index["name"] == index_name for index in inspector.get_indexes(table_name))


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if not _table_exists(inspector, "access_codes"):
        op.create_table(
            "access_codes",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("code", sa.String(length=64), nullable=False),
            sa.Column("percent_off", sa.Integer(), nullable=False),
            sa.Column("active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
            sa.Column("max_redemptions", sa.Integer()),
            sa.Column("redeemed_count", sa.Integer(), nullable=False, server_default=sa.text("0")),
            sa.Column("expires_at", sa.DateTime(timezone=True)),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        )
        op.create_index("ix_access_codes_code", "access_codes", ["code"], unique=True)

    if not _table_exists(inspector, "access_code_redemptions"):
        op.create_table(
            "access_code_redemptions",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "access_code_id",
                sa.Integer(),
                sa.ForeignKey("access_codes.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "user_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("redeemed_at", sa.DateTime(timezone=True), nullable=False),
            sa.UniqueConstraint("access_code_id", "user_id", name="uq_access_code_user"),
        )
        op.create_index(
            "ix_access_code_redemptions_access_code_id",
            "access_code_redemptions",
            ["access_code_id"],
        )
        op.create_index(
            "ix_access_code_redemptions_user_id",
            "access_code_redemptions",
            ["user_id"],
        )

    if _table_exists(inspector, "access_codes") and not _index_exists(
        inspector,
        "access_codes",
        "ix_access_codes_code",
    ):
        op.create_index("ix_access_codes_code", "access_codes", ["code"], unique=True)


def downgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if _table_exists(inspector, "access_code_redemptions"):
        if _index_exists(
            inspector,
            "access_code_redemptions",
            "ix_access_code_redemptions_access_code_id",
        ):
            op.drop_index(
                "ix_access_code_redemptions_access_code_id",
                table_name="access_code_redemptions",
            )
        if _index_exists(
            inspector,
            "access_code_redemptions",
            "ix_access_code_redemptions_user_id",
        ):
            op.drop_index(
                "ix_access_code_redemptions_user_id",
                table_name="access_code_redemptions",
            )
        op.drop_table("access_code_redemptions")

    if _table_exists(inspector, "access_codes"):
        if _index_exists(inspector, "access_codes", "ix_access_codes_code"):
            op.drop_index("ix_access_codes_code", table_name="access_codes")
        op.drop_table("access_codes")
