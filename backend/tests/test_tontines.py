"""Tontines, cycles, cotisations et paiements."""

from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import (
    build_organization,
    create_tontine,
    cycles_of,
    pay_cycle,
    participants_of,
)


def test_creation_generates_one_cycle_per_participant(client: TestClient) -> None:
    context = build_organization(client, members=12)
    tontine = create_tontine(client, context)

    assert tontine["status"] == "active"
    assert tontine["allocationMode"] == "monthly_draw"

    cycles = cycles_of(client, context, tontine["id"])
    assert len(cycles) == 12
    assert [c["periodLabel"] for c in cycles[:3]] == [
        "Août 2026",
        "Septembre 2026",
        "Octobre 2026",
    ]
    assert cycles[0]["index"] == 1
    assert cycles[0]["dueDate"].startswith("2026-08-05")


def test_pot_is_computed_never_hardcoded(client: TestClient) -> None:
    context = build_organization(client, members=12)
    tontine = create_tontine(client, context, amount=50000)
    cycles = cycles_of(client, context, tontine["id"])

    # 12 participants × 50 000 = 600 000
    assert cycles[0]["expectedAmount"] == 600000

    smaller = build_organization(client, members=12, prefix="91")
    smaller["members"] = smaller["members"][:5]
    other = create_tontine(client, smaller, amount=20000)
    assert cycles_of(client, smaller, other["id"])[0]["expectedAmount"] == 100000


def test_every_participant_owes_every_cycle(client: TestClient) -> None:
    context = build_organization(client, members=12)
    tontine = create_tontine(client, context)
    cycles = cycles_of(client, context, tontine["id"])

    for cycle in (cycles[0], cycles[5], cycles[-1]):
        slots = client.get(
            f"/api/v1/cycles/{cycle['id']}/contribution-slots",
            headers=context["headers"],
        ).json()["data"]
        assert len(slots) == 12
        assert all(slot["expectedAmount"] == 50000 for slot in slots)


def test_scenario_h_only_confirmed_payments_count(client: TestClient) -> None:
    """Scénario H : un paiement `pending` ne compte pas ; confirmé, il compte."""
    context = build_organization(client, members=12)
    tontine = create_tontine(client, context)
    cycle = cycles_of(client, context, tontine["id"])[0]
    slots = client.get(
        f"/api/v1/cycles/{cycle['id']}/contribution-slots", headers=context["headers"]
    ).json()["data"]

    pending = client.post(
        f"/api/v1/tontines/{tontine['id']}/contributions",
        json={
            "cycleId": cycle["id"],
            "memberId": slots[0]["memberId"],
            "amount": 50000,
            "method": "wave",
            "status": "pending",
        },
        headers=context["headers"],
    ).json()["data"]

    after_pending = client.get(
        f"/api/v1/cycles/{cycle['id']}", headers=context["headers"]
    ).json()["data"]
    assert after_pending["collectedAmount"] == 0

    client.post(
        f"/api/v1/contributions/{pending['id']}/confirm", headers=context["headers"]
    )
    after_confirm = client.get(
        f"/api/v1/cycles/{cycle['id']}", headers=context["headers"]
    ).json()["data"]
    assert after_confirm["collectedAmount"] == 50000


def test_cancelled_payment_stops_counting_but_stays_in_history(
    client: TestClient,
) -> None:
    context = build_organization(client, members=12)
    tontine = create_tontine(client, context)
    cycle = cycles_of(client, context, tontine["id"])[0]
    slots = client.get(
        f"/api/v1/cycles/{cycle['id']}/contribution-slots", headers=context["headers"]
    ).json()["data"]

    payment = client.post(
        f"/api/v1/tontines/{tontine['id']}/contributions",
        json={
            "cycleId": cycle["id"],
            "memberId": slots[0]["memberId"],
            "amount": 50000,
            "method": "cash",
        },
        headers=context["headers"],
    ).json()["data"]

    client.post(
        f"/api/v1/contributions/{payment['id']}/cancel",
        json={"reason": "Chèque sans provision"},
        headers=context["headers"],
    )

    cycle_after = client.get(
        f"/api/v1/cycles/{cycle['id']}", headers=context["headers"]
    ).json()["data"]
    assert cycle_after["collectedAmount"] == 0

    history = client.get(
        f"/api/v1/cycles/{cycle['id']}/contributions", headers=context["headers"]
    ).json()["data"]
    assert [item["status"] for item in history] == ["cancelled"]


def test_cycle_becomes_ready_when_everything_is_paid(client: TestClient) -> None:
    context = build_organization(client, members=12)
    tontine = create_tontine(client, context)
    cycle = cycles_of(client, context, tontine["id"])[0]

    pay_cycle(client, context, tontine["id"], cycle["id"], skip=1)
    partial = client.get(
        f"/api/v1/cycles/{cycle['id']}", headers=context["headers"]
    ).json()["data"]
    assert partial["collectedAmount"] == 550000
    assert partial["status"] == "collecting"

    pay_cycle(client, context, tontine["id"], cycle["id"])
    complete = client.get(
        f"/api/v1/cycles/{cycle['id']}", headers=context["headers"]
    ).json()["data"]
    assert complete["collectedAmount"] == 600000
    assert complete["status"] == "ready_for_draw"


