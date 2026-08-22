"""Envoi des notifications push, via l'API HTTP v1 de Firebase Cloud Messaging.

Le service est **facultatif** : sans compte de service configuré, l'envoi est
simplement ignoré et l'application continue de fonctionner. Les notifications
restent alors visibles dans l'application, mais rien n'arrive sur l'écran
verrouillé du téléphone.

Configuration — une seule variable, contenant soit le chemin du fichier JSON de
compte de service, soit son contenu :

    FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account", ...}
    FIREBASE_SERVICE_ACCOUNT_JSON=/run/secrets/firebase.json

Le fichier se télécharge depuis la console Firebase :
*Paramètres du projet → Comptes de service → Générer une nouvelle clé privée*.
Il donne le droit d'envoyer à tous les appareils : à traiter comme un secret,
jamais dans le dépôt.
"""

from __future__ import annotations

import json
import logging
import uuid
from pathlib import Path
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.notification import DeviceToken

logger = logging.getLogger("kadjane.push")

FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
FCM_ENDPOINT = "https://fcm.googleapis.com/v1/projects/{project}/messages:send"

# Codes signalant un jeton devenu invalide : l'application a été désinstallée,
# ou Firebase l'a renouvelé. On les purge plutôt que de réessayer indéfiniment.
_DEAD_TOKEN_ERRORS = frozenset({"UNREGISTERED", "INVALID_ARGUMENT"})


class PushService:
    """Expédie les notifications aux appareils enregistrés."""

    def __init__(self, db: Session) -> None:
        self.db = db

    @property
    def is_configured(self) -> bool:
        return _credentials() is not None

    def send_to_users(
        self,
        user_ids: list[uuid.UUID],
        *,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> int:
        """Envoie à tous les appareils de ces utilisateurs.

        Retourne le nombre d'envois acceptés par Firebase. Un échec n'est
        jamais propagé : une relance doit rester enregistrée même si le push
        n'a pas pu partir.
        """
        if not user_ids:
            return 0

        credentials = _credentials()
        if credentials is None:
            logger.info("Push non configuré (FIREBASE_SERVICE_ACCOUNT_JSON absent) : envoi ignoré")
            return 0

        tokens = list(
            self.db.scalars(
                select(DeviceToken).where(DeviceToken.user_id.in_(user_ids))
            )
        )
        if not tokens:
            return 0

        try:
            access_token = _access_token(credentials)
        except Exception as error:  # noqa: BLE001 - jamais bloquant
            logger.warning("Jeton d'accès Firebase indisponible : %s", error)
            return 0

        project = credentials.get("project_id", "")
        sent = 0
        stale: list[DeviceToken] = []
        for device in tokens:
            outcome = _send_one(
                access_token,
                project,
                device.token,
                title=title,
                body=body,
                data=data or {},
            )
            if outcome is True:
                sent += 1
            elif outcome is None:
                stale.append(device)

        if stale:
            # Purge : un appareil désinstallé ne doit pas rester en base.
            for device in stale:
                self.db.delete(device)
            self.db.flush()
            logger.info("%d jeton(s) obsolète(s) supprimé(s)", len(stale))

        return sent


def _send_one(
    access_token: str,
    project: str,
    token: str,
    *,
    title: str,
    body: str,
    data: dict[str, str],
) -> bool | None:
    """Envoie à un appareil.

    `True` accepté, `False` échec transitoire, `None` jeton mort à purger.
    """
    import httpx

    payload: dict[str, Any] = {
        "message": {
            "token": token,
            "notification": {"title": title, "body": body},
            # Les valeurs doivent être des chaînes : Firebase refuse le reste.
            "data": {key: str(value) for key, value in data.items()},
            "android": {"priority": "high"},
        }
    }

    try:
        response = httpx.post(
            FCM_ENDPOINT.format(project=project),
            json=payload,
            headers={"Authorization": f"Bearer {access_token}"},
            timeout=10,
        )
    except Exception as error:  # noqa: BLE001
        logger.warning("Envoi push impossible : %s", error)
        return False

    if response.status_code == 200:
        return True

    detail = _error_status(response)
    if detail in _DEAD_TOKEN_ERRORS or response.status_code == 404:
        return None
    logger.warning("Push refusé (%s) : %s", response.status_code, detail)
    return False


def _error_status(response: Any) -> str:
    try:
        return response.json().get("error", {}).get("status", "")
    except Exception:  # noqa: BLE001
        return ""


def _credentials() -> dict[str, Any] | None:
    """Compte de service, lu depuis un chemin ou directement du JSON."""
    raw = settings.firebase_service_account_json.strip()
    if not raw:
        return None

    try:
        if raw.startswith("{"):
            return json.loads(raw)
        path = Path(raw)
        if not path.is_file():
            logger.warning("FIREBASE_SERVICE_ACCOUNT_JSON pointe vers un fichier absent : %s", raw)
            return None
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as error:  # noqa: BLE001
        logger.warning("FIREBASE_SERVICE_ACCOUNT_JSON illisible : %s", error)
        return None


def _access_token(credentials: dict[str, Any]) -> str:
    """Échange la clé de service contre un jeton d'accès OAuth2."""
    from google.oauth2 import service_account  # type: ignore[import-not-found]
    from google.auth.transport.requests import Request  # type: ignore[import-not-found]

    account = service_account.Credentials.from_service_account_info(
        credentials, scopes=[FCM_SCOPE]
    )
    account.refresh(Request())
    return account.token
