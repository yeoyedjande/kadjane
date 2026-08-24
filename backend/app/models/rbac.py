"""Rôles et permissions persistés.

Trois tables, et une règle de lecture qui décide de tout :

    organization_members.role_id  →  roles  →  role_permissions  →  permissions

`organization_members.role` (la chaîne `treasurer`, `admin`…) reste
l'**étiquette** du membre : elle porte la hiérarchie, donc l'anti-escalade
lors d'un changement de rôle. `role_id` porte les **droits**. Un membre sans
`role_id` — tout l'existant — retombe sur le rôle système de même code, ce qui
laisse les organisations déjà en base fonctionner sans reprise de données.

Les permissions sont un catalogue **global** : elles décrivent ce que le code
sait protéger, pas ce qu'une organisation autorise. Seule leur attribution aux
rôles est propre à chaque organisation.
"""

from __future__ import annotations

import uuid

from sqlalchemy import (
    Boolean,
    ForeignKey,
    Index,
    String,
    Text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, new_uuid
from app.models.enums import RoleStatus


class Permission(Base, TimestampMixin):
    """Un droit élémentaire que le backend sait exiger.

    Le catalogue est semé depuis `app.rbac.catalog` et n'est pas administrable :
    ajouter une permission suppose du code qui l'exige quelque part. La console
    d'administration attribue, elle ne crée pas.
    """

    __tablename__ = "permissions"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    code: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    category: Mapped[str] = mapped_column(String(32), nullable=False, index=True)


class Role(Base, TimestampMixin):
    """Un ensemble de permissions, système ou sur mesure.

    `organization_id` nul désigne un rôle **système** : le gabarit partagé par
    toutes les organisations, non modifiable et non supprimable. Une
    organisation qui personnalise un rôle système en obtient une copie qui lui
    appartient, portant le même `code` — d'où l'unicité sur le couple.
    """

    __tablename__ = "roles"
    __table_args__ = (
        UniqueConstraint("organization_id", "code", name="uq_roles_organization_id"),
        Index("ix_roles_org_status", "organization_id", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    organization_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid,
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    code: Mapped[str] = mapped_column(String(64), nullable=False)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    # Vrai pour les six rôles du produit. Un rôle système garde son code
    # aligné sur `OrgRole`, ce qui permet de le retrouver depuis l'étiquette
    # d'un membre qui n'a pas encore de `role_id`.
    is_system: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=RoleStatus.ACTIVE.value
    )
    # `use_alter` : `organization_members.role_id` pointe vers `roles`, et
    # cette colonne pointe en retour. Sans cela, ni Alembic ni `create_all` ne
    # savent laquelle des deux tables créer en premier.
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid,
        ForeignKey(
            "organization_members.id",
            ondelete="SET NULL",
            use_alter=True,
            name="fk_roles_created_by_organization_members",
        ),
        nullable=True,
    )

    permissions: Mapped[list[RolePermission]] = relationship(
        back_populates="role", cascade="all, delete-orphan", lazy="selectin"
    )

    @property
    def status_enum(self) -> RoleStatus:
        return RoleStatus(self.status)

    @property
    def is_assignable(self) -> bool:
        return self.status == RoleStatus.ACTIVE.value

    @property
    def permission_codes(self) -> set[str]:
        return {link.permission.code for link in self.permissions}


class RolePermission(Base):
    """Attribution d'une permission à un rôle.

    Table d'association nue : la présence de la ligne **est** le droit. Retirer
    une permission supprime la ligne — c'est la seule suppression franche du
    domaine, parce qu'aucune valeur financière n'y est attachée. L'audit
    conserve la trace du changement.
    """

    __tablename__ = "role_permissions"

    role_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("roles.id", ondelete="CASCADE"), primary_key=True
    )
    permission_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("permissions.id", ondelete="CASCADE"), primary_key=True
    )

    role: Mapped[Role] = relationship(back_populates="permissions")
    permission: Mapped[Permission] = relationship(lazy="joined")
