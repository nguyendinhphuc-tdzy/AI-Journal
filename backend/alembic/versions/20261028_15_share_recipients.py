"""Explicit recipient lists for friends-only 24h shares.

Revision ID: 20261028_15
Revises: 20261028_14
"""
from alembic import op
import sqlalchemy as sa

revision = "20261028_15"
down_revision = "20261028_14"
branch_labels = None
depends_on = None


def upgrade():
    constraints = [sa.ForeignKeyConstraint(["share_id"], ["memory_shares.id"], ondelete="CASCADE"),
                   sa.CheckConstraint("owner_id <> recipient_id", name="ck_share_recipient_distinct")]
    if op.get_bind().dialect.name == "postgresql":
        constraints += [
            sa.ForeignKeyConstraint(["owner_id"], ["auth.users.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["recipient_id"], ["auth.users.id"], ondelete="CASCADE"),
        ]
    op.create_table("memory_share_recipients",
        sa.Column("share_id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("owner_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("recipient_id", sa.Uuid(as_uuid=True), primary_key=True),
        *constraints)
    if op.get_bind().dialect.name == "postgresql":
        op.execute("ALTER TABLE public.memory_share_recipients ENABLE ROW LEVEL SECURITY")
        op.execute("REVOKE ALL ON public.memory_share_recipients FROM anon, authenticated")
    # Fail closed: legacy shares minted before explicit audiences are inaccessible to friends
    # until the author creates a new share with explicit recipients.


def downgrade():
    raise RuntimeError("Refusing to discard explicit share-recipient ACLs")
