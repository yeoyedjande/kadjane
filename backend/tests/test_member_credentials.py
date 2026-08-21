"""Accès des membres : l'administrateur les crée, le membre les change.

Faute de fournisseur SMS, le parcours OTP n'est pas exploitable. Le membre
reçoit donc un mot de passe provisoire de son administrateur, puis le change
lui-même depuis l'application s'il le souhaite.
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import auth_headers, create_organization, register

ADMIN_PHONE = "+225 07 66 00 00 01"
MEMBER_PHONE = "+225 07 66 00 00 02"


def setup_organization(client: TestClient) -> tuple[dict[str, str], str]:
    headers = auth_headers(register(client, ADMIN_PHONE))
    organization = create_organization(client, headers, "Association Accès")
    return headers, organization["id"]


def add_member(
    client: TestClient, headers: dict[str, str], organization_id: str, **extra
) -> dict:
    payload = {
        "firstName": "Awa",
        "lastName": "KOUASSI",
        "phone": MEMBER_PHONE,
    }
    payload.update(extra)
    response = client.post(
        f"/api/v1/organizations/{organization_id}/members",
        json=payload,
        headers=headers,
    )
    assert response.status_code == 201, response.text
    return response.json()["data"]


# --- Création par l'administrateur -------------------------------------------


def test_le_mot_de_passe_choisi_par_l_admin_ouvre_la_session(
    client: TestClient,
) -> None:
    headers, organization_id = setup_organization(client)
    created = add_member(client, headers, organization_id, password="AccesProvisoire1")

    # Fourni par l'administrateur : rien n'est renvoyé, il le connaît déjà.
    assert "temporaryPassword" not in created

    login = client.post(
        "/api/v1/auth/login",
        json={"identifier": MEMBER_PHONE, "password": "AccesProvisoire1"},
    )
    assert login.status_code == 200, login.text


def test_sans_mot_de_passe_fourni_un_provisoire_est_renvoye(
    client: TestClient,
) -> None:
    headers, organization_id = setup_organization(client)
    created = add_member(client, headers, organization_id)

    temporary = created["temporaryPassword"]
    assert len(temporary) >= 8

    login = client.post(
        "/api/v1/auth/login",
        json={"identifier": MEMBER_PHONE, "password": temporary},
    )
    assert login.status_code == 200, login.text


def test_le_provisoire_evite_les_caracteres_ambigus(client: TestClient) -> None:
    """L'administrateur le dicte ou le recopie : `0`/`O` et `1`/`l` sont exclus."""
    headers, organization_id = setup_organization(client)

    temporary = add_member(client, headers, organization_id)["temporaryPassword"]

    assert not set(temporary) & set("0O1lI")


def test_ajouter_un_compte_existant_ne_touche_pas_a_son_mot_de_passe(
    client: TestClient,
) -> None:
    """Rejoindre une organisation ne doit pas réinitialiser un accès existant."""
    headers, organization_id = setup_organization(client)
    register(client, MEMBER_PHONE)  # mot de passe `motdepasse123`

    created = add_member(client, headers, organization_id, password="TentativeEcrasement1")

    assert "temporaryPassword" not in created
    ancien = client.post(
        "/api/v1/auth/login",
        json={"identifier": MEMBER_PHONE, "password": "motdepasse123"},
    )
    impose = client.post(
        "/api/v1/auth/login",
        json={"identifier": MEMBER_PHONE, "password": "TentativeEcrasement1"},
    )
    assert ancien.status_code == 200, ancien.text
    assert impose.status_code == 401


def test_un_mot_de_passe_trop_court_est_refuse(client: TestClient) -> None:
    headers, organization_id = setup_organization(client)

    response = client.post(
        f"/api/v1/organizations/{organization_id}/members",
        json={
            "firstName": "Awa",
            "lastName": "KOUASSI",
            "phone": MEMBER_PHONE,
            "password": "court",
        },
        headers=headers,
    )

    assert response.status_code == 422


# --- Changement par le membre ------------------------------------------------


def member_session(client: TestClient) -> tuple[dict[str, str], str]:
    headers, organization_id = setup_organization(client)
    temporary = add_member(client, headers, organization_id)["temporaryPassword"]
    login = client.post(
        "/api/v1/auth/login",
        json={"identifier": MEMBER_PHONE, "password": temporary},
    )
    return auth_headers(login.json()["data"]), temporary


def test_le_membre_change_son_mot_de_passe(client: TestClient) -> None:
    headers, temporary = member_session(client)

    response = client.post(
        "/api/v1/auth/password/change",
        json={"currentPassword": temporary, "newPassword": "MonNouveauMotDePasse1"},
        headers=headers,
    )
    assert response.status_code == 200, response.text
    assert response.json()["data"] == {"changed": True}

    ancien = client.post(
        "/api/v1/auth/login",
        json={"identifier": MEMBER_PHONE, "password": temporary},
    )
    nouveau = client.post(
        "/api/v1/auth/login",
        json={"identifier": MEMBER_PHONE, "password": "MonNouveauMotDePasse1"},
    )
    assert ancien.status_code == 401
    assert nouveau.status_code == 200, nouveau.text


def test_l_ancien_mot_de_passe_doit_etre_exact(client: TestClient) -> None:
    headers, _ = member_session(client)

    response = client.post(
        "/api/v1/auth/password/change",
        json={"currentPassword": "PasLeBon1", "newPassword": "MonNouveauMotDePasse1"},
        headers=headers,
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_current_password"


def test_le_nouveau_doit_differer_de_l_ancien(client: TestClient) -> None:
    headers, temporary = member_session(client)

    response = client.post(
        "/api/v1/auth/password/change",
        json={"currentPassword": temporary, "newPassword": temporary},
        headers=headers,
    )

    assert response.json()["error"]["code"] == "password_unchanged"


def test_le_changement_ferme_les_autres_sessions(client: TestClient) -> None:
    """Un accès déjà ouvert ailleurs ne doit pas survivre au changement."""
    headers, temporary = member_session(client)
    autre = client.post(
        "/api/v1/auth/login",
        json={"identifier": MEMBER_PHONE, "password": temporary},
    ).json()["data"]

    client.post(
        "/api/v1/auth/password/change",
        json={"currentPassword": temporary, "newPassword": "MonNouveauMotDePasse1"},
        headers=headers,
    )

    refresh = client.post(
        "/api/v1/auth/refresh", json={"refreshToken": autre["tokens"]["refreshToken"]}
    )
    assert refresh.status_code == 401


def test_le_changement_exige_une_session(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/password/change",
        json={"currentPassword": "peu importe", "newPassword": "MonNouveauMotDePasse1"},
    )

    assert response.status_code in (401, 403)
