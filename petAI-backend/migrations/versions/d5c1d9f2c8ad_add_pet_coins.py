"""Add coins to pets

Revision ID: d5c1d9f2c8ad
Revises: c7c6f8a1b2d3
Create Date: 2025-12-01 12:00:00.000000
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "d5c1d9f2c8ad"
down_revision = "c7c6f8a1b2d3"
branch_labels = None
depends_on = None


def _column_exists(inspector, table_name: str, column_name: str) -> bool:
    return any(col["name"] == column_name for col in inspector.get_columns(table_name))


def _check_constraint_exists(inspector, table_name: str, constraint_name: str) -> bool:
    return any(constraint["name"] == constraint_name for constraint in inspector.get_check_constraints(table_name))


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "pets" not in inspector.get_table_names():
        return
    coins_exists = _column_exists(inspector, "pets", "coins")
    with op.batch_alter_table("pets", schema=None) as batch_op:
        if not coins_exists:
            batch_op.add_column(sa.Column("coins", sa.Integer(), nullable=False, server_default="0"))
            coins_exists = True
    with op.batch_alter_table("pets", schema=None) as batch_op:
        if coins_exists:
            batch_op.alter_column("coins", server_default=None)
        if not _check_constraint_exists(inspector, "pets", "ck_pet_coins_non_negative"):
            batch_op.create_check_constraint("ck_pet_coins_non_negative", "coins >= 0")


def downgrade():
    with op.batch_alter_table("pets", schema=None) as batch_op:
        batch_op.drop_constraint("ck_pet_coins_non_negative", type_="check")
        batch_op.drop_column("coins")
