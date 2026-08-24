"""Caisses et campagnes de cotisation.

La règle que ces tests protègent : une cotisation attendue, un paiement reçu et
un solde de caisse sont trois nombres distincts. Ils ne bougent pas ensemble,
et le seul qui fasse grossir la caisse est le paiement.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from tests.conftest import auth_headers, build_organization, register

API = "/api/v1"


def _cashbox(client: TestClient, context: dict, name: str = "Caisse principale") -> dict:
    response = client.post(
        f"{API}/organizations/{context['organization']['id']}/cashboxes",
        json={"name": name, "openingBalance": "0"},
        headers=context["headers"],
    )
    assert response.status_code == 201, response.text
    return response.json()["data"]


def _campaign(
    client: TestClient,
    context: dict,
    *,
    amount: str = "10000",
    members: list[str] | None = None,
    cashbox_id: str | None = None,
    due_date: str | None = None,
    amount_mode: str = "fixed",
    contribution_type: str = "association",
) -> dict:
    payload = {
        "title": "Cotisation mensuelle — Septembre",
        "contributionType": contribution_type,
        "amount": amount,
        "amountMode": amount_mode,
    }
    if members is not None:
        payload["memberIds"] = members
    if cashbox_id is not None:
        payload["cashboxId"] = cashbox_id
    if due_date is not None:
        payload["dueDate"] = due_date

    response = client.post(
        f"{API}/organizations/{context['organization']['id']}/contribution-campaigns",
        json=payload,
        headers=context["headers"],
    )
    assert response.status_code == 201, response.text
    return response.json()["data"]


# --- Caisses ------------------------------------------------------------------


def test_le_solde_est_calcule_et_non_stocke(client: TestClient) -> None:
    context = build_organization(client, members=2, prefix="71")
    box = _cashbox(client, context)

    for type_, amount in (("income", "50000"), ("expense", "12000")):
        response = client.post(
            f"{API}/cashboxes/{box['id']}/transactions",
            json={"type": type_, "category": "donation", "amount": amount},
            headers=context["headers"],
        )
        assert response.status_code == 201, response.text

    refreshed = client.get(
        f"{API}/cashboxes/{box['id']}", headers=context["headers"]
    ).json()["data"]

    assert refreshed["inflows"] == 50000
    assert refreshed["outflows"] == 12000
    assert refreshed["currentBalance"] == 38000


def test_une_ecriture_annulee_sort_du_solde_mais_pas_du_journal(
    client: TestClient,
) -> None:
    """§33 : aucune suppression silencieuse d'une écriture financière."""
    context = build_organization(client, members=2, prefix="72")
    box = _cashbox(client, context)

    transaction = client.post(
        f"{API}/cashboxes/{box['id']}/transactions",
        json={"type": "income", "category": "donation", "amount": "25000"},
        headers=context["headers"],
    ).json()["data"]

    cancelled = client.post(
        f"{API}/cash-transactions/{transaction['id']}/cancel",
        json={"reason": "Saisie en double"},
        headers=context["headers"],
    )
    assert cancelled.status_code == 200, cancelled.text
    assert cancelled.json()["data"]["status"] == "cancelled"

    balance = client.get(
        f"{API}/cashboxes/{box['id']}", headers=context["headers"]
    ).json()["data"]
    assert balance["currentBalance"] == 0

    journal = client.get(
        f"{API}/cashboxes/{box['id']}/transactions", headers=context["headers"]
    ).json()
    assert journal["meta"]["total"] == 1
    assert journal["data"][0]["cancelReason"] == "Saisie en double"


def test_une_caisse_fermee_refuse_les_mouvements(client: TestClient) -> None:
    context = build_organization(client, members=2, prefix="73")
    box = _cashbox(client, context)

    closed = client.post(
        f"{API}/cashboxes/{box['id']}/close", headers=context["headers"]
    )
    assert closed.status_code == 200
    assert closed.json()["data"]["status"] == "closed"

    refused = client.post(
        f"{API}/cashboxes/{box['id']}/transactions",
        json={"type": "income", "category": "donation", "amount": "1000"},
        headers=context["headers"],
    )
    assert refused.status_code == 409
    assert refused.json()["error"]["code"] == "cashbox_closed"


