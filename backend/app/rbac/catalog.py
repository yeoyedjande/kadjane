"""Catalogue des permissions et matrice par défaut des rôles système.

Ce fichier est la **source** du seed : il décrit ce que le backend sait
protéger. Une permission qui n'y figure pas ne peut être exigée nulle part, et
une permission exigée sans être ici ferait échouer le contrôle de cohérence de
`tests/test_rbac.py`.

Les codes restent en `point.minuscule`, comme le reste du produit : les gardes
Angular, l'énumération Dart et les soixante appels `require` existants les
utilisent déjà tels quels. Les permissions fines ajoutées ici les complètent
sans les remplacer.

Certaines actions sont couvertes par deux codes — `contribution.confirm`
historique et `payment.confirm` plus précis. Les rôles système portent les
deux, si bien qu'aucun comportement ne change ; un rôle sur mesure peut, lui,
n'accorder que le code fin.
"""

from __future__ import annotations

from dataclasses import dataclass

from app.models.enums import OrgRole


@dataclass(frozen=True, slots=True)
class PermissionSpec:
    code: str
    name: str
    description: str
    category: str


# Catégories, dans l'ordre d'affichage du back-office.
CATEGORIES: tuple[str, ...] = (
    "organization",
    "members",
    "tontines",
    "contributions",
    "payments",
    "cashbox",
    "draws",
    "payouts",
    "dues",
    "reminders",
    "reports",
    "audit",
    "administration",
)


