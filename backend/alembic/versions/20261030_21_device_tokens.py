"""FCM device registration tokens: private table with account deletion cascade.

Revision ID: 20261030_21
Revises: 20261030_20
"""
from alembic import op
import sqlalchemy as sa

revision = "20261030_21"
down_revision = "20261030_20"
branch_labels = None
depends_on = None

def upgrade() -> None:
    postgres = op.get_bind().dialect.name == "postgresql"
    fks = [sa.ForeignKeyConstraint(["user_id"], ["auth.users.id"],
                                   ondelete="CASCADE")] if postgres else []
    op.create_table("device_tokens",
        sa.Column("token_hash", sa.String(64), primary_key=True),
        sa.Column("token", sa.Text(), nullable=False),
        sa.Column("user_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("installation_id", sa.String(128), nullable=False),
        sa.Column("platform", sa.String(10), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("user_id", "installation_id",
                            name="uq_device_owner_installation"),
        sa.CheckConstraint("platform IN ('android','ios')",
                           name="ck_device_platform"),
        *fks)
    op.create_index("ix_device_tokens_user_last_seen", "device_tokens",
                    ["user_id", "last_seen_at"])
    if postgres:
        op.execute("ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY")
        op.execute("REVOKE ALL ON public.device_tokens FROM anon, authenticated")

def downgrade() -> None:
    # No other user table depends on tokens. Device registration is disposable.
    op.drop_index("ix_device_tokens_user_last_seen", table_name="device_tokens")
    op.drop_table("device_tokens")
