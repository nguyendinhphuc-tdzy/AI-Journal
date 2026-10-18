"""Add private place notes and same-owner journal-place associations.

Revision ID: 20261018_06
Revises: 20261018_05
"""
from alembic import op
import sqlalchemy as sa

revision = "20261018_06"
down_revision = "20261018_05"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "place_notes",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("place_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["place_id", "user_id"],
            ["saved_places.id", "saved_places.user_id"],
            name="fk_place_notes_owner_place",
            ondelete="CASCADE",
        ),
    )
    op.create_index(
        "ix_place_notes_owner_place_created_id",
        "place_notes", ["user_id", "place_id", "created_at", "id"],
    )

    op.create_table(
        "journal_places",
        sa.Column("user_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("journal_id", sa.Integer(), nullable=False),
        sa.Column("place_id", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("user_id", "journal_id", "place_id"),
        sa.ForeignKeyConstraint(
            ["journal_id", "user_id"],
            ["journal_entries.id", "journal_entries.user_id"],
            name="fk_journal_places_owner_journal",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["place_id", "user_id"],
            ["saved_places.id", "saved_places.user_id"],
            name="fk_journal_places_owner_place",
            ondelete="CASCADE",
        ),
    )
    op.create_index(
        "ix_journal_places_owner_place",
        "journal_places", ["user_id", "place_id"],
    )

    if op.get_bind().dialect.name == "postgresql":
        for table in ("place_notes", "journal_places"):
            op.execute(f"ALTER TABLE public.{table} ENABLE ROW LEVEL SECURITY")
            op.execute(
                f"REVOKE ALL ON TABLE public.{table} FROM anon, authenticated"
            )
        op.execute(
            "REVOKE ALL ON SEQUENCE public.place_notes_id_seq "
            "FROM anon, authenticated"
        )


def downgrade() -> None:
    # These are personal notes and links; an automatic downgrade would discard
    # user data. Do not reverse B10 without an audited recovery/backup plan.
    raise RuntimeError(
        "Refusing destructive B10 downgrade: preserve notes and journal links."
    )
