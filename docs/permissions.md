# Catalogue des permissions

> **Fichier engendré.** Source : `backend/app/rbac/catalog.py`.
> Le régénérer après toute modification du catalogue :
>
> ```bash
> cd backend && .venv/Scripts/python -m app.rbac.docgen
> ```

61 permissions, réparties en 13 catégories.

Colonnes : **Mbr** membre · **Aud** commissaire aux comptes · **Tré** trésorier · **Pré** président · **Adm** administrateur.

Ces cases sont les valeurs **par défaut**, posées au premier seed. Une fois les rôles en base, c'est le back-office qui fait autorité — voir [`rbac.md`](rbac.md).

## Organisation

| Code | Libellé | Mbr | Aud | Tré | Pré | Adm |
|---|---|---|---|---|---|---|
| `organization.view` | Voir l'organisation | ☑ | ☑ | ☑ | ☑ | ☑ |
| `organization.edit` | Modifier l'organisation | ☐ | ☐ | ☐ | ☐ | ☑ |
| `organization.manage_officers` | Gérer le bureau | ☐ | ☐ | ☐ | ☐ | ☑ |

- **`organization.view`** — Consulter la fiche et les réglages de l'association.
- **`organization.edit`** — Changer le nom, les coordonnées et les règles de l'association.
- **`organization.manage_officers`** — Désigner président, trésorier et commissaire aux comptes.

## Membres

| Code | Libellé | Mbr | Aud | Tré | Pré | Adm |
|---|---|---|---|---|---|---|
| `member.view` | Voir les membres | ☑ | ☑ | ☑ | ☑ | ☑ |
| `member.create` | Ajouter un membre | ☐ | ☐ | ☐ | ☐ | ☑ |
| `member.edit` | Modifier un membre | ☐ | ☐ | ☐ | ☐ | ☑ |
| `member.invite` | Inviter un membre | ☐ | ☐ | ☐ | ☑ | ☑ |
| `member.disable` | Désactiver un membre | ☐ | ☐ | ☐ | ☐ | ☑ |
| `member.delete` | Supprimer un membre | ☐ | ☐ | ☐ | ☐ | ☑ |

- **`member.view`** — Consulter la liste et les fiches.
- **`member.create`** — Créer un compte membre et lui remettre un accès.
- **`member.edit`** — Corriger l'identité et les informations d'un membre.
- **`member.invite`** — Proposer à une personne de rejoindre l'association.
- **`member.disable`** — Suspendre l'accès sans effacer l'historique financier.
- **`member.delete`** — Retirer définitivement un membre sans historique financier.

## Tontines

| Code | Libellé | Mbr | Aud | Tré | Pré | Adm |
|---|---|---|---|---|---|---|
| `tontine.view` | Voir les tontines | ☑ | ☑ | ☑ | ☑ | ☑ |
| `tontine.create` | Créer une tontine | ☐ | ☐ | ☐ | ☐ | ☑ |
| `tontine.edit` | Modifier une tontine | ☐ | ☐ | ☐ | ☐ | ☑ |
| `tontine.validate` | Activer une tontine | ☐ | ☐ | ☐ | ☑ | ☑ |
| `tontine.suspend` | Suspendre une tontine | ☐ | ☐ | ☐ | ☑ | ☑ |

- **`tontine.view`** — Consulter les tontines et leurs cycles.
- **`tontine.create`** — Ouvrir une nouvelle tontine.
- **`tontine.edit`** — Ajuster le paramétrage d'une tontine.
- **`tontine.validate`** — Valider une tontine et lancer son premier cycle.
- **`tontine.suspend`** — Interrompre une tontine en cours sans la clore.

## Cotisations

| Code | Libellé | Mbr | Aud | Tré | Pré | Adm |
|---|---|---|---|---|---|---|
| `contribution.view` | Voir les cotisations | ☑ | ☑ | ☑ | ☑ | ☑ |
| `contribution.create` | Créer une cotisation | ☐ | ☐ | ☑ | ☐ | ☑ |
| `contribution.update` | Modifier une cotisation | ☐ | ☐ | ☑ | ☐ | ☑ |
| `contribution.record` | Enregistrer un règlement | ☐ | ☐ | ☑ | ☐ | ☑ |
| `contribution.mark_paid` | Marquer payé | ☐ | ☐ | ☑ | ☐ | ☑ |
| `contribution.mark_late` | Constater un retard | ☐ | ☐ | ☑ | ☐ | ☑ |
| `contribution.exempt` | Exempter un membre | ☐ | ☐ | ☐ | ☐ | ☑ |
| `contribution.confirm` | Confirmer une cotisation | ☐ | ☐ | ☑ | ☐ | ☑ |
| `contribution.cancel` | Annuler une cotisation | ☐ | ☐ | ☑ | ☐ | ☑ |

