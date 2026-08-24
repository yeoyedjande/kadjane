from __future__ import annotations

from fastapi import APIRouter

from app.api.v1 import (
    attachments,
    audit,
    auth,
    campaigns,
    cashboxes,
    contributions,
    draws,
    dues,
    members,
    notifications,
    organizations,
    payouts,
    rbac,
    reminders,
    tontines,
    treasury,
    users,
)

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(users.router)
# Avant `organizations` : `/organizations/{id}/roles` y est servi, et le
# routeur des organisations ne doit pas capter le chemin en premier.
api_router.include_router(rbac.router)
api_router.include_router(organizations.router)
api_router.include_router(members.router)
api_router.include_router(tontines.router)
api_router.include_router(contributions.router)
api_router.include_router(draws.router)
api_router.include_router(dues.router)
api_router.include_router(payouts.router)
api_router.include_router(treasury.router)
api_router.include_router(cashboxes.router)
api_router.include_router(campaigns.router)
api_router.include_router(reminders.router)
api_router.include_router(notifications.router)
api_router.include_router(attachments.router)
api_router.include_router(audit.router)
