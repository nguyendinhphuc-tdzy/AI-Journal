"""B13: real PostgreSQL security checks on a STRICTLY LOCAL disposable database.

Run only when B13_POSTGRES_TEST_URL points to localhost/127.0.0.1 and the
hardcoded CI test database name. NEVER run against a Supabase project URL.
Supabase-managed auth.users and roles are mocked only inside this test DB.
"""
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

import pytest
import sqlalchemy as sa
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.engine import make_url


DATABASE_NAME = "ai_journal_b13_ci"
BACKEND_DIR = Path(__file__).resolve().parents[1]
TABLES = (
    "alembic_version", "journal_entries", "user_profiles",
    "journal_action_days", "saved_places", "place_notes", "journal_places",
    "albums", "album_memories",
)
USER_TABLES = TABLES[1:]


@pytest.fixture(scope="module")
def postgres_engine():
    raw = os.getenv("B13_POSTGRES_TEST_URL")
    if not raw:
        pytest.skip("PostgreSQL integration requires an explicit disposable B13_POSTGRES_TEST_URL")

    url = make_url(raw)
    # Hard fail (not skip!) before opening a connection if any value could
    # identify a shared Supabase or production database.
    if (
        url.get_backend_name() != "postgresql"
        or url.host not in ("localhost", "127.0.0.1", "::1")
        or url.database != DATABASE_NAME
        or url.username != "postgres"
        or url.port != 5432
    ):
        pytest.fail(
            "B13_POSTGRES_TEST_URL MUST target postgres@localhost:5432/"
            + DATABASE_NAME
            + "; refusing to connect to a shared database."
        )

    engine = sa.create_engine(raw, pool_pre_ping=True)
    with engine.begin() as connection:
        assert connection.execute(text("SELECT current_database()")).scalar_one() == DATABASE_NAME
        # Supabase owns these objects in a real project. The mock below is
        # allowed ONLY on this ephemeral CI service PostgreSQL instance.
        connection.execute(text("CREATE SCHEMA IF NOT EXISTS auth"))
        connection.execute(text(
            "CREATE TABLE IF NOT EXISTS auth.users (id uuid PRIMARY KEY)"
        ))
        connection.execute(text("""
            DO $$
            BEGIN
              IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
                CREATE ROLE anon NOLOGIN;
              END IF;
              IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
                CREATE ROLE authenticated NOLOGIN;
              END IF;
            END
            $$;
        """))

    env = os.environ.copy()
    env["DATABASE_URL"] = raw
    env["MIGRATION_DATABASE_URL"] = raw
    env["APP_ENV"] = "test"
    # Reproduce the exact live Supabase-Dev baseline: revision 20261011_01,
    # public journals/alembic_version with RLS enabled and client grants
    # revoked. The project is not a fresh database, so testing only a clean
    # upgrade head would miss failures unique to the deployed state.
    baseline = subprocess.run(
        [sys.executable, "-m", "alembic", "upgrade", "20261011_01"],
        cwd=BACKEND_DIR, env=env, capture_output=True, text=True, timeout=90,
    )
    assert baseline.returncode == 0, (
        f"Baseline Alembic migration FAILED:\n{baseline.stdout}\n{baseline.stderr}"
    )
    with engine.begin() as connection:
        connection.execute(text(
            "ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY"
        ))
        connection.execute(text(
            "ALTER TABLE public.alembic_version ENABLE ROW LEVEL SECURITY"
        ))
        connection.execute(text(
            "REVOKE ALL ON TABLE public.journal_entries, public.alembic_version "
            "FROM anon, authenticated"
        ))
        connection.execute(text(
            "REVOKE ALL ON SEQUENCE public.journal_entries_id_seq "
            "FROM anon, authenticated"
        ))
        assert connection.execute(text(
            "SELECT COUNT(*) FROM public.journal_entries"
        )).scalar_one() == 0

    # Rehearse the additive 08 and 09 upgrades on a populated
    # existing revision 07 database. Cloud fields MUST preserve old entries.
    previous = subprocess.run(
        [sys.executable, "-m", "alembic", "upgrade", "20261025_07"],
        cwd=BACKEND_DIR, env=env, capture_output=True, text=True, timeout=90,
    )
    assert previous.returncode == 0, (
        f"Previous head failed:\\n{previous.stdout}\\n{previous.stderr}"
    )
    synthetic_user = uuid4()
    with engine.begin() as connection:
        connection.execute(
            text("INSERT INTO auth.users (id) VALUES (:id)"),
            {"id": synthetic_user},
        )
        old_journal = connection.execute(text("""
            INSERT INTO public.journal_entries
              (user_id, title, content, created_at, updated_at)
            VALUES (:id, 'Existing entry', 'Keep this journal', now(), now())
            RETURNING id
        """), {"id": synthetic_user}).scalar_one()

    migrated = subprocess.run(
        [sys.executable, "-m", "alembic", "upgrade", "head"],
        cwd=BACKEND_DIR, env=env, capture_output=True, text=True, timeout=90,
    )
    assert migrated.returncode == 0, (
        f"Postgres Alembic migration FAILED:\n{migrated.stdout}\n{migrated.stderr}"
    )
    with engine.connect() as connection:
        preserved = connection.execute(text("""
            SELECT content, body_version, guided, source
            FROM public.journal_entries WHERE id = :id
        """), {"id": old_journal}).one()
        assert preserved == ("Keep this journal", 1, None, None)

    checked = subprocess.run(
        [sys.executable, "-m", "alembic", "check"],
        cwd=BACKEND_DIR, env=env, capture_output=True, text=True, timeout=90,
    )
    assert checked.returncode == 0, (
        f"Postgres Alembic autogenerate drift detected:\n"
        f"{checked.stdout}\n{checked.stderr}"
    )
    yield engine
    engine.dispose()


