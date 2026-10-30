"""Private AI analysis, saved quotes and cached weekly narratives.

Revision ID: 20261029_16
Revises: 20261028_15
"""
from alembic import op
import sqlalchemy as sa

revision = "20261029_16"
down_revision = "20261028_15"
branch_labels = None
depends_on = None


def upgrade():
    postgres = op.get_bind().dialect.name == "postgresql"
    owner_fk = lambda col: ([sa.ForeignKeyConstraint([col], ["auth.users.id"],
                     ondelete="CASCADE")] if postgres else [])

    op.create_table(
        "journal_analyses",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("journal_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("body_version", sa.Integer(), nullable=False),
        sa.Column("result", sa.JSON(), nullable=False),
        sa.Column("feedback", sa.String(8), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["journal_id", "user_id"],
                                ["journal_entries.id", "journal_entries.user_id"],
                                name="fk_analysis_owned_journal", ondelete="CASCADE"),
        sa.UniqueConstraint("journal_id", "user_id", name="uq_analysis_owned_journal"),
        sa.CheckConstraint("body_version >= 1", name="ck_analysis_body_version"),
        sa.CheckConstraint("feedback IN ('up', 'down') OR feedback IS NULL",
                           name="ck_analysis_feedback"),
    )
    op.create_index("ix_analysis_user_created", "journal_analyses", ["user_id", "created_at"])

    op.create_table(
        "saved_quotes",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("user_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("author", sa.String(160), nullable=False),
        sa.Column("source", sa.String(250), nullable=True),
        sa.Column("saved_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("user_id", "text", name="uq_saved_quote_user_text"),
        *owner_fk("user_id"),
    )
    op.create_index("ix_saved_quotes_user_id", "saved_quotes", ["user_id"])

    op.create_table(
        "weekly_insights",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("user_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("monday", sa.Date(), nullable=False),
        sa.Column("fingerprint", sa.String(64), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False),
        sa.Column("generated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("user_id", "monday", name="uq_weekly_insight_user_week"),
        *owner_fk("user_id"),
    )
    op.create_index("ix_weekly_insights_user_id", "weekly_insights", ["user_id"])

    if postgres:
        for table in ("journal_analyses", "saved_quotes", "weekly_insights"):
            op.execute(f"ALTER TABLE public.{table} ENABLE ROW LEVEL SECURITY")
            # Application only uses its server-side SQLAlchemy connection,
            # never direct Data API access from anon/authenticated Flutter.
            op.execute(f"REVOKE ALL ON public.{table} FROM anon, authenticated")


def downgrade():
    raise RuntimeError("Refusing to discard private user AI data")
