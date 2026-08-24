"""Résolution des droits : source de vérité du contrôle d'accès.

Un membre porte deux choses distinctes, et les confondre serait une faille :

* `organization_members.role` — l'**étiquette** (`treasurer`, `admin`…). Elle
  porte la hiérarchie, donc l'anti-escalade : on ne promeut personne au-dessus
  de soi. Un rôle sur mesure n'en a pas d'équivalent et se range au niveau
  `MEMBER`.
* `organization_members.role_id` — les **droits**, lus dans `role_permissions`.

Ordre de résolution, du plus précis au plus général :

1. le rôle explicitement attribué au membre (`role_id`) ;
2. le rôle système **de cette organisation** portant le même code que
   l'étiquette — c'est celui que la console personnalise ;
3. le rôle système **global** de même code, semé au démarrage ;
4. la matrice statique de `app.rbac.catalog`, en dernier recours.

Le dernier niveau n'est pas décoratif : il maintient l'API vivante si le seed
n'a pas encore tourné — sur une base restaurée, par exemple — au lieu de
refuser tout à tout le monde.
"""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import PermissionDeniedError
from app.models.enums import OrgRole, RoleStatus
from app.models.membership import OrganizationMember
from app.models.rbac import Permission, Role, RolePermission
from app.rbac import catalog

# Ré-exports : la matrice statique reste consultable sans session, notamment
# par le seed et par les tests de cohérence.
DEFAULT_MATRIX = catalog.DEFAULT_MATRIX
ALL_PERMISSIONS: set[str] = set(catalog.ALL_CODES)


def static_permissions_of(role: OrgRole) -> set[str]:
    """Droits par défaut d'un rôle système, hors base."""
    return set(catalog.DEFAULT_MATRIX.get(role, catalog.MEMBER_PERMISSIONS))