def test_deux_caisses_coexistent_avec_des_soldes_distincts(
    client: TestClient,
) -> None:
    """§16 : caisse principale, caisse sociale, caisse événements."""
    context = build_organization(client, members=2, prefix="74")
    main = _cashbox(client, context, "Caisse principale")
    social = _cashbox(client, context, "Caisse sociale")

    client.post(
        f"{API}/cashboxes/{main['id']}/transactions",
        json={"type": "income", "category": "donation", "amount": "30000"},
        headers=context["headers"],
    )
    client.post(
        f"{API}/cashboxes/{social['id']}/transactions",
        json={"type": "income", "category": "social_aid", "amount": "5000"},
        headers=context["headers"],
    )

    boxes = {
        item["name"]: item
        for item in client.get(
            f"{API}/organizations/{context['organization']['id']}/cashboxes",
            headers=context["headers"],
        ).json()["data"]
    }
    assert boxes["Caisse principale"]["currentBalance"] == 30000
    assert boxes["Caisse sociale"]["currentBalance"] == 5000


def test_une_caisse_d_une_autre_organisation_est_introuvable(
    client: TestClient,
) -> None:
    first = build_organization(client, members=2, prefix="75")
    second = build_organization(client, members=2, prefix="76")
    box = _cashbox(client, first)

    response = client.get(f"{API}/cashboxes/{box['id']}", headers=second["headers"])

    assert response.status_code == 404


# --- Campagnes de cotisation --------------------------------------------------


def test_la_cotisation_ne_vise_que_les_membres_choisis(client: TestClient) -> None:
    """§22 QUATER : trois membres cochés sur quatre."""
    context = build_organization(client, members=4, prefix="77")
    chosen = [member["id"] for member in context["members"][:3]]

    campaign = _campaign(client, context, members=chosen)

    assert campaign["summary"]["membersCount"] == 3
    assert campaign["summary"]["expected"] == 30000
    assert campaign["summary"]["collected"] == 0
    assert campaign["summary"]["remaining"] == 30000


def test_le_paiement_partiel_puis_le_solde(client: TestClient) -> None:
    """§22 SEXIES : 20 000 puis 30 000 sur 50 000, deux lignes d'historique."""
    context = build_organization(client, members=2, prefix="78")
    campaign = _campaign(
        client, context, amount="50000", members=[context["members"][0]["id"]]
    )
    entry = client.get(
        f"{API}/contribution-campaigns/{campaign['id']}/entries",
        headers=context["headers"],
    ).json()["data"][0]

    first = client.post(
        f"{API}/contribution-entries/{entry['id']}/payments",
        json={"amount": "20000", "paymentMethod": "cash"},
        headers=context["headers"],
    )
    assert first.status_code == 201, first.text
    assert first.json()["data"]["entry"]["status"] == "partial"
    assert first.json()["data"]["entry"]["remainingAmount"] == 30000

    second = client.post(
        f"{API}/contribution-entries/{entry['id']}/payments",
        json={"amount": "30000", "paymentMethod": "wave"},
        headers=context["headers"],
    )
    assert second.status_code == 201, second.text
    assert second.json()["data"]["entry"]["status"] == "paid"
    assert second.json()["data"]["entry"]["remainingAmount"] == 0

    detail = client.get(
        f"{API}/contribution-entries/{entry['id']}", headers=context["headers"]
    ).json()["data"]
    assert len(detail["payments"]) == 2
    assert [item["amount"] for item in detail["payments"]] == [20000, 30000]


def test_un_paiement_confirme_alimente_la_caisse_sans_double_saisie(
    client: TestClient,
) -> None:
    """§22 SEPTIES : une saisie du trésorier, une seule écriture de caisse."""
    context = build_organization(client, members=2, prefix="79")
    box = _cashbox(client, context, "Caisse sociale")
    campaign = _campaign(
        client,
        context,
        amount="10000",
        members=[context["members"][0]["id"]],
        cashbox_id=box["id"],
    )
    entry = client.get(
        f"{API}/contribution-campaigns/{campaign['id']}/entries",
        headers=context["headers"],
    ).json()["data"][0]

    payment = client.post(
        f"{API}/contribution-entries/{entry['id']}/payments",
        json={"amount": "10000", "paymentMethod": "cash"},
        headers=context["headers"],
    ).json()["data"]["payment"]

    assert payment["cashTransactionId"] is not None

    journal = client.get(
        f"{API}/cashboxes/{box['id']}/transactions", headers=context["headers"]
    ).json()
    assert journal["meta"]["total"] == 1

    balance = client.get(
        f"{API}/cashboxes/{box['id']}", headers=context["headers"]
    ).json()["data"]
    assert balance["currentBalance"] == 10000


