"""Fixtures de test.

Les tests tournent sur SQLite en mémoire : ils sont rapides et ne demandent
aucun conteneur. Les modèles utilisent des types portables (`Uuid`, `JSON`),
donc le schéma testé est celui de PostgreSQL.
"""

from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import settings
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models import User  # noqa: F401 - peuple les métadonnées
from app.rbac.seed import sync_rbac


# Coût bcrypt minimal : la suite teste le mécanisme, pas sa lenteur.
settings.bcrypt_rounds = 4


@pytest.fixture
def db_session() -> Iterator[Session]:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    session = factory()
    # Le catalogue et les six rôles système : ce que le démarrage de l'API
    # pose en production, posé ici aussi pour que les tests exercent le
    # chemin réel plutôt que le repli statique.
    sync_rbac(session)
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(engine)
        engine.dispose()


@pytest.fixture
def client(db_session: Session) -> Iterator[TestClient]:
    app.dependency_overrides[get_db] = lambda: db_session
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


# --- Aides ------------------------------------------------------------------


def register(client: TestClient, phone: str, **overrides) -> dict:
    payload = {
        "firstName": "Test",
        "lastName": "Utilisateur",
        "phone": phone,
        "password": "motdepasse123",
        "gender": "unspecified",
    }
    payload.update(overrides)
    response = client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 201, response.text
    return response.json()["data"]


def auth_headers(session: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {session['tokens']['accessToken']}"}


def create_organization(client: TestClient, headers: dict[str, str], name: str) -> dict:
    response = client.post(
        "/api/v1/organizations",
        json={"name": name, "currency": "XOF", "country": "CI"},
        headers=headers,
    )
    assert response.status_code == 201, response.text
    return response.json()["data"]


# --- Aides métier tontine ----------------------------------------------------


def build_organization(
    client: TestClient, *, members: int = 12, prefix: str = "90", name: str | None = None
) -> dict:
    """Organisation avec un administrateur et `members - 1` autres membres.

    `prefix` isole les numéros de téléphone : deux organisations peuvent
    coexister dans un même test.
    """
    admin_session = register(client, f"+225 07 {prefix} 00 00 01", firstName="Yedjane")
    headers = auth_headers(admin_session)
    organization = create_organization(
        client, headers, name or f"Association {prefix}"
    )

    roster = [
        {
            "id": client.get(
                f"/api/v1/organizations/{organization['id']}/membership",
                headers=headers,
            ).json()["data"]["id"],
            "name": "Yedjane Utilisateur",
        }
    ]
    for index in range(2, members + 1):
        response = client.post(
            f"/api/v1/organizations/{organization['id']}/members",
            json={
                "firstName": f"Membre{index:02d}",
                "lastName": "TEST",
                "phone": f"+225 07 {prefix} 00 00 {index:02d}",
            },
            headers=headers,
        )
        assert response.status_code == 201, response.text
        member = response.json()["data"]
        roster.append({"id": member["id"], "name": member["user"]["firstName"]})

    return {
        "headers": headers,
        "session": admin_session,
        "organization": organization,
        "members": roster,
    }


def create_tontine(
    client: TestClient,
    context: dict,
    *,
    amount: int = 50000,
    mode: str = "monthly_draw",
    require_all: bool = True,
    allow_override: bool = True,
    start_date: str = "2026-08-01",
) -> dict:
    response = client.post(
        f"/api/v1/organizations/{context['organization']['id']}/tontines",
        json={
            "name": "Tontine Solidarité",
            "contributionAmount": amount,
            "currency": "XOF",
            "frequency": "monthly",
            "allocationMode": mode,
            "startDate": start_date,
            "dueDayOfPeriod": 5,
            "memberIds": [member["id"] for member in context["members"]],
            "requireAllContributionsBeforeDraw": require_all,
            "allowDrawOverride": allow_override,
        },
        headers=context["headers"],
    )
    assert response.status_code == 201, response.text
    return response.json()["data"]


def cycles_of(client: TestClient, context: dict, tontine_id: str) -> list[dict]:
    response = client.get(
        f"/api/v1/tontines/{tontine_id}/cycles", headers=context["headers"]
    )
    assert response.status_code == 200, response.text
    return response.json()["data"]


def pay_cycle(
    client: TestClient,
    context: dict,
    tontine_id: str,
    cycle_id: str,
    *,
    skip: int = 0,
    status: str = "confirmed",
) -> int:
    """Règle les cotisations du cycle, en laissant `skip` impayées."""
    slots = client.get(
        f"/api/v1/cycles/{cycle_id}/contribution-slots", headers=context["headers"]
    ).json()["data"]
    targets = slots[: len(slots) - skip] if skip else slots
    for slot in targets:
        if slot["contribution"] is not None:
            continue
        response = client.post(
            f"/api/v1/tontines/{tontine_id}/contributions",
            json={
                "cycleId": cycle_id,
                "memberId": slot["memberId"],
                "amount": slot["expectedAmount"],
                "method": "cash",
                "status": status,
            },
            headers=context["headers"],
        )
        assert response.status_code == 201, response.text
    return len(targets)


def participants_of(client: TestClient, context: dict, tontine_id: str) -> list[dict]:
    return client.get(
        f"/api/v1/tontines/{tontine_id}/participants", headers=context["headers"]
    ).json()["data"]
