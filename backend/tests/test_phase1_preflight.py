"""Unit tests for Phase 1 gate: safe, offline, no database credentials."""

from dataclasses import replace

from scripts.phase1_preflight import PreflightSnapshot, blocking_findings


def baseline():
    return PreflightSnapshot(
        revision="20261011_01",
        tables=frozenset({"alembic_version", "journal_entries"}),
        journals=0,
        auth_users=0,
        has_auth_users_table=True,
        has_id_sequence=True,
        rls_by_table={"alembic_version": True, "journal_entries": True},
        anon_select_by_table={"alembic_version": False, "journal_entries": False},
        authenticated_select_by_table={
            "alembic_version": False, "journal_entries": False,
        },
        anon_write_by_table={"alembic_version": False, "journal_entries": False},
        authenticated_write_by_table={
            "alembic_version": False, "journal_entries": False,
        },
    )


def test_current_expected_supabase_baseline_passes():
    assert blocking_findings(baseline()) == []


def test_abort_if_unowned_diary_rows_exist():
    findings = blocking_findings(replace(baseline(), journals=1))
    assert any("Legacy journals" in msg for msg in findings)


def test_abort_if_database_revision_or_public_tables_drift():
    assert blocking_findings(replace(baseline(), revision="20261018_02"))
    assert blocking_findings(replace(
        baseline(), tables=frozenset({"alembic_version", "journal_entries", "unexpected"})
    ))


def test_abort_if_anon_or_authenticated_can_read():
    wrong = replace(baseline(), anon_select_by_table={
        "alembic_version": False, "journal_entries": True,
    })
    assert any("Anon can read" in x for x in blocking_findings(wrong))
    wrong = replace(baseline(), authenticated_select_by_table={
        "alembic_version": False, "journal_entries": True,
    })
    assert any("Authenticated client" in x for x in blocking_findings(wrong))


def test_abort_if_any_client_can_mutate_private_tables():
    bad_anon = replace(baseline(), anon_write_by_table={
        "alembic_version": False, "journal_entries": True,
    })
    assert any("Anon can write" in s for s in blocking_findings(bad_anon))
    bad_auth = replace(baseline(), authenticated_write_by_table={
        "alembic_version": False, "journal_entries": True,
    })
    assert any("Authenticated client can write" in s for s in blocking_findings(bad_auth))


def test_abort_if_rls_missing_or_auth_table_and_sequence_drift():
    wrong = replace(baseline(), rls_by_table={
        "alembic_version": True, "journal_entries": False,
    })
    assert any("RLS is not enabled" in x for x in blocking_findings(wrong))
    assert blocking_findings(replace(baseline(), has_id_sequence=False))
    assert blocking_findings(replace(baseline(), has_auth_users_table=False))


def test_existing_auth_users_alone_do_not_block_schema_upgrade():
    # New signups may happen between preflight and migration; the migration
    # is only unsafe when *unowned journal rows* exist.
    assert blocking_findings(replace(baseline(), auth_users=2)) == []
