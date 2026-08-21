"""Trésorerie, rapports, notifications, relances et justificatifs."""

from __future__ import annotations

import io

from fastapi.testclient import TestClient

from tests.conftest import (
    auth_headers,
    build_organization,
    create_tontine,
    cycles_of,
    pay_cycle,
    register,
)


def _drawn_tontine(client: TestClient) -> dict:
    context = build_organization(client, members=12)
    tontine = create_tontine(client, context)
    cycles = cycles_of(client, context, tontine["id"])
    pay_cycle(client, context, tontine["id"], cycles[0]["id"])
    draw = client.post(
        f"/api/v1/tontines/{tontine['id']}/draws",
        json={"cycleId": cycles[0]["id"]},
        headers=context["headers"],
    ).json()["data"]
    return {"context": context, "tontine": tontine, "cycles": cycles, "draw": draw}


# --- Trésorerie --------------------------------------------------------------


def test_treasury_aggregates_real_money(client: TestClient) -> None:
    setup = _drawn_tontine(client)
    context = setup["context"]
    organization_id = context["organization"]["id"]

    beneficiary = client.get(
        f"/api/v1/cycles/{setup['cycles'][0]['id']}/beneficiary",
        headers=context["headers"],
    ).json()["data"]
    client.post(
        "/api/v1/payouts",
        json={
            "beneficiaryId": beneficiary["id"],
            "amount": 600000,
            "method": "wave",
            "status": "paid",
        },
        headers=context["headers"],
    )

    treasury = client.get(
        f"/api/v1/organizations/{organization_id}/treasury",
        headers=context["headers"],
    ).json()["data"]

    # 12 cotisations encaissées, une cagnotte versée : le solde retombe à zéro.
    assert treasury["inflows"] == 600000
    assert treasury["outflows"] == 600000
    assert treasury["balance"] == 0
    assert len(treasury["transactions"]) == 13
    assert {t["category"] for t in treasury["transactions"]} == {
        "contribution",
        "payout",
    }


def test_manual_transaction_moves_the_balance(client: TestClient) -> None:
    context = build_organization(client, members=12)
    organization_id = context["organization"]["id"]

    response = client.post(
        f"/api/v1/organizations/{organization_id}/transactions",
        json={
            "type": "income",
            "category": "donation",
            "amount": 25000,
            "description": "Don d'un membre bienfaiteur",
        },
        headers=context["headers"],
    )
    assert response.status_code == 201
    assert response.json()["data"]["category"] == "donation"

    client.post(
        f"/api/v1/organizations/{organization_id}/transactions",
        json={"type": "expense", "category": "fee", "amount": 5000},
        headers=context["headers"],
    )

    treasury = client.get(
        f"/api/v1/organizations/{organization_id}/treasury",
        headers=context["headers"],
    ).json()["data"]
    assert treasury["inflows"] == 25000
    assert treasury["outflows"] == 5000
    assert treasury["balance"] == 20000


def test_treasury_requires_the_permission(client: TestClient) -> None:
    context = build_organization(client, members=12)
    organization_id = context["organization"]["id"]

    simple = register(client, "+225 07 97 00 00 01", firstName="Simple")
    client.post(
        f"/api/v1/organizations/{organization_id}/members",
        json={
            "firstName": "Simple",
            "lastName": "Membre",
            "phone": "+225 07 97 00 00 01",
            "role": "member",
        },
        headers=context["headers"],
    )

    response = client.get(
        f"/api/v1/organizations/{organization_id}/treasury",
        headers=auth_headers(simple),
    )
    assert response.status_code == 403


# --- Rapports ----------------------------------------------------------------


def test_report_lines_per_tontine(client: TestClient) -> None:
    setup = _drawn_tontine(client)
    context = setup["context"]

    report = client.get(
        f"/api/v1/organizations/{context['organization']['id']}/reports",
        headers=context["headers"],
    ).json()["data"]

    assert report["membersCount"] == 12
    assert report["activeTontines"] == 1
    # 12 cycles × 600 000 attendus, un seul cycle encaissé.
    assert report["totalExpected"] == 7200000
    assert report["totalCollected"] == 600000
    assert report["totalDistributed"] == 0

    line = report["lines"][0]
    assert line["tontineName"] == "Tontine Solidarité"
    assert line["participants"] == 12
    assert line["collected"] == 600000


# --- Clôture automatique -----------------------------------------------------


