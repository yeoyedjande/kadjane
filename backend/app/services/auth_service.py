from __future__ import annotations

import uuid
from datetime import datetime, timezone

import jwt
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.errors import AuthenticationError, ConflictError, SessionExpiredError
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.models.user import User
from app.repositories.refresh_token_repository import RefreshTokenRepository
from app.repositories.user_repository import UserRepository
from app.schemas.auth import AuthSessionRead, RegisterRequest, TokenPair
from app.schemas.user import UserRead


class AuthService:
    """Inscription, connexion, renouvellement et fermeture de session."""

    def __init__(self, db: Session) -> None:
        self.db = db
        self.users = UserRepository(db)
        self.tokens = RefreshTokenRepository(db)

    # --- Cas d'usage ---------------------------------------------------------

    def register(self, payload: RegisterRequest) -> AuthSessionRead:
        if self.users.by_phone(payload.phone) is not None:
            raise ConflictError(
                "Ce numéro de téléphone est déjà utilisé.",
                code="phone_already_used",
            )
        if payload.email and self.users.by_email(payload.email) is not None:
            raise ConflictError(
                "Cette adresse e-mail est déjà utilisée.", code="email_already_used"
            )

        user = User(
            first_name=payload.first_name.strip(),
            last_name=payload.last_name.strip(),
            phone=payload.phone.strip(),
            email=payload.email,
            gender=payload.gender.value,
            password_hash=hash_password(payload.password),
            is_active=True,
        )
        try:
            self.users.add(user)
            session = self._open_session(user)
            self.db.commit()
        except IntegrityError as error:
            self.db.rollback()
            raise ConflictError(
                "Ce compte existe déjà.", code="user_already_exists"
            ) from error
        return session

    def login(self, identifier: str, password: str) -> AuthSessionRead:
        user = self.users.by_identifier(identifier)
        # Message volontairement identique dans les deux cas : ne pas révéler
        # l'existence d'un compte.
        if user is None or not verify_password(password, user.password_hash):
            raise AuthenticationError("Identifiants invalides.")
        if not user.is_active:
            raise AuthenticationError(
                "Ce compte est désactivé.", code="account_disabled"
            )

        user.last_login_at = datetime.now(timezone.utc)
        session = self._open_session(user)
        self.db.commit()
        return session

    def refresh(self, refresh_token: str) -> AuthSessionRead:
        try:
            claims = decode_token(refresh_token, "refresh")
        except jwt.PyJWTError as error:
            raise SessionExpiredError("Session expirée.") from error

        record = self.tokens.active(refresh_token)
        if record is None:
            raise SessionExpiredError("Session expirée.")

        user = self.users.by_id(uuid.UUID(claims["sub"]))
        if user is None or not user.is_active:
            raise SessionExpiredError("Session expirée.")

        # Rotation : l'ancien jeton n'est plus rejouable.
        self.tokens.revoke(refresh_token)
        session = self._open_session(user)
        self.db.commit()
        return session

    def logout(self, user_id: uuid.UUID, refresh_token: str | None = None) -> None:
        if refresh_token:
            self.tokens.revoke(refresh_token)
        else:
            self.tokens.revoke_all(user_id)
        self.db.commit()

    # --- Interne -------------------------------------------------------------

    def _open_session(self, user: User) -> AuthSessionRead:
        access_token, expires_at = create_access_token(str(user.id))
        refresh_token, refresh_expires = create_refresh_token(str(user.id))
        self.tokens.store(user.id, refresh_token, refresh_expires)
        return AuthSessionRead(
            user=UserRead.model_validate(user),
            tokens=TokenPair(
                access_token=access_token,
                refresh_token=refresh_token,
                expires_at=expires_at,
            ),
        )
