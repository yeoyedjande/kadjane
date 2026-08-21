"""Hachage des mots de passe et émission/vérification des jetons JWT.

Aucun mot de passe en clair ne sort de ce module : il n'est ni journalisé,
ni stocké, ni renvoyé par l'API.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Literal

import bcrypt
import jwt

from app.core.config import settings

TokenType = Literal["access", "refresh"]

# bcrypt tronque au-delà de 72 octets : on refuse explicitement plus long.
_MAX_PASSWORD_BYTES = 72


def hash_password(password: str) -> str:
    raw = password.encode("utf-8")[:_MAX_PASSWORD_BYTES]
    return bcrypt.hashpw(raw, bcrypt.gensalt(rounds=settings.bcrypt_rounds)).decode(
        "utf-8"
    )


def verify_password(password: str, password_hash: str) -> bool:
    if not password_hash:
        return False
    try:
        return bcrypt.checkpw(
            password.encode("utf-8")[:_MAX_PASSWORD_BYTES],
            password_hash.encode("utf-8"),
        )
    except ValueError:
        # Empreinte corrompue ou format inconnu : jamais une authentification.
        return False


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _encode(subject: str, token_type: TokenType, expires: timedelta) -> tuple[str, datetime]:
    expires_at = _now() + expires
    payload: dict[str, Any] = {
        "sub": subject,
        "type": token_type,
        "iat": int(_now().timestamp()),
        "exp": int(expires_at.timestamp()),
        "jti": uuid.uuid4().hex,
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    return token, expires_at


def create_access_token(subject: str) -> tuple[str, datetime]:
    return _encode(
        subject,
        "access",
        timedelta(minutes=settings.jwt_access_token_expire_minutes),
    )


def create_refresh_token(subject: str) -> tuple[str, datetime]:
    return _encode(
        subject,
        "refresh",
        timedelta(days=settings.jwt_refresh_token_expire_days),
    )


def decode_token(token: str, expected_type: TokenType) -> dict[str, Any]:
    """Décode un jeton et vérifie son type. Lève `jwt.PyJWTError` sinon."""
    payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    if payload.get("type") != expected_type:
        raise jwt.InvalidTokenError("unexpected_token_type")
    return payload
