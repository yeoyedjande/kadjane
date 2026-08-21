"""Isolation multi-association.

Règle non négociable : un utilisateur de l'organisation A ne doit jamais
accéder aux données de l'organisation B, même en envoyant lui-même son
identifiant. Ces tests verrouillent ce comportement.
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from tests.conftest import auth_headers, create_organization, register


@pytest.fixture
def two_organizations(client: TestClient) -> dict:
    alice = register(client, "+225 07 44 44 44 01", firstName="Alice")
    bob = register(client, "+225 07 44 44 44 02", firstName="Bob")
    alice_headers = auth_headers(alice)
    bob_headers = auth_headers(bob)

    organization_a = create_organization(client, alice_headers, "Organisation A")
    organization_b = create_organization(client, bob_headers, "Organisation B")

    member_b = client.post(
        f"/api/v1/organizations/{organization_b['id']}/members",
        json={
            "firstName": "Membre",
            "lastName": "DeB",
            "phone": "+225 07 44 44 44 03",
        },
        headers=bob_headers,
    ).json()["data"]

    return {
        "alice": alice_headers,
        "bob": bob_headers,
        "a": organization_a,
        "b": organization_b,
        "member_b": member_b,
    }


def test_alice_cannot_list_members_of_b(
    client: TestClient, two_organizations: dict
) -> None:
    response = client.get(
        f"/api/v1/organizations/{two_organizations['b']['id']}/members",
        headers=two_organizations["alice"],
    )
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "organization_not_found"


def test_alice_cannot_read_organization_b(
    client: TestClient, two_organizations: dict
) -> None:
    response = client.get(
        f"/api/v1/organizations/{two_organizations['b']['id']}",
        headers=two_organizations["alice"],
    )
    assert response.status_code == 404


def test_alice_cannot_read_the_dashboard_of_b(
    client: TestClient, two_organizations: dict
) -> None:
    response = client.get(
        f"/api/v1/organizations/{two_organizations['b']['id']}/dashboard",
        headers=two_organizations["alice"],
    )
    assert response.status_code == 404


def test_alice_cannot_add_a_member_to_b(
    client: TestClient, two_organizations: dict
) -> None:
    response = client.post(
        f"/api/v1/organizations/{two_organizations['b']['id']}/members",
        json={"firstName": "Intrus", "lastName": "X", "phone": "+225 07 44 44 44 09"},
        headers=two_organizations["alice"],
    )
    assert response.status_code == 404


def test_alice_cannot_read_a_member_of_b_by_short_route(
    client: TestClient, two_organizations: dict
) -> None:
    """`/members/{id}` déduit l'organisation du membre, puis vérifie l'accès."""
    member_id = two_organizations["member_b"]["id"]
    response = client.get(f"/api/v1/members/{member_id}", headers=two_organizations["alice"])
    assert response.status_code == 404

    stats = client.get(
        f"/api/v1/members/{member_id}/stats", headers=two_organizations["alice"]
    )
    assert stats.status_code == 404


def test_alice_cannot_update_a_member_of_b(
    client: TestClient, two_organizations: dict
) -> None:
    member_id = two_organizations["member_b"]["id"]
    response = client.put(
        f"/api/v1/members/{member_id}",
        json={"role": "admin"},
        headers=two_organizations["alice"],
    )
    assert response.status_code == 404


def test_a_member_id_from_b_is_rejected_under_organization_a(
    client: TestClient, two_organizations: dict
) -> None:
    """Identifiant croisé : membre de B demandé via l'URL de A."""
    response = client.get(
        f"/api/v1/organizations/{two_organizations['a']['id']}/members/"
        f"{two_organizations['member_b']['id']}",
        headers=two_organizations["alice"],
    )
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "member_not_found"


def test_bob_still_reaches_his_own_data(
    client: TestClient, two_organizations: dict
) -> None:
    """Le verrou ne doit pas bloquer l'accès légitime."""
    response = client.get(
        f"/api/v1/organizations/{two_organizations['b']['id']}/members",
        headers=two_organizations["bob"],
    )
    assert response.status_code == 200
    assert response.json()["data"]["total"] == 2


def test_no_token_no_access(client: TestClient, two_organizations: dict) -> None:
    response = client.get(
        f"/api/v1/organizations/{two_organizations['b']['id']}/members"
    )
    assert response.status_code == 401