- **`contribution.view`** — Consulter les cotisations attendues et leur état.
- **`contribution.create`** — Lancer une campagne de cotisation associative ou exceptionnelle.
- **`contribution.update`** — Ajuster une campagne tant qu'elle n'est pas close.
- **`contribution.record`** — Saisir le paiement d'une cotisation au nom d'un membre.
- **`contribution.mark_paid`** — Solder une cotisation contre une écriture de paiement.
- **`contribution.mark_late`** — Basculer une cotisation échue en retard.
- **`contribution.exempt`** — Dispenser un membre d'une cotisation, sans fausser le recouvrement.
- **`contribution.confirm`** — Valider un règlement déclaré par un membre.
- **`contribution.cancel`** — Annuler une ligne de cotisation erronée.

## Paiements

| Code | Libellé | Mbr | Aud | Tré | Pré | Adm |
|---|---|---|---|---|---|---|
| `payment.view` | Voir les paiements | ☑ | ☑ | ☑ | ☑ | ☑ |
| `payment.create` | Enregistrer un paiement | ☐ | ☐ | ☑ | ☐ | ☑ |
| `payment.confirm` | Confirmer un paiement | ☐ | ☐ | ☑ | ☐ | ☑ |
| `payment.reject` | Rejeter un paiement | ☐ | ☐ | ☑ | ☐ | ☑ |
| `payment.cancel` | Annuler un paiement | ☐ | ☐ | ☑ | ☐ | ☑ |

- **`payment.view`** — Consulter le journal des règlements.
- **`payment.create`** — Saisir un règlement reçu d'un membre.
- **`payment.confirm`** — Valider un règlement : il compte alors dans la caisse.
- **`payment.reject`** — Refuser un règlement déclaré mais non reçu.
- **`payment.cancel`** — Annuler un règlement confirmé par erreur ; la trace subsiste.

## Caisse et trésorerie

| Code | Libellé | Mbr | Aud | Tré | Pré | Adm |
|---|---|---|---|---|---|---|
| `cashbox.view` | Voir la caisse | ☐ | ☑ | ☑ | ☑ | ☑ |
| `cashbox.create` | Créer une caisse | ☐ | ☐ | ☑ | ☐ | ☑ |
| `cashbox.update` | Modifier une caisse | ☐ | ☐ | ☑ | ☐ | ☑ |
| `cashbox.close` | Fermer une caisse | ☐ | ☐ | ☐ | ☐ | ☑ |
| `cash_transaction.create` | Enregistrer un mouvement | ☐ | ☐ | ☑ | ☐ | ☑ |
| `cash_transaction.update` | Modifier un mouvement | ☐ | ☐ | ☑ | ☐ | ☑ |
| `cash_transaction.cancel` | Annuler un mouvement | ☐ | ☐ | ☑ | ☐ | ☑ |
| `treasury.view` | Voir la trésorerie | ☐ | ☑ | ☑ | ☑ | ☑ |
| `treasury.manage` | Gérer la trésorerie | ☐ | ☐ | ☑ | ☐ | ☑ |

- **`cashbox.view`** — Consulter les caisses et leurs soldes.
- **`cashbox.create`** — Ouvrir une nouvelle caisse.
- **`cashbox.update`** — Renommer une caisse ou en changer la description.
- **`cashbox.close`** — Clore une caisse : elle n'accepte plus de mouvement.
- **`cash_transaction.create`** — Saisir une entrée ou une sortie de caisse.
- **`cash_transaction.update`** — Corriger le libellé ou le justificatif d'un mouvement.
- **`cash_transaction.cancel`** — Annuler ou contrepasser une écriture ; rien n'est supprimé.
- **`treasury.view`** — Consulter le tableau de bord financier consolidé.
- **`treasury.manage`** — Agir sur l'ensemble des mouvements financiers.

## Tirages

| Code | Libellé | Mbr | Aud | Tré | Pré | Adm |
|---|---|---|---|---|---|---|
| `draw.view` | Voir les tirages | ☑ | ☑ | ☑ | ☑ | ☑ |
| `draw.run` | Lancer un tirage | ☐ | ☐ | ☐ | ☑ | ☑ |
| `draw.override` | Forcer un tirage | ☐ | ☐ | ☐ | ☐ | ☑ |
| `draw.invalidate` | Invalider un tirage | ☐ | ☐ | ☐ | ☐ | ☑ |

