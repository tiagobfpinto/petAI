"""add background slot to pet styles

Revision ID: a9b8c7d6e5f4
Revises: b2c3d4e5f6a7
Create Date: 2026-01-08 19:20:00.000000
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "a9b8c7d6e5f4"
down_revision = "b2c3d4e5f6a7"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("PetStyles", schema=None) as batch_op:
        batch_op.add_column(sa.Column("background_id", sa.Integer(), nullable=True))
        batch_op.create_foreign_key(
            "fk_PetStyles_background_id_Item",
            "Item",
            ["background_id"],
            ["id"],
            ondelete="SET NULL",
        )


def downgrade():
    with op.batch_alter_table("PetStyles", schema=None) as batch_op:
        batch_op.drop_constraint("fk_PetStyles_background_id_Item", type_="foreignkey")
        batch_op.drop_column("background_id")
