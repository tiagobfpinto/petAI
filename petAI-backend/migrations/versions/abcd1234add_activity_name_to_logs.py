"""add activity_name to activity_logs

Revision ID: abcd1234add_activity_name_to_logs
Revises: 1a2b3c4d5e6f_add_rrule_column
Create Date: 2025-12-03
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
# Keep revision ids within 32 chars to fit alembic_version.version_num.
revision = "abcd1234activityname"
# Point to the actual revision id (not the filename) of the rrule migration.
down_revision = "1a2b3c4d5e6f"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("activity_logs", sa.Column("activity_name", sa.String(length=255), nullable=True))


def downgrade():
    op.drop_column("activity_logs", "activity_name")
