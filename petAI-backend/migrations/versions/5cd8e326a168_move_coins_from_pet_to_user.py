"""move coins from pet to user

Revision ID: 5cd8e326a168
Revises: 0d3b411b054b
Create Date: 2025-12-14 17:54:39.855348

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '5cd8e326a168'
down_revision = '0d3b411b054b'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(sa.Column('coins', sa.Integer(), nullable=False, server_default="0"))
        batch_op.create_check_constraint("ck_user_coins_non_negative", "coins >= 0")

    # copy any existing balances from pets to users
    op.execute(
        """
        UPDATE users
        SET coins = pets.coins
        FROM pets
        WHERE pets.user_id = users.id
        """
    )

    # drop the temporary server default
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.alter_column('coins', server_default=None)

    with op.batch_alter_table('pets', schema=None) as batch_op:
        batch_op.drop_constraint("ck_pet_coins_non_negative", type_="check")
        batch_op.drop_column('coins')


def downgrade():
    with op.batch_alter_table('pets', schema=None) as batch_op:
        batch_op.add_column(sa.Column('coins', sa.INTEGER(), autoincrement=False, nullable=False, server_default="0"))
        batch_op.create_check_constraint("ck_pet_coins_non_negative", "coins >= 0")

    op.execute(
        """
        UPDATE pets
        SET coins = users.coins
        FROM users
        WHERE pets.user_id = users.id
        """
    )

    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_constraint("ck_user_coins_non_negative", type_="check")
        batch_op.drop_column('coins')

    with op.batch_alter_table('pets', schema=None) as batch_op:
        batch_op.alter_column('coins', server_default=None)
