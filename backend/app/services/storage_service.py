"""Stockage des justificatifs.

Le contrat est volontairement minimal — `save()` et `url_for()` — pour qu'un
stockage objet (S3, MinIO) remplace le stockage disque sans toucher aux
appelants. Aujourd'hui les fichiers vivent dans un volume monté ; demain,
`S3Storage` implémentera la même interface avec des URL pré-signées.
"""

from __future__ import annotations

import mimetypes
import secrets
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO, Protocol

from app.core.config import settings
from app.core.errors import ValidationError

MAX_UPLOAD_BYTES = 5 * 1024 * 1024

ALLOWED_TYPES: dict[str, str] = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "application/pdf": ".pdf",
}


@dataclass(frozen=True, slots=True)
class StoredFile:
    id: str
    url: str
    file_name: str
    content_type: str
    size_bytes: int


class Storage(Protocol):
    def save(
        self, stream: BinaryIO, *, file_name: str, content_type: str
    ) -> StoredFile: ...

    def url_for(self, identifier: str) -> str: ...


class LocalStorage:
    """Stockage disque, servi en statique par l'API."""

    def __init__(self, root: Path | None = None, public_prefix: str = "/files") -> None:
        self.root = root or Path(settings.upload_dir)
        self.public_prefix = public_prefix
        self.root.mkdir(parents=True, exist_ok=True)

    def save(
        self, stream: BinaryIO, *, file_name: str, content_type: str
    ) -> StoredFile:
        extension = _validated_extension(file_name, content_type)
        identifier = f"{uuid.uuid4().hex}{secrets.token_hex(4)}{extension}"
        destination = self.root / identifier

        size = 0
        with destination.open("wb") as target:
            while chunk := stream.read(64 * 1024):
                size += len(chunk)
                if size > MAX_UPLOAD_BYTES:
                    target.close()
                    destination.unlink(missing_ok=True)
                    raise ValidationError(
                        "Le justificatif dépasse 5 Mo.", code="file_too_large"
                    )
                target.write(chunk)

        if size == 0:
            destination.unlink(missing_ok=True)
            raise ValidationError("Le fichier est vide.", code="empty_file")

        return StoredFile(
            id=identifier,
            url=self.url_for(identifier),
            file_name=file_name,
            content_type=content_type,
            size_bytes=size,
        )

    def url_for(self, identifier: str) -> str:
        return f"{self.public_prefix}/{identifier}"


def _validated_extension(file_name: str, content_type: str) -> str:
    """N'accepte que des images et des PDF, et jamais l'extension du client."""
    normalized = (content_type or "").split(";")[0].strip().lower()
    if normalized not in ALLOWED_TYPES:
        raise ValidationError(
            "Format non accepté : images (JPEG, PNG, WebP) ou PDF.",
            code="unsupported_file_type",
            details={"contentType": normalized or None},
        )
    guessed = mimetypes.guess_type(file_name)[0]
    if guessed is not None and guessed.lower() != normalized:
        raise ValidationError(
            "L'extension ne correspond pas au type du fichier.",
            code="file_type_mismatch",
        )
    return ALLOWED_TYPES[normalized]


def get_storage() -> Storage:
    """Point d'extension : renvoyer `S3Storage()` le jour venu."""
    return LocalStorage()