def test_annuler_un_reglement_contrepasse_l_ecriture_de_caisse(
    client: TestClient,
) -> None:
    context = build_organization(client, members=2, prefix="80")
    box = _cashbox(client, context)
    campaign = _campaign(
        client,
        context,
        amount="10000",
        members=[context["members"][0]["id"]],
        cashbox_id=box["id"],
    )
    entry = client.get(
        f"{API}/contribution-campaigns/{campaign['id']}/entries",
        headers=context["headers"],
    ).json()["data"][0]
    payment = client.post(
        f"{API}/contribution-entries/{entry['id']}/payments",
        json={"amount": "10000", "paymentMethod": "cash"},
        headers=context["headers"],
    ).json()["data"]["payment"]

    cancelled = client.post(
        f"{API}/contribution-payments/{payment['id']}/cancel",
        json={"reason": "Chèque sans provision"},
        headers=context["headers"],
    )

    assert cancelled.status_code == 200, cancelled.text
    assert cancelled.json()["data"]["entry"]["status"] == "pending"
    assert cancelled.json()["data"]["entry"]["paidAmount"] == 0

    balance = client.get(
        f"{API}/cashboxes/{box['id']}", headers=context["headers"]
    ).json()["data"]
    assert balance["currentBalance"] == 0

    journal = client.get(
        f"{API}/cashboxes/{box['id']}/transactions", headers=context["headers"]
    ).json()["data"]
    assert journal[0]["status"] == "reversed"


def test_le_trop_percu_est_refuse(client: TestClient) -> None:
    context = build_organization(client, members=2, prefix="81")
    campaign = _campaign(
        client, context, amount="10000", members=[context["members"][0]["id"]]
    )
    entry = client.get(
        f"{API}/contribution-campaigns/{campaign['id']}/entries",
        headers=context["headers"],
    ).json()["data"][0]

    response = client.post(
        f"{API}/contribution-entries/{entry['id']}/payments",
        json={"amount": "15000", "paymentMethod": "cash"},
        headers=context["headers"],
    )

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "amount_exceeds_remaining"


def test_une_cotisation_a_montant_libre_est_soldee_par_tout_versement(
    client: TestClient,
) -> None:
    """§22 D : participation volontaire, sans attendu."""
    context = build_organization(client, members=2, prefix="82")
    campaign = _campaign(
        client,
        context,
        amount="0",
        amount_mode="free",
        contribution_type="voluntary",
        members=[context["members"][0]["id"]],
    )
    assert campaign["summary"]["recoveryRate"] is None

    entry = client.get(
        f"{API}/contribution-campaigns/{campaign['id']}/entries",
        headers=context["headers"],
    ).json()["data"][0]
    response = client.post(
        f"{API}/contribution-entries/{entry['id']}/payments",
        json={"amount": "7500", "paymentMethod": "cash"},
        headers=context["headers"],
    )

    assert response.status_code == 201, response.text
    assert response.json()["data"]["entry"]["status"] == "paid"


def test_une_echeance_depassee_bascule_en_retard(client: TestClient) -> None:
    context = build_organization(client, members=3, prefix="83")
    past = (datetime.now(timezone.utc) - timedelta(days=5)).isoformat()
    _campaign(
        client,
        context,
        amount="10000",
        members=[member["id"] for member in context["members"][:2]],
        due_date=past,
    )

    unpaid = client.get(
        f"{API}/organizations/{context['organization']['id']}/unpaid",
        headers=context["headers"],
    )

    assert unpaid.status_code == 200, unpaid.text
    rows = unpaid.json()["data"]
    assert len(rows) == 2
    assert all(row["status"] == "late" for row in rows)
    assert all(row["daysLate"] >= 5 for row in rows)
    assert all(row["remainingAmount"] == 10000 for row in rows)


def test_l_exemption_sort_du_recouvrement_sans_fausser_le_taux(
    client: TestClient,
) -> None:
    """§24 : `EXEMPTED` n'est pas un impayé."""
    context = build_organization(client, members=3, prefix="84")
    campaign = _campaign(
        client,
        context,
        amount="10000",
        members=[member["id"] for member in context["members"][:2]],
    )
    entries = client.get(
        f"{API}/contribution-campaigns/{campaign['id']}/entries",
        headers=context["headers"],
    ).json()["data"]

    exempted = client.post(
        f"{API}/contribution-entries/{entries[1]['id']}/exempt",
        json={"reason": "Membre en difficulté"},
        headers=context["headers"],
    )
    assert exempted.status_code == 200, exempted.text

    client.post(
        f"{API}/contribution-entries/{entries[0]['id']}/payments",
        json={"amount": "10000", "paymentMethod": "cash"},
        headers=context["headers"],
    )

    summary = client.get(
        f"{API}/contribution-campaigns/{campaign['id']}",
        headers=context["headers"],
    ).json()["data"]["summary"]

    # Un seul membre reste attendu : le taux est de 100 %, pas de 50 %.
    assert summary["expected"] == 10000
    assert summary["collected"] == 10000
    assert summary["recoveryRate"] == 100.0
    assert summary["exemptedCount"] == 1


