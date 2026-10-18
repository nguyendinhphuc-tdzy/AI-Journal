"""Add private user-owned map pins, without Journal / Notes tables.

Revision ID: 20261018_05
Revises: 20261018_04
"""
from alembic import op
import sqlalchemy as sa


revision = "20261018_05"
down_revision = "20261018_04"
branch_labels = None
depends_on = None


def upgrade() -> None:
    is_postgresql = op.get_bind().dialect.name == "postgresql"
    constraints = [
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("id", "user_id", name="uq_saved_places_id_user_id"),
        sa.CheckConstraint(
            "latitude >= -90 AND latitude <= 90", name="ck_saved_places_lat"
        ),
        sa.CheckConstraint(
            "longitude >= -180 AND longitude <= 180", name="ck_saved_places_lon"
        ),
        sa.CheckConstraint(
            "provider IN ('manual', 'geoapify')", name="ck_saved_places_provider"
        ),
        sa.CheckConstraint(
            "(provider = 'manual' AND external_place_id IS NULL) OR "
            "(provider = 'geoapify' AND external_place_id IS NOT NULL "
            "AND length(trim(external_place_id)) > 0)",
            name="ck_saved_places_external_id",
        ),
    ]
    if is_postgresql:
        constraints.append(
            sa.ForeignKeyConstraint(
                ["user_id"], ["auth.users.id"],
                name="fk_saved_places_auth_users", ondelete="CASCADE",
            )
        )
    op.create_table(
        "saved_places",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("label", sa.String(160), nullable=False),
        sa.Column("latitude", sa.Numeric(9, 6), nullable=False),
        sa.Column("longitude", sa.Numeric(9, 6), nullable=False),
        sa.Column("address_text", sa.Text(), nullable=True),
        sa.Column("provider", sa.String(32), nullable=False),
        sa.Column("external_place_id", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        *constraints,
    )
    op.create_index(
        "ix_saved_places_user_created_id",
        "saved_places", ["user_id", "created_at", "id"],
    )
    op.create_index(
        "uq_saved_places_owner_provider_external_id",
        "saved_places",
        ["user_id", "provider", "external_place_id"],
        unique=True,
        postgresql_where=sa.text("external_place_id IS NOT NULL"),
        sqlite_where=sa.text("external_place_id IS NOT NULL"),
    )
    if is_postgresql:
        op.execute("ALTER TABLE public.saved_places ENABLE ROW LEVEL SECURITY")
        op.execute(
            "REVOKE ALL ON TABLE public.saved_places FROM anon, authenticated"
        )
        op.execute(
            "REVOKE ALL ON SEQUENCE public.saved_places_id_seq FROM anon, authenticated"
        )


def downgrade() -> None:
    # Future B10 Notes/Journal links may depend on this table; dropping it
    # would also irreversibly destroy a user's personal map data.
    raise RuntimeError(
        "Refusing destructive B09 downgrade: preserve saved places and "
        "use a reviewed PostgreSQL backup/recovery plan."
    )
