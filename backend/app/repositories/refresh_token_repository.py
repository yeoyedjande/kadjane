from __future__ import annotations

import hashlib
import uuid
from datetime import datetime, timezone

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.models.refresh_token import RefreshToken


def fingerprint(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


class RefreshTokenRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def store(
        self, user_id: uuid.UUID, token: str, expires_at: datetime
    ) -> RefreshToken:
        record = RefreshToken(
            user_id=user_id,
            token_hash=fingerprint(token),
            expires_at=expires_at,
        )
        self.db.add(record)
        self.db.flush()
        return record

    def active(self, token: str) -> RefreshToken | None:
        record = self.db.scalars(
            select(RefreshToken).where(RefreshToken.token_hash == fingerprint(token))
        ).first()
        if record is None or record.revoked_at is not None:
            return None
        expires_at = record.expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at <= datetime.now(timezone.utc):
            return None
        return record

    def revoke(self, token: str) -> None:
        self.db.execute(
            update(RefreshToken)
            .where(
                RefreshToken.token_hash == fingerprint(token),
                RefreshToken.revoked_at.is_(None),
            )
            .values(revoked_at=datetime.now(timezone.utc))
        )

    def revoke_all(self, user_id: uuid.UUID) -> None:
        self.db.execute(
            update(RefreshToken)
            .where(
                RefreshToken.user_id == user_id,
                RefreshToken.revoked_at.is_(None),
            )
            .values(revoked_at=datetime.now(timezone.utc))
        )
