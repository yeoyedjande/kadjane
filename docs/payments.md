# Cotisations, paiements et versements

Deux flux d'argent coexistent dans Kadjane :

* **entrant** — les membres cotisent à chaque période ;
* **sortant** — la cagnotte est versée au bénéficiaire du cycle.

---

## 1. Cotisation ≠ paiement

Le serveur sépare ce qui est **dû** de ce qui est **versé** :

| Table | Sens | Une ligne par |
|---|---|---|
| `contributions` | ce qu'un participant doit | participant × cycle |
| `payments` | ce qu'il a versé | versement (plusieurs possibles) |

L'application mobile, elle, manipule un objet unique. La conversion est faite
par `payment_as_contribution()` dans
[`app/schemas/serializers.py`](../backend/app/schemas/serializers.py) : un
paiement replacé dans le contexte de sa cotisation. Aucun mapper Dart n'a
changé.

Une tontine de 12 participants sur 12 cycles crée **144 lignes de cotisation**
à l'activation — y compris pour les cycles postérieurs à la réception de la
cagnotte : un ancien bénéficiaire continue de cotiser.

---

## 2. La règle financière

> **Seuls les paiements `confirmed` comptent.**

Un paiement `pending`, `rejected` ou `cancelled` n'augmente ni
`contribution.paid_amount`, ni `cycle.collected_amount`, ni les totaux du
tableau de bord.

Les montants stockés ne sont jamais incrémentés à la main. Après chaque
mouvement, `ContributionService.recompute_contribution()` les **recalcule**
depuis les paiements :

```
contribution.paid_amount = Σ(payments confirmés)
cycle.collected_amount   = Σ(contributions.paid_amount)
```

C'est ce qui empêche toute dérive entre le stocké et le réel. Le scénario H
(`tests/test_tontines.py::test_scenario_h_only_confirmed_payments_count`)
verrouille ce comportement.

### Statuts dérivés

| Cotisation | Condition |
|---|---|
| `paid` | payé ≥ attendu |
| `partial` | 0 < payé < attendu |
| `late` | rien payé et échéance dépassée |
| `pending` | rien payé, échéance à venir |
| `cancelled` | ligne annulée (reste dans l'historique) |

| Cycle | Condition |
|---|---|
| `collecting` | collecté < attendu |
| `ready_for_draw` | collecté ≥ attendu |
| `drawn`, `paid_out`, `closed` | scellés : la collecte ne les écrase plus |

---

## 3. Enregistrer un paiement

Deux routes, un seul service.

**Contrat mobile** — la cible est le membre et le cycle :

```http
POST /api/v1/tontines/{tontine_id}/contributions
```

```json
{
  "cycleId": "…", "memberId": "…",
  "amount": 50000, "method": "orange_money",
  "reference": "OM-9931", "status": "confirmed",
  "paidAt": "2026-08-03T10:00:00Z", "attachmentId": null
}
```

**Cahier des charges** — la cotisation est dans l'URL :

```http
POST /api/v1/contributions/{contribution_id}/payments
```

Méthodes acceptées : `cash`, `wave`, `orange_money`, `mtn_momo`,
`moov_money`, `bank_transfer`, `other`. Le justificatif est stocké dans
`proof_url` (`attachmentId` du client y est mappé).

### Opérations suivantes

| Route | Effet |
|---|---|
| `POST /contributions/{payment_id}/confirm` | le paiement compte dans la collecte |
| `POST /contributions/{payment_id}/reject` | rejeté, avec raison obligatoire |
| `POST /contributions/{payment_id}/cancel` | annulé, avec raison obligatoire |

Aucune suppression : la ligne reste dans l'historique et cesse simplement de
compter. Chaque opération est auditée (`contribution.recorded`,
`contribution.confirmed`, `contribution.cancelled`).

---

## 4. Lire les cotisations

| Route | Vue |
|---|---|
| `GET /cycles/{id}/contribution-slots` | une ligne par participant, payée ou non |
| `GET /tontines/{id}/cycles/{cycleId}/contributions` | attendu / payé / restant par participant |
| `GET /cycles/{id}/contributions` | les paiements du cycle |
| `GET /organizations/{org}/members/{id}/contributions` | les paiements d'un membre |

Filtres : `status`, `search`. La vue « attendues » renvoie aussi les totaux
dans `meta` :

```json
"meta": { "expected": 600000, "collected": 550000, "remaining": 50000,
          "paid_count": 11, "late_count": 0, "total": 12 }
```

C'est ce qui alimente l'écran Cotisations : *Attendu, Collecté, Restant,
Payés, En retard*, puis la liste nominative.

---

## 5. Verser la cagnotte

```http
POST /api/v1/payouts
{ "beneficiaryId": "…", "amount": 600000, "method": "wave", "reference": "WV-88120", "status": "pending" }
```

```http
POST /api/v1/payouts/{id}/confirm
POST /api/v1/payouts/{id}/fail      { "reason": "…" }
```

À la confirmation :

* `beneficiary.status` → `paid` ;
* `cycle.status` → `paid_out` ;
* audit `payout.confirmed`.

Un versement en échec repasse le bénéficiaire en `designated` et rouvre le
cycle en `drawn` — jamais de suppression silencieuse d'une écriture
financière.

> Statuts : le cahier des charges parle de `CONFIRMED`, le contrat mobile de
> `paid`. L'API accepte les deux en entrée et renvoie toujours `paid`.
> L'annulation est un `failed` porteur de sa raison.

---

## 6. Journal d'audit

`GET /api/v1/organizations/{id}/audit-logs?tontineId=&actions=&limit=`

Actions tracées, avec organisation, acteur, cible, montant, horodatage et
métadonnées :

```
tontine.created          tontine.status_changed
contribution.recorded    contribution.confirmed    contribution.cancelled
draw.completed           draw.overridden           draw.invalidated
beneficiary.designated   order.generated
payout.recorded          payout.confirmed
```

L'audit est écrit **dans la transaction de l'opération** : si l'opération
échoue, la trace n'est pas écrite ; si elle réussit, la trace existe toujours.

---

## 7. Transactions

Les opérations critiques sont atomiques : création et activation d'une
tontine (avec génération des cycles et des 144 cotisations), enregistrement et
confirmation d'un paiement, tirage complet, versement. Une erreur ne laisse
jamais la base à moitié modifiée.
