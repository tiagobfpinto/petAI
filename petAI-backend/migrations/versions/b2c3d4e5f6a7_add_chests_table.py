"""add chests table

Revision ID: b2c3d4e5f6a7
Revises: e8708d57f4f0
Create Date: 2025-12-28 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "b2c3d4e5f6a7"
down_revision = "e8708d57f4f0"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "Chest",
        sa.Column("item_id", sa.Integer(), sa.ForeignKey("Item.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("tier", sa.String(), nullable=False, server_default="common"),
        sa.Column("item_drop_rate", sa.Float(), nullable=False, server_default="0.05"),
        sa.Column("xp_min", sa.Integer(), nullable=False, server_default="25"),
        sa.Column("xp_max", sa.Integer(), nullable=False, server_default="60"),
        sa.Column("coin_min", sa.Integer(), nullable=False, server_default="40"),
        sa.Column("coin_max", sa.Integer(), nullable=False, server_default="120"),
        sa.Column("max_item_rarity", sa.String(), nullable=True),
    )


def downgrade():
    op.drop_table("Chest")
