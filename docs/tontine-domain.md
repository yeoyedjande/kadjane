# Domaine tontine

Ce document décrit le cœur métier de Kadjane tel qu'il est implémenté dans
`backend/app/`. Il fait autorité : l'application mobile ne décide de rien.

```
Organisation → Tontine → Participants → Cycles → Cotisations → Paiements
                                          ↓
                                       Cagnotte → Tirage → Bénéficiaire → Versement
```

---

## 1. La règle qui définit Kadjane

> **Recevoir la cagnotte ne fait pas sortir de la tontine.**

Après le tirage, le bénéficiaire :

| Champ | Valeur | Conséquence |
|---|---|---|
| `has_received_payout` | `true` | il a touché sa cagnotte |
| `is_draw_eligible` | `false` | il **disparaît de la roue** des périodes suivantes |
| `is_active` | **`true`** | il **continue de cotiser** jusqu'à la fin |

Il reste donc visible dans les membres, dans les participants, dans les
cotisations de chaque cycle suivant et dans tous les historiques. Cette règle
est verrouillée par les tests
`tests/test_draw.py::test_scenario_a_winner_leaves_the_wheel_but_stays_active`
et `::test_scenario_b_winner_still_owes_the_next_cycle`.

---

## 2. Modes d'attribution

| Mode | Valeur d'API | Fonctionnement |
|---|---|---|
| Tirage périodique | `monthly_draw` | Un tirage à chaque cycle parmi les éligibles restants |
| Ordre complet tiré | `full_order_draw` | Un tirage unique au démarrage fixe l'ordre des 12 passages |
| Ordre manuel | `manual_order` | Le bureau fournit l'ordre ; il est validé puis figé |

`monthly_draw` est le mode principal de l'association. Dans les deux autres,
le bénéficiaire d'un cycle est le participant dont `draw_position` égale le
`sequence_number` du cycle — le « tirage » ne fait que constater cet ordre.

L'ordre, une fois défini, ne se modifie pas en silence : le regénérer renvoie
`409 orderAlreadyDefined`, et toute définition manuelle est auditée
(`order.generated`).

---

## 3. Modèle de données

| Table | Rôle |
|---|---|
| `tontines` | Paramètres : montant, fréquence, mode, règles de tirage |
| `tontine_participants` | Qui participe, éligibilité, position d'ordre |
| `tontine_cycles` | Une période de collecte (« Août 2026 ») |
| `contributions` | Ce qu'un participant **doit** pour un cycle |
| `payments` | Ce qu'il a **versé** (plusieurs versements possibles) |
| `draw_sessions` + `draw_participants` | Preuve du tirage et roue figée |
| `beneficiaries` | Désigné pour recevoir la cagnotte d'un cycle |
| `payouts` | Versement effectif de la cagnotte |
| `audit_logs` | Journal inaltérable des opérations sensibles |

### Statuts

```
tontine   draft → pending → active → suspended → completed | cancelled
cycle     upcoming → collecting → ready_for_draw → drawn → paid_out → closed
cotisation pending | partial | paid | late | cancelled
paiement  pending | confirmed | rejected | cancelled
tirage    scheduled | completed | cancelled | invalidated
bénéf.    designated | payout_pending | paid | cancelled
versement pending | processing | paid | failed
```

> Le cahier des charges parle de `CONFIRMED` pour un versement ; le contrat
> mobile utilise `paid`. L'API accepte les deux en entrée et renvoie toujours
> `paid`.

---

## 4. Cagnotte

Elle n'est **jamais** écrite en dur :

```
cagnotte = nombre de participants actifs × montant de cotisation
```

12 × 50 000 = **600 000 FCFA**. Le calcul vit dans `Tontine.pot_for()`
(`app/models/tontine.py`) et alimente `cycle.expected_amount` à la génération
des cycles.

---

## 5. Activation et génération des cycles

`POST /organizations/{id}/tontines` crée la tontine, inscrit les participants
et — sauf `"activate": false` — l'active immédiatement. L'activation, dans une
seule transaction :

1. vérifie qu'il y a au moins deux participants ;
2. génère **un cycle par participant** (12 participants → 12 cycles) ;
3. calcule `expected_amount` de chaque cycle ;
4. crée **toutes** les lignes de cotisation : `participants × cycles`
   (12 × 12 = 144), y compris les cycles postérieurs à la réception de la
   cagnotte ;
5. tire l'ordre complet si le mode est `full_order_draw` ;
6. journalise `tontine.created` puis `tontine.status_changed`.

Le découpage en périodes est dans `app/services/period_service.py` :
mensuel (mois calendaire, échéance au `due_day`), hebdomadaire, quinzaine, ou
durée libre. Les libellés sont français : « Août 2026 ».

Après activation, `contribution_amount`, `frequency`, `start_date` et
`custom_period_days` sont verrouillés (`409 tontine_locked`) : les cycles et
cotisations déjà générés en dépendent.

---

## 6. Permissions

Le backend contrôle, l'application ne fait qu'adapter l'affichage.

| Action | Permission requise |
|---|---|
| Voir les tontines, cycles, cotisations | `tontine.view`, `contribution.view` |
| Créer / modifier une tontine | `tontine.create`, `tontine.edit` |
| Activer, changer le statut | `tontine.validate` |
| Enregistrer / confirmer / annuler un paiement | `contribution.record`, `.confirm`, `.cancel` |
| Lancer un tirage | `draw.run` |
| Forcer un tirage | `draw.override` |
| Invalider un tirage | `draw.invalidate` |
| Enregistrer un versement | `payout.record` |

Par rôle : l'administrateur et le président pilotent la tontine et le tirage,
le trésorier tient les cotisations, les paiements et les versements,
l'auditeur lit les données financières, le membre lit ce qui le concerne.

---

## 7. Isolation multi-association

Les routes `/tontines/{id}/…` et `/cycles/{id}/…` ne portent pas
l'organisation dans l'URL. Elle est **déduite de la ressource**, puis
l'appartenance de l'appelant est vérifiée (`get_tontine_context`,
`get_cycle_context` dans `app/core/deps.py`). Sans appartenance : **404**.

Un membre d'une autre organisation ne peut ni lire la tontine, ni ses cycles,
ni ses cotisations, ni lancer son tirage — c'est le scénario G de
`tests/test_draw.py`.

---

## 8. Ce qui reste à faire

| Sujet | État |
|---|---|
| Trésorerie et rapports | Encore servis à zéro (`app/api/v1/pending.py`) |
| Relances et notifications | Contrat prêt, envoi à brancher |
| Justificatifs | `proof_url` stocké ; upload S3 à écrire |
| Clôture automatique d'une tontine | Le dernier cycle versé ne bascule pas encore la tontine en `completed` |
