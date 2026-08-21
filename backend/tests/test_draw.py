"""Tirage, bénéficiaire et versement.

Ces tests couvrent les scénarios métier critiques du cahier des charges
(A à H). Le plus important : **un ancien bénéficiaire sort de la roue mais
reste dans la tontine et continue de cotiser.**
"""

from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient

from tests.conftest import (
    auth_headers,
    build_organization,
    create_tontine,
    cycles_of,
    participants_of,
    pay_cycle,
    register,
)


@pytest.fixture
def ready_tontine(client: TestClient) -> dict:
    """Tontine de 12 membres dont le premier cycle est intégralement réglé."""
    context = build_organization(client, members=12)
    tontine = create_tontine(client, context)
    cycles = cycles_of(client, context, tontine["id"])
    pay_cycle(client, context, tontine["id"], cycles[0]["id"])
    return {"context": context, "tontine": tontine, "cycles": cycles}


def _draw(client: TestClient, setup: dict, cycle_id: str, **body) -> dict:
    return client.post(
        f"/api/v1/tontines/{setup['tontine']['id']}/draws",
        json={"cycleId": cycle_id, **body},
        headers=setup["context"]["headers"],
    )


# --- Scénario A --------------------------------------------------------------


def test_scenario_a_winner_leaves_the_wheel_but_stays_active(
    client: TestClient, ready_tontine: dict
) -> None:
    context = ready_tontine["context"]
    tontine = ready_tontine["tontine"]
    cycle = ready_tontine["cycles"][0]

    response = _draw(client, ready_tontine, cycle["id"])
    assert response.status_code == 201, response.text
    session = response.json()["data"]

    assert session["status"] == "completed"
    assert session["winnerParticipantId"]
    assert len(session["participants"]) == 12
    assert session["randomSourceLabel"] == "server_secrets_choice"
    assert session["proofReference"].startswith("KDJ-")

    winner = next(
        p
        for p in participants_of(client, context, tontine["id"])
        if p["id"] == session["winnerParticipantId"]
    )
    assert winner["hasReceivedPot"] is True
    assert winner["isEligibleForDraw"] is False
    # La règle centrale de Kadjane : il reste dans la tontine.
    assert winner["isActive"] is True


# --- Scénario B --------------------------------------------------------------


def test_scenario_b_winner_still_owes_the_next_cycle(
    client: TestClient, ready_tontine: dict
) -> None:
    context = ready_tontine["context"]
    tontine = ready_tontine["tontine"]
    session = _draw(client, ready_tontine, ready_tontine["cycles"][0]["id"]).json()[
        "data"
    ]
    winner_name = session["winnerName"]

    september = ready_tontine["cycles"][1]
    slots = client.get(
        f"/api/v1/cycles/{september['id']}/contribution-slots",
        headers=context["headers"],
    ).json()["data"]

    assert len(slots) == 12
    mine = [slot for slot in slots if slot["memberName"] == winner_name]
    assert len(mine) == 1
    assert mine[0]["expectedAmount"] == 50000
    del tontine


# --- Scénario C --------------------------------------------------------------


def test_scenario_c_winner_is_absent_from_the_next_wheel(
    client: TestClient, ready_tontine: dict
) -> None:
    context = ready_tontine["context"]
    tontine = ready_tontine["tontine"]
    session = _draw(client, ready_tontine, ready_tontine["cycles"][0]["id"]).json()[
        "data"
    ]

    september = ready_tontine["cycles"][1]
    eligibility = client.get(
        f"/api/v1/tontines/{tontine['id']}/cycles/{september['id']}/draw-eligibility",
        headers=context["headers"],
    ).json()["data"]

    assert eligibility["eligible_count"] == 11
    assert eligibility["participants_count"] == 12
    identifiers = {p["participantId"] for p in eligibility["eligible_participants"]}
    assert session["winnerParticipantId"] not in identifiers


# --- Scénario D --------------------------------------------------------------


