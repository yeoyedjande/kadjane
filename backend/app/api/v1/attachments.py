"""Justificatifs : upload et référencement.

Le fichier est stocké par `StorageService` (disque aujourd'hui, stockage objet
demain) et l'API renvoie une URL utilisable telle quelle dans `proofUrl` /
`attachmentId` des paiements, versements et mouvements de caisse.
"""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, File, UploadFile, status

from app.core.deps import CurrentUser
from app.core.errors import ValidationError
from app.core.responses import success
from app.services.storage_service import MAX_UPLOAD_BYTES, get_storage

router = APIRouter(tags=["justificatifs"])


@router.post(
    "/attachments",
    status_code=status.HTTP_201_CREATED,
    summary="Téléverser un justificatif (image ou PDF, 5 Mo max)",
)
def upload_attachment(
    user: CurrentUser, file: UploadFile = File(description="Image ou PDF")
) -> dict[str, Any]:
    if not file.filename:
        raise ValidationError("Aucun fichier reçu.", code="file_required")

    stored = get_storage().save(
        file.file,
        file_name=file.filename,
        content_type=file.content_type or "",
    )
    return success(
        {
            "id": stored.id,
            "url": stored.url,
            "fileName": stored.file_name,
            "mimeType": stored.content_type,
            "sizeBytes": stored.size_bytes,
            "maxSizeBytes": MAX_UPLOAD_BYTES,
            "uploadedAt": None,
        }
    )
