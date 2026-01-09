"""add background to type_of_item_enum

Revision ID: d4c3b2a1908f
Revises: a9b8c7d6e5f4
Create Date: 2026-01-08 19:30:00.000000
"""
from alembic import op


# revision identifiers, used by Alembic.
revision = "d4c3b2a1908f"
down_revision = "a9b8c7d6e5f4"
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.execute("ALTER TYPE type_of_item_enum ADD VALUE IF NOT EXISTS 'BACKGROUND'")


def downgrade():
    pass