- **`draw.view`** — Consulter les tirages et leurs résultats.
- **`draw.run`** — Exécuter le tirage d'un cycle.
- **`draw.override`** — Passer outre les conditions de tirage, avec justification.
- **`draw.invalidate`** — Annuler un tirage validé ; la trace subsiste.

## Versements

| Code | Libellé | Mbr | Aud | Tré | Pré | Adm |
|---|---|---|---|---|---|---|
| `payout.view` | Voir les versements | ☑ | ☑ | ☑ | ☑ | ☑ |
| `payout.record` | Enregistrer un versement | ☐ | ☐ | ☑ | ☐ | ☑ |
| `payout.confirm` | Confirmer un versement | ☐ | ☐ | ☑ | ☐ | ☑ |
| `payout.cancel` | Annuler un versement | ☐ | ☐ | ☐ | ☐ | ☑ |

- **`payout.view`** — Consulter les versements aux bénéficiaires.
- **`payout.record`** — Saisir le versement de la cagnotte au bénéficiaire.
- **`payout.confirm`** — Valider la remise effective des fonds.
- **`payout.cancel`** — Annuler un versement erroné ; la trace subsiste.

## Cotisations de caisse (plans périodiques)

| Code | Libellé | Mbr | Aud | Tré | Pré | Adm |
|---|---|---|---|---|---|---|
| `dues.view` | Voir les cotisations de caisse | ☑ | ☑ | ☑ | ☑ | ☑ |
| `dues.manage` | Gérer les plans de caisse | ☐ | ☐ | ☐ | ☐ | ☑ |
| `dues.record` | Régler une échéance de caisse | ☐ | ☐ | ☑ | ☐ | ☑ |

- **`dues.view`** — Consulter les plans et échéances.
- **`dues.manage`** — Créer et ajuster les plans périodiques.
- **`dues.record`** — Saisir le règlement d'une échéance.

## Relances

| Code | Libellé | Mbr | Aud | Tré | Pré | Adm |
|---|---|---|---|---|---|---|
| `reminder.view` | Voir les relances | ☑ | ☑ | ☑ | ☑ | ☑ |
| `reminder.send` | Envoyer une relance | ☐ | ☐ | ☑ | ☑ | ☑ |

- **`reminder.view`** — Consulter les campagnes de relance.
- **`reminder.send`** — Lancer une campagne de relance.

## Rapports

| Code | Libellé | Mbr | Aud | Tré | Pré | Adm |
|---|---|---|---|---|---|---|
| `report.view` | Voir les rapports | ☐ | ☑ | ☑ | ☑ | ☑ |

- **`report.view`** — Consulter les rapports financiers.

## Audit

| Code | Libellé | Mbr | Aud | Tré | Pré | Adm |
|---|---|---|---|---|---|---|
| `audit.view` | Voir le journal d'audit | ☐ | ☑ | ☑ | ☑ | ☑ |

- **`audit.view`** — Consulter la trace de toutes les opérations.

## Administration

| Code | Libellé | Mbr | Aud | Tré | Pré | Adm |
|---|---|---|---|---|---|---|
| `user.view` | Voir les comptes | ☐ | ☐ | ☐ | ☑ | ☑ |
| `user.create` | Créer un compte | ☐ | ☐ | ☐ | ☐ | ☑ |
| `user.update` | Modifier un compte | ☐ | ☐ | ☐ | ☐ | ☑ |
| `role.view` | Voir les rôles | ☐ | ☐ | ☐ | ☑ | ☑ |
| `role.create` | Créer un rôle | ☐ | ☐ | ☐ | ☐ | ☑ |
| `role.update` | Modifier un rôle | ☐ | ☐ | ☐ | ☐ | ☑ |
| `role.assign` | Attribuer un rôle | ☐ | ☐ | ☐ | ☐ | ☑ |
| `permission.view` | Voir les permissions | ☐ | ☐ | ☐ | ☑ | ☑ |
| `permission.assign` | Attribuer des permissions | ☐ | ☐ | ☐ | ☐ | ☑ |

- **`user.view`** — Consulter les comptes utilisateurs.
- **`user.create`** — Ouvrir un compte utilisateur.
- **`user.update`** — Modifier un compte utilisateur.
- **`role.view`** — Consulter les rôles et leurs droits.
- **`role.create`** — Définir un rôle sur mesure.
- **`role.update`** — Renommer ou désactiver un rôle.
- **`role.assign`** — Changer le rôle d'un membre.
- **`permission.view`** — Consulter le catalogue des droits.
- **`permission.assign`** — Cocher les droits portés par un rôle.