def test_le_tableau_de_bord_distingue_attendu_encaisse_et_solde(
    client: TestClient,
) -> None:
    """Principe §22 TERDECIES : 60 000 attendus ≠ 40 000 encaissés."""
    context = build_organization(client, members=7, prefix="85")
    box = _cashbox(client, context)
    campaign = _campaign(
        client,
        context,
        amount="10000",
        members=[member["id"] for member in context["members"][:6]],
        cashbox_id=box["id"],
    )
    entries = client.get(
        f"{API}/contribution-campaigns/{campaign['id']}/entries",
        headers=context["headers"],
    ).json()["data"]

    for entry in entries[:4]:
        client.post(
            f"{API}/contribution-entries/{entry['id']}/payments",
            json={"amount": "10000", "paymentMethod": "cash"},
            headers=context["headers"],
        )

    dashboard = client.get(
        f"{API}/organizations/{context['organization']['id']}/financial-dashboard",
        headers=context["headers"],
    )

    assert dashboard.status_code == 200, dashboard.text
    data = dashboard.json()["data"]
    assert data["expected"] == 60000
    assert data["collected"] == 40000
    assert data["remaining"] == 20000
    assert data["cashBalance"] == 40000
    assert data["recoveryRate"] == 66.67


# --- Permissions appliquées aux routes financières ---------------------------


def _member_session(client: TestClient, prefix: str) -> dict:
    """Un compte extérieur, sans aucun rôle dans l'organisation testée."""
    return auth_headers(register(client, f"+225 07 {prefix} 11 11 11"))


def test_un_simple_membre_ne_cree_pas_de_caisse(client: TestClient) -> None:
    """§36 : le refus vient du backend, pas d'un bouton masqué."""
    context = build_organization(client, members=3, prefix="86")
    organization_id = context["organization"]["id"]
    target = context["members"][1]["id"]

    roles = client.get(
        f"{API}/organizations/{organization_id}/roles", headers=context["headers"]
    ).json()["data"]
    member_role = next(item for item in roles if item["role"] == "member")

    # L'administrateur se rétrograde volontairement en membre pour éprouver le
    # refus sur un compte dont on possède les identifiants.
    client.patch(
        f"{API}/organizations/{organization_id}/members/{target}/role",
        json={"roleId": member_role["id"]},
        headers=context["headers"],
    )
    _ = target

    demoted = client.patch(
        f"{API}/organizations/{organization_id}/members/"
        f"{context['members'][0]['id']}/role",
        json={"roleId": member_role["id"]},
        headers=context["headers"],
    )
    assert demoted.status_code == 200, demoted.text

    refused = client.post(
        f"{API}/organizations/{organization_id}/cashboxes",
        json={"name": "Caisse interdite"},
        headers=context["headers"],
    )
    assert refused.status_code == 403
    assert refused.json()["error"]["details"]["requiredPermission"] == "cashbox.create"


def test_un_role_sur_mesure_lit_mais_ne_confirme_pas(client: TestClient) -> None:
    """§37 : « Assistant Trésorier » — lecture OK, confirmation refusée 403."""
    context = build_organization(client, members=3, prefix="87")
    organization_id = context["organization"]["id"]
    box = _cashbox(client, context)
    campaign = _campaign(
        client,
        context,
        amount="10000",
        members=[context["members"][1]["id"]],
        cashbox_id=box["id"],
    )
    entry = client.get(
        f"{API}/contribution-campaigns/{campaign['id']}/entries",
        headers=context["headers"],
    ).json()["data"][0]

    assistant = client.post(
        f"{API}/organizations/{organization_id}/roles",
        json={
            "name": "Assistant Trésorier",
            "permissions": ["cashbox.view", "payment.view", "contribution.view"],
        },
        headers=context["headers"],
    ).json()["data"]
    assert "payment.create" not in assistant["permissions"]

    client.patch(
        f"{API}/organizations/{organization_id}/members/"
        f"{context['members'][0]['id']}/role",
        json={"roleId": assistant["id"]},
        headers=context["headers"],
    )

    readable = client.get(f"{API}/cashboxes/{box['id']}", headers=context["headers"])
    assert readable.status_code == 200

    refused = client.post(
        f"{API}/contribution-entries/{entry['id']}/payments",
        json={"amount": "10000", "paymentMethod": "cash"},
        headers=context["headers"],
    )
    assert refused.status_code == 403
