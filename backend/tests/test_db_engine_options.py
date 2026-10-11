from app.core.database import make_engine_options


def test_sqlite_uses_test_friendly_settings():
    opts = make_engine_options("sqlite:///./demo_test.db")
    assert opts["pool_pre_ping"] is True
    assert opts["connect_args"] == {"check_same_thread": False}


def test_postgresql_uses_small_pool_and_connect_timeout_without_connecting():
    opts = make_engine_options(
        "postgresql+psycopg://postgres.project:pass@pooler.example.com:5432/postgres?sslmode=require"
    )
    assert opts["pool_size"] == 3
    assert opts["max_overflow"] == 2
    assert opts["connect_args"]["connect_timeout"] == 10
