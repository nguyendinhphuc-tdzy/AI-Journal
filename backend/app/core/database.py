from sqlalchemy import create_engine, event
from sqlalchemy.engine import make_url
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from .config import get_settings


def make_engine_options(database_url: str) -> dict:
    """Keep pool sizes modest for Supabase and test SQLite locally."""
    dialect = make_url(database_url).get_backend_name()
    options = {"pool_pre_ping": True}
    if dialect == "sqlite":
        options["connect_args"] = {"check_same_thread": False}
    elif dialect == "postgresql":
        options.update(
            pool_size=3,
            max_overflow=2,
            pool_timeout=10,
            pool_recycle=1800,
            connect_args={"connect_timeout": 10},
        )
    return options


settings = get_settings()
engine = create_engine(settings.database_url, **make_engine_options(settings.database_url))

# SQLite turns FK enforcement off by default; real PostgreSQL enforces FKs.
# B10 tests need matching same-owner composite-FK and cascade behavior.
if engine.dialect.name == "sqlite":
    @event.listens_for(engine, "connect")
    def _enable_sqlite_foreign_keys(dbapi_connection, connection_record):
        del connection_record
        cursor = dbapi_connection.cursor()
        try:
            cursor.execute("PRAGMA foreign_keys=ON")
        finally:
            cursor.close()
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
