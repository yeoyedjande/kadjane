from __future__ import annotations

import uuid

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.errors import ConflictError, NotFoundError, PermissionDeniedError
from app.core.security import generate_temporary_password, hash_password
from app.models.enums import MemberStatus, OrgRole
from app.models.membership import OrganizationMember
from app.models.user import User
from app.repositories.member_repository import MemberRepository
from app.repositories.user_repository import UserRepository
from app.schemas.member import MemberCreate, MemberUpdate


class MemberService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.members = MemberRepository(db)
        self.users = UserRepository(db)

    def search(
        self,
        organization_id: uuid.UUID,
        *,
        query: str = "",
        role: OrgRole | None = None,
        status: MemberStatus | None = None,
        page: int = 0,
        page_size: int = 20,
    ) -> tuple[list[OrganizationMember], int]:
        return self.members.search(
            organization_id,
            query=query,
            role=role,
            status=status,
            page=page,
            page_size=page_size,
        )

    def get_in_organization(
        self, member_id: uuid.UUID, organization_id: uuid.UUID
    ) -> OrganizationMember:
        """Charge un membre **et** vérifie qu'il appartient à l'organisation.

        C'est le point de contrôle de l'isolation multi-association pour les
        routes `/members/{id}` : un identifiant appartenant à une autre
        organisation est traité comme inexistant.
        """
        member = self.members.by_id(member_id)
        if member is None or member.organization_id != organization_id:
            raise NotFoundError("Membre introuvable.", code="member_not_found")
        return member

    def create(
        self,
        organization_id: uuid.UUID,
        payload: MemberCreate,
        actor: OrganizationMember,
    ) -> tuple[OrganizationMember, str | None]:
        """Ajoute un membre et renvoie son mot de passe provisoire s'il en a un.

        Le second élément n'est renseigné que lorsqu'un mot de passe a été tiré
        au hasard : c'est la seule occasion de le lire, il n'est stocké que
        haché. Si l'administrateur en a fourni un, il le connaît déjà et rien
        n'est renvoyé.
        """
        generated_password: str | None = None
        user = self.users.by_phone(payload.phone)
        if user is None:
            # Le membre reçoit un accès utilisable immédiatement : c'est
            # l'administrateur qui le lui transmet, puis le membre le change
            # depuis l'application s'il le souhaite.
            if payload.password:
                password = payload.password
            else:
                password = generate_temporary_password()
                generated_password = password

            user = User(
                first_name=payload.first_name.strip(),
                last_name=payload.last_name.strip(),
                phone=payload.phone.strip(),
                email=payload.email,
                gender=payload.gender.value,
                birth_date=payload.birth_date,
                avatar_url=payload.avatar_url,
                password_hash=hash_password(password),
                is_active=True,
                is_verified=False,
            )
            self.users.add(user)
        elif self.members.membership(organization_id, user.id) is not None:
            raise ConflictError(
                "Ce membre fait déjà partie de l'organisation.",
                code="member_already_exists",
            )

        self._guard_role_escalation(actor, payload.role)

        member = OrganizationMember(
            organization_id=organization_id,
            user_id=user.id,
            role=payload.role.value,
            status=payload.status.value,
            member_number=payload.member_number
            or self.members.next_member_number(organization_id),
        )
        try:
            self.members.add(member)
            self.db.commit()
        except IntegrityError as error:
            self.db.rollback()
            raise ConflictError(
                "Ce membre existe déjà dans l'organisation.",
                code="member_already_exists",
            ) from error
        self.db.refresh(member)
        return member, generated_password

    def update(
        self,
        member: OrganizationMember,
        payload: MemberUpdate,
        actor: OrganizationMember,
    ) -> OrganizationMember:
        data = payload.model_dump(exclude_unset=True, exclude_none=True)

        if "role" in data:
            self._guard_role_escalation(actor, payload.role)
            member.role = payload.role.value
        if "status" in data:
            member.status = payload.status.value
        if "member_number" in data:
            member.member_number = payload.member_number

        user_fields = {
            "first_name",
            "last_name",
            "phone",
            "email",
            "gender",
            "birth_date",
            "avatar_url",
        }
        for field in user_fields & data.keys():
            value = data[field]
            setattr(member.user, field, getattr(value, "value", value))

        try:
            self.db.commit()
        except IntegrityError as error:
            self.db.rollback()
            raise ConflictError(
                "Ce numéro de téléphone ou cet e-mail est déjà utilisé.",
                code="identity_already_used",
            ) from error
        self.db.refresh(member)
        return member

    def delete(self, member: OrganizationMember, actor: OrganizationMember) -> None:
        """Retire définitivement un membre de l'organisation.

        Trois refus, dans cet ordre :

        1. **Se supprimer soi-même** — l'organisation perdrait son
           administrateur sans qu'aucun autre ne puisse reprendre la main.
        2. **Supprimer plus haut placé que soi** — pendant de
           `_guard_role_escalation` : un trésorier ne retire pas un président.
        3. **Supprimer un membre engagé dans une tontine** — le lien
           `tontine_participants → organization_members` est en `CASCADE`, tout
           comme `contributions → tontine_participants` : la suppression
           effacerait silencieusement cotisations et versements. L'historique
           financier prime, on redirige vers la désactivation.
        """
        if member.id == actor.id:
            raise ConflictError(
                "Vous ne pouvez pas vous supprimer vous-même.",
                code="member_self_delete",
            )

        if member.role_enum.level > actor.role_enum.level:
            raise PermissionDeniedError(
                "Vous ne pouvez pas supprimer un membre au rôle supérieur au vôtre.",
                code="role_escalation_denied",
            )

        if self.members.has_tontine_participation(member.id):
            raise ConflictError(
                "Ce membre participe à une tontine : son historique de "
                "cotisations serait perdu. Désactivez-le plutôt.",
                code="member_has_history",
            )

        self.members.remove(member)
        self.db.commit()

    # --- Interne -------------------------------------------------------------

    @staticmethod
    def _guard_role_escalation(
        actor: OrganizationMember, target_role: OrgRole | None
    ) -> None:
        """Interdit d'attribuer un rôle supérieur au sien."""
        if target_role is None:
            return
        if target_role.level > actor.role_enum.level:
            raise PermissionDeniedError(
                "Vous ne pouvez pas attribuer un rôle supérieur au vôtre.",
                code="role_escalation_denied",
            )
