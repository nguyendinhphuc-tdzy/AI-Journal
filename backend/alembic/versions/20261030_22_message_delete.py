"""Deleting messages: recall for both, hide one or a whole chat for oneself.

Revision ID: 20261030_22
Revises: 20261030_21
"""
from alembic import op
import sqlalchemy as sa

revision = "20261030_22"
down_revision = "20261030_21"
branch_labels = None
depends_on = None

TEXT_RULE = ("kind != 'text' OR recalled_at IS NOT NULL OR "
             "(text IS NOT NULL AND length(trim(text)) > 0 AND length(text) <= 2000)")


def upgrade() -> None:
    pg = op.get_bind().dialect.name == "postgresql"
    # A recalled message keeps its row (order, read cursors) but no content.
    with op.batch_alter_table("messages") as batch:
        batch.add_column(sa.Column("recalled_at", sa.DateTime(timezone=True), nullable=True))
        batch.drop_constraint("ck_message_text", type_="check")
        batch.create_check_constraint("ck_message_text", TEXT_RULE)
    # "Xoá cuộc trò chuyện": messages up to this moment are gone for this user.
    with op.batch_alter_table("conversation_reads") as batch:
        batch.add_column(sa.Column("cleared_at", sa.DateTime(timezone=True), nullable=True))
    users_fk = [sa.ForeignKeyConstraint(["user_id"], ["auth.users.id"], ondelete="CASCADE")] if pg else []
    op.create_table("message_hides",
        sa.Column("message_id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("user_id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["message_id"], ["messages.id"], ondelete="CASCADE"),
        *users_fk,
    )
    op.create_index("ix_message_hides_user", "message_hides", ["user_id"])
    if pg:
        op.execute("ALTER TABLE public.message_hides ENABLE ROW LEVEL SECURITY")
        op.execute("REVOKE ALL ON public.message_hides FROM anon, authenticated")


def downgrade() -> None:
    raise RuntimeError("Refusing to bring back recalled or deleted messages")
