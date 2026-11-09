"""Private album tables for PR17. Revision 20261025_07."""
from alembic import op
import sqlalchemy as sa

revision = "20261025_07"
down_revision = "20261018_06"
branch_labels = None
depends_on = None


def upgrade() -> None:
    pg = op.get_bind().dialect.name == "postgresql"
    constraints = [
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("id", "user_id", name="uq_albums_id_user"),
        sa.CheckConstraint("length(trim(name)) > 0", name="ck_albums_nonblank"),
    ]
    if pg:
        constraints.append(sa.ForeignKeyConstraint(
            ["user_id"], ["auth.users.id"],
            name="fk_albums_auth_users", ondelete="CASCADE"))
    op.create_table(
        "albums",
        sa.Column("id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("user_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("theme_id", sa.String(60), nullable=False),
        sa.Column("locked", sa.Boolean(), nullable=False),
        sa.Column("hide_name_when_locked", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        *constraints,
    )
    op.create_index("ix_albums_user_created", "albums",
                    ["user_id", "created_at", "id"])
    op.create_table(
        "album_memories",
        sa.Column("id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("user_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("album_id", sa.Uuid(as_uuid=True), nullable=False),
        sa.Column("title", sa.String(160), nullable=True),
        sa.Column("note", sa.Text(), nullable=False),
        sa.Column("display_date", sa.Date(), nullable=False),
        sa.Column("place", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.CheckConstraint("note IS NOT NULL AND length(trim(note)) > 0",
                           name="ck_album_memories_nonblank_note"),
        sa.ForeignKeyConstraint(
            ["album_id", "user_id"], ["albums.id", "albums.user_id"],
            name="fk_album_memories_owner_album", ondelete="CASCADE"),
    )
    op.create_index("ix_album_memories_owner_album_date", "album_memories",
                    ["user_id", "album_id", "display_date", "created_at"])
    if pg:
        for table in ("albums", "album_memories"):
            op.execute(f"ALTER TABLE public.{table} ENABLE ROW LEVEL SECURITY")
            op.execute(f"REVOKE ALL ON TABLE public.{table} FROM anon, authenticated")


def downgrade() -> None:
    raise RuntimeError("Destructive album downgrade is disabled; preserve personal data.")