CATALOG: tuple[PermissionSpec, ...] = (
    # --- Organisation ------------------------------------------------------
    PermissionSpec(
        "organization.view",
        "Voir l'organisation",
        "Consulter la fiche et les réglages de l'association.",
        "organization",
    ),
    PermissionSpec(
        "organization.edit",
        "Modifier l'organisation",
        "Changer le nom, les coordonnées et les règles de l'association.",
        "organization",
    ),
    PermissionSpec(
        "organization.manage_officers",
        "Gérer le bureau",
        "Désigner président, trésorier et commissaire aux comptes.",
        "organization",
    ),
    # --- Membres -----------------------------------------------------------
    PermissionSpec(
        "member.view", "Voir les membres", "Consulter la liste et les fiches.", "members"
    ),
    PermissionSpec(
        "member.create",
        "Ajouter un membre",
        "Créer un compte membre et lui remettre un accès.",
        "members",
    ),
    PermissionSpec(
        "member.edit",
        "Modifier un membre",
        "Corriger l'identité et les informations d'un membre.",
        "members",
    ),
    PermissionSpec(
        "member.invite",
        "Inviter un membre",
        "Proposer à une personne de rejoindre l'association.",
        "members",
    ),
    PermissionSpec(
        "member.disable",
        "Désactiver un membre",
        "Suspendre l'accès sans effacer l'historique financier.",
        "members",
    ),
    PermissionSpec(
        "member.delete",
        "Supprimer un membre",
        "Retirer définitivement un membre sans historique financier.",
        "members",
    ),
    # --- Tontines ----------------------------------------------------------
    PermissionSpec(
        "tontine.view", "Voir les tontines", "Consulter les tontines et leurs cycles.", "tontines"
    ),
    PermissionSpec(
        "tontine.create", "Créer une tontine", "Ouvrir une nouvelle tontine.", "tontines"
    ),
    PermissionSpec(
        "tontine.edit",
        "Modifier une tontine",
        "Ajuster le paramétrage d'une tontine.",
        "tontines",
    ),
    PermissionSpec(
        "tontine.validate",
        "Activer une tontine",
        "Valider une tontine et lancer son premier cycle.",
        "tontines",
    ),
    PermissionSpec(
        "tontine.suspend",
        "Suspendre une tontine",
        "Interrompre une tontine en cours sans la clore.",
        "tontines",
    ),
    # --- Cotisations -------------------------------------------------------
    PermissionSpec(
        "contribution.view",
        "Voir les cotisations",
        "Consulter les cotisations attendues et leur état.",
        "contributions",
    ),
    PermissionSpec(
        "contribution.create",
        "Créer une cotisation",
        "Lancer une campagne de cotisation associative ou exceptionnelle.",
        "contributions",
    ),
    PermissionSpec(
        "contribution.update",
        "Modifier une cotisation",
        "Ajuster une campagne tant qu'elle n'est pas close.",
        "contributions",
    ),
    PermissionSpec(
        "contribution.record",
        "Enregistrer un règlement",
        "Saisir le paiement d'une cotisation au nom d'un membre.",
        "contributions",
    ),
    PermissionSpec(
        "contribution.mark_paid",
        "Marquer payé",
        "Solder une cotisation contre une écriture de paiement.",
        "contributions",
    ),
    PermissionSpec(
        "contribution.mark_late",
        "Constater un retard",
        "Basculer une cotisation échue en retard.",
        "contributions",
    ),
    PermissionSpec(
        "contribution.exempt",
        "Exempter un membre",
        "Dispenser un membre d'une cotisation, sans fausser le recouvrement.",
        "contributions",
    ),
    PermissionSpec(
        "contribution.confirm",
        "Confirmer une cotisation",
        "Valider un règlement déclaré par un membre.",
        "contributions",
    ),
    PermissionSpec(
        "contribution.cancel",
        "Annuler une cotisation",
        "Annuler une ligne de cotisation erronée.",
        "contributions",
    ),
    # --- Paiements ---------------------------------------------------------
    PermissionSpec(
        "payment.view", "Voir les paiements", "Consulter le journal des règlements.", "payments"
    ),
    PermissionSpec(
        "payment.create",
        "Enregistrer un paiement",
        "Saisir un règlement reçu d'un membre.",
        "payments",
    ),
    PermissionSpec(
        "payment.confirm",
        "Confirmer un paiement",
        "Valider un règlement : il compte alors dans la caisse.",
        "payments",
    ),
    PermissionSpec(
        "payment.reject",
        "Rejeter un paiement",
        "Refuser un règlement déclaré mais non reçu.",
        "payments",
    ),
    PermissionSpec(
        "payment.cancel",
        "Annuler un paiement",
        "Annuler un règlement confirmé par erreur ; la trace subsiste.",
        "payments",
    ),
    # --- Caisse ------------------------------------------------------------
    PermissionSpec(
        "cashbox.view", "Voir la caisse", "Consulter les caisses et leurs soldes.", "cashbox"
    ),
    PermissionSpec(
        "cashbox.create", "Créer une caisse", "Ouvrir une nouvelle caisse.", "cashbox"
    ),
    PermissionSpec(
        "cashbox.update",
        "Modifier une caisse",
        "Renommer une caisse ou en changer la description.",
        "cashbox",
    ),
    PermissionSpec(
        "cashbox.close",
        "Fermer une caisse",
        "Clore une caisse : elle n'accepte plus de mouvement.",
        "cashbox",
    ),
    PermissionSpec(
        "cash_transaction.create",
        "Enregistrer un mouvement",
        "Saisir une entrée ou une sortie de caisse.",
        "cashbox",
    ),
    PermissionSpec(
        "cash_transaction.update",
        "Modifier un mouvement",
        "Corriger le libellé ou le justificatif d'un mouvement.",
        "cashbox",
    ),
    PermissionSpec(
        "cash_transaction.cancel",
        "Annuler un mouvement",
        "Annuler ou contrepasser une écriture ; rien n'est supprimé.",
        "cashbox",
    ),
    PermissionSpec(
        "treasury.view",
        "Voir la trésorerie",
        "Consulter le tableau de bord financier consolidé.",
        "cashbox",
    ),
    PermissionSpec(
        "treasury.manage",
        "Gérer la trésorerie",
        "Agir sur l'ensemble des mouvements financiers.",
        "cashbox",
    ),
    # --- Tirages -----------------------------------------------------------
    PermissionSpec("draw.view", "Voir les tirages", "Consulter les tirages et leurs résultats.", "draws"),
    PermissionSpec("draw.run", "Lancer un tirage", "Exécuter le tirage d'un cycle.", "draws"),
    PermissionSpec(
        "draw.override",
        "Forcer un tirage",
        "Passer outre les conditions de tirage, avec justification.",
        "draws",
    ),
    PermissionSpec(
        "draw.invalidate",
        "Invalider un tirage",
        "Annuler un tirage validé ; la trace subsiste.",
        "draws",
    ),
    # --- Versements --------------------------------------------------------
    PermissionSpec("payout.view", "Voir les versements", "Consulter les versements aux bénéficiaires.", "payouts"),
    PermissionSpec(
        "payout.record",
        "Enregistrer un versement",
        "Saisir le versement de la cagnotte au bénéficiaire.",
        "payouts",
    ),
    PermissionSpec(
        "payout.confirm",
        "Confirmer un versement",
        "Valider la remise effective des fonds.",
        "payouts",
    ),
    PermissionSpec(
        "payout.cancel",
        "Annuler un versement",
        "Annuler un versement erroné ; la trace subsiste.",
        "payouts",
    ),
    # --- Cotisations de caisse (plans périodiques) -------------------------
    PermissionSpec("dues.view", "Voir les cotisations de caisse", "Consulter les plans et échéances.", "dues"),
    PermissionSpec("dues.manage", "Gérer les plans de caisse", "Créer et ajuster les plans périodiques.", "dues"),
    PermissionSpec("dues.record", "Régler une échéance de caisse", "Saisir le règlement d'une échéance.", "dues"),
    # --- Relances ----------------------------------------------------------
    PermissionSpec("reminder.view", "Voir les relances", "Consulter les campagnes de relance.", "reminders"),
    PermissionSpec("reminder.send", "Envoyer une relance", "Lancer une campagne de relance.", "reminders"),
    # --- Rapports ----------------------------------------------------------
    PermissionSpec("report.view", "Voir les rapports", "Consulter les rapports financiers.", "reports"),
    # --- Audit -------------------------------------------------------------
    PermissionSpec("audit.view", "Voir le journal d'audit", "Consulter la trace de toutes les opérations.", "audit"),
    # --- Administration ----------------------------------------------------
    PermissionSpec("user.view", "Voir les comptes", "Consulter les comptes utilisateurs.", "administration"),
    PermissionSpec("user.create", "Créer un compte", "Ouvrir un compte utilisateur.", "administration"),
    PermissionSpec("user.update", "Modifier un compte", "Modifier un compte utilisateur.", "administration"),
    PermissionSpec("role.view", "Voir les rôles", "Consulter les rôles et leurs droits.", "administration"),
    PermissionSpec("role.create", "Créer un rôle", "Définir un rôle sur mesure.", "administration"),
    PermissionSpec("role.update", "Modifier un rôle", "Renommer ou désactiver un rôle.", "administration"),
    PermissionSpec("role.assign", "Attribuer un rôle", "Changer le rôle d'un membre.", "administration"),
    PermissionSpec("permission.view", "Voir les permissions", "Consulter le catalogue des droits.", "administration"),
    PermissionSpec(
        "permission.assign",
        "Attribuer des permissions",
        "Cocher les droits portés par un rôle.",
        "administration",
    ),
)

