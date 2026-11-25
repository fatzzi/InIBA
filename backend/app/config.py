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
    # SCRUM-76: one shared database + image bucket behind one public backend.
    # "development" (your laptop) or "production" (the hosted API everyone's app uses). Production refuses to
    # start with unsafe settings; see production_problems().
    environment: str = "development"
    # Extra browser origins allowed to call the API (comma-separated), e.g. a Flutter web build. Phones need none.
    cors_origins: str = ""
    # "local" keeps images in backend/media (that machine only); "supabase" uploads to a shared public bucket.
    image_store: str = "local"
    supabase_url: str = ""  # e.g. https://abcdxyz.supabase.co
    supabase_service_key: str = ""  # service_role key. Secret: .env only, never commit
    supabase_bucket: str = "media"  # must be a *public* bucket


    def production_problems(self) -> list[str]:
        """Settings that would break or endanger a public deployment. Empty means safe to start."""
        if self.environment != "production":
            return []
        problems = []
        if self.jwt_secret == "change-me" or len(self.jwt_secret) < 32:
            problems.append("JWT_SECRET must be a random value of 32+ characters")
        if self.database_url.startswith("sqlite"):
            problems.append("DATABASE_URL must point at the hosted Postgres, not SQLite")
        if self.image_store != "supabase" or not self.supabase_url or not self.supabase_service_key:
            problems.append("IMAGE_STORE=supabase with SUPABASE_URL and SUPABASE_SERVICE_KEY is required")
        if not self.smtp_host:
            problems.append("SMTP_HOST must be set so real users receive their OTP emails")
        return problems


@lru_cache
def get_settings() -> Settings:
    return Settings()
