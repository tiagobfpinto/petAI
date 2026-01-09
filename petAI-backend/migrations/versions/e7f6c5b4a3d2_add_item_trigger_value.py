"""Add trigger value to items

Revision ID: e7f6c5b4a3d2
Revises: d2e4f6a8b9c0
Create Date: 2025-12-27 12:00:00.000000
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "e7f6c5b4a3d2"
down_revision = "d2e4f6a8b9c0"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("Item", schema=None) as batch_op:
        batch_op.add_column(sa.Column("trigger_value", sa.Integer(), nullable=True))


def downgrade():
    with op.batch_alter_table("Item", schema=None) as batch_op:
        batch_op.drop_column("trigger_value")
