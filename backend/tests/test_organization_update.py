"""Mise à jour des paramètres d'une organisation.

Régression : l'écran mobile envoyait `""` pour les champs facultatifs laissés
vides. `EmailStr` rejetait la requête et **tout** l'enregistrement échouait sur
« Impossible de charger les données », alors que l'intention était seulement de
vider un champ.
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import auth_headers, create_organization, register

PHONE = "+225 07 77 11 00 01"


def setup(client: TestClient) -> tuple[dict[str, str], str]:
    headers = auth_headers(register(client, PHONE))
    organization = create_organization(client, headers, "Association Réglages")
    client.put(
        f"/api/v1/organizations/{organization['id']}",
        json={
            "email": "contact@solidarite.ci",
            "phone": "+225 27 22 00 00 00",
            "address": "Cocody, Abidjan",
        },
        headers=headers,
    )
    return headers, organization["id"]


def test_les_champs_vides_ne_font_plus_echouer_l_enregistrement(
    client: TestClient,
) -> None:
    headers, org = setup(client)

    response = client.put(
        f"/api/v1/organizations/{org}",
        json={
            "name": "Association Réglages",
            "description": "",
            "phone": "",
            "email": "",
            "address": "",
            "rules": "",
        },
        headers=headers,
    )

    assert response.status_code == 200, response.text


def test_vider_un_champ_facultatif_l_efface_vraiment(client: TestClient) -> None:
    """Sans cela, un e-mail saisi une fois ne pouvait plus jamais être retiré."""
    headers, org = setup(client)

    client.put(
        f"/api/v1/organizations/{org}",
        json={"email": "", "address": ""},
        headers=headers,
    )

    body = client.get(f"/api/v1/organizations/{org}", headers=headers).json()["data"]
    assert body["email"] is None
    assert body["address"] is None
    # Le champ non transmis reste intact.
    assert body["phone"] == "+225 27 22 00 00 00"


def test_une_adresse_valide_est_conservee(client: TestClient) -> None:
    headers, org = setup(client)

    client.put(
        f"/api/v1/organizations/{org}",
        json={"email": "tresorier@kadjane.app"},
        headers=headers,
    )

    body = client.get(f"/api/v1/organizations/{org}", headers=headers).json()["data"]
    assert body["email"] == "tresorier@kadjane.app"


def test_une_adresse_invalide_reste_refusee(client: TestClient) -> None:
    """Tolérer le vide ne veut pas dire tolérer n'importe quoi."""
    headers, org = setup(client)

    response = client.put(
        f"/api/v1/organizations/{org}", json={"email": "pas-une-adresse"}, headers=headers
    )

    assert response.status_code == 422


def test_un_champ_obligatoire_ne_s_efface_pas(client: TestClient) -> None:
    """`null` sur une colonne non nulle vaut « ne pas toucher », pas « effacer »."""
    headers, org = setup(client)

    response = client.put(
        f"/api/v1/organizations/{org}",
        json={"name": None, "currency": None, "country": None},
        headers=headers,
    )

    assert response.status_code == 200, response.text
    body = response.json()["data"]
    assert body["name"] == "Association Réglages"
    assert body["currency"] == "XOF"
    assert body["country"] == "CI"


def test_les_reglages_metier_restent_modifiables(client: TestClient) -> None:
    headers, org = setup(client)

    client.put(
        f"/api/v1/organizations/{org}",
        json={
            "settings": {
                "requireFullPaymentBeforeDraw": False,
                "allowDrawOverride": False,
                "latePaymentGraceDays": 7,
                "notifyBeforeDueDays": 2,
            }
        },
        headers=headers,
    )

    body = client.get(f"/api/v1/organizations/{org}", headers=headers).json()["data"]
    assert body["settings"]["requireFullPaymentBeforeDraw"] is False
    assert body["settings"]["latePaymentGraceDays"] == 7
