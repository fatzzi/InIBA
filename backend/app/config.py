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
 # SCRUM-20: SMTP email sending + resend cooldown
    smtp_host: str = ""  # empty = dev mode: print the OTP instead of emailing it
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_from_email: str = "no-reply@iniba.local"
    smtp_use_tls: bool = True
    otp_resend_cooldown_seconds: int = 60


@lru_cache
def get_settings() -> Settings:
    return Settings()
