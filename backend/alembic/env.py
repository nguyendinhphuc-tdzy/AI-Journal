"""Alembic migrations: optional direct URL, otherwise backend URL."""

from logging.config import fileConfig

from alembic import context
from sqlalchemy import create_engine, pool

from app.core.config import get_settings
from app.core.database import Base
from app.models.memory_share_recipient import MemoryShareRecipient  # noqa: F401
from app.models.message import Conversation, Message, ConversationRead  # noqa: F401
from app.models.journal_analysis import JournalAnalysis  # noqa: F401
from app.models.saved_quote import SavedQuote  # noqa: F401
from app.models.weekly_insight import WeeklyInsight  # noqa: F401
from app.models.community import CommunityPost, CommunityReport  # noqa: F401
from app.models.memory_share import MemoryShare  # noqa: F401
from app.models.user_block import UserBlock  # noqa: F401
from app.models.friendship import Friendship  # noqa: F401
from app.models import JournalEntry, UserProfile, JournalActionDay, SavedPlace, PlaceNote, JournalPlace, Album, AlbumMemory  # noqa: F401 - register metadata

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def migration_url() -> str:
    settings = get_settings()
    return settings.migration_database_url or settings.database_url


def _include_object(obj, name, type_, reflected, compare_to):
    # Supabase's auth.users belongs to Supabase, never to application Alembic.
    if type_ == "table" and getattr(obj, "info", {}).get("externally_managed"):
        return False
    # SQLite cannot enforce FKs to Supabase's separate 'auth' schema.
    if type_ == "foreign_key_constraint" and context.get_context().dialect.name == "sqlite":
        return False
    return True


def run_migrations_offline() -> None:
    context.configure(
        url=migration_url(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
        include_object=_include_object,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    engine = create_engine(migration_url(), poolclass=pool.NullPool)
    with engine.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
            include_object=_include_object,
        )
        with context.begin_transaction():
            context.run_migrations()
    engine.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
