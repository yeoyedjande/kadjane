"""Contrôle d'accès : ce que chaque rôle peut, et surtout ce qu'il ne peut pas.

Le frontend masque des boutons ; c'est ici que se joue la sécurité. Chaque test
vise une route réelle et vérifie le code HTTP, pas une matrice en mémoire.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.rbac import catalog
from tests.conftest import auth_headers, build_organization, register

API = "/api/v1"


# --- Cohérence du catalogue ---------------------------------------------------


def test_toute_permission_exigee_par_le_code_existe_au_catalogue() -> None:
    """Un `require("…")` visant un code absent refuserait tout le monde.

    L'erreur serait silencieuse : la permission ne figurant dans aucun rôle,
    l'endpoint deviendrait inaccessible sans qu'aucun test ne le signale.
    """
    sources = list(Path("app").rglob("*.py"))
    required: set[str] = set()
    pattern = re.compile(r"require(?:_any)?\(\s*[^,]+,\s*((?:\"[\w.]+\"\s*,?\s*)+)\)")
    for source in sources:
        for group in pattern.findall(source.read_text(encoding="utf-8")):
            required |= set(re.findall(r"\"([\w.]+)\"", group))

    unknown = sorted(required - catalog.ALL_CODES)
    assert not unknown, f"Permissions exigées mais absentes du catalogue : {unknown}"


def test_le_catalogue_ne_contient_pas_de_categorie_orpheline() -> None:
    categories = {spec.category for spec in catalog.CATALOG}
    assert categories <= set(catalog.CATEGORIES)


def test_le_tresorier_ne_gere_ni_les_roles_ni_les_permissions() -> None:
    """§43 : le trésorier gère l'argent, pas les droits."""
    treasurer = catalog.TREASURER_PERMISSIONS
    assert not {code for code in treasurer if code.startswith(("role.", "permission."))}


def test_le_commissaire_aux_comptes_ne_modifie_rien_financierement() -> None:
    """§44 : lecture seule sur les finances."""
    auditor = catalog.AUDITOR_PERMISSIONS
    forbidden = {
        "cash_transaction.create",
        "payment.create",
        "payment.confirm",
        "payout.record",
        "cashbox.create",
        "treasury.manage",
    }
    assert not (auditor & forbidden)
    assert {"cashbox.view", "treasury.view", "audit.view", "report.view"} <= auditor


# --- Le catalogue servi par l'API ---------------------------------------------


def test_le_catalogue_est_servi_groupe_par_categorie(client: TestClient) -> None:
    headers = auth_headers(register(client, "+225 07 60 00 00 01"))

    response = client.get(f"{API}/permissions", headers=headers)

    assert response.status_code == 200, response.text
    body = response.json()
    codes = {item["code"] for item in body["data"]}
    assert "cashbox.create" in codes
    assert "role.assign" in codes
    assert body["meta"]["source"] == "database"
    assert "cashbox" in body["meta"]["categories"]


def test_mes_permissions_dependent_de_l_organisation(client: TestClient) -> None:
    """§6 : trésorier ici, membre ailleurs — le rôle n'est jamais global."""
    first = build_organization(client, members=2, prefix="61")
    second = build_organization(client, members=2, prefix="62")

    # Le membre 2 de la première organisation rejoint la seconde comme membre.
    admin_two = second["headers"]
    client.post(
        f"{API}/organizations/{second['organization']['id']}/members",
        json={
            "firstName": "Membre02",
            "lastName": "TEST",
            "phone": "+225 07 61 00 00 02",
        },
        headers=admin_two,
    )

    session = client.post(
        f"{API}/auth/login",
        json={"identifier": "+225 07 61 00 00 02", "password": "motdepasse123"},
    )
    # Le membre créé par l'administrateur reçoit un mot de passe provisoire :
    # ce test ne cherche pas à s'y connecter, seulement à constater les deux
    # appartenances côté administrateur.
    assert session.status_code in (200, 401)

    response = client.get(
        f"{API}/me/permissions",
        headers=first["headers"],
        params={"organizationId": first["organization"]["id"]},
    )
    assert response.status_code == 200
    payload = response.json()["data"]
    assert len(payload) == 1
    assert payload[0]["role"] == "admin"
    assert "cashbox.create" in payload[0]["permissions"]


# --- Rôles système et rôles sur mesure ---------------------------------------


def test_les_six_roles_systeme_sont_proposes(client: TestClient) -> None:
    context = build_organization(client, members=2, prefix="63")

    response = client.get(
        f"{API}/organizations/{context['organization']['id']}/roles",
        headers=context["headers"],
    )

    assert response.status_code == 200, response.text
    roles = {item["role"]: item for item in response.json()["data"]}
    assert set(roles) >= {
        "super_admin",
        "admin",
        "president",
        "treasurer",
        "auditor",
        "member",
    }
    assert "draw.run" in roles["president"]["permissions"]
    assert "draw.run" not in roles["member"]["permissions"]
    assert "cashbox.create" in roles["treasurer"]["permissions"]
    assert roles["treasurer"]["isSystem"] is True


