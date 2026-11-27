"""Request/response bodies for /auth (API doc section 2).

JSON uses camelCase, Python uses snake_case.
"""

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator
from pydantic.alias_generators import to_camel

from app.config import get_settings
from app.security import BCRYPT_MAX_BYTES


def _normalise_iba_email(value: str) -> str:
    email = value.strip().lower()
    domain = get_settings().allowed_email_domain.lower()
    if not email.endswith("@" + domain):
        raise ValueError(f"Only @{domain} email addresses can register")
    return email


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class RegisterRequest(CamelModel):
    email: EmailStr
    password: str = Field(min_length=8)
    confirm_password: str
    name: str = Field(min_length=1, max_length=120)

    @field_validator("email")
    @classmethod
    def iba_domain_only(cls, value: str) -> str:
        return _normalise_iba_email(value)

    @field_validator("name")
    @classmethod
    def name_not_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Name is required")
        return value.strip()

    @field_validator("password")
    @classmethod
    def password_fits_bcrypt(cls, value: str) -> str:
        if len(value.encode("utf-8")) > BCRYPT_MAX_BYTES:
            raise ValueError(f"Password must be at most {BCRYPT_MAX_BYTES} bytes")
        return value

    @model_validator(mode="after")
    def passwords_match(self) -> "RegisterRequest":
        if self.password != self.confirm_password:
            raise ValueError("Passwords do not match")
        return self


class RegisterResponse(CamelModel):
    message: str
    expires_in_minutes: int


class ResendOtpRequest(CamelModel):
    email: EmailStr

    @field_validator("email")
    @classmethod
    def iba_domain_only(cls, value: str) -> str:
        return _normalise_iba_email(value)


class ResendOtpResponse(CamelModel):
    message: str
    expires_in_minutes: int
class VerifyOtpRequest(CamelModel):
    email: EmailStr
    code: str = Field(min_length=6, max_length=6, pattern=r"^\d{6}$")

    @field_validator("email")
    @classmethod
    def iba_domain_only(cls, value: str) -> str:
        return _normalise_iba_email(value)


class StudentSummary(CamelModel):
    student_id: int
    name: str | None
    batch: str | None
    department: str | None
    profile_photo: str | None


class AuthResponse(CamelModel):
    token: str
    expires_in: int
    student: StudentSummary

class LogoutResponse(CamelModel):
    message: str
