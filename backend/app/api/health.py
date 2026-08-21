from __future__ import annotations

from typing import Any

from fastapi import APIRouter
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.core.deps import DbSession

router = APIRouter(tags=["santé"])


@router.get("/health", summary="État du service et de la base")
def health(db: DbSession) -> Any:
    """Vérifie réellement PostgreSQL par un `SELECT 1`."""
    try:
        db.execute(text("SELECT 1"))
        database = "ok"
    except Exception:  # noqa: BLE001 - toute panne DB doit ressortir ici
        database = "error"

    payload = {"status": "ok" if database == "ok" else "degraded", "database": database}
    if database != "ok":
        return JSONResponse(status_code=503, content=payload)
    return payload
