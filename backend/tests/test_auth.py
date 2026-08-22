from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import auth_headers, register


def test_health_checks_the_database(client: TestClient) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["database"] == "ok"
    # `push` renseigne si la clé Firebase est présente — jamais son contenu.
    # Aucune clé en test, d'où `disabled`.
    assert body["push"] == "disabled"


def test_register_returns_user_and_tokens(client: TestClient) -> None:
    data = register(client, "+225 07 11 11 11 01", firstName="Yedjane", lastName="YEO")

    assert data["user"]["firstName"] == "Yedjane"
    assert data["tokens"]["accessToken"]
    assert data["tokens"]["refreshToken"]
    # Compatibilité OAuth pour les futurs clients web.
    assert data["token_type"] == "bearer"
    assert "password" not in str(data)


def test_register_rejects_duplicate_phone(client: TestClient) -> None:
    register(client, "+225 07 11 11 11 02")
    response = client.post(
        "/api/v1/auth/register",
        json={
            "firstName": "Autre",
            "lastName": "Personne",
            "phone": "+225 07 11 11 11 02",
            "password": "motdepasse123",
        },
    )
    assert response.status_code == 409
    body = response.json()
    assert body["success"] is False
    assert body["error"]["code"] == "phone_already_used"


def test_login_with_phone_and_with_email(client: TestClient) -> None:
    register(client, "+225 07 11 11 11 03", email="test3@kadjane.app")

    for identifier in ("+225 07 11 11 11 03", "test3@kadjane.app"):
        response = client.post(
            "/api/v1/auth/login",
            json={"identifier": identifier, "password": "motdepasse123"},
        )
        assert response.status_code == 200, identifier
        assert response.json()["data"]["tokens"]["accessToken"]


def test_login_rejects_wrong_password(client: TestClient) -> None:
    register(client, "+225 07 11 11 11 04")
    response = client.post(
        "/api/v1/auth/login",
        json={"identifier": "+225 07 11 11 11 04", "password": "mauvais-mot-de-passe"},
    )
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_credentials"


def test_me_requires_a_token(client: TestClient) -> None:
    assert client.get("/api/v1/me").status_code == 401
    assert client.get("/api/v1/auth/me").status_code == 401


def test_me_returns_the_authenticated_user(client: TestClient) -> None:
    session = register(client, "+225 07 11 11 11 05", firstName="Awa")
    response = client.get("/api/v1/me", headers=auth_headers(session))

    assert response.status_code == 200
    assert response.json()["data"]["firstName"] == "Awa"


def test_refresh_rotates_the_session(client: TestClient) -> None:
    session = register(client, "+225 07 11 11 11 06")
    refresh_token = session["tokens"]["refreshToken"]

    response = client.post("/api/v1/auth/refresh", json={"refreshToken": refresh_token})
    assert response.status_code == 200
    renewed = response.json()["data"]["tokens"]
    assert renewed["refreshToken"] != refresh_token

    # L'ancien jeton n'est plus rejouable.
    replay = client.post("/api/v1/auth/refresh", json={"refreshToken": refresh_token})
    assert replay.status_code == 401


def test_logout_revokes_the_refresh_token(client: TestClient) -> None:
    session = register(client, "+225 07 11 11 11 07")
    response = client.post("/api/v1/auth/logout", headers=auth_headers(session))
    assert response.status_code == 200

    replay = client.post(
        "/api/v1/auth/refresh",
        json={"refreshToken": session["tokens"]["refreshToken"]},
    )
    assert replay.status_code == 401


def test_invalid_payload_returns_the_error_envelope(client: TestClient) -> None:
    response = client.post("/api/v1/auth/login", json={"identifier": "x"})
    assert response.status_code == 422
    body = response.json()
    assert body["success"] is False
    assert body["error"]["code"] == "validation_error"
    assert "errors" in body["error"]["details"]
