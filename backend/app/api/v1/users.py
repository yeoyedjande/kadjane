from __future__ import annotations

from typing import Any

from fastapi import APIRouter

from app.core.deps import CurrentUser, DbSession
from app.core.errors import ConflictError
from app.core.responses import success
from app.repositories.user_repository import UserRepository
from app.schemas.base import dump
from app.schemas.user import UserRead, UserUpdate

router = APIRouter(tags=["profil"])


@router.get("/me", summary="Profil de l'utilisateur connecté")
def read_me(user: CurrentUser) -> dict[str, Any]:
    return success(dump(UserRead.model_validate(user)))


@router.put("/me", summary="Mettre à jour son profil")
def update_me(db: DbSession, user: CurrentUser, payload: UserUpdate) -> dict[str, Any]:
    data = payload.model_dump(exclude_unset=True)
    users = UserRepository(db)

    phone = data.get("phone")
    if phone and phone != user.phone and users.by_phone(phone) is not None:
        raise ConflictError(
            "Ce numéro de téléphone est déjà utilisé.", code="phone_already_used"
        )
    email = data.get("email")
    if email and email != user.email and users.by_email(email) is not None:
        raise ConflictError(
            "Cette adresse e-mail est déjà utilisée.", code="email_already_used"
        )

    for field, value in data.items():
        setattr(user, field, getattr(value, "value", value))
    db.commit()
    db.refresh(user)
    return success(dump(UserRead.model_validate(user)))