def test_scenario_d_draw_refused_while_a_contribution_is_missing(
    client: TestClient,
) -> None:
    context = build_organization(client, members=12)
    tontine = create_tontine(client, context, require_all=True)
    cycles = cycles_of(client, context, tontine["id"])
    pay_cycle(client, context, tontine["id"], cycles[0]["id"], skip=1)

    eligibility = client.get(
        f"/api/v1/tontines/{tontine['id']}/cycles/{cycles[0]['id']}/draw-eligibility",
        headers=context["headers"],
    ).json()["data"]
    assert eligibility["allowed"] is False
    assert eligibility["reason"] == "missingContributions"
    assert eligibility["missingContributions"] == 1
    assert eligibility["remaining_amount"] == 50000

    response = client.post(
        f"/api/v1/tontines/{tontine['id']}/draws",
        json={"cycleId": cycles[0]["id"]},
        headers=context["headers"],
    )
    assert response.status_code == 409
    error = response.json()["error"]
    assert error["code"] == "missingContributions"
    assert error["details"]["remaining_count"] == 1
    assert error["details"]["remaining_amount"] == 50000


def test_draw_allowed_when_the_rule_is_disabled(client: TestClient) -> None:
    context = build_organization(client, members=12)
    tontine = create_tontine(client, context, require_all=False)
    cycles = cycles_of(client, context, tontine["id"])
    pay_cycle(client, context, tontine["id"], cycles[0]["id"], skip=1)

    response = client.post(
        f"/api/v1/tontines/{tontine['id']}/draws",
        json={"cycleId": cycles[0]["id"]},
        headers=context["headers"],
    )
    assert response.status_code == 201


# --- Scénario E --------------------------------------------------------------


def test_scenario_e_override_requires_a_reason_and_is_audited(
    client: TestClient,
) -> None:
    context = build_organization(client, members=12)
    tontine = create_tontine(client, context, require_all=True, allow_override=True)
    cycles = cycles_of(client, context, tontine["id"])
    pay_cycle(client, context, tontine["id"], cycles[0]["id"], skip=1)

    without_reason = client.post(
        f"/api/v1/tontines/{tontine['id']}/draws",
        json={"cycleId": cycles[0]["id"], "override": True},
        headers=context["headers"],
    )
    assert without_reason.status_code == 409
    assert without_reason.json()["error"]["code"] == "override_reason_required"

    forced = client.post(
        f"/api/v1/tontines/{tontine['id']}/draws",
        json={
            "cycleId": cycles[0]["id"],
            "override": True,
            "overrideReason": "Décision exceptionnelle validée par le bureau.",
        },
        headers=context["headers"],
    )
    assert forced.status_code == 201
    session = forced.json()["data"]
    assert session["overrideUsed"] is True
    assert "bureau" in session["overrideReason"]

    logs = client.get(
        f"/api/v1/organizations/{context['organization']['id']}/audit-logs",
        headers=context["headers"],
    ).json()["data"]
    overrides = [entry for entry in logs if entry["action"] == "draw.overridden"]
    assert len(overrides) == 1
    assert overrides[0]["metadata"]["missingContributions"] == 1


def test_override_refused_when_disabled_on_the_tontine(client: TestClient) -> None:
    context = build_organization(client, members=12)
    tontine = create_tontine(client, context, require_all=True, allow_override=False)
    cycles = cycles_of(client, context, tontine["id"])
    pay_cycle(client, context, tontine["id"], cycles[0]["id"], skip=1)

    response = client.post(
        f"/api/v1/tontines/{tontine['id']}/draws",
        json={
            "cycleId": cycles[0]["id"],
            "override": True,
            "overrideReason": "Je veux passer outre.",
        },
        headers=context["headers"],
    )
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "override_disabled"


# --- Scénario F --------------------------------------------------------------


def test_scenario_f_a_cycle_can_only_have_one_winner(
    client: TestClient, ready_tontine: dict
) -> None:
    """Rejeu réseau ou double clic : le second tirage est refusé."""
    cycle_id = ready_tontine["cycles"][0]["id"]

    first = _draw(client, ready_tontine, cycle_id)
    assert first.status_code == 201
    winner = first.json()["data"]["winnerParticipantId"]

    second = _draw(client, ready_tontine, cycle_id)
    assert second.status_code == 409
    assert second.json()["error"]["code"] == "alreadyDrawn"

    # Un seul bénéficiaire, celui du premier tirage.
    beneficiary = client.get(
        f"/api/v1/cycles/{cycle_id}/beneficiary",
        headers=ready_tontine["context"]["headers"],
    ).json()["data"]
    assert beneficiary["participantId"] == winner


