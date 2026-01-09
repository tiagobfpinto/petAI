"""add auth tokens table

Revision ID: f3c5b8c9da2a
Revises: ba68f0ee9a23
Create Date: 2025-11-18 21:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'f3c5b8c9da2a'
down_revision = 'ba68f0ee9a23'
branch_labels = None
depends_on = None


def _table_exists(inspector, table_name: str) -> bool:
    return table_name in inspector.get_table_names()


def _index_exists(inspector, table_name: str, index_name: str) -> bool:
    return any(index["name"] == index_name for index in inspector.get_indexes(table_name))


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    table_exists = _table_exists(inspector, 'auth_tokens')
    if not table_exists:
        op.create_table(
            'auth_tokens',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('token', sa.String(length=255), nullable=False),
            sa.Column('user_id', sa.Integer(), nullable=False),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
            sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_auth_tokens_token'), 'auth_tokens', ['token'], unique=True)
        op.create_index(op.f('ix_auth_tokens_user_id'), 'auth_tokens', ['user_id'], unique=False)
        return

    token_index = op.f('ix_auth_tokens_token')
    user_index = op.f('ix_auth_tokens_user_id')
    if not _index_exists(inspector, 'auth_tokens', token_index):
        op.create_index(token_index, 'auth_tokens', ['token'], unique=True)
    if not _index_exists(inspector, 'auth_tokens', user_index):
        op.create_index(user_index, 'auth_tokens', ['user_id'], unique=False)


def downgrade():
    op.drop_index(op.f('ix_auth_tokens_user_id'), table_name='auth_tokens')
    op.drop_index(op.f('ix_auth_tokens_token'), table_name='auth_tokens')
    op.drop_table('auth_tokens')
