"""Normalisation de l'URL de base de données.

Régression : en déploiement manageé, `DATABASE_URL` arrive sans pilote
(`postgresql://…`). SQLAlchemy traduit ce schéma par psycopg2, que l'image
n'installe pas — le conteneur mourait au démarrage sur
`ModuleNotFoundError: No module named 'psycopg2'`.
"""

from __future__ import annotations

import pytest

from app.core.config import Settings

PSYCOPG3 = "postgresql+psycopg://"


@pytest.mark.parametrize(
    "injected",
    [
        # Ce qu'injectent Railway / Render.
        "postgresql://user:pass@db.internal:5432/kadjane",
        # Schéma historique, encore servi par Heroku et d'anciens add-ons.
        "postgres://user:pass@db.internal:5432/kadjane",
    ],
)
def test_une_url_sans_pilote_bascule_sur_psycopg3(injected: str) -> None:
    settings = Settings(DATABASE_URL=injected)

    assert settings.database_url.startswith(PSYCOPG3)
    assert settings.database_url.endswith("@db.internal:5432/kadjane")


def test_les_parametres_de_connexion_sont_preserves() -> None:
    """Le `sslmode` exigé par les hébergeurs manageés doit survivre."""
    settings = Settings(
        DATABASE_URL="postgresql://user:pass@db.internal:5432/kadjane?sslmode=require"
    )

    assert settings.database_url == (
        PSYCOPG3 + "user:pass@db.internal:5432/kadjane?sslmode=require"
    )


@pytest.mark.parametrize(
    "explicit",
    [
        "postgresql+psycopg://user:pass@localhost:5432/kadjane",
        "postgresql+asyncpg://user:pass@localhost:5432/kadjane",
        "sqlite://",
    ],
)
def test_une_url_qui_nomme_son_pilote_reste_intacte(explicit: str) -> None:
    assert Settings(DATABASE_URL=explicit).database_url == explicit