def test_postgres_upgrade_schema_and_rls(postgres_engine):
    inspector = sa.inspect(postgres_engine)
    with postgres_engine.connect() as conn:
        assert conn.execute(text("SELECT version_num FROM alembic_version")).scalar_one() == "20261028_09"
        for table in TABLES:
            assert inspector.has_table(table, schema="public"), table
            rls = conn.execute(text("""
                SELECT relrowsecurity FROM pg_class
                WHERE oid = to_regclass(:table_name)
            """), {"table_name": f"public.{table}"}).scalar_one()
            assert rls is True, f"{table}: RLS not enabled"
            for role in ("anon", "authenticated"):
                for privilege in ("SELECT", "INSERT", "UPDATE", "DELETE"):
                    has_privilege = conn.execute(
                        text("SELECT has_table_privilege(:role,:table,:privilege)"),
                        {"role": role, "table": f"public.{table}", "privilege": privilege},
                    ).scalar_one()
                    assert has_privilege is False, (
                        f"{table} exposed via {role} {privilege}"
                    )

        expected_composites = {
            "place_notes": {"fk_place_notes_owner_place"},
            "album_memories": {"fk_album_memories_owner_album"},
            "journal_places": {
                "fk_journal_places_owner_journal",
                "fk_journal_places_owner_place",
            },
        }
        for table, required in expected_composites.items():
            actual = {fk["name"] for fk in inspector.get_foreign_keys(table)}
            assert required.issubset(actual), (table, actual)
        journal_fks = inspector.get_foreign_keys("journal_entries")
        assert any(fk["referred_schema"] == "auth" and
                   fk["referred_table"] == "users" for fk in journal_fks)
        assert any(fk["referred_schema"] == "auth" and
                   fk["referred_table"] == "users"
                   for fk in inspector.get_foreign_keys("saved_places"))
        assert any(fk["referred_schema"] == "auth" and
                   fk["referred_table"] == "users"
                   for fk in inspector.get_foreign_keys("user_profiles"))
        assert any(fk["referred_schema"] == "auth" and
                   fk["referred_table"] == "users"
                   for fk in inspector.get_foreign_keys("albums"))


