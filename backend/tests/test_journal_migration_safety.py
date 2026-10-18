"""An old journal without a verified owner must block the B04 migration."""
import importlib.util
from pathlib import Path

import pytest
import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations


def test_ownerless_legacy_journals_abort_migration(tmp_path):
    engine = sa.create_engine(f"sqlite:///{tmp_path / 'legacy.sqlite'}")
    migration_path = (
        Path(__file__).resolve().parents[1]
        / "alembic/versions/20261018_03_journal_ownership.py"
    )
    spec = importlib.util.spec_from_file_location("b04_journal_ownership", migration_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    with engine.begin() as connection:
        connection.execute(sa.text(
            "CREATE TABLE journal_entries ("
            "id INTEGER PRIMARY KEY, title VARCHAR(160) NOT NULL, "
            "content TEXT NOT NULL, created_at DATETIME NOT NULL, "
            "updated_at DATETIME NOT NULL)"
        ))
        connection.execute(sa.text(
            "INSERT INTO journal_entries "
            "(id, title, content, created_at, updated_at) "
            "VALUES (1,'old','private','2026-10-01','2026-10-01')"
        ))
        module.op = Operations(MigrationContext.configure(connection))
        with pytest.raises(RuntimeError, match="Refusing journal ownership migration"):
            module.upgrade()

        row = connection.execute(
            sa.text("SELECT id, title, content FROM journal_entries")
        ).one()
        assert row == (1, "old", "private")
        cols = connection.execute(sa.text("PRAGMA table_info(journal_entries)")).all()
        assert "user_id" not in [col[1] for col in cols]
    engine.dispose()
