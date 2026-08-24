"""Lecture de la clé de service et robustesse de l'envoi push.

Le push est un canal d'appoint : il ne doit jamais faire échouer une relance.
Une clé absente, illisible ou un réseau coupé se traduisent par « rien n'est
parti », pas par une exception.
"""

from __future__ import annotations

import json
import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.notification import DeviceToken
from app.services import push_service
from app.services.push_service import PushService
from tests.conftest import auth_headers, register

# Structure d'un compte de service, sans clé réelle : on vérifie la lecture,
# pas la cryptographie.
FAKE_ACCOUNT = {
    "type": "service_account",
    "project_id": "kadjane-test",
    "private_key_id": "0" * 40,
    "private_key": "-----BEGIN PRIVATE KEY-----\nZmFrZQ==\n-----END PRIVATE KEY-----\n",
    "client_email": "push@kadjane-test.iam.gserviceaccount.com",
    "token_uri": "https://oauth2.googleapis.com/token",
}


@pytest.fixture
def credentials(monkeypatch: pytest.MonkeyPatch):
    def use(value: str) -> None:
        monkeypatch.setattr(
            settings, "firebase_service_account_json", value, raising=False
        )

    return use


def test_sans_cle_le_service_n_est_pas_configure(credentials) -> None:
    credentials("")
    assert PushService.__init__ is not None  # le module reste importable
    assert push_service._credentials() is None


def test_la_cle_est_lue_depuis_le_json_brut(credentials) -> None:
    """Railway stocke le contenu du fichier dans la variable, pas un chemin."""
    credentials(json.dumps(FAKE_ACCOUNT))

    parsed = push_service._credentials()

    assert parsed is not None
    assert parsed["project_id"] == "kadjane-test"


def test_la_cle_est_lue_depuis_un_chemin(credentials, tmp_path) -> None:
    path = tmp_path / "firebase.json"
    path.write_text(json.dumps(FAKE_ACCOUNT), encoding="utf-8")
    credentials(str(path))

    parsed = push_service._credentials()

    assert parsed is not None
    assert parsed["client_email"].endswith("gserviceaccount.com")


def test_un_json_invalide_ne_leve_pas(credentials) -> None:
    credentials('{"type": "service_account"')  # accolade jamais fermée

    assert push_service._credentials() is None


def test_un_chemin_inexistant_ne_leve_pas(credentials) -> None:
    credentials("/introuvable/firebase.json")

    assert push_service._credentials() is None


def test_sans_configuration_l_envoi_est_ignore(
    db_session: Session, credentials
) -> None:
    credentials("")

    sent = PushService(db_session).send_to_users(
        [uuid.uuid4()], title="Kadjane", body="Cotisation à régler"
    )

    assert sent == 0


def test_sans_destinataire_rien_n_est_tente(
    db_session: Session, credentials
) -> None:
    credentials(json.dumps(FAKE_ACCOUNT))

    assert PushService(db_session).send_to_users([], title="x", body="y") == 0


def test_une_cle_invalide_ne_fait_pas_echouer_l_envoi(
    db_session: Session, credentials
) -> None:
    """Le jeton d'accès ne peut pas être obtenu : on renonce, sans lever."""
    user_id = uuid.uuid4()
    db_session.add(
        DeviceToken(user_id=user_id, token="jeton-de-test", platform="android")
    )
    db_session.flush()
    credentials(json.dumps(FAKE_ACCOUNT))

    sent = PushService(db_session).send_to_users(
        [user_id], title="Kadjane", body="Cotisation à régler"
    )

    assert sent == 0


def test_l_appareil_est_detache_a_la_deconnexion(client: TestClient) -> None:
    """Sinon le téléphone reçoit encore les relances du compte précédent."""
    headers = auth_headers(register(client, "+225 07 00 00 90 01"))

    registered = client.post(
        "/api/v1/notifications/devices",
        json={"token": "jeton-appareil-1", "platform": "android"},
        headers=headers,
    )
    assert registered.status_code == 200, registered.text

    removed = client.post(
        "/api/v1/notifications/devices/unregister",
        json={"token": "jeton-appareil-1"},
        headers=headers,
    )
    assert removed.status_code == 200, removed.text
    assert removed.json()["data"]["unregistered"] is True

    # Idempotent : la déconnexion ne doit pas échouer sur un jeton déjà retiré.
    again = client.post(
        "/api/v1/notifications/devices/unregister",
        json={"token": "jeton-appareil-1"},
        headers=headers,
    )
    assert again.json()["data"]["unregistered"] is False


def test_un_compte_ne_detache_pas_l_appareil_d_un_autre(client: TestClient) -> None:
    proprietaire = auth_headers(register(client, "+225 07 00 00 90 02"))
    tiers = auth_headers(register(client, "+225 07 00 00 90 03"))

    client.post(
        "/api/v1/notifications/devices",
        json={"token": "jeton-appareil-2", "platform": "android"},
        headers=proprietaire,
    )

    response = client.post(
        "/api/v1/notifications/devices/unregister",
        json={"token": "jeton-appareil-2"},
        headers=tiers,
    )

    assert response.json()["data"]["unregistered"] is False