def test_postgres_composite_owner_fk_and_cascades(postgres_engine):
    alice, bob = uuid4(), uuid4()
    now = datetime.now(timezone.utc)
    with postgres_engine.begin() as conn:
        conn.execute(
            text("INSERT INTO auth.users (id) VALUES (:a),(:b)"),
            {"a": alice, "b": bob},
        )
        journals = [
            conn.execute(text("""
                INSERT INTO journal_entries
                (user_id,title,content,created_at,updated_at)
                VALUES (:uid,'Synthetic', 'CI only', :now,:now)
                RETURNING id
            """), {"uid": uid, "now": now}).scalar_one()
            for uid in (alice, bob)
        ]
        places = [
            conn.execute(text("""
                INSERT INTO saved_places
                (user_id,label,latitude,longitude,provider,created_at,updated_at)
                VALUES (:uid,'CI pin', 10.823100,106.629700, 'manual',:now,:now)
                RETURNING id
            """), {"uid": uid, "now": now}).scalar_one()
            for uid in (alice, bob)
        ]
        # Joining Alice's journal to Bob's place MUST fail at FK layer.
        with pytest.raises(IntegrityError):
            with conn.begin_nested():
                conn.execute(text("""
                    INSERT INTO journal_places (user_id,journal_id,place_id,created_at)
                    VALUES (:a,:j,:foreign_place,:now)
                """), {"a": alice, "j": journals[0], "foreign_place": places[1], "now": now})
        with pytest.raises(IntegrityError):
            with conn.begin_nested():
                conn.execute(text("""
                    INSERT INTO place_notes (user_id,place_id,content,created_at,updated_at)
                    VALUES (:bob,:alice_place,'cross-owner',:now,:now)
                """), {"bob": bob, "alice_place": places[0], "now": now})

        conn.execute(text("""
            INSERT INTO journal_places (user_id,journal_id,place_id,created_at)
            VALUES (:alice,:journal,:place,:now)
        """), {"alice": alice, "journal": journals[0], "place": places[0], "now": now})
        conn.execute(text("""
            INSERT INTO place_notes (user_id,place_id,content,created_at,updated_at)
            VALUES (:alice,:place,'synthetic note',:now,:now)
        """), {"alice": alice, "place": places[0], "now": now})
        # Deleting one place deletes only its dependent rows.
        conn.execute(
            text("DELETE FROM saved_places WHERE id=:id AND user_id=:uid"),
            {"id": places[0], "uid": alice},
        )
        assert conn.execute(text(
            "SELECT COUNT(*) FROM journal_places WHERE journal_id=:j"
        ), {"j": journals[0]}).scalar_one() == 0
        assert conn.execute(text(
            "SELECT COUNT(*) FROM place_notes WHERE place_id=:p"
        ), {"p": places[0]}).scalar_one() == 0
        assert conn.execute(text(
            "SELECT COUNT(*) FROM journal_entries WHERE id=:j"
        ), {"j": journals[0]}).scalar_one() == 1
        assert conn.execute(text(
            "SELECT COUNT(*) FROM journal_entries WHERE id=:j"
        ), {"j": journals[1]}).scalar_one() == 1


def test_postgres_fastapi_owner_isolation(postgres_engine):
    """HTTP behavior with actual Postgres persistence, synthetic verified identities."""
    from fastapi.testclient import TestClient
    from sqlalchemy.orm import Session, sessionmaker

    from app.core.auth import AuthenticatedUser, get_current_user
    from app.core.database import get_db
    from app.main import app

    alice, bob = uuid4(), uuid4()
    session_factory = sessionmaker(bind=postgres_engine, expire_on_commit=False)

    with postgres_engine.begin() as conn:
        conn.execute(text("INSERT INTO auth.users (id) VALUES (:a), (:b)"),
                     {"a": alice, "b": bob})

    def override_db():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_db] = override_db
    client = TestClient(app)
    try:
        app.dependency_overrides.pop(get_current_user, None)
        assert client.get("/api/v1/journals").status_code == 401
        assert client.get("/api/v1/places").status_code == 401
        assert client.get("/api/v1/streak").status_code == 401

        app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
            user_id=alice, email="alice@example.test"
        )
        ja = client.post("/api/v1/journals", json={"content":"Alice's private synthetic entry"})
        assert ja.status_code == 201, ja.text
        pa = client.post("/api/v1/places", json={
            "label":"Alice's pin","latitude":10.8,"longitude":106.6
        })
        assert pa.status_code == 201, pa.text
        note = client.post(f"/api/v1/places/{pa.json()['id']}/notes", json={
            "content":"Alice's note"
        })
        assert note.status_code == 201, note.text
        link = client.put(f"/api/v1/journals/{ja.json()['id']}/places/{pa.json()['id']}")
        assert link.status_code == 204, link.text

        app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
            user_id=bob, email="bob@example.test"
        )
        assert client.get(f"/api/v1/journals/{ja.json()['id']}").status_code == 404
        assert client.get(f"/api/v1/places/{pa.json()['id']}").status_code == 404
        assert client.get(f"/api/v1/places/{pa.json()['id']}/notes").status_code == 404
        assert client.get(f"/api/v1/journals/{ja.json()['id']}/places").status_code == 404
        assert client.get("/api/v1/journals").json()["items"] == []
        assert client.get("/api/v1/places").json()["items"] == []
        assert client.get("/api/v1/streak").json()["today_completed"] is False
    finally:
        app.dependency_overrides.clear()
        client.close()
