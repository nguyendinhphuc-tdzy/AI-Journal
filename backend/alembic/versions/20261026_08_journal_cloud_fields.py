"""Preserve guided Journal data and AI body version on PostgreSQL.

Revision ID: 20261026_08
Revises: 20261025_07

Additive. Never drops journal data; existing content is version 1.
"""
from alembic import op
import sqlalchemy as sa

revision = "20261026_08"
down_revision = "20261025_07"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # SQLite requires a table rebuild to add a CHECK constraint; use the
    # Alembic batch operation in tests and simple ALTER TABLE in PostgreSQL.
    sqlite = op.get_bind().dialect.name == "sqlite"
    with op.batch_alter_table(
        "journal_entries", recreate="always" if sqlite else "auto"
    ) as batch:
        batch.add_column(sa.Column("guided", sa.JSON(), nullable=True))
        batch.add_column(sa.Column(
            "body_version", sa.Integer(), nullable=False, server_default=sa.text("1")
        ))
        batch.create_check_constraint(
            "ck_journal_entries_body_version", "body_version >= 1"
        )
    if op.get_bind().dialect.name == "postgresql":
        op.execute("ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY")
        op.execute(
            "REVOKE ALL ON TABLE public.journal_entries FROM anon, authenticated"
        )


def downgrade() -> None:
    raise RuntimeError(
        "Refusing destructive Journal Cloud downgrade: guided journal values "
        "and body versions must not be discarded."
    )
