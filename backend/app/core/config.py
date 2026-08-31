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
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440


settings = Settings()
