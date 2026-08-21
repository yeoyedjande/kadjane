"""Suppression d'un membre depuis le back-office.

Le back-office administre l'application mobile : c'est lui qui crée les comptes
des membres, et donc lui qui les retire. La suppression est volontairement
étroite — l'historique financier prime sur le ménage dans la liste.
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import (
    auth_headers,
    build_organization,
    create_organization,
    create_tontine,
    register,
)


def _add_member(
    client: TestClient,
    headers: dict[str, str],
    organization_id: str,
    phone: str,
    role: str = "member",
) -> dict:
    response = client.post(
        f"/api/v1/organizations/{organization_id}/members",
        json={
            "firstName": "Membre",
            "lastName": "TEST",
            "phone": phone,
            "role": role,
        },
        headers=headers,
    )
    assert response.status_code == 201, response.text
    return response.json()["data"]


def test_un_membre_sans_tontine_est_supprime(client: TestClient) -> None:
    headers = auth_headers(register(client, "+225 07 44 00 00 01"))
    organization = create_organization(client, headers, "Association Suppression")
    member = _add_member(client, headers, organization["id"], "+225 07 44 00 00 02")

    response = client.delete(
        f"/api/v1/organizations/{organization['id']}/members/{member['id']}",
        headers=headers,
    )
    assert response.status_code == 200, response.text
    assert response.json()["data"] == {"deleted": True}

    listing = client.get(
        f"/api/v1/organizations/{organization['id']}/members", headers=headers
    )
    identifiers = [item["id"] for item in listing.json()["data"]["items"]]
    assert member["id"] not in identifiers


def test_un_membre_engage_dans_une_tontine_est_protege(client: TestClient) -> None:
    """Le refus protège les cotisations, effacées en cascade sinon."""
    context = build_organization(client, members=3, prefix="44")
    create_tontine(client, context)
    participant = context["members"][1]

    response = client.delete(
        f"/api/v1/organizations/{context['organization']['id']}"
        f"/members/{participant['id']}",
        headers=context["headers"],
    )

    assert response.status_code == 409, response.text
    assert response.json()["error"]["code"] == "member_has_history"


def test_on_ne_peut_pas_se_supprimer_soi_meme(client: TestClient) -> None:
    headers = auth_headers(register(client, "+225 07 44 11 00 01"))
    organization = create_organization(client, headers, "Association Solo")
    me = client.get(
        f"/api/v1/organizations/{organization['id']}/membership", headers=headers
    ).json()["data"]

    response = client.delete(
        f"/api/v1/organizations/{organization['id']}/members/{me['id']}",
        headers=headers,
    )

    assert response.status_code == 409, response.text
    assert response.json()["error"]["code"] == "member_self_delete"


def test_un_role_inferieur_ne_supprime_pas_un_role_superieur(
    client: TestClient,
) -> None:
    admin_headers = auth_headers(register(client, "+225 07 44 22 00 01"))
    organization = create_organization(client, admin_headers, "Association Rôles")
    admin = client.get(
        f"/api/v1/organizations/{organization['id']}/membership",
        headers=admin_headers,
    ).json()["data"]

    # Le trésorier s'inscrit lui-même : un membre créé par l'administrateur
    # reçoit un mot de passe aléatoire inutilisable, et ne pourrait pas se
    # connecter ici. `create` réutilise l'utilisateur existant via son numéro.
    treasurer_session = register(client, "+225 07 44 22 00 02")
    treasurer_headers = auth_headers(treasurer_session)
    _add_member(
        client, admin_headers, organization["id"], "+225 07 44 22 00 02", "treasurer"
    )

    response = client.delete(
        f"/api/v1/organizations/{organization['id']}/members/{admin['id']}",
        headers=treasurer_headers,
    )

    assert response.status_code in (401, 403), response.text


def test_un_membre_d_une_autre_organisation_est_introuvable(
    client: TestClient,
) -> None:
    """Isolation multi-association : l'identifiant étranger n'existe pas."""
    mine = auth_headers(register(client, "+225 07 44 33 00 01"))
    my_org = create_organization(client, mine, "Association A")

    theirs = auth_headers(register(client, "+225 07 44 33 00 09"))
    their_org = create_organization(client, theirs, "Association B")
    their_member = _add_member(
        client, theirs, their_org["id"], "+225 07 44 33 00 10"
    )

    response = client.delete(
        f"/api/v1/organizations/{my_org['id']}/members/{their_member['id']}",
        headers=mine,
    )

    assert response.status_code == 404, response.text
