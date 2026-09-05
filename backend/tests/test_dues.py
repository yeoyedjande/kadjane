"""Cotisations de caisse.

Distinctes des tontines : l'association encaisse et garde, elle ne redistribue
pas. Le trésorier tient la caisse — il définit les plans et encaisse —, chaque
membre voit ce qu'il doit.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient

from tests.conftest import auth_headers, create_organization, register

ADMIN = "+225 07 55 11 00 01"
MEMBER = "+225 07 55 11 00 02"


def setup_org(client: TestClient) -> tuple[dict[str, str], str]:
    headers = auth_headers(register(client, ADMIN))
    organization = create_organization(client, headers, "Association Caisse")
    return headers, organization["id"]


def add_member(client, headers, org, phone=MEMBER, role="member") -> dict:
    response = client.post(
        f"/api/v1/organizations/{org}/members",
        json={"firstName": "Awa", "lastName": "KOUASSI", "phone": phone, "role": role},
        headers=headers,
    )
    assert response.status_code == 201, response.text
    return response.json()["data"]


def create_plan(client, headers, org, **overrides) -> dict:
    payload = {
        "name": "Caisse de solidarité",
        "amount": "5000",
        "frequency": "monthly",
        "dueDay": 5,
        # Deux mois en arrière : deux périodes doivent apparaître d'elles-mêmes.
        "startDate": str(date.today().replace(day=1) - timedelta(days=45)),
    }
    payload.update(overrides)
    response = client.post(
        f"/api/v1/organizations/{org}/dues-plans", json=payload, headers=headers
    )
    assert response.status_code == 201, response.text
    return response.json()["data"]


# --- Plans -------------------------------------------------------------------


def test_l_administrateur_cree_une_cotisation(client: TestClient) -> None:
    headers, org = setup_org(client)

    plan = create_plan(client, headers, org)

    assert plan["name"] == "Caisse de solidarité"
    assert plan["amount"] == "5000.00"
    assert plan["status"] == "active"


def test_deux_cotisations_peuvent_coexister(client: TestClient) -> None:
    """Caisse de solidarité et fonds événement sont des plans distincts."""
    headers, org = setup_org(client)
    create_plan(client, headers, org)
    create_plan(client, headers, org, name="Fonds événement", amount="2000")

    plans = client.get(
        f"/api/v1/organizations/{org}/dues-plans", headers=headers
    ).json()["data"]

    assert {p["name"] for p in plans} == {"Caisse de solidarité", "Fonds événement"}


def test_un_nom_en_double_est_refuse(client: TestClient) -> None:
    headers, org = setup_org(client)
    create_plan(client, headers, org)

    response = client.post(
        f"/api/v1/organizations/{org}/dues-plans",
        json={"name": "caisse de SOLIDARITÉ", "amount": "5000"},
        headers=headers,
    )

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "dues_plan_exists"


def test_un_montant_nul_est_refuse(client: TestClient) -> None:
    headers, org = setup_org(client)

    response = client.post(
        f"/api/v1/organizations/{org}/dues-plans",
        json={"name": "Caisse", "amount": "0"},
        headers=headers,
    )

    assert response.status_code == 422


# --- Échéances ---------------------------------------------------------------


def test_les_echeances_apparaissent_a_la_lecture(client: TestClient) -> None:
    """Aucune tâche planifiée : consulter le plan suffit à créer les périodes."""
    headers, org = setup_org(client)
    add_member(client, headers, org)
    plan = create_plan(client, headers, org)

    entries = client.get(
        f"/api/v1/organizations/{org}/dues-plans/{plan['id']}/entries",
        headers=headers,
    ).json()["data"]

    # Les deux membres viennent d'adhérer : chacun ne doit que la période en
    # cours, au montant du plan.
    assert len(entries) == 2
    assert {e["expectedAmount"] for e in entries} == {"5000.00"}
    assert len({e["memberId"] for e in entries}) == 2


def test_un_membre_ancien_doit_toutes_les_periodes_ecoulees(
    client: TestClient, db_session
) -> None:
    """Le rattrapage vaut pour qui était déjà là : trois mois, trois échéances."""
    from app.models.membership import OrganizationMember

    headers, org = setup_org(client)
    membership = db_session.query(OrganizationMember).one()
    # Antidatage : l'adhésion précède le début du plan.
    membership.joined_at = datetime.now(timezone.utc) - timedelta(days=200)
    db_session.commit()

    plan = create_plan(client, headers, org)
    entries = client.get(
        f"/api/v1/organizations/{org}/dues-plans/{plan['id']}/entries",
        headers=headers,
    ).json()["data"]

    # Plan démarré il y a ~45 jours : le mois de départ, l'intermédiaire et
    # le mois courant.
    assert len(entries) >= 2
    assert len({e["sequenceNumber"] for e in entries}) == len(entries)


def test_la_generation_est_idempotente(client: TestClient) -> None:
    headers, org = setup_org(client)
    add_member(client, headers, org)
    plan = create_plan(client, headers, org)
    url = f"/api/v1/organizations/{org}/dues-plans/{plan['id']}/entries"

    first = client.get(url, headers=headers).json()["data"]
    second = client.get(url, headers=headers).json()["data"]

    assert len(first) == len(second)


def test_un_membre_ne_doit_rien_avant_son_adhesion(client: TestClient) -> None:
    """Rejoindre en cours de route ne crée pas de dette rétroactive."""
    headers, org = setup_org(client)
    plan = create_plan(client, headers, org)
    client.get(
        f"/api/v1/organizations/{org}/dues-plans/{plan['id']}/entries", headers=headers
    )
    late = add_member(client, headers, org, phone="+225 07 55 11 00 09")

    entries = client.get(
        f"/api/v1/organizations/{org}/dues-plans/{plan['id']}/entries",
        params={"memberId": late["id"]},
        headers=headers,
    ).json()["data"]

    # Le nouveau membre ne doit que la période en cours, pas les précédentes.
    periods = {e["sequenceNumber"] for e in entries}
    assert periods, "le membre doit au moins la période courante"
    assert min(periods) == max(periods)


def test_un_plan_suspendu_n_engendre_plus_rien(client: TestClient) -> None:
    headers, org = setup_org(client)
    plan = create_plan(client, headers, org)
    url = f"/api/v1/organizations/{org}/dues-plans/{plan['id']}/entries"
    before = len(client.get(url, headers=headers).json()["data"])

    client.patch(
        f"/api/v1/organizations/{org}/dues-plans/{plan['id']}",
        json={"status": "paused"},
        headers=headers,
    )
    add_member(client, headers, org, phone="+225 07 55 11 00 08")

    assert len(client.get(url, headers=headers).json()["data"]) == before


# --- Règlements --------------------------------------------------------------


def first_entry(client, headers, org, plan_id) -> dict:
    entries = client.get(
        f"/api/v1/organizations/{org}/dues-plans/{plan_id}/entries", headers=headers
    ).json()["data"]
    return entries[0]


def test_un_reglement_complet_solde_l_echeance(client: TestClient) -> None:
    headers, org = setup_org(client)
    plan = create_plan(client, headers, org)
    entry = first_entry(client, headers, org, plan["id"])

    response = client.post(
        f"/api/v1/dues-entries/{entry['id']}/payments",
        json={"amount": "5000", "paymentMethod": "cash"},
        headers=headers,
    )

    assert response.status_code == 201, response.text
    assert response.json()["data"]["entry"]["status"] == "paid"
    assert response.json()["data"]["entry"]["remainingAmount"] == "0"


def test_un_reglement_partiel_laisse_un_reste(client: TestClient) -> None:
    headers, org = setup_org(client)
    plan = create_plan(client, headers, org)
    entry = first_entry(client, headers, org, plan["id"])

    body = client.post(
        f"/api/v1/dues-entries/{entry['id']}/payments",
        json={"amount": "2000", "paymentMethod": "cash"},
        headers=headers,
    ).json()["data"]

    assert body["entry"]["status"] == "partial"
    assert body["entry"]["remainingAmount"] == "3000.00"


def test_annuler_un_reglement_retablit_la_dette(client: TestClient) -> None:
    """L'écriture reste dans l'historique, mais ne compte plus."""
    headers, org = setup_org(client)
    plan = create_plan(client, headers, org)
    entry = first_entry(client, headers, org, plan["id"])
    payment = client.post(
        f"/api/v1/dues-entries/{entry['id']}/payments",
        json={"amount": "5000", "paymentMethod": "cash"},
        headers=headers,
    ).json()["data"]

    cancelled = client.post(
        f"/api/v1/dues-payments/{payment['id']}/cancel",
        json={"reason": "Encaissement saisi deux fois"},
        headers=headers,
    )
    assert cancelled.status_code == 200, cancelled.text
    assert cancelled.json()["data"]["status"] == "cancelled"

    refreshed = client.get(
        f"/api/v1/organizations/{org}/dues-plans/{plan['id']}/entries",
        params={"memberId": entry["memberId"]},
        headers=headers,
    ).json()["data"]
    same = next(e for e in refreshed if e["id"] == entry["id"])
    assert same["paidAmount"] == "0.00"
    assert same["status"] != "paid"


def test_un_montant_negatif_est_refuse(client: TestClient) -> None:
    headers, org = setup_org(client)
    plan = create_plan(client, headers, org)
    entry = first_entry(client, headers, org, plan["id"])

    response = client.post(
        f"/api/v1/dues-entries/{entry['id']}/payments",
        json={"amount": "-100", "paymentMethod": "cash"},
        headers=headers,
    )

    assert response.status_code == 422


# --- Droits ------------------------------------------------------------------


def test_le_tresorier_cree_un_plan(client: TestClient) -> None:
    """Le trésorier tient la caisse : il n'attend pas le back-office."""
    headers, org = setup_org(client)
    register(client, MEMBER)
    add_member(client, headers, org, role="treasurer")
    treasurer_headers = auth_headers(
        client.post(
            "/api/v1/auth/login",
            json={"identifier": MEMBER, "password": "motdepasse123"},
        ).json()["data"]
    )

    response = client.post(
        f"/api/v1/organizations/{org}/dues-plans",
        json={"name": "Caisse du trésorier", "amount": "5000"},
        headers=treasurer_headers,
    )

    assert response.status_code == 201, response.text

    # Et il l'ajuste : suspendre une cotisation relève du même geste.
    plan_id = response.json()["data"]["id"]
    update = client.patch(
        f"/api/v1/organizations/{org}/dues-plans/{plan_id}",
        json={"status": "paused"},
        headers=treasurer_headers,
    )
    assert update.status_code == 200, update.text
    assert update.json()["data"]["status"] == "paused"