def test_the_database_itself_refuses_a_second_completed_draw(
    client: TestClient, db_session, ready_tontine: dict
) -> None:
    """Filet de sécurité : la contrainte tient même si le code est contourné."""
    from sqlalchemy.exc import IntegrityError

    from app.models.draw import DrawSession

    cycle_id = ready_tontine["cycles"][0]["id"]
    session = _draw(client, ready_tontine, cycle_id).json()["data"]

    duplicate = DrawSession(
        organization_id=uuid.UUID(ready_tontine["context"]["organization"]["id"]),
        tontine_id=uuid.UUID(ready_tontine["tontine"]["id"]),
        cycle_id=uuid.UUID(cycle_id),
        status="completed",
        period_label="Doublon",
        proof_reference="KDJ-DOUBLON",
    )
    db_session.add(duplicate)
    with pytest.raises(IntegrityError):
        db_session.flush()
    db_session.rollback()
    assert session["status"] == "completed"


# --- Scénario G --------------------------------------------------------------


def test_scenario_g_another_organization_cannot_touch_the_tontine(
    client: TestClient, ready_tontine: dict
) -> None:
    intruder = auth_headers(register(client, "+225 07 95 00 00 99", firstName="Intrus"))
    tontine_id = ready_tontine["tontine"]["id"]
    cycle_id = ready_tontine["cycles"][0]["id"]

    assert client.get(f"/api/v1/tontines/{tontine_id}", headers=intruder).status_code == 404
    assert (
        client.get(f"/api/v1/tontines/{tontine_id}/cycles", headers=intruder).status_code
        == 404
    )
    assert (
        client.get(
            f"/api/v1/cycles/{cycle_id}/contribution-slots", headers=intruder
        ).status_code
        == 404
    )
    assert (
        client.post(
            f"/api/v1/tontines/{tontine_id}/draws",
            json={"cycleId": cycle_id},
            headers=intruder,
        ).status_code
        == 404
    )


def test_a_simple_member_cannot_launch_the_draw(
    client: TestClient, ready_tontine: dict
) -> None:
    context = ready_tontine["context"]
    organization_id = context["organization"]["id"]

    member_session = register(client, "+225 07 96 00 00 01", firstName="Simple")
    client.post(
        f"/api/v1/organizations/{organization_id}/members",
        json={
            "firstName": "Simple",
            "lastName": "Membre",
            "phone": "+225 07 96 00 00 01",
            "role": "member",
        },
        headers=context["headers"],
    )

    response = client.post(
        f"/api/v1/tontines/{ready_tontine['tontine']['id']}/draws",
        json={"cycleId": ready_tontine["cycles"][0]["id"]},
        headers=auth_headers(member_session),
    )
    assert response.status_code == 403
    assert response.json()["error"]["code"] == "permission_denied"


# --- Bénéficiaire et versement ----------------------------------------------


def test_payout_confirmation_closes_the_cycle(
    client: TestClient, ready_tontine: dict
) -> None:
    context = ready_tontine["context"]
    cycle_id = ready_tontine["cycles"][0]["id"]
    _draw(client, ready_tontine, cycle_id)

    beneficiary = client.get(
        f"/api/v1/cycles/{cycle_id}/beneficiary", headers=context["headers"]
    ).json()["data"]
    assert beneficiary["status"] == "designated"
    assert beneficiary["amount"] == 600000

    payout = client.post(
        "/api/v1/payouts",
        json={
            "beneficiaryId": beneficiary["id"],
            "amount": 600000,
            "method": "wave",
            "reference": "WV-100",
            "status": "pending",
        },
        headers=context["headers"],
    ).json()["data"]
    assert payout["status"] == "pending"

    confirmed = client.post(
        f"/api/v1/payouts/{payout['id']}/confirm", headers=context["headers"]
    ).json()["data"]
    assert confirmed["status"] == "paid"

    cycle = client.get(
        f"/api/v1/cycles/{cycle_id}", headers=context["headers"]
    ).json()["data"]
    assert cycle["status"] == "paid_out"
    assert cycle["payoutId"] == confirmed["id"]

    updated = client.get(
        f"/api/v1/cycles/{cycle_id}/beneficiary", headers=context["headers"]
    ).json()["data"]
    assert updated["status"] == "paid"


