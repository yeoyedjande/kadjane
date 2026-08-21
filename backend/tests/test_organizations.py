from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import auth_headers, create_organization, register


def test_create_organization_makes_the_creator_admin(client: TestClient) -> None:
    session = register(client, "+225 07 22 22 22 01")
    headers = auth_headers(session)

    organization = create_organization(client, headers, "Association Solidarité")
    assert organization["name"] == "Association Solidarité"
    assert organization["slug"] == "association-solidarite"
    assert organization["settings"]["requireFullPaymentBeforeDraw"] is True

    membership = client.get(
        f"/api/v1/organizations/{organization['id']}/membership", headers=headers
    )
    assert membership.status_code == 200
    assert membership.json()["data"]["role"] == "admin"
    assert membership.json()["data"]["memberNumber"] == "M-001"


def test_list_returns_only_my_organizations(client: TestClient) -> None:
    first = auth_headers(register(client, "+225 07 22 22 22 02"))
    second = auth_headers(register(client, "+225 07 22 22 22 03"))

    create_organization(client, first, "Association A")
    create_organization(client, second, "Association B")

    response = client.get("/api/v1/organizations", headers=first)
    assert response.status_code == 200
    names = [organization["name"] for organization in response.json()["data"]]
    assert names == ["Association A"]


def test_user_id_query_parameter_cannot_widen_the_result(client: TestClient) -> None:
    """`?userId=` est ignoré : l'identité vient du jeton."""
    first_session = register(client, "+225 07 22 22 22 04")
    second_session = register(client, "+225 07 22 22 22 05")
    second = auth_headers(second_session)

    create_organization(client, auth_headers(first_session), "Association Privée")

    response = client.get(
        "/api/v1/organizations",
        params={"userId": first_session["user"]["id"]},
        headers=second,
    )
    assert response.status_code == 200
    assert response.json()["data"] == []


def test_patch_updates_the_organization(client: TestClient) -> None:
    headers = auth_headers(register(client, "+225 07 22 22 22 06"))
    organization = create_organization(client, headers, "Association Modifiable")

    response = client.patch(
        f"/api/v1/organizations/{organization['id']}",
        json={"description": "Nouvelle description", "settings": {"latePaymentGraceDays": 7}},
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["description"] == "Nouvelle description"
    assert data["settings"]["latePaymentGraceDays"] == 7
    # Les autres réglages ne sont pas écrasés.
    assert data["settings"]["requireFullPaymentBeforeDraw"] is True


def test_dashboard_counts_real_members(client: TestClient) -> None:
    headers = auth_headers(register(client, "+225 07 22 22 22 07"))
    organization = create_organization(client, headers, "Association Tableau")

    client.post(
        f"/api/v1/organizations/{organization['id']}/members",
        json={
            "firstName": "Awa",
            "lastName": "KOUASSI",
            "phone": "+225 07 22 22 22 08",
            "role": "treasurer",
        },
        headers=headers,
    )

    response = client.get(
        f"/api/v1/organizations/{organization['id']}/dashboard", headers=headers
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["membersCount"] == 2
    assert data["members_count"] == 2
    assert data["organization"]["id"] == organization["id"]
    # Non encore migré : explicitement à zéro, jamais simulé.
    assert data["activeTontines"] == 0
    assert data["collection_rate"] == 0
    assert data["remaining_this_month"] == 0


def test_roles_matrix_is_served_by_the_backend(client: TestClient) -> None:
    headers = auth_headers(register(client, "+225 07 22 22 22 09"))
    organization = create_organization(client, headers, "Association Rôles")

    response = client.get(
        f"/api/v1/organizations/{organization['id']}/roles", headers=headers
    )
    assert response.status_code == 200
    definitions = {item["role"]: item["permissions"] for item in response.json()["data"]}
    assert "draw.run" in definitions["president"]
    assert "draw.run" not in definitions["member"]
    assert "member.create" in definitions["admin"]
