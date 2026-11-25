from datetime import time
from functools import lru_cache

from pydantic import model_validator
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
    # SCRUM-42: the daily IBA Moment opens at a random time between these campus-time (Karachi) hours
    moment_earliest: time = time(9, 0)
    moment_latest: time = time(21, 0)
    moment_duration_seconds: int = 120

    @model_validator(mode="after")
    def _moment_hours_fit(self) -> "Settings":
        def seconds(t: time) -> int:
            return t.hour * 3600 + t.minute * 60 + t.second

        room = seconds(self.moment_latest) - seconds(self.moment_earliest)
        if self.moment_duration_seconds <= 0 or room < self.moment_duration_seconds:
            raise ValueError("MOMENT_EARLIEST to MOMENT_LATEST must fit MOMENT_DURATION_SECONDS")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
