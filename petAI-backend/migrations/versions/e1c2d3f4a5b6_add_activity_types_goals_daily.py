"""add activity_types, goals, daily_activities tables

Revision ID: e1c2d3f4a5b6
Revises: 79d94f992409
Create Date: 2025-12-01 12:25:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'e1c2d3f4a5b6'
down_revision = '79d94f992409'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'activity_types',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('interest_id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=120), nullable=False),
        sa.Column('description', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['interest_id'], ['interests.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'interest_id', 'name', name='uq_user_interest_activity_type')
    )
    op.create_index(op.f('ix_activity_types_interest_id'), 'activity_types', ['interest_id'], unique=False)
    op.create_index(op.f('ix_activity_types_user_id'), 'activity_types', ['user_id'], unique=False)

    op.create_table(
        'goals',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('activity_type_id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=True),
        sa.Column('amount', sa.Float(), nullable=True),
        sa.Column('unit', sa.String(length=32), nullable=True),
        sa.Column('progress_value', sa.Float(), nullable=True),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['activity_type_id'], ['activity_types.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_goals_activity_type_id'), 'goals', ['activity_type_id'], unique=False)
    op.create_index(op.f('ix_goals_user_id'), 'goals', ['user_id'], unique=False)

    op.create_table(
        'daily_activities',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('interest_id', sa.Integer(), nullable=False),
        sa.Column('activity_type_id', sa.Integer(), nullable=False),
        sa.Column('goal_id', sa.Integer(), nullable=True),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('scheduled_for', sa.Date(), nullable=False),
        sa.Column('status', sa.String(length=32), nullable=False),
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('xp_awarded', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['activity_type_id'], ['activity_types.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['goal_id'], ['goals.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['interest_id'], ['interests.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'activity_type_id', 'scheduled_for', 'title', name='uq_user_activitytype_date_title')
    )
    op.create_index(op.f('ix_daily_activities_activity_type_id'), 'daily_activities', ['activity_type_id'], unique=False)
    op.create_index(op.f('ix_daily_activities_goal_id'), 'daily_activities', ['goal_id'], unique=False)
    op.create_index(op.f('ix_daily_activities_interest_id'), 'daily_activities', ['interest_id'], unique=False)
    op.create_index(op.f('ix_daily_activities_scheduled_for'), 'daily_activities', ['scheduled_for'], unique=False)
    op.create_index(op.f('ix_daily_activities_user_id'), 'daily_activities', ['user_id'], unique=False)


def downgrade():
    op.drop_index(op.f('ix_daily_activities_user_id'), table_name='daily_activities')
    op.drop_index(op.f('ix_daily_activities_scheduled_for'), table_name='daily_activities')
    op.drop_index(op.f('ix_daily_activities_interest_id'), table_name='daily_activities')
    op.drop_index(op.f('ix_daily_activities_goal_id'), table_name='daily_activities')
    op.drop_index(op.f('ix_daily_activities_activity_type_id'), table_name='daily_activities')
    op.drop_table('daily_activities')
    op.drop_index(op.f('ix_goals_user_id'), table_name='goals')
    op.drop_index(op.f('ix_goals_activity_type_id'), table_name='goals')
    op.drop_table('goals')
    op.drop_index(op.f('ix_activity_types_user_id'), table_name='activity_types')
    op.drop_index(op.f('ix_activity_types_interest_id'), table_name='activity_types')
    op.drop_table('activity_types')
