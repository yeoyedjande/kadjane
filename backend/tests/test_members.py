from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import auth_headers, create_organization, register


def _organization_with_members(client: TestClient, headers: dict[str, str]) -> str:
    organization = create_organization(client, headers, "Association Membres")
    roster = [
        ("Awa", "KOUASSI", "+225 07 33 33 33 02", "treasurer"),
        ("Serge", "KOFFI", "+225 07 33 33 33 03", "president"),
        ("Fatou", "DIALLO", "+225 07 33 33 33 04", "auditor"),
        ("Ibrahim", "TRAORE", "+225 07 33 33 33 05", "member"),
    ]
    for first_name, last_name, phone, role in roster:
        response = client.post(
            f"/api/v1/organizations/{organization['id']}/members",
            json={
                "firstName": first_name,
                "lastName": last_name,
                "phone": phone,
                "role": role,
            },
            headers=headers,
        )
        assert response.status_code == 201, response.text
    return organization["id"]


def test_members_are_listed_with_pagination(client: TestClient) -> None:
    headers = auth_headers(register(client, "+225 07 33 33 33 01"))
    organization_id = _organization_with_members(client, headers)

    response = client.get(
        f"/api/v1/organizations/{organization_id}/members",
        params={"page": 0, "pageSize": 2},
        headers=headers,
    )
    assert response.status_code == 200
    body = response.json()
    data = body["data"]
    assert len(data["items"]) == 2
    assert data["total"] == 5
    assert data["hasMore"] is True
    assert data["page"] == 0
    assert body["meta"] == {"page": 0, "page_size": 2, "total": 5, "has_more": True}

    last_page = client.get(
        f"/api/v1/organizations/{organization_id}/members",
        params={"page": 2, "pageSize": 2},
        headers=headers,
    ).json()["data"]
    assert last_page["hasMore"] is False
    assert len(last_page["items"]) == 1


def test_members_can_be_searched_and_filtered(client: TestClient) -> None:
    headers = auth_headers(register(client, "+225 07 33 33 33 10"))
    organization_id = _organization_with_members(client, headers)

    by_name = client.get(
        f"/api/v1/organizations/{organization_id}/members",
        params={"query": "kouassi"},
        headers=headers,
    ).json()["data"]
    assert [item["user"]["firstName"] for item in by_name["items"]] == ["Awa"]

    by_role = client.get(
        f"/api/v1/organizations/{organization_id}/members",
        params={"role": "president"},
        headers=headers,
    ).json()["data"]
    assert by_role["total"] == 1
    assert by_role["items"][0]["user"]["lastName"] == "KOFFI"


def test_member_creation_assigns_a_member_number(client: TestClient) -> None:
    headers = auth_headers(register(client, "+225 07 33 33 33 20"))
    organization = create_organization(client, headers, "Association Numérotée")

    response = client.post(
        f"/api/v1/organizations/{organization['id']}/members",
        json={
            "firstName": "Mariam",
            "lastName": "BAMBA",
            "phone": "+225 07 33 33 33 21",
        },
        headers=headers,
    )
    assert response.status_code == 201
    assert response.json()["data"]["memberNumber"] == "M-002"


def test_member_can_be_updated(client: TestClient) -> None:
    headers = auth_headers(register(client, "+225 07 33 33 33 30"))
    organization = create_organization(client, headers, "Association Édition")
    member = client.post(
        f"/api/v1/organizations/{organization['id']}/members",
        json={
            "firstName": "Salif",
            "lastName": "OUATTARA",
            "phone": "+225 07 33 33 33 31",
        },
        headers=headers,
    ).json()["data"]

    response = client.patch(
        f"/api/v1/organizations/{organization['id']}/members/{member['id']}",
        json={"role": "treasurer", "status": "suspended", "firstName": "Salifou"},
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["role"] == "treasurer"
    assert data["status"] == "suspended"
    assert data["user"]["firstName"] == "Salifou"


def test_a_simple_member_cannot_create_members(client: TestClient) -> None:
    admin = auth_headers(register(client, "+225 07 33 33 33 40"))
    organization = create_organization(client, admin, "Association Droits")

    # Compte réel du membre simple, rattaché à l'organisation.
    simple = register(client, "+225 07 33 33 33 41", firstName="Simple")
    client.post(
        f"/api/v1/organizations/{organization['id']}/members",
        json={
            "firstName": "Simple",
            "lastName": "Utilisateur",
            "phone": "+225 07 33 33 33 41",
            "role": "member",
        },
        headers=admin,
    )

    response = client.post(
        f"/api/v1/organizations/{organization['id']}/members",
        json={
            "firstName": "Nouveau",
            "lastName": "Membre",
            "phone": "+225 07 33 33 33 42",
        },
        headers=auth_headers(simple),
    )
    assert response.status_code == 403
    assert response.json()["error"]["code"] == "permission_denied"
