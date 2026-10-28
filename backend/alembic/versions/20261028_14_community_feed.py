"""Moderated opt-in text-only feed.

Revision ID: 20261028_14
Revises: 20261028_13
"""
from alembic import op
import sqlalchemy as sa

revision = "20261028_14"
down_revision = "20261028_13"
branch_labels = None
depends_on = None


def upgrade():
    postgres = op.get_bind().dialect.name == "postgresql"
    author_fk = [sa.ForeignKeyConstraint(["author_id"], ["auth.users.id"], ondelete="CASCADE")] if postgres else []
    report_fk = [sa.ForeignKeyConstraint(["reporter_id"], ["auth.users.id"], ondelete="CASCADE")] if postgres else []
    op.create_table("community_posts",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("author_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("status IN ('pending','approved','rejected')", name="ck_community_status"),
        *author_fk)
    op.create_index("ix_community_posts_author_id", "community_posts", ["author_id"])
    op.create_table("community_reports",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("post_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("reporter_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("reason", sa.String(200), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("post_id", "reporter_id", name="uq_community_reporter_post"),
        sa.ForeignKeyConstraint(["post_id"], ["community_posts.id"], ondelete="CASCADE"),
        *report_fk)
    if postgres:
        for table in ("community_posts", "community_reports"):
            op.execute(f"ALTER TABLE public.{table} ENABLE ROW LEVEL SECURITY")
            op.execute(f"REVOKE ALL ON public.{table} FROM anon, authenticated")


def downgrade():
    raise RuntimeError("Refusing to discard community posts and reports")
