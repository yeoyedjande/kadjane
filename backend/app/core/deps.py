"""Dépendances FastAPI : session, utilisateur courant, isolation multi-association."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from typing import Annotated, Any

import jwt
from fastapi import Depends, Path
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.errors import NotFoundError, SessionExpiredError
from app.core.security import decode_token
from app.db.session import get_db
from app.models.membership import OrganizationMember
from app.models.organization import Organization
from app.models.user import User
from app.repositories.member_repository import MemberRepository
from app.repositories.organization_repository import OrganizationRepository

bearer_scheme = HTTPBearer(auto_error=False, description="Jeton d'accès JWT")

DbSession = Annotated[Session, Depends(get_db)]


def get_current_user(
    db: DbSession,
    credentials: Annotated[
        HTTPAuthorizationCredentials | None, Depends(bearer_scheme)
    ] = None,
) -> User:
    if credentials is None or not credentials.credentials:
        raise SessionExpiredError("Authentification requise.", code="unauthenticated")
    try:
        claims = decode_token(credentials.credentials, "access")
        user_id = uuid.UUID(claims["sub"])
    except (jwt.PyJWTError, KeyError, ValueError) as error:
        raise SessionExpiredError("Session expirée.") from error

    user = db.get(User, user_id)
    if user is None or not user.is_active:
        raise SessionExpiredError("Session expirée.")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


@dataclass(slots=True)
class OrganizationContext:
    """Organisation demandée **et** appartenance de l'appelant.

    Obtenir ce contexte est la seule façon d'accéder aux données d'une
    organisation : un `organization_id` envoyé par le client ne donne jamais
    accès à quoi que ce soit sans ligne `organization_members` correspondante.
    """

    organization: Organization
    membership: OrganizationMember
    user: User

    @property
    def organization_id(self) -> uuid.UUID:
        return self.organization.id


def get_organization_context(
    db: DbSession,
    user: CurrentUser,
    organization_id: Annotated[uuid.UUID, Path(description="Identifiant d'organisation")],
) -> OrganizationContext:
    organization = OrganizationRepository(db).by_id(organization_id)
    membership = MemberRepository(db).membership(organization_id, user.id)
    if organization is None or membership is None:
        # Volontairement 404 et non 403 : ne pas révéler l'existence d'une
        # organisation à laquelle l'appelant n'appartient pas.
        raise NotFoundError("Organisation introuvable.", code="organization_not_found")
    return OrganizationContext(
        organization=organization, membership=membership, user=user
    )


OrgContext = Annotated[OrganizationContext, Depends(get_organization_context)]


@dataclass(slots=True)
class TontineContext:
    """Tontine demandée, avec l'appartenance de l'appelant à son organisation.

    Les routes `/tontines/{id}/…` ne portent pas l'organisation dans l'URL :
    elle est déduite de la tontine, puis l'accès est vérifié comme partout
    ailleurs. Un identifiant appartenant à une autre organisation est traité
    comme inexistant.
    """

    tontine: Any
    organization: Organization
    membership: OrganizationMember
    user: User

    @property
    def organization_id(self) -> uuid.UUID:
        return self.organization.id


def get_tontine_context(
    db: DbSession,
    user: CurrentUser,
    tontine_id: Annotated[uuid.UUID, Path(description="Identifiant de tontine")],
) -> TontineContext:
    from app.models.tontine import Tontine

    tontine = db.get(Tontine, tontine_id)
    if tontine is None:
        raise NotFoundError("Tontine introuvable.", code="tontine_not_found")
    context = get_organization_context(db, user, tontine.organization_id)
    return TontineContext(
        tontine=tontine,
        organization=context.organization,
        membership=context.membership,
        user=context.user,
    )


def get_cycle_context(
    db: DbSession,
    user: CurrentUser,
    cycle_id: Annotated[uuid.UUID, Path(description="Identifiant de cycle")],
) -> TontineContext:
    from app.models.tontine import TontineCycle

    cycle = db.get(TontineCycle, cycle_id)
    if cycle is None:
        raise NotFoundError("Cycle introuvable.", code="cycle_not_found")
    return get_tontine_context(db, user, cycle.tontine_id)


TontineCtx = Annotated[TontineContext, Depends(get_tontine_context)]
CycleCtx = Annotated[TontineContext, Depends(get_cycle_context)]


def get_cashbox_context(
    db: DbSession,
    user: CurrentUser,
    cashbox_id: Annotated[uuid.UUID, Path(description="Identifiant de caisse")],
) -> OrganizationContext:
    """Organisation d'une caisse, avec l'appartenance de l'appelant.

    Même principe que pour les tontines : l'organisation n'est pas dans l'URL,
    elle est déduite de la caisse. Une caisse d'une autre association est
    traitée comme inexistante.
    """
    from app.models.treasury import Cashbox

    cashbox = db.get(Cashbox, cashbox_id)
    if cashbox is None:
        raise NotFoundError("Caisse introuvable.", code="cashbox_not_found")
    return get_organization_context(db, user, cashbox.organization_id)


def get_campaign_context(
    db: DbSession,
    user: CurrentUser,
    campaign_id: Annotated[uuid.UUID, Path(description="Identifiant de cotisation")],
) -> OrganizationContext:
    from app.models.campaign import ContributionCampaign

    campaign = db.get(ContributionCampaign, campaign_id)
    if campaign is None:
        raise NotFoundError("Cotisation introuvable.", code="campaign_not_found")
    return get_organization_context(db, user, campaign.organization_id)


def get_entry_context(
    db: DbSession,
    user: CurrentUser,
    entry_id: Annotated[uuid.UUID, Path(description="Identifiant de ligne")],
) -> OrganizationContext:
    from app.models.campaign import CampaignEntry

    entry = db.get(CampaignEntry, entry_id)
    if entry is None:
        raise NotFoundError("Ligne de cotisation introuvable.", code="entry_not_found")
    return get_organization_context(db, user, entry.organization_id)


CashboxCtx = Annotated[OrganizationContext, Depends(get_cashbox_context)]
CampaignCtx = Annotated[OrganizationContext, Depends(get_campaign_context)]
EntryCtx = Annotated[OrganizationContext, Depends(get_entry_context)]
