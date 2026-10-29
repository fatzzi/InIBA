from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "sqlite:///./iniba_dev.db"
    jwt_secret: str = "change-me"
    jwt_expire_hours: int = 24
    allowed_email_domain: str = "khi.iba.edu.pk"
    otp_expire_minutes: int = 10
    otp_max_attempts: int = 5


@lru_cache
def get_settings() -> Settings:
    return Settings()
