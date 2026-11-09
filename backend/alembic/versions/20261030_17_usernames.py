"""Add optional unique public username; private profiles stay opt-in.

Revision ID: 20261030_17
Revises: 20261029_16
"""
from alembic import op
import sqlalchemy as sa

revision = "20261030_17"
down_revision = "20261029_16"
branch_labels = None
depends_on = None

def upgrade() -> None:
    # Nullable: existing users keep their profile and discoverable=False.
    # Batch mode supports SQLite test migrations and PostgreSQL.
    with op.batch_alter_table("user_profiles") as batch:
        batch.add_column(sa.Column("username", sa.String(24), nullable=True))
        batch.create_unique_constraint("uq_user_profiles_username", ["username"])

def downgrade() -> None:
    raise RuntimeError("Refusing to drop account usernames")
