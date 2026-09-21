from typing import List, Union
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    APP_NAME: str = "Mentra"
    APP_ENV: str = "development"
    VERSION: str = "0.1.0"
    PORT: int = 8000
    HOST: str = "0.0.0.0"

    DATABASE_URL: str = "postgresql://mentra:mentra@localhost:5432/mentra"
    REDIS_URL: str = "redis://localhost:6379/0"

    JWT_SECRET: str = "default_secret_key_change_in_production"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440  # 24 hours

    CORS_ORIGINS: Union[List[str], str] = ["*"]

    # AI LLM Provider Configuration
    AI_PROVIDER: str = "auto"  # "auto", "openai", "gemini", or "heuristic"
    OPENAI_API_KEY: Union[str, None] = None
    OPENAI_MODEL: str = "gpt-4o-mini"
    GEMINI_API_KEY: Union[str, None] = None

    # Local on-device LLM runtime (Ollama)
    LOCAL_LLM_URL: str = "http://127.0.0.1:11434"
    LOCAL_LLM_MODEL: str = "qwen2.5:1.5b"
    # Keep the model resident in RAM between requests. Without this Ollama unloads
    # the model after idle time and the next request pays a multi-second cold
    # start, which used to look like "the AI coach randomly stopped working".
    LOCAL_LLM_KEEP_ALIVE: str = "30m"
    LOCAL_LLM_TIMEOUT_SECONDS: float = 120.0
    # Warm the model up in the background on backend startup.
    LOCAL_LLM_WARMUP_ON_STARTUP: bool = True

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> List[str]:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",") if i.strip()]
        return v


settings = Settings()
