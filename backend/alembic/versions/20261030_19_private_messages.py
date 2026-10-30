"""Private one-to-one messaging, read cursors and idempotent sends.

Revision ID: 20261030_19
Revises: 20261030_18
"""
from alembic import op
import sqlalchemy as sa

revision = "20261030_19"
down_revision = "20261030_18"
branch_labels = None
depends_on = None

def upgrade() -> None:
    pg = op.get_bind().dialect.name == "postgresql"
    users_fk = lambda col: [sa.ForeignKeyConstraint([col], ["auth.users.id"], ondelete="CASCADE")] if pg else []
    op.create_table("conversations",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("user_low_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("user_high_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("user_low_id", "user_high_id", name="uq_conversations_pair"),
        sa.CheckConstraint("user_low_id <> user_high_id", name="ck_conversation_distinct"),
        *users_fk("user_low_id"), *users_fk("user_high_id"),
    )
    op.create_table("messages",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("conversation_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("sender_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("kind", sa.String(20), nullable=False),
        sa.Column("client_id", sa.String(100), nullable=True),
        sa.Column("text", sa.Text(), nullable=True),
        sa.Column("place", sa.JSON(), nullable=True),
        sa.Column("memory_share_id", sa.Uuid(as_uuid=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["conversation_id"], ["conversations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["memory_share_id"], ["memory_shares.id"], ondelete="SET NULL"),
        sa.UniqueConstraint("conversation_id", "sender_id", "client_id", name="uq_message_client_id"),
        sa.CheckConstraint("kind IN ('text','place','memory_share')", name="ck_message_kind"),
        sa.CheckConstraint("kind != 'text' OR (text IS NOT NULL AND length(trim(text)) > 0 AND length(text) <= 2000)", name="ck_message_text"),
        *users_fk("sender_id"),
    )
    op.create_index("ix_messages_conversation_created", "messages", ["conversation_id", "created_at", "id"])
    op.create_index("ix_messages_sender_created", "messages", ["sender_id", "created_at"])
    op.create_table("conversation_reads",
        sa.Column("conversation_id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("user_id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("last_read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_read_message_id", sa.Uuid(as_uuid=True), nullable=True),
        sa.ForeignKeyConstraint(["conversation_id"], ["conversations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["last_read_message_id"], ["messages.id"], ondelete="SET NULL"),
        *users_fk("user_id"),
    )
    op.create_index("ix_conversation_reads_user", "conversation_reads", ["user_id"])
    if pg:
        for table in ("conversations", "messages", "conversation_reads"):
            op.execute(f"ALTER TABLE public.{table} ENABLE ROW LEVEL SECURITY")
            op.execute(f"REVOKE ALL ON public.{table} FROM anon, authenticated")

def downgrade() -> None:
    raise RuntimeError("Refusing to discard private chat history or read cursors")
