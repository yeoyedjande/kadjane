"""Exceptions métier et format d'erreur unique de l'API.

Toutes les erreurs sortent sous la forme :

    {"success": false, "error": {"code": ..., "message": ..., "details": ...}}

Le client Flutter lit `error.code` (409 → règle métier) et `error.details`
pour les erreurs de validation champ par champ.
"""

from __future__ import annotations

from typing import Any


class AppError(Exception):
    """Erreur métier convertie en réponse HTTP par le gestionnaire global."""

    status_code = 400
    code = "bad_request"

    def __init__(
        self,
        message: str,
        *,
        code: str | None = None,
        details: dict[str, Any] | None = None,
        status_code: int | None = None,
    ) -> None:
        super().__init__(message)
        self.message = message
        if code is not None:
            self.code = code
        if status_code is not None:
            self.status_code = status_code
        self.details = details


class ValidationError(AppError):
    status_code = 422
    code = "validation_error"


class AuthenticationError(AppError):
    status_code = 401
    code = "invalid_credentials"


class SessionExpiredError(AppError):
    status_code = 401
    code = "session_expired"


class PermissionDeniedError(AppError):
    status_code = 403
    code = "permission_denied"


class NotFoundError(AppError):
    status_code = 404
    code = "not_found"


class ConflictError(AppError):
    status_code = 409
    code = "conflict"
