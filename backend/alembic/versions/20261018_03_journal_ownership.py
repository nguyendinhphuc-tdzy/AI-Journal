"""Require authenticated ownership on journal entries.

Revision ID: 20261018_03
Revises: 20261018_02

Migration intentionally aborts if any legacy journal entries exist. Such rows
have no verifiable owner; they must be reviewed and explicitly mapped to
Supabase user UUIDs in a separately reviewed data migration first.
"""
from alembic import op
import sqlalchemy as sa

revision = "20261018_03"
down_revision = "20261018_02"
branch_labels = None
depends_on = None


def upgrade() -> None:
    connection = op.get_bind()
    existing = connection.execute(
        sa.text("SELECT COUNT(*) FROM journal_entries")
    ).scalar_one()
    if existing:
        raise RuntimeError(
            f"Refusing journal ownership migration: {existing} unowned legacy "
            "entries exist. Map all legacy rows to verified auth.users IDs "
            "using a separately reviewed data migration before continuing."
        )

    is_postgresql = connection.dialect.name == "postgresql"
    with op.batch_alter_table("journal_entries", schema=None) as batch:
        batch.add_column(sa.Column("user_id", sa.Uuid(as_uuid=True), nullable=False))
        if is_postgresql:
            batch.create_foreign_key(
                "fk_journal_entries_auth_users",
                "users",
                ["user_id"], ["id"],
                referent_schema="auth",
                ondelete="CASCADE",
            )
        batch.create_unique_constraint(
            "uq_journal_entries_id_user_id", ["id", "user_id"]
        )
        batch.create_index(
            "ix_journal_entries_user_created_id",
            ["user_id", "created_at", "id"],
            unique=False,
        )

    if is_postgresql:
        # B02 hardening must remain enabled. No direct client policies:
        # clients access private data via owner-filtered FastAPI only.
        op.execute("ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    # A downgrade would remove the ownership boundary and allow legacy
    # unscoped journal APIs to expose private diaries. Fail closed instead.
    raise RuntimeError(
        "Refusing unsafe downgrade: journal ownership cannot be removed. "
        "Restore using a reviewed backup and manual plan."
    )
