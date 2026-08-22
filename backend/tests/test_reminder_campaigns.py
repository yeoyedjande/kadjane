"""Campagnes de relance.

Le trésorier réclame les cotisations. Trois effets attendus, dans cet ordre :
la relance est tracée, la notification apparaît dans l'application, puis le
push part. Le dernier ne doit jamais remettre en cause les deux premiers — un
téléphone hors ligne n'est pas une erreur.
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import auth_headers, build_organization, create_tontine, register


def context(client: TestClient) -> dict:
    ctx = build_organization(client, members=3, prefix="66")
    create_tontine(client, ctx)
    return ctx


def targets(client: TestClient, ctx: dict) -> list[dict]:
    response = client.get(
        f"/api/v1/organizations/{ctx['organization']['id']}/reminder-targets",
        headers=ctx["headers"],
    )
    assert response.status_code == 200, response.text
    return response.json()["data"]


def send(client: TestClient, ctx: dict, members: list[str], **overrides) -> dict:
    payload = {
        "actorMemberId": ctx["members"][0]["id"],
        "messages": {member: "Merci de régler votre cotisation." for member in members},
        "channels": ["in_app"],
    }
    payload.update(overrides)
    return client.post(
        "/api/v1/reminder-campaigns", json=payload, headers=ctx["headers"]
    )


def test_une_campagne_est_tracee(client: TestClient) -> None:
    ctx = context(client)
    people = targets(client, ctx)
    assert people, "le seed doit produire des cibles"

    response = send(client, ctx, [people[0]["memberId"]])

    assert response.status_code == 201, response.text
    body = response.json()["data"]
    assert body["campaign"]["targetCount"] == 1
    assert body["campaign"]["sentCount"] == 1
    assert len(body["reminders"]) == 1
    assert body["reminders"][0]["status"] == "sent"


def test_la_campagne_apparait_dans_l_historique(client: TestClient) -> None:
    ctx = context(client)
    people = targets(client, ctx)
    send(client, ctx, [people[0]["memberId"]])

    history = client.get(
        f"/api/v1/organizations/{ctx['organization']['id']}/reminder-campaigns",
        headers=ctx["headers"],
    ).json()["data"]

    assert len(history) == 1
    assert history[0]["channels"] == ["in_app"]


def test_le_membre_relance_recoit_une_notification(client: TestClient) -> None:
    """Le canal in-app est le seul réellement acheminé aujourd'hui."""
    ctx = context(client)
    people = targets(client, ctx)
    target = people[0]

    send(client, ctx, [target["memberId"]])

    reminders = client.get(
        f"/api/v1/organizations/{ctx['organization']['id']}"
        f"/members/{target['memberId']}/reminders",
        headers=ctx["headers"],
    ).json()["data"]
    assert len(reminders) == 1
    assert reminders[0]["memberName"]
    assert reminders[0]["message"] == "Merci de régler votre cotisation."


def test_les_canaux_sans_passerelle_restent_en_file(client: TestClient) -> None:
    """SMS et WhatsApp sont acceptés mais non acheminés : `queued`, pas `failed`."""
    ctx = context(client)
    people = targets(client, ctx)

    body = send(
        client,
        ctx,
        [people[0]["memberId"]],
        channels=["in_app", "sms"],
    ).json()["data"]

    statuses = {r["channel"]: r["status"] for r in body["reminders"]}
    assert statuses["in_app"] == "sent"
    assert statuses["sms"] == "queued"
    # Une seule relance est comptée comme envoyée : celle réellement acheminée.
    assert body["campaign"]["sentCount"] == 1


def test_le_push_non_configure_n_empeche_pas_la_relance(client: TestClient) -> None:
    """`FIREBASE_SERVICE_ACCOUNT_JSON` est vide en test : l'envoi est ignoré, pas échoué."""
    ctx = context(client)
    people = targets(client, ctx)

    response = send(client, ctx, [people[0]["memberId"]])

    assert response.status_code == 201, response.text
    assert response.json()["data"]["campaign"]["sentCount"] == 1


def test_un_simple_membre_ne_relance_pas(client: TestClient) -> None:
    ctx = context(client)
    people = targets(client, ctx)
    outsider = auth_headers(register(client, "+225 07 66 99 00 01"))

    response = client.post(
        "/api/v1/reminder-campaigns",
        json={
            "actorMemberId": ctx["members"][0]["id"],
            "messages": {people[0]["memberId"]: "Bonjour"},
        },
        headers=outsider,
    )

    # 404 et non 403 : ne pas révéler l'existence d'une organisation étrangère.
    assert response.status_code == 404


def test_une_campagne_sans_destinataire_est_refusee(client: TestClient) -> None:
    ctx = context(client)

    response = client.post(
        "/api/v1/reminder-campaigns",
        json={"actorMemberId": ctx["members"][0]["id"], "messages": {}},
        headers=ctx["headers"],
    )

    assert response.status_code == 422