class PermissionService:
    """Lit les droits d'un membre et les fait respecter.

    Instancié par requête. Le cache interne évite de relire `role_permissions`
    à chaque `require` d'un même endpoint — certains en enchaînent plusieurs.
    """

    def __init__(self, db: Session) -> None:
        self.db = db
        self._cache: dict[uuid.UUID, frozenset[str]] = {}

    # --- Lecture -------------------------------------------------------------

    def permissions_for(self, membership: OrganizationMember) -> frozenset[str]:
        cached = self._cache.get(membership.id)
        if cached is not None:
            return cached

        resolved = self._resolve(membership)
        self._cache[membership.id] = resolved
        return resolved

    def _resolve(self, membership: OrganizationMember) -> frozenset[str]:
        if membership.role_id is not None:
            role = self.db.get(Role, membership.role_id)
            # Un rôle désactivé ne confère plus rien : c'est le sens de la
            # désactivation, et c'est plus sûr que de retomber sur l'étiquette.
            if role is not None:
                return frozenset(
                    role.permission_codes if role.is_assignable else set()
                )

        for organization_id in (membership.organization_id, None):
            role = self._system_role(membership.role, organization_id)
            if role is not None:
                return frozenset(role.permission_codes)

        try:
            return frozenset(static_permissions_of(OrgRole(membership.role)))
        except ValueError:
            # Étiquette inconnue — un rôle sur mesure dont le rôle a disparu.
            return frozenset(catalog.MEMBER_PERMISSIONS)

    def _system_role(self, code: str, organization_id: uuid.UUID | None) -> Role | None:
        statement = select(Role).where(Role.code == code, Role.is_system.is_(True))
        statement = statement.where(
            Role.organization_id == organization_id
            if organization_id is not None
            else Role.organization_id.is_(None)
        )
        return self.db.scalars(statement).first()

    # --- Contrôle ------------------------------------------------------------

    def can(self, membership: OrganizationMember, permission: str) -> bool:
        return permission in self.permissions_for(membership)

    def can_any(self, membership: OrganizationMember, *permissions: str) -> bool:
        granted = self.permissions_for(membership)
        return any(permission in granted for permission in permissions)

    def require(self, membership: OrganizationMember, permission: str) -> None:
        """Lève `PermissionDeniedError` si le membre ne porte pas la permission."""
        if not self.can(membership, permission):
            raise PermissionDeniedError(
                "Votre rôle ne permet pas cette action.",
                details={
                    "requiredPermission": permission,
                    "role": membership.role,
                },
            )

    def require_any(self, membership: OrganizationMember, *permissions: str) -> None:
        """Accepte l'une quelconque des permissions.

        Sert aux actions couvertes par deux codes — le code historique et son
        équivalent fin — pour qu'un rôle sur mesure n'ait pas à porter les deux.
        """
        if not self.can_any(membership, *permissions):
            raise PermissionDeniedError(
                "Votre rôle ne permet pas cette action.",
                details={
                    "requiredPermission": sorted(permissions),
                    "role": membership.role,
                },
            )

    # --- Rôles ---------------------------------------------------------------

    def roles_of(self, organization_id: uuid.UUID) -> list[Role]:
        """Rôles proposés à cette organisation.

        Les rôles système globaux **non encore personnalisés** y figurent : une
        organisation qui n'a rien redéfini doit tout de même voir les six rôles
        du produit. Ceux qu'elle a personnalisés masquent leur gabarit.
        """
        own = list(
            self.db.scalars(
                select(Role).where(Role.organization_id == organization_id)
            )
        )
        overridden = {role.code for role in own}
        shared = [
            role
            for role in self.db.scalars(
                select(Role).where(
                    Role.organization_id.is_(None), Role.is_system.is_(True)
                )
            )
            if role.code not in overridden
        ]
        return sorted(own + shared, key=_role_rank)

    def role_for(self, organization_id: uuid.UUID, role_id: uuid.UUID) -> Role | None:
        """Rôle utilisable par cette organisation, ou `None`.

        Filtre volontairement : un identifiant appartenant à une autre
        organisation ne doit rien donner, pas même son existence.
        """
        role = self.db.get(Role, role_id)
        if role is None:
            return None
        if role.organization_id in (None, organization_id):
            return role
        return None

    def set_permissions(self, role: Role, codes: set[str]) -> set[str]:
        """Remplace les permissions d'un rôle. Retourne les codes réellement posés.

        Les codes inconnus du catalogue sont ignorés plutôt que refusés : le
        catalogue peut avoir perdu une permission entre deux versions, et un
        enregistrement ne doit pas échouer pour un droit qui n'existe plus.
        """
        known = {
            permission.code: permission
            for permission in self.db.scalars(
                select(Permission).where(Permission.code.in_(codes))
            )
        }
        # Passer par la relation, et non par `db.add` : la collection déjà
        # chargée doit refléter la base. Sans cela, la réponse renverrait
        # l'ancien état, et un second enregistrement dans la même session
        # réinsérerait des lignes que `clear()` croyait avoir supprimées.
        role.permissions.clear()
        self.db.flush()
        for code in sorted(known):
            role.permissions.append(
                RolePermission(role_id=role.id, permission_id=known[code].id)
            )
        self.db.flush()
        return set(known)

    def fork_system_role(
        self, role: Role, organization_id: uuid.UUID
    ) -> Role:
        """Copie un rôle système global au profit d'une organisation.

        Personnaliser « Trésorier » ne doit pas changer le trésorier des autres
        associations : la première modification crée la copie, et c'est elle
        que l'organisation voit désormais.
        """
        # Idempotent : deux requêtes concurrentes visant le même gabarit ne
        # doivent pas produire deux copies — la contrainte d'unicité sur
        # (organization_id, code) l'interdirait de toute façon.
        existing = self.db.scalars(
            select(Role).where(
                Role.organization_id == organization_id, Role.code == role.code
            )
        ).first()
        if existing is not None:
            return existing

        copy = Role(
            organization_id=organization_id,
            code=role.code,
            name=role.name,
            description=role.description,
            is_system=True,
            status=role.status,
        )
        self.db.add(copy)
        self.db.flush()
        self.set_permissions(copy, role.permission_codes)
        return copy

    def catalog(self) -> list[Permission]:
        return list(
            self.db.scalars(select(Permission).order_by(Permission.code))
        )


def _role_rank(role: Role) -> tuple[int, str]:
    """Rôles système du plus fort au plus faible, puis les rôles sur mesure."""
    try:
        return (-OrgRole(role.code).level, role.name)
    except ValueError:
        return (1, role.name)


__all__ = [
    "ALL_PERMISSIONS",
    "DEFAULT_MATRIX",
    "PermissionService",
    "RoleStatus",
    "static_permissions_of",
]
