from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_env: str = "development"
    # Configure in backend/.env; never commit actual Supabase credentials.
    database_url: str = Field(min_length=1)
    migration_database_url: str | None = None
    ai_provider: str = "mock"
    # Public project URL, NOT a key. Required to verify Supabase Auth JWT.
    # Example: https://your-project-ref.supabase.co
    supabase_url: str | None = None
    # Server-side Geoapify key. Leave unset to disable external search.
    geoapify_api_key: str | None = None

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
