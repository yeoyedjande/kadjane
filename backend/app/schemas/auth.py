from __future__ import annotations

from datetime import datetime

from pydantic import EmailStr, Field, computed_field

from app.models.enums import Gender
from app.schemas.base import CamelModel
from app.schemas.user import UserRead


class LoginRequest(CamelModel):
    """`identifier` = téléphone **ou** e-mail."""

    identifier: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=1, max_length=128)


class RegisterRequest(CamelModel):
    first_name: str = Field(min_length=1, max_length=120)
    last_name: str = Field(min_length=1, max_length=120)
    phone: str = Field(min_length=4, max_length=32)
    password: str = Field(min_length=8, max_length=128)
    email: EmailStr | None = None
    gender: Gender = Gender.UNSPECIFIED


class RefreshRequest(CamelModel):
    refresh_token: str = Field(min_length=10)


class TokenPair(CamelModel):
    access_token: str
    refresh_token: str
    expires_at: datetime

    @computed_field(alias="tokenType")
    @property
    def token_type(self) -> str:
        return "bearer"


class AuthSessionRead(CamelModel):
    """Réponse de `/auth/login`, `/auth/register` et `/auth/refresh`.

    Elle expose les jetons sous deux formes volontairement redondantes :
    `tokens` (contrat Flutter) et `access_token`/`refresh_token` (convention
    OAuth attendue par les futurs clients Angular et web).
    """

    user: UserRead
    tokens: TokenPair

    @computed_field(alias="access_token")
    @property
    def access_token_alias(self) -> str:
        return self.tokens.access_token

    @computed_field(alias="refresh_token")
    @property
    def refresh_token_alias(self) -> str:
        return self.tokens.refresh_token

    @computed_field(alias="token_type")
    @property
    def token_type_alias(self) -> str:
        return "bearer"


class OtpRequest(CamelModel):
    target: str = Field(min_length=3, max_length=255)


class OtpVerifyRequest(CamelModel):
    target: str = Field(min_length=3, max_length=255)
    code: str = Field(min_length=4, max_length=8)


class PasswordResetRequest(CamelModel):
    reset_token: str = Field(min_length=10)
    new_password: str = Field(min_length=8, max_length=128)
