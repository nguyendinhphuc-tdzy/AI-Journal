"""Opt-in profile discovery and private blocks.

Revision ID: 20261028_12
Revises: 20261028_11
"""
from alembic import op
import sqlalchemy as sa

revision = "20261028_12"
down_revision = "20261028_11"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("user_profiles", sa.Column("discoverable", sa.Boolean(), nullable=False, server_default=sa.false()))
    constraints = [sa.CheckConstraint("blocker_id <> blocked_id", name="ck_block_distinct")]
    if op.get_bind().dialect.name == "postgresql":
        constraints += [
            sa.ForeignKeyConstraint(["blocker_id"], ["auth.users.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["blocked_id"], ["auth.users.id"], ondelete="CASCADE"),
        ]
    op.create_table("user_blocks",
        sa.Column("blocker_id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("blocked_id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        *constraints)
    if op.get_bind().dialect.name == "postgresql":
        op.execute("ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY")
        op.execute("REVOKE ALL ON public.user_blocks FROM anon, authenticated")


def downgrade():
    raise RuntimeError("Refusing to remove blocks or opt-in privacy settings")
