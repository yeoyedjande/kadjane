"""Jeu de données de développement.

Reproduit en base le jeu de démonstration de l'application mobile
(`lib/data/mock/mock_seed.dart`) : deux organisations et douze membres.

Utilisation :

    python -m app.db.seed

Le script est idempotent : relancé, il complète ce qui manque sans dupliquer.

**Développement uniquement.** Les douze comptes partagent le mot de passe
`SEED_PASSWORD` (défaut `kadjane`), sont marqués comme déjà vérifiés, et onze
paiements fictifs de 50 000 FCFA atterrissent dans la trésorerie, les rapports
et le journal d'audit. Pour amorcer une Beta ou une production, utiliser
`app.db.create_admin`, qui ne crée qu'un super administrateur.
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from datetime import date
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models.enums import (
    AllocationMode,
    Gender,
    MemberStatus,
    OrgRole,
    PaymentMethod,
    PaymentStatus,
    TontineFrequency,
)
from app.models.membership import OrganizationMember
from app.models.organization import Organization
from app.models.tontine import Tontine
from app.models.user import User
from app.repositories.member_repository import MemberRepository
from app.repositories.organization_repository import OrganizationRepository
from app.repositories.user_repository import UserRepository
from app.services.contribution_service import ContributionService
from app.services.organization_service import slugify
from app.services.tontine_service import TontineService


@dataclass(frozen=True)
class SeedUser:
    first_name: str
    last_name: str
    phone: str
    gender: Gender
    email: str | None = None


TONTINE_NAME = "Tontine Solidarité"
CONTRIBUTION_AMOUNT = Decimal("50000")

SEED_USERS: tuple[SeedUser, ...] = (
    SeedUser("Yedjane", "YEO", "+225 07 00 00 00 01", Gender.MALE, "yeo@kadjane.app"),
    SeedUser("Awa", "KOUASSI", "+225 07 00 00 00 02", Gender.FEMALE, "awa@kadjane.app"),
    SeedUser("Serge", "KOFFI", "+225 07 00 00 00 03", Gender.MALE, "serge@kadjane.app"),
    SeedUser("Fatou", "DIALLO", "+225 07 00 00 00 04", Gender.FEMALE),
    SeedUser("Ibrahim", "TRAORE", "+225 07 00 00 00 05", Gender.MALE),
    SeedUser("Mariam", "BAMBA", "+225 07 00 00 00 06", Gender.FEMALE),
    SeedUser("Kouadio", "N GUESSAN", "+225 07 00 00 00 07", Gender.MALE),
    SeedUser("Aminata", "CISSE", "+225 07 00 00 00 08", Gender.FEMALE),
    SeedUser("Jean-Marc", "ADJE", "+225 07 00 00 00 09", Gender.MALE),
    SeedUser("Rokia", "SANOGO", "+225 07 00 00 00 10", Gender.FEMALE),
    SeedUser("Salif", "OUATTARA", "+225 07 00 00 00 11", Gender.MALE),
    SeedUser("Celine", "GNAGNE", "+225 07 00 00 00 12", Gender.FEMALE),
)

SOLIDARITE_ROLES: tuple[tuple[str, OrgRole], ...] = (
    ("+225 07 00 00 00 01", OrgRole.ORGANIZATION_ADMIN),
    ("+225 07 00 00 00 02", OrgRole.TREASURER),
    ("+225 07 00 00 00 03", OrgRole.PRESIDENT),
    ("+225 07 00 00 00 04", OrgRole.AUDITOR),
    ("+225 07 00 00 00 05", OrgRole.MEMBER),
    ("+225 07 00 00 00 06", OrgRole.MEMBER),
    ("+225 07 00 00 00 07", OrgRole.MEMBER),
    ("+225 07 00 00 00 08", OrgRole.MEMBER),
    ("+225 07 00 00 00 09", OrgRole.MEMBER),
    ("+225 07 00 00 00 10", OrgRole.MEMBER),
    ("+225 07 00 00 00 11", OrgRole.MEMBER),
    ("+225 07 00 00 00 12", OrgRole.MEMBER),
)

AMICALE_ROLES: tuple[tuple[str, OrgRole], ...] = (
    ("+225 07 00 00 00 01", OrgRole.TREASURER),
    ("+225 07 00 00 00 03", OrgRole.ORGANIZATION_ADMIN),
    ("+225 07 00 00 00 07", OrgRole.MEMBER),
    ("+225 07 00 00 00 10", OrgRole.MEMBER),
    ("+225 07 00 00 00 12", OrgRole.PRESIDENT),
)


def seed(db: Session, *, password: str | None = None) -> dict[str, int]:
    demo_password = password or settings.seed_password
    users_repo = UserRepository(db)
    organizations_repo = OrganizationRepository(db)
    members_repo = MemberRepository(db)

    created_users = 0
    users: dict[str, User] = {}
    for entry in SEED_USERS:
        user = users_repo.by_phone(entry.phone)
        if user is None:
            user = User(
                first_name=entry.first_name,
                last_name=entry.last_name,
                phone=entry.phone,
                email=entry.email,
                gender=entry.gender.value,
                password_hash=hash_password(demo_password),
                is_active=True,
                is_verified=True,
            )
            users_repo.add(user)
            created_users += 1
        users[entry.phone] = user

    owner = users["+225 07 00 00 00 01"]

    solidarite = _ensure_organization(
        db,
        organizations_repo,
        name="Association Solidarité",
        description=(
            "Association de solidarité familiale et professionnelle basée à "
            "Abidjan."
        ),
        phone="+225 27 22 00 00 00",
        email="contact@solidarite.ci",
        address="Cocody Angré, Abidjan",
        rules=(
            "Les cotisations sont dues le 5 de chaque mois. Le tirage a lieu "
            "une fois toutes les cotisations réglées."
        ),
        owner=owner,
    )
    amicale = _ensure_organization(
        db,
        organizations_repo,
        name="Amicale des Anciens",
        description="Amicale des anciens élèves, promotion 2008.",
        phone=None,
        email="amicale2008@kadjane.app",
        address=None,
        rules=None,
        owner=users["+225 07 00 00 00 03"],
        settings={
            "requireFullPaymentBeforeDraw": False,
            "allowDrawOverride": True,
            "latePaymentGraceDays": 5,
            "notifyBeforeDueDays": 3,
        },
    )

    created_members = 0
    for organization, roster in (
        (solidarite, SOLIDARITE_ROLES),
        (amicale, AMICALE_ROLES),
    ):
        for index, (phone, role) in enumerate(roster, start=1):
            user = users[phone]
            if members_repo.membership(organization.id, user.id) is not None:
                continue
            members_repo.add(
                OrganizationMember(
                    organization_id=organization.id,
                    user_id=user.id,
                    role=role.value,
                    status=MemberStatus.ACTIVE.value,
                    member_number=f"M-{index:03d}",
                )
            )
            created_members += 1

    db.flush()
    tontine_report = _seed_tontine(db, solidarite, users)

    db.commit()
    return {
        "users_created": created_users,
        "members_created": created_members,
        "organizations": 2,
        **tontine_report,
    }


def _seed_tontine(
    db: Session, organization: Organization, users: dict[str, User]
) -> dict[str, int | str]:
    """Tontine Solidarité : 12 participants, 50 000 FCFA, une cotisation impayée.

    L'impayé est volontaire : l'écran de tirage doit afficher « Tirage
    indisponible — 1 cotisation reste à régler », ce qui permet aussi de tester
    le forçage.
    """
    members = MemberRepository(db)
    existing = db.scalars(
        select(Tontine).where(
            Tontine.organization_id == organization.id,
            Tontine.name == TONTINE_NAME,
        )
    ).first()
    if existing is not None:
        return {"tontine": "déjà présente", "payments_created": 0}

    roster = [
        members.membership(organization.id, users[phone].id)
        for phone, _ in SOLIDARITE_ROLES
    ]
    admin = roster[0]
    treasurer = roster[1]

    today = date.today()
    start = date(today.year, today.month, 1)

    tontine = TontineService(db).create(
        organization=organization,
        actor=admin,
        name=TONTINE_NAME,
        contribution_amount=CONTRIBUTION_AMOUNT,
        currency="XOF",
        frequency=TontineFrequency.MONTHLY,
        attribution_mode=AllocationMode.MONTHLY_DRAW,
        start_date=start,
        due_day=5,
        member_ids=[member.id for member in roster],
        description="Tontine mensuelle de l'association.",
        require_all_contributions_before_draw=True,
        allow_draw_override=True,
        activate=True,
    )

    service = TontineService(db)
    contributions = ContributionService(db)
    cycle = service.current_cycle(tontine.id)
    lines = contributions.for_cycle(cycle.id)

    # Toutes les cotisations sont réglées sauf la dernière.
    paid = 0
    for line in lines[:-1]:
        contributions.record_payment(
            contribution=line,
            amount=CONTRIBUTION_AMOUNT,
            method=PaymentMethod.WAVE if paid % 2 else PaymentMethod.CASH,
            actor=treasurer,
            status=PaymentStatus.CONFIRMED,
            reference=f"SEED-{paid + 1:03d}",
            commit=False,
        )
        paid += 1

    db.flush()
    return {
        "tontine": TONTINE_NAME,
        "participants": len(roster),
        "cycles": len(service.cycles(tontine.id)),
        "payments_created": paid,
        "unpaid_left": len(lines) - paid,
    }


def _ensure_organization(
    db: Session,
    repository: OrganizationRepository,
    *,
    name: str,
    description: str | None,
    phone: str | None,
    email: str | None,
    address: str | None,
    rules: str | None,
    owner: User,
    settings: dict | None = None,
) -> Organization:
    slug = slugify(name)
    organization = repository.by_slug(slug)
    if organization is not None:
        return organization

    organization = Organization(
        name=name,
        slug=slug,
        description=description,
        country="CI",
        currency="XOF",
        phone=phone,
        email=email,
        address=address,
        rules=rules,
        created_by=owner.id,
    )
    if settings is not None:
        organization.settings = settings
    repository.add(organization)
    db.flush()
    return organization


def main() -> int:
    with SessionLocal() as db:
        report = seed(db)
    print("Seed terminé :", report)
    print(
        "Comptes de démonstration : "
        "+225 07 00 00 00 01 (ou yeo@kadjane.app) "
        f"/ mot de passe « {settings.seed_password} » — DEV uniquement."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
