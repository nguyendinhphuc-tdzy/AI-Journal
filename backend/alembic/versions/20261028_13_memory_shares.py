"""Friends-only 24-hour Memory shares.

Revision ID: 20261028_13
Revises: 20261028_12
"""
from alembic import op
import sqlalchemy as sa

revision = "20261028_13"
down_revision = "20261028_12"
branch_labels = None
depends_on = None


def upgrade():
    constraints = [
        sa.ForeignKeyConstraint(["memory_id"], ["album_memories.id"], ondelete="CASCADE"),
        sa.CheckConstraint("expires_at > created_at", name="ck_share_expiration_after_creation"),
    ]
    if op.get_bind().dialect.name == "postgresql":
        constraints.append(sa.ForeignKeyConstraint(["owner_id"], ["auth.users.id"], ondelete="CASCADE"))
    op.create_table("memory_shares",
        sa.Column("id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("memory_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("owner_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        *constraints)
    op.create_index("ix_memory_shares_memory_id", "memory_shares", ["memory_id"])
    op.create_index("ix_memory_shares_owner_id", "memory_shares", ["owner_id"])
    if op.get_bind().dialect.name == "postgresql":
        op.execute("ALTER TABLE public.memory_shares ENABLE ROW LEVEL SECURITY")
        op.execute("REVOKE ALL ON public.memory_shares FROM anon, authenticated")


def downgrade():
    raise RuntimeError("Refusing to delete share audit metadata")