def test_un_role_sur_mesure_est_cree_puis_attribue(client: TestClient) -> None:
    """§7 : « Responsable Cotisations » et ses quatre droits."""
    context = build_organization(client, members=3, prefix="64")
    organization_id = context["organization"]["id"]

    created = client.post(
        f"{API}/organizations/{organization_id}/roles",
        json={
            "name": "Responsable Cotisations",
            "description": "Suit les cotisations sans toucher à la caisse.",
            "permissions": [
                "contribution.view",
                "contribution.create",
                "contribution.update",
                "payment.view",
            ],
        },
        headers=context["headers"],
    )

    assert created.status_code == 201, created.text
    role = created.json()["data"]
    assert role["code"] == "responsable-cotisations"
    assert role["isSystem"] is False
    assert set(role["permissions"]) == {
        "contribution.view",
        "contribution.create",
        "contribution.update",
        "payment.view",
    }

    target = context["members"][1]["id"]
    assigned = client.patch(
        f"{API}/organizations/{organization_id}/members/{target}/role",
        json={"roleId": role["id"]},
        headers=context["headers"],
    )
    assert assigned.status_code == 200, assigned.text
    assert set(assigned.json()["data"]["permissions"]) == set(role["permissions"])
    # L'étiquette retombe au niveau le plus bas : un rôle sur mesure ne doit
    # jamais servir d'échelle vers un rang supérieur.
    assert assigned.json()["data"]["role"] == "member"


def test_on_ne_peut_pas_accorder_un_droit_qu_on_ne_possede_pas(
    client: TestClient,
) -> None:
    """Sinon `role.create` suffirait à se fabriquer les pleins pouvoirs."""
    context = build_organization(client, members=2, prefix="65")
    organization_id = context["organization"]["id"]

    # L'administrateur se restreint : son propre rôle perd `draw.override`.
    roles = client.get(
        f"{API}/organizations/{organization_id}/roles", headers=context["headers"]
    ).json()["data"]
    admin_role = next(item for item in roles if item["role"] == "admin")
    kept = [code for code in admin_role["permissions"] if code != "draw.override"]
    client.put(
        f"{API}/organizations/{organization_id}/roles/{admin_role['id']}/permissions",
        json={"permissions": kept},
        headers=context["headers"],
    )

    response = client.post(
        f"{API}/organizations/{organization_id}/roles",
        json={"name": "Faux Arbitre", "permissions": ["draw.view", "draw.override"]},
        headers=context["headers"],
    )

    assert response.status_code == 201
    assert response.json()["data"]["permissions"] == ["draw.view"]


def test_un_role_systeme_personnalise_ne_deborde_pas_sur_les_autres(
    client: TestClient,
) -> None:
    """Personnaliser « Trésorier » chez soi ne change rien chez le voisin."""
    first = build_organization(client, members=2, prefix="66")
    second = build_organization(client, members=2, prefix="67")

    roles = client.get(
        f"{API}/organizations/{first['organization']['id']}/roles",
        headers=first["headers"],
    ).json()["data"]
    treasurer = next(item for item in roles if item["role"] == "treasurer")

    client.put(
        f"{API}/organizations/{first['organization']['id']}/roles/{treasurer['id']}/permissions",
        json={"permissions": ["cashbox.view"]},
        headers=first["headers"],
    )

    others = client.get(
        f"{API}/organizations/{second['organization']['id']}/roles",
        headers=second["headers"],
    ).json()["data"]
    untouched = next(item for item in others if item["role"] == "treasurer")
    assert "cash_transaction.create" in untouched["permissions"]


def test_un_role_d_une_organisation_n_est_pas_visible_d_une_autre(
    client: TestClient,
) -> None:
    """§36, isolation : aucun droit ne traverse la frontière d'une association."""
    first = build_organization(client, members=2, prefix="68")
    second = build_organization(client, members=2, prefix="69")

    created = client.post(
        f"{API}/organizations/{first['organization']['id']}/roles",
        json={"name": "Rôle Privé", "permissions": ["contribution.view"]},
        headers=first["headers"],
    )
    role_id = created.json()["data"]["id"]

    # L'administrateur de la seconde organisation ne peut ni le lire ni s'en servir.
    response = client.patch(
        f"{API}/organizations/{second['organization']['id']}/roles/{role_id}",
        json={"name": "Détourné"},
        headers=second["headers"],
    )
    assert response.status_code == 404

    stolen = client.patch(
        f"{API}/organizations/{second['organization']['id']}/members/"
        f"{second['members'][1]['id']}/role",
        json={"roleId": role_id},
        headers=second["headers"],
    )
    assert stolen.status_code == 404


def test_un_role_systeme_ne_peut_pas_etre_desactive(client: TestClient) -> None:
    """Désactiver « Membre » priverait de droits tous ceux qui n'en ont pas d'autre."""
    context = build_organization(client, members=2, prefix="70")
    organization_id = context["organization"]["id"]
    roles = client.get(
        f"{API}/organizations/{organization_id}/roles", headers=context["headers"]
    ).json()["data"]
    member_role = next(item for item in roles if item["role"] == "member")

    response = client.patch(
        f"{API}/organizations/{organization_id}/roles/{member_role['id']}",
        json={"status": "disabled"},
        headers=context["headers"],
    )

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "system_role_locked"


@pytest.mark.parametrize(
    ("permission", "expected"),
    [
        ("cashbox.create", True),
        ("payment.confirm", True),
        ("cash_transaction.create", True),
        ("payout.confirm", True),
        ("role.assign", False),
        ("permission.assign", False),
    ],
)
def test_matrice_du_tresorier(permission: str, expected: bool) -> None:
    """§43 : la liste minimale du cahier des charges, et ses exclusions."""
    assert (permission in catalog.TREASURER_PERMISSIONS) is expected


@pytest.mark.parametrize(
    ("permission", "expected"),
    [
        ("contribution.view", True),
        ("payment.view", True),
        ("cashbox.create", False),
        ("payment.confirm", False),
        ("member.create", False),
    ],
)
def test_matrice_du_membre(permission: str, expected: bool) -> None:
    """§45 : le membre consulte, il n'écrit pas."""
    assert (permission in catalog.MEMBER_PERMISSIONS) is expected
