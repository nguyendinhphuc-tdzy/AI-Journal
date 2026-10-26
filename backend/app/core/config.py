from functools import lru_cache
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_env: str = "development"
    # Configure in backend/.env; never commit actual Supabase credentials.
    database_url: str = Field(min_length=1)
    migration_database_url: str | None = None
    ai_provider: Literal["mock", "ollama"] = "mock"
    # Local by default: FastAPI should call Ollama on the same computer.
    ollama_base_url: str = "http://127.0.0.1:11434"
    ollama_model: str = "qwen3:4b"
    ollama_timeout_seconds: float = Field(default=60, ge=5, le=180)
    ollama_num_ctx: int = Field(default=4096, ge=1024, le=32768)
    ollama_num_predict: int = Field(default=350, ge=64, le=2048)
    # Public project URL, NOT a key. Required to verify Supabase Auth JWT.
    supabase_url: str | None = None
    # Server-side Geoapify key. Leave unset to disable external search.
    geoapify_api_key: str | None = None

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