ALL_CODES: frozenset[str] = frozenset(spec.code for spec in CATALOG)

BY_CODE: dict[str, PermissionSpec] = {spec.code: spec for spec in CATALOG}


def _codes(*prefixes_or_codes: str) -> set[str]:
    """Développe des préfixes de catégorie en codes exacts.

    `"cashbox."` prend toute la famille ; `"draw.view"` prend ce seul code. La
    matrice ci-dessous y gagne en lisibilité, et une permission ajoutée au
    catalogue rejoint automatiquement les rôles qui possèdent sa famille.
    """
    selected: set[str] = set()
    for item in prefixes_or_codes:
        if item.endswith("."):
            selected |= {code for code in ALL_CODES if code.startswith(item)}
        else:
            if item not in ALL_CODES:
                raise KeyError(f"Permission inconnue dans la matrice : {item}")
            selected.add(item)
    return selected


# --- Matrice par défaut des rôles système -----------------------------------
#
# Chaque rôle hérite du précédent puis ajoute ses droits propres. Cette matrice
# ne sert qu'au **premier** seed : une fois les rôles en base, la console
# d'administration fait autorité.

MEMBER_PERMISSIONS: set[str] = _codes(
    "organization.view",
    "member.view",
    "tontine.view",
    "contribution.view",
    "payment.view",
    "draw.view",
    "payout.view",
    "reminder.view",
    "dues.view",
)

