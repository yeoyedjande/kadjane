from __future__ import annotations

from fastapi import APIRouter

from app.api.v1 import (
    attachments,
    audit,
    auth,
    contributions,
    draws,
    dues,
    members,
    notifications,
    organizations,
    payouts,
    reminders,
    tontines,
    treasury,
    users,
)

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(organizations.router)
api_router.include_router(members.router)
api_router.include_router(tontines.router)
api_router.include_router(contributions.router)
api_router.include_router(draws.router)
api_router.include_router(dues.router)
api_router.include_router(payouts.router)
api_router.include_router(treasury.router)
api_router.include_router(reminders.router)
api_router.include_router(notifications.router)
api_router.include_router(attachments.router)
api_router.include_router(audit.router)
