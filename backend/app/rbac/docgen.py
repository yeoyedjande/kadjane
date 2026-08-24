"""Engendre `docs/permissions.md` depuis le catalogue.

La documentation des droits ne peut pas dériver du code si elle en est tirée.
Après toute modification de `catalog.py` :

    cd backend && .venv/Scripts/python -m app.rbac.docgen

Le fichier est écrit en UTF-8 explicite : la console Windows est en cp1252 et
avalerait les cases à cocher si l'on passait par la sortie standard.
"""

from __future__ import annotations

from pathlib import Path

from app.models.enums import OrgRole
from app.rbac import catalog

CATEGORY_LABELS: dict[str, str] = {
    "organization": "Organisation",
    "members": "Membres",
    "tontines": "Tontines",
    "contributions": "Cotisations",
    "payments": "Paiements",
    "cashbox": "Caisse et trésorerie",
    "draws": "Tirages",
    "payouts": "Versements",
    "dues": "Cotisations de caisse (plans périodiques)",
    "reminders": "Relances",
    "reports": "Rapports",
    "audit": "Audit",
    "administration": "Administration",
}

# Le super administrateur porte tout : une colonne pleine n'apprendrait rien.
COLUMNS: list[tuple[OrgRole, str]] = [
    (OrgRole.MEMBER, "Mbr"),
    (OrgRole.AUDITOR, "Aud"),
    (OrgRole.TREASURER, "Tré"),
    (OrgRole.PRESIDENT, "Pré"),
    (OrgRole.ORGANIZATION_ADMIN, "Adm"),
]

DESTINATION = Path(__file__).resolve().parents[3] / "docs" / "permissions.md"


def render() -> str:
    categories = {spec.category for spec in catalog.CATALOG}
    lines: list[str] = [
        "# Catalogue des permissions",
        "",
        "> **Fichier engendré.** Source : `backend/app/rbac/catalog.py`.",
        "> Le régénérer après toute modification du catalogue :",
        ">",
        "> ```bash",
        "> cd backend && .venv/Scripts/python -m app.rbac.docgen",
        "> ```",
        "",
        f"{len(catalog.CATALOG)} permissions, réparties en {len(categories)} "
        "catégories.",
        "",
        "Colonnes : **Mbr** membre · **Aud** commissaire aux comptes · "
        "**Tré** trésorier · **Pré** président · **Adm** administrateur.",
        "",
        "Ces cases sont les valeurs **par défaut**, posées au premier seed. "
        "Une fois les rôles en base, c'est le back-office qui fait autorité — "
        "voir [`rbac.md`](rbac.md).",
        "",
    ]

    for category in catalog.CATEGORIES:
        specs = [spec for spec in catalog.CATALOG if spec.category == category]
        if not specs:
            continue
        lines += [
            f"## {CATEGORY_LABELS.get(category, category)}",
            "",
            "| Code | Libellé | " + " | ".join(label for _, label in COLUMNS) + " |",
            "|---|---|" + "---|" * len(COLUMNS),
        ]
        for spec in specs:
            cells = " | ".join(
                "☑" if spec.code in catalog.DEFAULT_MATRIX[role] else "☐"
                for role, _ in COLUMNS
            )
            lines.append(f"| `{spec.code}` | {spec.name} | {cells} |")
        lines.append("")
        for spec in specs:
            lines.append(f"- **`{spec.code}`** — {spec.description}")
        lines.append("")

    return "\n".join(lines)


def main() -> None:
    DESTINATION.write_text(render(), encoding="utf-8")
    print(f"{DESTINATION} — {len(catalog.CATALOG)} permissions")


if __name__ == "__main__":
    main()