def test_history_lists_periods_beneficiaries_and_payments(
    client: TestClient, ready_tontine: dict
) -> None:
    context = ready_tontine["context"]
    tontine_id = ready_tontine["tontine"]["id"]
    _draw(client, ready_tontine, ready_tontine["cycles"][0]["id"])

    beneficiaries = client.get(
        f"/api/v1/tontines/{tontine_id}/beneficiaries", headers=context["headers"]
    ).json()["data"]
    assert len(beneficiaries) == 1
    assert beneficiaries[0]["source"] == "periodic_draw"

    draws = client.get(
        f"/api/v1/tontines/{tontine_id}/draws", headers=context["headers"]
    ).json()["data"]
    assert len(draws) == 1
    assert draws[0]["periodLabel"] == "Août 2026"


def test_invalidating_a_draw_puts_the_winner_back_in_the_wheel(
    client: TestClient, ready_tontine: dict
) -> None:
    """Rien n'est supprimé : la session passe à `invalidated`."""
    context = ready_tontine["context"]
    cycle_id = ready_tontine["cycles"][0]["id"]
    session = _draw(client, ready_tontine, cycle_id).json()["data"]

    invalidated = client.post(
        f"/api/v1/draws/{session['id']}/invalidate",
        json={"reason": "Erreur de saisie sur une cotisation."},
        headers=context["headers"],
    )
    assert invalidated.status_code == 200
    assert invalidated.json()["data"]["status"] == "invalidated"

    winner = next(
        p
        for p in participants_of(client, context, ready_tontine["tontine"]["id"])
        if p["id"] == session["winnerParticipantId"]
    )
    assert winner["isEligibleForDraw"] is True
    assert winner["hasReceivedPot"] is False

    # Le cycle repart en collecte : un nouveau tirage est possible.
    again = _draw(client, ready_tontine, cycle_id)
    assert again.status_code == 201


def test_audit_trail_records_the_financial_operations(
    client: TestClient, ready_tontine: dict
) -> None:
    context = ready_tontine["context"]
    cycle_id = ready_tontine["cycles"][0]["id"]
    _draw(client, ready_tontine, cycle_id)

    logs = client.get(
        f"/api/v1/organizations/{context['organization']['id']}/audit-logs",
        params={"limit": 200},
        headers=context["headers"],
    ).json()["data"]
    actions = {entry["action"] for entry in logs}

    assert {
        "tontine.created",
        "tontine.status_changed",
        "contribution.recorded",
        "contribution.confirmed",
        "draw.completed",
        "beneficiary.designated",
    } <= actions


def test_dashboard_reflects_the_real_state_after_the_draw(
    client: TestClient, ready_tontine: dict
) -> None:
    """Le tableau de bord n'affiche que des valeurs venues de la base."""
    context = ready_tontine["context"]
    organization_id = context["organization"]["id"]
    _draw(client, ready_tontine, ready_tontine["cycles"][0]["id"])

    dashboard = client.get(
        f"/api/v1/organizations/{organization_id}/dashboard",
        headers=context["headers"],
    ).json()["data"]

    assert dashboard["membersCount"] == 12
    assert dashboard["activeTontines"] == 1
    assert dashboard["collectedThisPeriod"] == 600000
    assert dashboard["collection_rate"] == 1.0
    assert dashboard["currentBeneficiary"]["amount"] == 600000
    assert dashboard["currentBeneficiary"]["isPaidOut"] is False

    # Le cycle courant est tiré : on annonce le suivant, sans le gagnant.
    assert dashboard["nextDraw"]["eligibleCount"] == 11
    assert dashboard["nextDraw"]["isUnlocked"] is False
