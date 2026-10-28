"""Create private canonical friend relationships.

Revision ID: 20261028_11
Revises: 20261028_10
"""
from alembic import op
import sqlalchemy as sa

revision = "20261028_11"
down_revision = "20261028_10"
branch_labels = None
depends_on = None


def upgrade() -> None:
    postgres = op.get_bind().dialect.name == "postgresql"
    constraints = [
        sa.CheckConstraint("user_low_id <> user_high_id", name="ck_friend_distinct"),
        sa.CheckConstraint("status IN ('pending', 'accepted')", name="ck_friend_status"),
        sa.CheckConstraint("requester_id IN (user_low_id, user_high_id)", name="ck_friend_requester"),
    ]
    if postgres:
        constraints += [
            sa.ForeignKeyConstraint(["user_low_id"], ["auth.users.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["user_high_id"], ["auth.users.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["requester_id"], ["auth.users.id"], ondelete="CASCADE"),
        ]
    op.create_table("friendships",
        sa.Column("user_low_id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("user_high_id", sa.Uuid(as_uuid=True), primary_key=True),
        sa.Column("requester_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        *constraints)
    if postgres:
        op.execute("ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY")
        op.execute("REVOKE ALL ON public.friendships FROM anon, authenticated")


def downgrade() -> None:
    # Avoid silent loss of user relationship data.
    raise RuntimeError("Refusing to drop friendships or weaken privacy policies")
