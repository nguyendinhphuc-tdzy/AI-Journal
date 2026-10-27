"""Persist Study-to-Journal source metadata without changing existing journal text.

Revision ID: 20261028_09
Revises: 20261026_08

Additive nullable JSON. Existing entries remain unchanged.
"""
from alembic import op
import sqlalchemy as sa

revision = "20261028_09"
down_revision = "20261026_08"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("journal_entries", sa.Column("source", sa.JSON(), nullable=True))
    if op.get_bind().dialect.name == "postgresql":
        op.execute("ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY")
        op.execute("REVOKE ALL ON TABLE public.journal_entries FROM anon, authenticated")


def downgrade() -> None:
    raise RuntimeError(
        "Refusing destructive Journal source downgrade: Study attribution "
        "would be discarded."
    )
