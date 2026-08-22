"""Schémas des campagnes de relance."""

from __future__ import annotations

import uuid

from pydantic import Field

from app.models.enums import ReminderChannel
from app.schemas.base import CamelModel


class ReminderCampaignCreate(CamelModel):
    """Envoi groupé de relances.

    L'organisation se déduit de `actorMemberId` : c'est l'adhésion au nom de
    laquelle la campagne part. Le serveur vérifie qu'elle appartient bien à
    l'utilisateur authentifié — sans quoi on pourrait relancer au nom d'autrui.

    `messages` associe l'identifiant de **membre** au texte déjà personnalisé :
    le client compose à partir du modèle correspondant au niveau d'escalade, le
    serveur transmet et trace.
    """

    actor_member_id: uuid.UUID
    messages: dict[str, str] = Field(min_length=1)
    channels: list[ReminderChannel] = Field(
        default_factory=lambda: [ReminderChannel.IN_APP]
    )
    tontine_id: uuid.UUID | None = None
    cycle_id: uuid.UUID | None = None
