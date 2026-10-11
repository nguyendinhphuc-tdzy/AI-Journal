"""Create journal entries schema.

Revision ID: 20261011_01
Revises:
"""
from alembic import op
import sqlalchemy as sa

revision = "20261011_01"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "journal_entries",
        sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("prompt", sa.String(length=500), nullable=True),
        sa.Column("mood", sa.String(length=64), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_journal_entries_id", "journal_entries", ["id"])


def downgrade() -> None:
    op.drop_index("ix_journal_entries_id", table_name="journal_entries")
    op.drop_table("journal_entries")
