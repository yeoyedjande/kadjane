"""Alignement de la base sur le catalogue des permissions.

Idempotent, et conçu pour tourner à chaque démarrage : il rattrape une base
neuve comme une base restaurée, sans jamais toucher aux personnalisations
d'une organisation.

Trois garanties, dans cet ordre :

1. **Le catalogue est reflété.** Toute permission de `catalog.CATALOG` existe
   en base ; libellé et description sont remis à jour, le code jamais.
2. **Les six rôles système globaux existent**, avec leurs droits par défaut —
   mais ces droits ne sont posés qu'à la **création**. Repasser dessus
   écraserait une matrice que l'administrateur a peut-être ajustée.
3. **Rien n'est supprimé.** Une permission retirée du catalogue reste en base :
   des rôles la portent peut-être, et une désaffectation silencieuse ouvrirait
   des droits ou en fermerait sans trace.
"""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.enums import OrgRole, RoleStatus
from app.models.rbac import Permission, Role, RolePermission
from app.rbac import catalog


def sync_permissions(db: Session) -> dict[str, Permission]:
    """Crée ou rafraîchit le catalogue. Retourne les permissions par code."""
    existing = {
        permission.code: permission for permission in db.scalars(select(Permission))
    }

    for spec in catalog.CATALOG:
        permission = existing.get(spec.code)
        if permission is None:
            permission = Permission(
                code=spec.code,
                name=spec.name,
                description=spec.description,
                category=spec.category,
            )
            db.add(permission)
            existing[spec.code] = permission
            continue
        # Le libellé peut évoluer d'une version à l'autre ; le code est
        # l'identité et ne bouge pas.
        permission.name = spec.name
        permission.description = spec.description
        permission.category = spec.category

    db.flush()
    return existing


def sync_system_roles(db: Session) -> dict[str, Role]:
    """Crée les six rôles système globaux s'ils manquent.

    Les rôles déjà présents sont laissés intacts, droits compris : c'est ce qui
    permet à un administrateur de retirer une permission au trésorier sans la
    voir revenir au prochain redémarrage.
    """
    permissions = sync_permissions(db)

    existing = {
        role.code: role
        for role in db.scalars(
            select(Role).where(Role.organization_id.is_(None), Role.is_system.is_(True))
        )
    }

    for role_enum in OrgRole:
        if role_enum.value in existing:
            continue
        name, description = catalog.ROLE_LABELS[role_enum]
        role = Role(
            organization_id=None,
            code=role_enum.value,
            name=name,
            description=description,
            is_system=True,
            status=RoleStatus.ACTIVE.value,
        )
        db.add(role)
        db.flush()
        for code in sorted(catalog.DEFAULT_MATRIX[role_enum]):
            permission = permissions.get(code)
            if permission is not None:
                db.add(RolePermission(role_id=role.id, permission_id=permission.id))
        existing[role_enum.value] = role

    db.flush()
    return existing


def sync_rbac(db: Session) -> None:
    """Point d'entrée unique : catalogue puis rôles système."""
    sync_system_roles(db)
    db.commit()


def main() -> None:
    """`python -m app.rbac.seed` — rattrape une base dont le catalogue a dérivé.

    La migration `phase7_rbac_treasury` fait déjà le travail au déploiement.
    Cette entrée sert aux bases restaurées depuis une sauvegarde antérieure.
    """
    from app.db.session import SessionLocal

    session = SessionLocal()
    try:
        sync_rbac(session)
        print("Catalogue des permissions et rôles système synchronisés.")
    finally:
        session.close()


if __name__ == "__main__":
    main()
