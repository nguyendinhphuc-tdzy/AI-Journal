"""Read-only Phase 1 gate for existing AI Journal Supabase PostgreSQL.

Run from backend:
    python -m scripts.phase1_preflight --project-ref rjwentsuqmwncpseakkt

Requires DATABASE_URL or MIGRATION_DATABASE_URL in backend/.env. Never
displays credentials, journal bodies, user email addresses, or SQL secrets.
This script *cannot* apply migrations.
"""

import argparse
from dataclasses import dataclass
import sys

from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

from app.core.config import get_settings


EXPECTED_FROM = "20261011_01"
EXPECTED_TO = "20261025_07"
BASE_TABLES = frozenset({"alembic_version", "journal_entries"})


@dataclass(frozen=True)
class PreflightSnapshot:
    revision: str | None
    tables: frozenset[str]
    journals: int
    auth_users: int
    has_auth_users_table: bool
    has_id_sequence: bool
    rls_by_table: dict[str, bool]
    anon_select_by_table: dict[str, bool]
    authenticated_select_by_table: dict[str, bool]


def blocking_findings(snapshot: PreflightSnapshot) -> list[str]:
    """Fail closed on schema drift, unowned entries and public table access."""
    issues: list[str] = []
    if snapshot.revision != EXPECTED_FROM:
        issues.append("Unexpected Alembic revision: stop and re-check migration order.")
    if snapshot.tables != BASE_TABLES:
        issues.append("Unexpected public tables: schema differs from the reviewed baseline.")
    if snapshot.journals != 0:
        issues.append("Legacy journals exist: ownership migration intentionally forbids unmapped rows.")
    if not snapshot.has_auth_users_table:
        issues.append("Supabase-managed auth.users is missing.")
    if not snapshot.has_id_sequence:
        issues.append("Expected public.journal_entries_id_seq is missing.")
    for table in sorted(BASE_TABLES):
        if snapshot.rls_by_table.get(table) is not True:
            issues.append(f"RLS is not enabled: {table}.")
        if snapshot.anon_select_by_table.get(table) is not False:
            issues.append(f"Anon can read private table: {table}.")
        if snapshot.authenticated_select_by_table.get(table) is not False:
            issues.append(f"Authenticated client can read private table directly: {table}.")
    return issues


def load_snapshot(connection) -> PreflightSnapshot:
    revision = connection.execute(text(
        "SELECT version_num FROM public.alembic_version LIMIT 1"
    )).scalar_one_or_none()
    tables = frozenset(connection.execute(text(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema='public' AND table_type='BASE TABLE'"
    )).scalars().all())
    journals = connection.execute(text(
        "SELECT COUNT(*) FROM public.journal_entries"
    )).scalar_one()
    auth_users_table = connection.execute(text(
        "SELECT to_regclass('auth.users') IS NOT NULL"
    )).scalar_one()
    auth_users = connection.execute(text(
        "SELECT COUNT(*) FROM auth.users"
    )).scalar_one() if auth_users_table else 0
    seq = connection.execute(text(
        "SELECT to_regclass('public.journal_entries_id_seq') IS NOT NULL"
    )).scalar_one()

    rows = connection.execute(text("""
        SELECT c.relname AS name, c.relrowsecurity AS rls,
               has_table_privilege('anon', c.oid, 'SELECT') AS anon_can_select,
               has_table_privilege('authenticated', c.oid, 'SELECT') AS auth_can_select
        FROM pg_class c
        JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='public' AND c.relkind='r'
    """)).mappings().all()
    return PreflightSnapshot(
        revision=revision,
        tables=tables,
        journals=journals,
        auth_users=auth_users,
        has_auth_users_table=bool(auth_users_table),
        has_id_sequence=bool(seq),
        rls_by_table={v["name"]: v["rls"] for v in rows},
        anon_select_by_table={v["name"]: v["anon_can_select"] for v in rows},
        authenticated_select_by_table={v["name"]: v["auth_can_select"] for v in rows},
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Read-only schema and migration preflight. Never applies DDL."
    )
    parser.add_argument("--project-ref", required=True,
                        help="Supabase project reference, not a credential.")
    args = parser.parse_args(argv)
    settings = get_settings()
    url = make_url(settings.migration_database_url or settings.database_url)
    identity = f"{url.username or ''}@{url.host or ''}"
    if url.get_backend_name() != "postgresql" or args.project_ref not in identity:
        print("BLOCKED: PostgreSQL target does not match the expected Supabase project.")
        return 2

    engine = create_engine(
        url, pool_pre_ping=True, connect_args={"connect_timeout": 10}
    )
    try:
        with engine.connect() as connection, connection.begin():
            # This is the first statement in the transaction. PostgreSQL
            # guarantees subsequent statements are read-only even if edited.
            connection.execute(text("SET TRANSACTION READ ONLY"))
            snapshot = load_snapshot(connection)
    except Exception as error:
        print(f"BLOCKED: unable to inspect database ({type(error).__name__}).")
        return 2
    finally:
        engine.dispose()

    print(f"Expected migration: {EXPECTED_FROM} -> {EXPECTED_TO}")
    print(f"Current migration: {snapshot.revision}")
    print(f"Public tables: {', '.join(sorted(snapshot.tables))}")
    print(f"Journal row count: {snapshot.journals}")
    print(f"Auth user count (no identities exported): {snapshot.auth_users}")
    issues = blocking_findings(snapshot)
    if issues:
        for issue in issues:
            print(f"BLOCKED: {issue}")
        return 1

    print("PREFLIGHT PASS: schema matched reviewed baseline.")
    print("NO MIGRATIONS APPLIED. Backup/recovery and release approval remain separate.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