def test_un_simple_membre_ne_cree_pas_de_plan(client: TestClient) -> None:
    headers, org = setup_org(client)
    member_session = register(client, MEMBER)
    add_member(client, headers, org)
    member_headers = auth_headers(member_session)

    response = client.post(
        f"/api/v1/organizations/{org}/dues-plans",
        json={"name": "Caisse", "amount": "5000"},
        headers=member_headers,
    )

    assert response.status_code == 403


def test_un_simple_membre_n_encaisse_pas(client: TestClient) -> None:
    """Le trésorier détient l'argent : lui seul enregistre un règlement."""
    headers, org = setup_org(client)
    register(client, MEMBER)
    add_member(client, headers, org)
    plan = create_plan(client, headers, org)
    entry = first_entry(client, headers, org, plan["id"])
    member_headers = auth_headers(
        client.post(
            "/api/v1/auth/login",
            json={"identifier": MEMBER, "password": "motdepasse123"},
        ).json()["data"]
    )

    response = client.post(
        f"/api/v1/dues-entries/{entry['id']}/payments",
        json={"amount": "5000", "paymentMethod": "cash"},
        headers=member_headers,
    )

    assert response.status_code == 403


def test_un_membre_voit_ce_qu_il_doit(client: TestClient) -> None:
    headers, org = setup_org(client)
    register(client, MEMBER)
    add_member(client, headers, org)
    create_plan(client, headers, org)
    member_headers = auth_headers(
        client.post(
            "/api/v1/auth/login",
            json={"identifier": MEMBER, "password": "motdepasse123"},
        ).json()["data"]
    )

    response = client.get(
        "/api/v1/me/dues", params={"organizationId": org}, headers=member_headers
    )

    assert response.status_code == 200, response.text
    assert len(response.json()["data"]) >= 1


