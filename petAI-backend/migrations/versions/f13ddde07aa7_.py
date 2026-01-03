from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = 'f13ddde07aa7'
down_revision = 'c8c47ef112c5'


def upgrade():
    enum_name = "type_of_item_enum"
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    item_enum = postgresql.ENUM(
        'HAT', 'SUNGLASSES', 'COLOR', 'DEFAULT',
        name=enum_name
    )

    item_enum.create(bind, checkfirst=True)

    if "Item" not in inspector.get_table_names():
        return

    # 🔧 NORMALIZA TODOS OS VALORES
    op.execute("""
        UPDATE "Item"
        SET type = UPPER(type);
    """)

    op.execute("""
        UPDATE "Item"
        SET type = 'SUNGLASSES'
        WHERE type = 'GLASSES';
    """)

    with op.batch_alter_table('Item') as batch_op:
        batch_op.alter_column(
            'type',
            existing_type=sa.VARCHAR(),
            type_=item_enum,
            existing_nullable=False,
            postgresql_using=f'"type"::text::{enum_name}'
        )

def downgrade():
    enum_name = "type_of_item_enum"

    item_enum = postgresql.ENUM(
        'HAT', 'SUNGLASSES', 'COLOR', 'DEFAULT',
        name=enum_name
    )

    with op.batch_alter_table('Item') as batch_op:
        batch_op.alter_column(
            'type',
            existing_type=item_enum,
            type_=sa.VARCHAR(),
            existing_nullable=False
        )

    item_enum.drop(op.get_bind(), checkfirst=True)
