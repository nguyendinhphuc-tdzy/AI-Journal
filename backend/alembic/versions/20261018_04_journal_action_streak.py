"""Create owner-scoped journal action days, not app-open events.

Revision ID: 20261018_04
Revises: 20261018_03
"""
from alembic import op
import sqlalchemy as sa


revision = "20261018_04"
down_revision = "20261018_03"
branch_labels = None
depends_on = None


def upgrade() -> None:
    is_postgresql = op.get_bind().dialect.name == "postgresql"
    columns_and_constraints = [
        sa.Column("user_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("activity_date", sa.Date(), nullable=False),
        sa.Column("first_completed_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("action_type", sa.String(length=32), nullable=False),
        sa.PrimaryKeyConstraint("user_id", "activity_date"),
    ]
    if is_postgresql:
        columns_and_constraints.append(
            sa.ForeignKeyConstraint(
                ["user_id"], ["auth.users.id"],
                name="fk_journal_action_days_auth_users",
                ondelete="CASCADE",
            )
        )
    op.create_table("journal_action_days", *columns_and_constraints)

    if is_postgresql:
        # All personal data flows through FastAPI; deny direct Supabase clients.
        op.execute(
            "ALTER TABLE public.journal_action_days ENABLE ROW LEVEL SECURITY"
        )
        op.execute(
            "REVOKE ALL ON TABLE public.journal_action_days FROM anon, authenticated"
        )


def downgrade() -> None:
    # Dropping action-day history would destroy the user's streaks.
    raise RuntimeError(
        "Refusing destructive B06 downgrade: preserve completed-action history "
        "and use a reviewed recovery plan."
    )
