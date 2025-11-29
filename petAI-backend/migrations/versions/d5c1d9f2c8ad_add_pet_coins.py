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


def upgrade():
    with op.batch_alter_table("pets", schema=None) as batch_op:
        batch_op.add_column(sa.Column("coins", sa.Integer(), nullable=False, server_default="0"))
    with op.batch_alter_table("pets", schema=None) as batch_op:
        batch_op.alter_column("coins", server_default=None)
        batch_op.create_check_constraint("ck_pet_coins_non_negative", "coins >= 0")


def downgrade():
    with op.batch_alter_table("pets", schema=None) as batch_op:
        batch_op.drop_constraint("ck_pet_coins_non_negative", type_="check")
        batch_op.drop_column("coins")
