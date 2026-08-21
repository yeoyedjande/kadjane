from __future__ import annotations

import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Body, status

from app.core.deps import CurrentUser, DbSession
from app.core.errors import AuthenticationError
from app.core.security import hash_password, verify_password
from app.core.responses import success
from app.schemas.auth import (
    LoginRequest,
    OtpRequest,
    OtpVerifyRequest,
    PasswordChangeRequest,
    PasswordResetRequest,
    RefreshRequest,
    RegisterRequest,
)
from app.repositories.refresh_token_repository import RefreshTokenRepository
from app.repositories.user_repository import UserRepository
from app.schemas.base import dump
from app.schemas.user import UserRead
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", status_code=status.HTTP_201_CREATED, summary="Créer un compte")
def register(db: DbSession, payload: RegisterRequest) -> dict[str, Any]:
    return success(dump(AuthService(db).register(payload)))


@router.post("/login", summary="Se connecter (téléphone ou e-mail)")
def login(db: DbSession, payload: LoginRequest) -> dict[str, Any]:
    return success(dump(AuthService(db).login(payload.identifier, payload.password)))


@router.post("/refresh", summary="Renouveler la session")
def refresh(db: DbSession, payload: RefreshRequest) -> dict[str, Any]:
    return success(dump(AuthService(db).refresh(payload.refresh_token)))


@router.post("/logout", summary="Fermer la session")
def logout(
    db: DbSession,
    user: CurrentUser,
    payload: Annotated[RefreshRequest | None, Body()] = None,
) -> dict[str, Any]:
    AuthService(db).logout(
        user.id, payload.refresh_token if payload is not None else None
    )
    return success({"loggedOut": True})


@router.get("/me", summary="Utilisateur connecté")
def me(user: CurrentUser) -> dict[str, Any]:
    return success(dump(UserRead.model_validate(user)))


@router.post("/password/change", summary="Changer son mot de passe")
def change_password(
    db: DbSession, user: CurrentUser, payload: PasswordChangeRequest
) -> dict[str, Any]:
    """Le membre change lui-même son mot de passe, en connaissant l'ancien.

    C'est le pendant du mot de passe provisoire remis par l'administrateur à la
    création du compte : le membre s'en affranchit quand il le souhaite.
    """
    if not verify_password(payload.current_password, user.password_hash):
        raise AuthenticationError(
            "Mot de passe actuel incorrect.", code="invalid_current_password"
        )
    if payload.current_password == payload.new_password:
        raise AuthenticationError(
            "Le nouveau mot de passe doit être différent de l'ancien.",
            code="password_unchanged",
        )

    user.password_hash = hash_password(payload.new_password)
    # Les autres sessions tombent : un mot de passe changé doit déconnecter
    # partout ailleurs, sans quoi un accès déjà ouvert survivrait au changement.
    RefreshTokenRepository(db).revoke_all(user.id)
    db.commit()
    return success({"changed": True})


# --- Réinitialisation de mot de passe ---------------------------------------
# Le code OTP n'est pas encore envoyé par SMS : en développement, seul
# `_DEV_OTP` est accepté. La réinitialisation, elle, est bien réelle.
# TODO(auth): brancher un fournisseur SMS/e-mail et persister les codes OTP.

_DEV_OTP = "123456"


@router.post("/otp/request", summary="Demander un code OTP (dev)")
def request_otp(db: DbSession, payload: OtpRequest) -> dict[str, Any]:
    # Réponse identique que le compte existe ou non : pas d'énumération.
    UserRepository(db).by_identifier(payload.target)
    return success({"sent": True, "target": payload.target})


@router.post("/otp/verify", summary="Vérifier un code OTP (dev)")
def verify_otp(db: DbSession, payload: OtpVerifyRequest) -> dict[str, Any]:
    if payload.code.strip() != _DEV_OTP:
        raise AuthenticationError("Code invalide.", code="invalid_otp")
    user = UserRepository(db).by_identifier(payload.target)
    if user is None:
        raise AuthenticationError("Code invalide.", code="invalid_otp")
    return success({"resetToken": f"reset_{user.id}"})


@router.post("/password/reset", summary="Définir un nouveau mot de passe")
def reset_password(db: DbSession, payload: PasswordResetRequest) -> dict[str, Any]:
    prefix = "reset_"
    if not payload.reset_token.startswith(prefix):
        raise AuthenticationError("Jeton invalide.", code="invalid_reset_token")
    try:
        user_id = uuid.UUID(payload.reset_token[len(prefix) :])
    except ValueError as error:
        raise AuthenticationError(
            "Jeton invalide.", code="invalid_reset_token"
        ) from error

    user = UserRepository(db).by_id(user_id)
    if user is None:
        raise AuthenticationError("Jeton invalide.", code="invalid_reset_token")

    user.password_hash = hash_password(payload.new_password)
    # Toutes les sessions ouvertes tombent : un mot de passe changé invalide
    # les jetons de renouvellement existants.
    RefreshTokenRepository(db).revoke_all(user.id)
    db.commit()
    return success({"reset": True})
