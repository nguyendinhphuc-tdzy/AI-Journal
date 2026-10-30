"""A 24-hour share's own photo, kept with the share and cleared on revoke.

Revision ID: 20261030_20
Revises: 20261030_19
"""
from alembic import op
import sqlalchemy as sa

revision = "20261030_20"
down_revision = "20261030_19"
branch_labels = None
depends_on = None


def upgrade():
    # Nullable: existing shares have no photo. The bytes are the sender's
    # chosen image only (never the album's private storage object).
    with op.batch_alter_table("memory_shares") as batch:
        batch.add_column(sa.Column("photo", sa.LargeBinary(), nullable=True))
        batch.add_column(sa.Column("photo_type", sa.String(16), nullable=True))


def downgrade():
    with op.batch_alter_table("memory_shares") as batch:
        batch.drop_column("photo_type")
        batch.drop_column("photo")
