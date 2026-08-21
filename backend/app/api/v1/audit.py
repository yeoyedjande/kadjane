from __future__ import annotations

import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Query

from app.core.deps import DbSession, OrgContext
from app.core.responses import success
from app.schemas import serializers as out
from app.services import permission_service
from app.services.audit_service import AuditService

router = APIRouter(tags=["audit"])


@router.get(
    "/organizations/{organization_id}/audit-logs", summary="Journal des opérations"
)
def list_audit_logs(
    db: DbSession,
    context: OrgContext,
    tontine_id: Annotated[uuid.UUID | None, Query(alias="tontineId")] = None,
    actions: Annotated[str | None, Query(description="Codes séparés par des virgules")] = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
) -> dict[str, Any]:
    permission_service.require(context.membership.role_enum, "audit.view")
    codes = [code.strip() for code in actions.split(",")] if actions else None
    entries = AuditService(db).history(
        context.organization_id, tontine_id=tontine_id, actions=codes, limit=limit
    )
    return success([out.audit_log(entry) for entry in entries])