AUDITOR_PERMISSIONS: set[str] = MEMBER_PERMISSIONS | _codes(
    "cashbox.view",
    "treasury.view",
    "report.view",
    "audit.view",
)

TREASURER_PERMISSIONS: set[str] = AUDITOR_PERMISSIONS | _codes(
    "contribution.create",
    "contribution.update",
    "contribution.record",
    "contribution.mark_paid",
    "contribution.mark_late",
    "contribution.confirm",
    "contribution.cancel",
    "payment.create",
    "payment.confirm",
    "payment.reject",
    "payment.cancel",
    "cashbox.create",
    "cashbox.update",
    "cash_transaction.create",
    "cash_transaction.update",
    "cash_transaction.cancel",
    "treasury.manage",
    "payout.record",
    "payout.confirm",
    "dues.record",
    # Le trésorier tient la caisse : il ouvre et ajuste lui-même les
    # cotisations qu'il encaisse, sans passer par le back-office.
    "dues.manage",
    "reminder.send",
)

PRESIDENT_PERMISSIONS: set[str] = AUDITOR_PERMISSIONS | _codes(
    "tontine.validate",
    "tontine.suspend",
    "draw.run",
    "member.invite",
    "reminder.send",
    "role.view",
    "user.view",
    "permission.view",
)

ADMIN_PERMISSIONS: set[str] = (
    TREASURER_PERMISSIONS
    | PRESIDENT_PERMISSIONS
    | _codes(
        "organization.edit",
        "organization.manage_officers",
        "member.create",
        "member.edit",
        "member.disable",
        "member.delete",
        "tontine.create",
        "tontine.edit",
        "draw.override",
        "draw.invalidate",
        "payout.cancel",
        "cashbox.close",
        "contribution.exempt",
        "user.",
        "role.",
        "permission.",
    )
)

# Le super administrateur porte tout : il n'existe pas de droit que la
# plateforme lui refuse dans son organisation.
SUPER_ADMIN_PERMISSIONS: set[str] = set(ALL_CODES)


DEFAULT_MATRIX: dict[OrgRole, set[str]] = {
    OrgRole.SUPER_ADMIN: SUPER_ADMIN_PERMISSIONS,
    OrgRole.ORGANIZATION_ADMIN: ADMIN_PERMISSIONS,
    OrgRole.PRESIDENT: PRESIDENT_PERMISSIONS,
    OrgRole.TREASURER: TREASURER_PERMISSIONS,
    OrgRole.AUDITOR: AUDITOR_PERMISSIONS,
    OrgRole.MEMBER: MEMBER_PERMISSIONS,
}

ROLE_LABELS: dict[OrgRole, tuple[str, str]] = {
    OrgRole.SUPER_ADMIN: (
        "Super administrateur",
        "Tous les droits sur l'organisation, y compris les rôles.",
    ),
    OrgRole.ORGANIZATION_ADMIN: (
        "Administrateur",
        "Pilote l'association : membres, tontines, rôles et finances.",
    ),
    OrgRole.PRESIDENT: (
        "Président",
        "Valide les tontines et conduit les tirages.",
    ),
    OrgRole.TREASURER: (
        "Trésorier",
        "Gère la caisse, les cotisations, les paiements et les versements.",
    ),
    OrgRole.AUDITOR: (
        "Commissaire aux comptes",
        "Consulte les finances et l'audit, sans rien pouvoir modifier.",
    ),
    OrgRole.MEMBER: (
        "Membre",
        "Consulte ses cotisations, ses paiements et ses tontines.",
    ),
}