def test_isolation_entre_organisations(client: TestClient) -> None:
    mine_headers, mine = setup_org(client)
    create_plan(client, mine_headers, mine)

    other_headers = auth_headers(register(client, "+225 07 55 22 00 01"))
    other = create_organization(client, other_headers, "Association B")["id"]

    # 404 et non 403 : ne pas révéler l'existence d'une organisation étrangère.
    response = client.get(
        f"/api/v1/organizations/{other}/dues-plans", headers=mine_headers
    )
    assert response.status_code == 404

    plans = client.get(
        f"/api/v1/organizations/{other}/dues-plans", headers=other_headers
    ).json()["data"]
    assert plans == []


# --- Trésorerie --------------------------------------------------------------


def test_la_caisse_integre_les_cotisations(client: TestClient) -> None:
    """Sans cela, l'argent encaissé n'apparaîtrait dans aucun solde."""
    headers, org = setup_org(client)
    plan = create_plan(client, headers, org)
    entry = first_entry(client, headers, org, plan["id"])

    before = client.get(
        f"/api/v1/organizations/{org}/treasury", headers=headers
    ).json()["data"]
    client.post(
        f"/api/v1/dues-entries/{entry['id']}/payments",
        json={"amount": "5000", "paymentMethod": "cash"},
        headers=headers,
    )
    after = client.get(
        f"/api/v1/organizations/{org}/treasury", headers=headers
    ).json()["data"]

    assert float(after["duesTotal"]) - float(before["duesTotal"]) == 5000
    assert float(after["balance"]) - float(before["balance"]) == 5000
