"""Garde-fou sur les origines acceptées.

Régression : le serveur de développement Flutter Web choisit un port au hasard
à chaque lancement. Tant que seule une liste fixe d'origines était autorisée,
la requête de pré-vol repartait en 400 (« Disallowed CORS origin ») et
l'application affichait « impossible de charger les données ».
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.core.config import Settings


def preflight(client: TestClient, origin: str):
    return client.options(
        "/api/v1/auth/login",
        headers={
            "Origin": origin,
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "content-type",
        },
    )


@pytest.mark.parametrize(
    "origin",
    [
        "http://localhost:4200",  # back-office Angular
        "http://localhost:50392",  # Flutter Web, port tiré au hasard
        "http://127.0.0.1:61234",
    ],
)
def test_les_origines_locales_sont_acceptees(client: TestClient, origin: str) -> None:
    response = preflight(client, origin)

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == origin


def test_une_origine_etrangere_reste_refusee(client: TestClient) -> None:
    assert preflight(client, "https://evil.example.com").status_code == 400


def test_le_repli_local_ne_vaut_qu_en_developpement() -> None:
    """Hors développement, seules les origines listées passent."""
    assert Settings(ENVIRONMENT="development").cors_origin_regex is not None
    assert Settings(ENVIRONMENT="production").cors_origin_regex is None
    assert Settings(ENVIRONMENT="staging").cors_origin_regex is None


def test_le_motif_explicite_prime_sur_le_repli() -> None:
    settings = Settings(
        ENVIRONMENT="production",
        CORS_ORIGIN_REGEX=r"^https://([a-z0-9-]+\.)?kadjane\.app$",
    )

    assert settings.cors_origin_regex == r"^https://([a-z0-9-]+\.)?kadjane\.app$"
