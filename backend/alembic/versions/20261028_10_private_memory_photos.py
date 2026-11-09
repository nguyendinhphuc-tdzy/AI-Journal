"""Private Memory photo object key and owner-scoped Supabase Storage bucket.

Revision ID: 20261028_10
Revises: 20261028_09
"""
from alembic import op
import sqlalchemy as sa

revision = "20261028_10"
down_revision = "20261028_09"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("album_memories", sa.Column("photo_path", sa.String(400), nullable=True))
    if op.get_bind().dialect.name != "postgresql":
        return
    op.execute("""
    DO $do$
    BEGIN
      IF to_regclass('storage.buckets') IS NOT NULL
         AND to_regclass('storage.objects') IS NOT NULL THEN
        INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
        VALUES ('journal-memory-private', 'journal-memory-private', false, 5242880,
                ARRAY['image/jpeg','image/png','image/webp'])
        ON CONFLICT (id) DO UPDATE SET public = false,
          file_size_limit = 5242880, allowed_mime_types = EXCLUDED.allowed_mime_types;
        EXECUTE 'CREATE POLICY "journal_memory_photo_select" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = ''journal-memory-private'' AND (storage.foldername(name))[1] = (select auth.uid())::text)';
        EXECUTE 'CREATE POLICY "journal_memory_photo_insert" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = ''journal-memory-private'' AND (storage.foldername(name))[1] = (select auth.uid())::text)';
        EXECUTE 'CREATE POLICY "journal_memory_photo_delete" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = ''journal-memory-private'' AND (storage.foldername(name))[1] = (select auth.uid())::text)';
      END IF;
    END
    $do$;
    """)


def downgrade() -> None:
    raise RuntimeError("Refusing to remove private photo storage metadata or policies")
