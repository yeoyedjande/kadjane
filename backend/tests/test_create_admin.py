"""Amorçage d'une instance avec un seul super administrateur.

C'est le pendant de `app.db.seed` pour la Beta et la production : un compte,
son organisation, et rien d'autre — ni mot de passe partagé, ni écriture
financière fictive.
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.db.create_admin import (
    BootstrapError,
    PASSWORD_ENV,
    create_admin,
    read_password,
)
from app.models.enums import OrgRole
from app.models.membership import OrganizationMember
from app.repositories.user_repository import UserRepository

PHONE = "+225 07 55 00 00 01"
STRONG_PASSWORD = "Tontine-Abidjan-2026"


def bootstrap(db: Session, **overrides) -> dict[str, str]:
    payload = {
        "phone": PHONE,
        "password": STRONG_PASSWORD,
        "first_name": "Yedjande",
        "last_name": "YEO",
        "organization_name": "Association Solidarité",
    }
    payload.update(overrides)
    return create_admin(db, **payload)


# --- Création ---------------------------------------------------------------


def test_le_compte_l_organisation_et_l_adhesion_sont_crees(db_session: Session) -> None:
    report = bootstrap(db_session)

    assert report["utilisateur"] == "créé"
    assert report["organisation"] == "créée"
    assert report["adhésion"] == "créée (super_admin)"


def test_le_super_admin_peut_se_connecter_et_administrer(
    client: TestClient, db_session: Session
) -> None:
    """Vérification de bout en bout : le compte créé ouvre bien le back-office."""
    bootstrap(db_session)

    login = client.post(
        "/api/v1/auth/login",
        json={"identifier": PHONE, "password": STRONG_PASSWORD},
    )
    assert login.status_code == 200, login.text
    token = login.json()["data"]["tokens"]["accessToken"]
    headers = {"Authorization": f"Bearer {token}"}

    organizations = client.get("/api/v1/organizations", headers=headers).json()["data"]
    organization_id = organizations[0]["id"]

    membership = client.get(
        f"/api/v1/organizations/{organization_id}/membership", headers=headers
    ).json()["data"]
    assert membership["role"] == OrgRole.SUPER_ADMIN.value

    # Le parcours visé : le super administrateur crée lui-même les membres.
    created = client.post(
        f"/api/v1/organizations/{organization_id}/members",
        json={
            "firstName": "Awa",
            "lastName": "KOUASSI",
            "phone": "+225 07 55 00 00 02",
            "role": "treasurer",
        },
        headers=headers,
    )
    assert created.status_code == 201, created.text


def test_aucune_donnee_de_demonstration_n_est_creee(
    client: TestClient, db_session: Session
) -> None:
    """Ni tontine ni écriture financière : la comptabilité démarre vierge."""
    bootstrap(db_session)

    login = client.post(
        "/api/v1/auth/login",
        json={"identifier": PHONE, "password": STRONG_PASSWORD},
    )
    headers = {"Authorization": f"Bearer {login.json()['data']['tokens']['accessToken']}"}
    organization_id = client.get("/api/v1/organizations", headers=headers).json()["data"][0]["id"]

    tontines = client.get(
        f"/api/v1/organizations/{organization_id}/tontines", headers=headers
    ).json()["data"]
    members = client.get(
        f"/api/v1/organizations/{organization_id}/members", headers=headers
    ).json()["data"]

    assert tontines == []
    assert members["total"] == 1


# --- Idempotence ------------------------------------------------------------


def test_relancer_ne_duplique_rien(db_session: Session) -> None:
    bootstrap(db_session)
    report = bootstrap(db_session)

    assert report["utilisateur"] == "déjà présent (mot de passe inchangé)"
    assert report["organisation"] == "déjà présente"
    assert report["adhésion"] == "déjà super_admin"


def test_le_mot_de_passe_n_est_reinitialise_que_sur_demande(
    client: TestClient, db_session: Session
) -> None:
    bootstrap(db_session)
    bootstrap(db_session, password="Un-Autre-Mot-De-Passe", reset_password=True)

    refused = client.post(
        "/api/v1/auth/login", json={"identifier": PHONE, "password": STRONG_PASSWORD}
    )
    accepted = client.post(
        "/api/v1/auth/login",
        json={"identifier": PHONE, "password": "Un-Autre-Mot-De-Passe"},
    )

    assert refused.status_code == 401
    assert accepted.status_code == 200


def test_un_compte_existant_au_role_moindre_est_promu(db_session: Session) -> None:
    """Le script est appelé pour obtenir un super admin : il élève, il n'échoue pas."""
    bootstrap(db_session)
    user = UserRepository(db_session).by_phone(PHONE)
    membership = (
        db_session.query(OrganizationMember).filter_by(user_id=user.id).one()
    )
    membership.role = OrgRole.MEMBER.value
    db_session.commit()

    report = bootstrap(db_session)

    assert report["adhésion"] == "promue en super_admin"


# --- Garde-fous sur le mot de passe -----------------------------------------


def test_un_mot_de_passe_absent_est_refuse(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv(PASSWORD_ENV, raising=False)

    with pytest.raises(BootstrapError, match="Aucun mot de passe"):
        read_password(None, interactive=False)


def test_un_mot_de_passe_trop_court_est_refuse(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv(PASSWORD_ENV, raising=False)

    with pytest.raises(BootstrapError, match="trop court"):
        read_password("court", interactive=False)


@pytest.mark.parametrize(
    "weak",
    [
        "kadjane",  # mot de passe du seed de démonstration
        "Kadjane",  # la casse ne doit pas contourner le refus
        "kadjane-2026-beta!",  # assez long, mais toujours dérivé du même terme
        "changeme",
        "MonMotDePasse",  # contient « motdepasse »
    ],
)
def test_les_mots_de_passe_trop_courants_sont_refuses(
    weak: str, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv(PASSWORD_ENV, raising=False)

    with pytest.raises(BootstrapError, match="trop courant|démonstration"):
        read_password(weak, interactive=False)


def test_un_mot_de_passe_solide_est_accepte(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv(PASSWORD_ENV, raising=False)

    assert read_password(STRONG_PASSWORD, interactive=False) == STRONG_PASSWORD


def test_la_variable_d_environnement_prime_sur_l_argument(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """L'argument laisse une trace dans l'historique du shell : il vient après."""
    monkeypatch.setenv(PASSWORD_ENV, "Depuis-L-Environnement")

    assert read_password("Depuis-L-Argument") == "Depuis-L-Environnement"
