"""Read-only schema/model checks before starting the local acceptance runtime."""
import sys

import httpx
from alembic.config import Config
from alembic.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine
from sqlalchemy.pool import NullPool

from app.core.config import get_settings
from app.modules.ai.service import OllamaAIProvider


def require_current_schema(source_heads, database_heads):
    if len(source_heads) != 1 or tuple(database_heads) != tuple(source_heads):
        raise RuntimeError(
            "Database revision does not match this checkout. "
            "Review the target database and migrations; no migration was run."
        )


def main():
    settings = get_settings()
    heads = ScriptDirectory.from_config(Config("alembic.ini")).get_heads()
    engine = create_engine(
        settings.migration_database_url or settings.database_url,
        poolclass=NullPool,
    )
    try:
        with engine.connect() as connection:
            current = MigrationContext.configure(connection).get_current_heads()
        require_current_schema(heads, current)
    finally:
        engine.dispose()
    print(f"Schema verified: {heads[0]} (read-only)")

    if settings.ai_provider != "ollama":
        raise RuntimeError("Acceptance runtime requires AI_PROVIDER=ollama.")
    provider = OllamaAIProvider(
        settings.ollama_base_url, settings.ollama_model,
        settings.ollama_timeout_seconds,
    )
    with httpx.Client(timeout=10, trust_env=False) as client:
        response = client.get(provider.base_url.rstrip("/") + "/api/tags")
        response.raise_for_status()
    models = response.json().get("models", [])
    if not any(
        item.get("name") == provider.model
        and not item.get("remote_host")
        and not item.get("remote_model")
        for item in models
    ):
        raise RuntimeError("Selected local Ollama model is not installed.")
    print(f"Local Ollama model available: {provider.model}")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Connection exceptions can include credentials or private hosts.
        print(
            "Runtime preflight failed. Check database revision, local Ollama "
            "and model configuration. No migration was run.",
            file=sys.stderr,
        )
        sys.exit(1)
