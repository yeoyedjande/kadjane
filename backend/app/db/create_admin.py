"""Amorçage d'une instance : un compte super administrateur, rien d'autre.

Destiné à la Beta et à la production, là où `app.db.seed` n'a pas sa place :
ce dernier crée douze comptes partageant un mot de passe connu et injecte des
mouvements financiers fictifs.

Ici, un seul compte est créé, avec son organisation. Le super administrateur
ajoute ensuite les membres depuis le back-office ; chacun définit son mot de
passe à la première connexion, par OTP.

    python -m app.db.create_admin \\
        --phone "+225 07 00 00 00 01" \\
        --first-name Yedjande --last-name YEO \\
        --organization "Association Solidarité"

Le mot de passe n'est jamais passé en argument par défaut : il est lu dans
`KADJANE_ADMIN_PASSWORD`, sinon demandé sans écho. Le script est idempotent —
relancé, il complète ce qui manque sans rien dupliquer.
"""

from __future__ import annotations

import argparse
import os
import sys
from getpass import getpass

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models.enums import Gender, MemberStatus, OrgRole
from app.models.membership import OrganizationMember
from app.models.organization import Organization
from app.models.user import User
from app.repositories.member_repository import MemberRepository
from app.repositories.organization_repository import OrganizationRepository
from app.repositories.user_repository import UserRepository
from app.services.organization_service import slugify

PASSWORD_ENV = "KADJANE_ADMIN_PASSWORD"
MIN_PASSWORD_LENGTH = 12

# Termes des jeux de démonstration et des mots de passe courants. Ils sont
# cherchés *à l'intérieur* du mot de passe : tous font moins de
# `MIN_PASSWORD_LENGTH`, donc une comparaison exacte ne se déclencherait jamais
# — et « kadjane2026! » doit être refusé autant que « kadjane ».
FORBIDDEN_TERMS = ("kadjane", "password", "motdepasse", "changeme", "azerty")


class BootstrapError(RuntimeError):
    """Erreur d'usage, rapportée sans trace d'exécution."""


def read_password(provided: str | None, *, interactive: bool = True) -> str:
    """Récupère le mot de passe, par ordre de préférence.

    L'argument de ligne de commande vient en dernier : il resterait dans
    l'historique du shell et dans les journaux de l'hébergeur.
    """
    password = os.environ.get(PASSWORD_ENV) or provided
    if not password and interactive and sys.stdin.isatty():
        password = getpass("Mot de passe du super administrateur : ")
        if password != getpass("Confirmer : "):
            raise BootstrapError("Les deux saisies diffèrent.")

    if not password:
        raise BootstrapError(
            f"Aucun mot de passe. Définir {PASSWORD_ENV} ou utiliser --password."
        )

    # Le terme interdit est testé avant la longueur : « kadjane » est court
    # *et* interdit, et le message utile est celui qui nomme la vraie raison.
    lowered = password.lower()
    for term in FORBIDDEN_TERMS:
        if term in lowered:
            raise BootstrapError(
                f"Le mot de passe contient « {term} », trop courant ou issu du "
                "jeu de démonstration. En choisir un autre."
            )

    if len(password) < MIN_PASSWORD_LENGTH:
        raise BootstrapError(
            f"Mot de passe trop court : {MIN_PASSWORD_LENGTH} caractères minimum."
        )
    return password


def create_admin(
    db: Session,
    *,
    phone: str,
    password: str,
    first_name: str,
    last_name: str,
    organization_name: str,
    email: str | None = None,
    gender: Gender = Gender.UNSPECIFIED,
    reset_password: bool = False,
) -> dict[str, str]:
    users = UserRepository(db)
    organizations = OrganizationRepository(db)
    members = MemberRepository(db)
    report: dict[str, str] = {}

    user = users.by_phone(phone)
    if user is None:
        user = User(
            first_name=first_name.strip(),
            last_name=last_name.strip(),
            phone=phone.strip(),
            email=email,
            gender=gender.value,
            password_hash=hash_password(password),
            is_active=True,
            is_verified=True,
        )
        users.add(user)
        report["utilisateur"] = "créé"
    else:
        if reset_password:
            user.password_hash = hash_password(password)
            report["utilisateur"] = "mot de passe réinitialisé"
        else:
            report["utilisateur"] = "déjà présent (mot de passe inchangé)"

    db.flush()

    slug = slugify(organization_name)
    organization = organizations.by_slug(slug)
    if organization is None:
        organization = Organization(
            name=organization_name.strip(),
            slug=slug,
            country="CI",
            currency="XOF",
            created_by=user.id,
        )
        organizations.add(organization)
        db.flush()
        report["organisation"] = "créée"
    else:
        report["organisation"] = "déjà présente"

    membership = members.membership(organization.id, user.id)
    if membership is None:
        members.add(
            OrganizationMember(
                organization_id=organization.id,
                user_id=user.id,
                role=OrgRole.SUPER_ADMIN.value,
                status=MemberStatus.ACTIVE.value,
                member_number=members.next_member_number(organization.id),
            )
        )
        report["adhésion"] = "créée (super_admin)"
    elif membership.role != OrgRole.SUPER_ADMIN.value:
        # Le script est appelé pour obtenir un super administrateur : si le
        # compte existe avec un rôle moindre, on l'élève plutôt que d'échouer.
        membership.role = OrgRole.SUPER_ADMIN.value
        report["adhésion"] = "promue en super_admin"
    else:
        report["adhésion"] = "déjà super_admin"

    try:
        db.commit()
    except IntegrityError as error:
        db.rollback()
        raise BootstrapError(
            "Ce numéro de téléphone ou cette adresse e-mail est déjà utilisé "
            "par un autre compte."
        ) from error

    report["organisation_nom"] = organization.name
    report["identifiant"] = phone
    return report


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="python -m app.db.create_admin",
        description="Crée le super administrateur et son organisation.",
    )
    parser.add_argument("--phone", required=True, help="Identifiant de connexion")
    parser.add_argument("--first-name", required=True)
    parser.add_argument("--last-name", required=True)
    parser.add_argument("--organization", required=True, help="Nom de l'organisation")
    parser.add_argument("--email", default=None)
    parser.add_argument(
        "--gender",
        default=Gender.UNSPECIFIED.value,
        choices=[item.value for item in Gender],
    )
    parser.add_argument(
        "--password",
        default=None,
        help=(
            f"À éviter : préférer la variable {PASSWORD_ENV}, "
            "qui ne laisse pas de trace dans l'historique du shell."
        ),
    )
    parser.add_argument(
        "--reset-password",
        action="store_true",
        help="Réinitialise le mot de passe si le compte existe déjà.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        password = read_password(args.password)
        with SessionLocal() as db:
            report = create_admin(
                db,
                phone=args.phone,
                password=password,
                first_name=args.first_name,
                last_name=args.last_name,
                organization_name=args.organization,
                email=args.email,
                gender=Gender(args.gender),
                reset_password=args.reset_password,
            )
    except BootstrapError as error:
        print(f"Échec : {error}", file=sys.stderr)
        return 1

    print("Super administrateur prêt :")
    for key, value in report.items():
        print(f"  {key:20} {value}")
    print(
        "\nConnectez-vous au back-office, puis ajoutez les membres depuis "
        "l'écran « Membres ». Chacun définira son mot de passe à la première "
        "connexion via « Mot de passe oublié ? »."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
