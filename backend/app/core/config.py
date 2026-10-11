from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_env: str = "development"
    # Configure this in backend/.env. Never commit actual Supabase credentials.
    database_url: str = Field(min_length=1)
    # Optional separate direct connection for migrations when IPv6 is available.
    migration_database_url: str | None = None
    ai_provider: str = "mock"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