def test_tontine_completes_itself_when_every_cycle_is_paid(
    client: TestClient,
) -> None:
    """Le dernier versement termine la tontine, sans intervention manuelle."""
    context = build_organization(client, members=12)
    context["members"] = context["members"][:2]
    tontine = create_tontine(client, context, amount=10000)
    cycles = cycles_of(client, context, tontine["id"])
    assert len(cycles) == 2

    for index, cycle in enumerate(cycles):
        pay_cycle(client, context, tontine["id"], cycle["id"])
        client.post(
            f"/api/v1/tontines/{tontine['id']}/draws",
            json={"cycleId": cycle["id"]},
            headers=context["headers"],
        )
        beneficiary = client.get(
            f"/api/v1/cycles/{cycle['id']}/beneficiary", headers=context["headers"]
        ).json()["data"]
        client.post(
            "/api/v1/payouts",
            json={
                "beneficiaryId": beneficiary["id"],
                "amount": beneficiary["amount"],
                "method": "cash",
                "status": "paid",
            },
            headers=context["headers"],
        )

        current = client.get(
            f"/api/v1/tontines/{tontine['id']}", headers=context["headers"]
        ).json()["data"]
        expected = "completed" if index == len(cycles) - 1 else "active"
        assert current["status"] == expected

    logs = client.get(
        f"/api/v1/organizations/{context['organization']['id']}/audit-logs",
        params={"limit": 200},
        headers=context["headers"],
    ).json()["data"]
    automatic = [
        entry
        for entry in logs
        if entry["action"] == "tontine.status_changed"
        and entry["metadata"].get("automatic")
    ]
    assert len(automatic) == 1


# --- Notifications -----------------------------------------------------------


def test_events_create_real_notifications(client: TestClient) -> None:
    setup = _drawn_tontine(client)
    context = setup["context"]

    notifications = client.get(
        "/api/v1/notifications", headers=context["headers"]
    ).json()["data"]
    types = {item["type"] for item in notifications}
    assert "payment_confirmed" in types
    assert "draw_result" in types

    count = client.get(
        "/api/v1/notifications/unread-count", headers=context["headers"]
    ).json()["data"]["count"]
    assert count == len(notifications)

    client.post("/api/v1/notifications/read-all", headers=context["headers"])
    after = client.get(
        "/api/v1/notifications/unread-count", headers=context["headers"]
    ).json()["data"]["count"]
    assert after == 0


def test_notifications_are_never_shared_between_users(client: TestClient) -> None:
    setup = _drawn_tontine(client)
    stranger = register(client, "+225 07 98 00 00 01", firstName="Étranger")

    mine = client.get(
        "/api/v1/notifications", headers=setup["context"]["headers"]
    ).json()["data"]
    theirs = client.get(
        "/api/v1/notifications", headers=auth_headers(stranger)
    ).json()["data"]

    assert mine
    assert theirs == []


# --- Relances ----------------------------------------------------------------


def test_reminder_targets_include_former_beneficiaries(client: TestClient) -> None:
    """Un ancien bénéficiaire doit être relancé : il cotise encore."""
    context = build_organization(client, members=12)
    # Tontine démarrée plusieurs mois plus tôt : des échéances sont dépassées.
    tontine = create_tontine(client, context, start_date="2026-05-01")
    cycles = cycles_of(client, context, tontine["id"])

    pay_cycle(client, context, tontine["id"], cycles[0]["id"])
    draw = client.post(
        f"/api/v1/tontines/{tontine['id']}/draws",
        json={"cycleId": cycles[0]["id"]},
        headers=context["headers"],
    ).json()["data"]

    targets = client.get(
        f"/api/v1/organizations/{context['organization']['id']}/reminder-targets",
        headers=context["headers"],
    ).json()["data"]

    assert targets
    assert all(target["amountDue"] > 0 for target in targets)
    assert {target["level"] for target in targets} <= {
        "upcoming",
        "due_today",
        "late",
        "escalated",
    }

    named = [t for t in targets if t["memberName"] == draw["winnerName"]]
    assert named, "l'ancien bénéficiaire doit rester une cible de relance"
    assert named[0]["hasReceivedPot"] is True
    assert named[0]["daysLate"] > 0

    # Le cycle déjà réglé ne génère aucune relance.
    assert all(target["cycleId"] != cycles[0]["id"] for target in targets)


def test_reminder_targets_require_the_permission(client: TestClient) -> None:
    context = build_organization(client, members=12)
    organization_id = context["organization"]["id"]
    outsider = register(client, "+225 07 99 00 00 01", firstName="Dehors")

    response = client.get(
        f"/api/v1/organizations/{organization_id}/reminder-targets",
        headers=auth_headers(outsider),
    )
    # Non membre : l'organisation n'existe pas de son point de vue.
    assert response.status_code == 404


# --- Justificatifs -----------------------------------------------------------


def test_attachment_upload_returns_a_usable_url(client: TestClient) -> None:
    context = build_organization(client, members=12)
    png = (
        b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
        b"\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89"
    )

    response = client.post(
        "/api/v1/attachments",
        files={"file": ("recu.png", io.BytesIO(png), "image/png")},
        headers=context["headers"],
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["url"].startswith("/files/")
    assert data["mimeType"] == "image/png"
    assert data["sizeBytes"] == len(png)


def test_attachment_rejects_unsupported_types(client: TestClient) -> None:
    context = build_organization(client, members=12)

    response = client.post(
        "/api/v1/attachments",
        files={"file": ("script.exe", io.BytesIO(b"MZ"), "application/x-msdownload")},
        headers=context["headers"],
    )
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "unsupported_file_type"


def test_attachment_requires_authentication(client: TestClient) -> None:
    response = client.post(
        "/api/v1/attachments",
        files={"file": ("recu.png", io.BytesIO(b"x"), "image/png")},
    )
    assert response.status_code == 401
