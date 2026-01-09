"""add rrule column to activity_types if missing

Revision ID: 1a2b3c4d5e6f
Revises: 0c7f5a2b9abc
Create Date: 2025-12-02 15:55:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '1a2b3c4d5e6f'
down_revision = '0c7f5a2b9abc'
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "activity_types" not in inspector.get_table_names():
        return
    columns = {col["name"] for col in inspector.get_columns("activity_types")}
    if "rrule" not in columns:
        op.add_column("activity_types", sa.Column("rrule", sa.String(length=255), nullable=True))


def downgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = {col["name"] for col in inspector.get_columns("activity_types")}
    if "rrule" in columns:
        op.drop_column("activity_types", "rrule")
