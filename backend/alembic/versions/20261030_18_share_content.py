"""Explicit share snapshots, no exposure of private memory notes.
Revision ID: 20261030_18
Revises: 20261030_17
"""
from alembic import op
import sqlalchemy as sa
revision = "20261030_18"
down_revision = "20261030_17"
branch_labels = None
depends_on = None

def upgrade():
    with op.batch_alter_table("memory_shares") as batch:
        batch.alter_column("memory_id", existing_type=sa.Uuid(as_uuid=True),
                           nullable=True)
        batch.add_column(sa.Column("title", sa.String(160), nullable=True))
        batch.add_column(sa.Column("text", sa.String(300), nullable=True))
        batch.add_column(sa.Column("place", sa.JSON(), nullable=True))
        batch.add_column(sa.Column("category", sa.String(60), nullable=True))
    # No migration of private memory.note; old shares have no public snapshot and fail closed.
    # Old shares may retain expiry but never become readable without explicit shared content.

def downgrade():
    raise RuntimeError("Refusing to discard independent sharing content")
