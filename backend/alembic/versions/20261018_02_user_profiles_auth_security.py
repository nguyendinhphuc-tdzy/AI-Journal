"""Add Supabase Auth profiles and deny direct client access to prototype data.

Revision ID: 20261018_02
Revises: 20261011_01

In isolated SQLite tests, auth.users lives outside the test database and
cannot be referenced; PostgreSQL always creates the real Supabase FK.
"""
from alembic import op
import sqlalchemy as sa

revision = "20261018_02"
down_revision = "20261011_01"
branch_labels = None
depends_on = None


def upgrade() -> None:
    is_postgresql = op.get_bind().dialect.name == "postgresql"
    columns_and_constraints = [
        sa.Column("user_id", sa.Uuid(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("display_name", sa.String(100), nullable=True),
        sa.Column("timezone", sa.String(64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    ]
    if is_postgresql:
        columns_and_constraints.append(
            sa.ForeignKeyConstraint(
                ["user_id"], ["auth.users.id"],
                name="fk_user_profiles_auth_users", ondelete="CASCADE"
            )
        )
    op.create_table("user_profiles", *columns_and_constraints)

    if is_postgresql:
        # No policies: direct anon/authenticated Data API access is intentionally
        # denied. FastAPI uses a separately secured Postgres role.
        op.execute("ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY")
        op.execute("ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY")
        op.execute("ALTER TABLE public.alembic_version ENABLE ROW LEVEL SECURITY")
        op.execute(
            "REVOKE ALL ON TABLE public.user_profiles, public.journal_entries, "
            "public.alembic_version FROM anon, authenticated"
        )
        op.execute(
            "REVOKE ALL ON SEQUENCE public.journal_entries_id_seq FROM anon, authenticated"
        )


def downgrade() -> None:
    # Security hardening intentionally stays in force even on rollback.
    # Disabling RLS or restoring public data grants would expose old diaries.
    op.drop_table("user_profiles")
