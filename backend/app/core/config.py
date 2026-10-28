from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_env: str = "development"
    # Configure in backend/.env; never commit actual Supabase credentials.
    database_url: str = Field(min_length=1)
    migration_database_url: str | None = None
    ai_provider: str = "mock"
    community_feed_enabled: bool = False
    community_moderator_ids: str = ""
    ollama_base_url: str = "http://127.0.0.1:11434"
    ollama_model: str = "qwen3.5:4b"
    ollama_timeout_seconds: float = Field(default=90.0, ge=1, le=300)
    # Public project URL, NOT a key. Required to verify Supabase Auth JWT.
    # Example: https://your-project-ref.supabase.co
    supabase_url: str | None = None
    # Public API key only; bearer user token enforces storage RLS.
    supabase_publishable_key: str | None = None
    # Server-side Geoapify key. Leave unset to disable external search.
    geoapify_api_key: str | None = None

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