def test_contribution_lines_expose_expected_paid_and_remaining(
    client: TestClient,
) -> None:
    context = build_organization(client, members=12)
    tontine = create_tontine(client, context)
    cycle = cycles_of(client, context, tontine["id"])[0]
    pay_cycle(client, context, tontine["id"], cycle["id"], skip=2)

    response = client.get(
        f"/api/v1/tontines/{tontine['id']}/cycles/{cycle['id']}/contributions",
        headers=context["headers"],
    )
    assert response.status_code == 200
    body = response.json()
    assert body["meta"]["expected"] == 600000
    assert body["meta"]["collected"] == 500000
    assert body["meta"]["remaining"] == 100000
    assert body["meta"]["paid_count"] == 10

    unpaid = [line for line in body["data"] if line["paidAmount"] == 0]
    assert len(unpaid) == 2
    assert unpaid[0]["remainingAmount"] == 50000


def test_summary_reports_real_aggregates(client: TestClient) -> None:
    context = build_organization(client, members=12)
    tontine = create_tontine(client, context)
    cycle = cycles_of(client, context, tontine["id"])[0]
    pay_cycle(client, context, tontine["id"], cycle["id"], skip=1)

    summary = client.get(
        f"/api/v1/tontines/{tontine['id']}/summary", headers=context["headers"]
    ).json()["data"]
    assert summary["participantCount"] == 12
    assert summary["totalCycles"] == 12
    assert summary["collectedCurrentCycle"] == 550000
    assert summary["expectedCurrentCycle"] == 600000
    assert summary["currentCycle"]["periodLabel"] == "Août 2026"


def test_locked_settings_after_activation(client: TestClient) -> None:
    context = build_organization(client, members=12)
    tontine = create_tontine(client, context)

    response = client.patch(
        f"/api/v1/tontines/{tontine['id']}",
        json={"contributionAmount": 90000},
        headers=context["headers"],
    )
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "tontine_locked"

    renamed = client.patch(
        f"/api/v1/tontines/{tontine['id']}",
        json={"description": "Tontine principale 2026"},
        headers=context["headers"],
    )
    assert renamed.status_code == 200
    assert renamed.json()["data"]["description"] == "Tontine principale 2026"


def test_participants_from_another_organization_are_refused(
    client: TestClient,
) -> None:
    first = build_organization(client, members=12, prefix="92")
    second = build_organization(client, members=12, prefix="93")

    response = client.post(
        f"/api/v1/organizations/{first['organization']['id']}/tontines",
        json={
            "name": "Tontine mélangée",
            "contributionAmount": 10000,
            "startDate": "2026-08-01",
            "memberIds": [
                first["members"][0]["id"],
                second["members"][1]["id"],
            ],
        },
        headers=first["headers"],
    )
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "unknown_participant"


def test_full_order_mode_assigns_every_position(client: TestClient) -> None:
    context = build_organization(client, members=12)
    tontine = create_tontine(client, context, mode="full_order_draw")

    positions = sorted(
        p["orderPosition"] for p in participants_of(client, context, tontine["id"])
    )
    assert positions == list(range(1, 13))

    # L'ordre est figé : il ne se retire pas en silence.
    again = client.post(
        f"/api/v1/tontines/{tontine['id']}/draws/order", headers=context["headers"]
    )
    assert again.status_code == 409
    assert again.json()["error"]["code"] == "orderAlreadyDefined"


def test_manual_order_requires_every_participant(client: TestClient) -> None:
    context = build_organization(client, members=12)
    tontine = create_tontine(client, context)
    participants = participants_of(client, context, tontine["id"])

    incomplete = client.put(
        f"/api/v1/tontines/{tontine['id']}/participants/order",
        json={"participantIds": [p["id"] for p in participants[:5]]},
        headers=context["headers"],
    )
    assert incomplete.status_code == 422
    assert incomplete.json()["error"]["code"] == "incomplete_order"

    duplicated = client.put(
        f"/api/v1/tontines/{tontine['id']}/participants/order",
        json={"participantIds": [participants[0]["id"]] * 12},
        headers=context["headers"],
    )
    assert duplicated.status_code == 422
    assert duplicated.json()["error"]["code"] == "duplicate_order_entry"

    ordered = client.put(
        f"/api/v1/tontines/{tontine['id']}/participants/order",
        json={"participantIds": [p["id"] for p in reversed(participants)]},
        headers=context["headers"],
    )
    assert ordered.status_code == 200
    assert ordered.json()["data"][0]["displayName"] == participants[-1]["displayName"]
