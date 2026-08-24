# Trésorerie — caisses, cotisations, paiements

## Le principe qui structure tout

Trois notions, à ne jamais confondre :

| Notion | Ce que c'est |
|---|---|
| **Cotisation** | un **engagement** : ce que l'association attend |
| **Paiement** | une **transaction réelle** : ce qu'elle a reçu |
| **Caisse** | les **fonds détenus** |

```
Cotisation attendue : 60 000 FCFA
        ≠
Argent encaissé     : 40 000 FCFA
        ≠
Solde de la caisse  : ce qui reste après les dépenses
```

La caisse n'augmente **que** lorsqu'un paiement est enregistré. Les tableaux de
bord distinguent donc quatre nombres : `expected`, `collected`, `remaining`,
`lateAmount`.

---

## 1. Caisses

`cashboxes` — une organisation peut en avoir plusieurs : « Caisse principale »,
« Caisse sociale », « Événements ».

| Champ | Note |
|---|---|
| `name` | unique dans l'organisation |
| `opening_balance` | solde au moment de l'ouverture |
| `status` | `open` · `closed` · `suspended` |
| `is_default` | destinataire d'un encaissement dont personne n'a précisé la caisse |

### Le solde n'est pas stocké

```
solde = solde d'ouverture
      + entrées confirmées
      - sorties confirmées
```

Il n'existe **pas** de colonne `current_balance`. Un total dénormalisé finit
toujours par diverger du journal le jour où une écriture est annulée sans
repasser par le service — et c'est le journal qui fait foi. Le champ
`currentBalance` de l'API est calculé à la lecture.

> Le cahier des charges listait `current_balance` parmi les colonnes. C'est le
> seul écart assumé du modèle, et il va dans le sens de sa propre règle §19 :
> « le solde ne doit pas être modifié arbitrairement ».

### Fermeture

Une caisse fermée refuse tout mouvement (409 `cashbox_closed`). Son solde
résiduel reste lisible : fermer ne fait pas disparaître l'argent. Le vider
proprement se fait par un transfert vers une autre caisse.

---

## 2. Mouvements de caisse

`cash_transactions` — deux origines, une seule table :

* la **saisie manuelle** du trésorier (don, frais, événement) ;
* l'écriture **engendrée** par un règlement de cotisation confirmé, qui porte
  alors `campaign_payments.cash_transaction_id`.

C'est ce lien qui interdit la double saisie.

| Type | Effet sur le solde |
|---|---|
| `income` | `+ montant` |
| `expense` | `- montant` |
| `transfer` | `- montant` (l'entrée dans l'autre caisse est une seconde ligne) |
| `adjustment` | signe **porté par le montant** — une correction d'inventaire va dans les deux sens |

### Aucune suppression

Une écriture financière ne se supprime pas. Elle passe à :

* `cancelled` — saisie erronée ;
* `reversed` — écriture valide, neutralisée par décision.

Ni l'une ni l'autre ne compte dans le solde ; les deux restent dans le journal
et dans l'audit. Le journal les montre par défaut : les masquer rendrait
incompréhensible tout écart qu'on chercherait à expliquer.

---

## 3. Les quatre natures de cotisation

Le mot « cotisation » recouvre quatre réalités, et elles ne vont pas au même
endroit.

| Nature | Table | Destination des fonds |
|---|---|---|
| **Tontine** | `contributions` + `payments` | la **cagnotte du cycle**, versée au bénéficiaire |
| **Association** ponctuelle | `contribution_campaigns` | une **caisse** |
| **Exceptionnelle** | `contribution_campaigns` | une **caisse** |
| **Volontaire** | `contribution_campaigns` | une **caisse** |
| Association **périodique** | `dues_plans` + `dues_entries` | l'association |

> **Les fonds de tontine ne se mélangent jamais à la caisse de l'association.**
> `ContributionType.TONTINE.feeds_cashbox` vaut faux, et aucune écriture de
> caisse n'est produite pour ce type.

`dues_plans` reste en place pour le cas **périodique** — il engendre une
échéance par période — là où une campagne en pose une seule. Les deux
coexistent plutôt que l'un remplace l'autre : migrer les plans existants
aurait cassé un parcours opérationnel pour un gain de cohérence théorique.

---

## 4. Campagnes de cotisation

`contribution_campaigns` :

| Champ | Note |
|---|---|
| `contribution_type` | `tontine` · `association` · `exceptional` · `voluntary` |
| `amount_mode` | `fixed` ou `free` |
| `cashbox_id` | caisse destinataire ; nulle pour une campagne de tontine |
| `mandatory`, `penalty_enabled`, `penalty_amount` | |
| `status` | `draft` · `active` · `closed` · `cancelled` |

Une campagne à **montant libre** n'a pas d'attendu : tout versement la solde,
et `recoveryRate` vaut `null` — ni 0 % ni 100 % ne diraient la vérité.

### Membres concernés

`memberIds` absent vise **tous les membres actifs**. Une liste vide est
refusée : une cotisation sans destinataire résulte presque toujours d'un
formulaire mal renvoyé.

### Suivi individuel

`campaign_entries` — une ligne par membre concerné :

```
Cotisation : Fonctionnement septembre

YEO        10 000 / 10 000   PAYÉ
Membre B    5 000 / 10 000   PARTIEL
Membre C        0 / 10 000   EN RETARD
```

| Statut | Sens |
|---|---|
| `pending` | rien reçu, échéance à venir |
| `partial` | versement incomplet |
| `paid` | soldé |
| `late` | échéance dépassée et reste dû |
| `exempted` | dispensé — **sort de l'attendu**, n'est pas un impayé |
| `cancelled` | ligne annulée |

`paid_amount` est un cumul **dérivé** des paiements confirmés, recalculé par le
service. Il n'est jamais incrémenté : annuler un règlement remet le compte
juste sans arithmétique inverse, qui finit toujours par dériver.

Le retard **prime** sur le partiel : c'est le retard qui appelle une relance,
et un règlement incomplet ne le fait pas disparaître.

Les retards sont constatés **à la lecture** (`refresh_late`), pas par une tâche
planifiée : l'exactitude de ce que l'écran affiche ne dépend ainsi d'aucun
ordonnanceur.

---

## 5. Une saisie, sept effets

Le cœur du module. Le trésorier saisit **une** fois « YEO a payé 10 000 FCFA »,
et tout en découle, dans la **même transaction** :

1. le règlement est enregistré (`campaign_payments`) ;
2. le suivi du membre est mis à jour ;
3. le reste à payer est recalculé ;
4. le statut est recalculé ;
5. l'écriture de caisse est créée ;
6. le solde de la caisse s'en trouve modifié ;
7. l'audit garde la trace — et une notification part.

Si une seule étape échoue, aucune ne subsiste : une caisse créditée sans
règlement, ou l'inverse, serait pire qu'une erreur visible.

### Paiements partiels

```
Attendu : 50 000

+ 20 000  →  20 000 / 50 000   reste 30 000   PARTIEL
+ 30 000  →  50 000 / 50 000   reste 0        PAYÉ
```

Deux lignes distinctes dans l'historique, jamais fusionnées.

Le **trop-perçu est refusé** (409 `amount_exceeds_remaining`) plutôt que rogné :
c'est presque toujours une faute de frappe, et un montant amputé en silence se
découvre trop tard.

### Annulation

Annuler un règlement **contrepasse** son écriture de caisse (`reversed`) et
recalcule le suivi du membre. Rien n'est supprimé.

---

## 6. Endpoints

### Caisses

| Méthode | Route | Permission |
|---|---|---|
| GET | `/organizations/{id}/cashboxes` | `cashbox.view` |
| POST | `/organizations/{id}/cashboxes` | `cashbox.create` |
| GET | `/cashboxes/{id}` | `cashbox.view` |
| PATCH | `/cashboxes/{id}` | `cashbox.update` |
| POST | `/cashboxes/{id}/close` | `cashbox.close` |
| GET | `/cashboxes/{id}/transactions` | `cashbox.view` |
| POST | `/cashboxes/{id}/transactions` | `cash_transaction.create` |
| POST | `/cash-transactions/{id}/cancel` | `cash_transaction.cancel` |

### Cotisations

| Méthode | Route | Permission |
|---|---|---|
| GET | `/organizations/{id}/contribution-campaigns` | `contribution.view` |
| POST | `/organizations/{id}/contribution-campaigns` | `contribution.create` |
| GET | `/contribution-campaigns/{id}` | `contribution.view` |
| PATCH | `/contribution-campaigns/{id}` | `contribution.update` |
| GET | `/contribution-campaigns/{id}/entries` | `contribution.view` |
| GET | `/contribution-entries/{id}` | `contribution.view` |
| POST | `/contribution-entries/{id}/payments` | `payment.create` **ou** `contribution.record` |
| POST | `/contribution-entries/{id}/exempt` | `contribution.exempt` |
| POST | `/contribution-payments/{id}/cancel` | `payment.cancel` |
| GET | `/organizations/{id}/unpaid` | `contribution.view` |
| GET | `/organizations/{id}/financial-dashboard` | `treasury.view` |

Les listes acceptent `limit` et `offset`, et renvoient `meta.total`.

---

## 7. Le trésorier

Ce que le rôle `treasurer` peut faire par défaut — voir
[`permissions.md`](permissions.md) pour la matrice complète :

voir et créer des caisses, enregistrer entrées et sorties, créer et modifier
des cotisations, enregistrer et confirmer des paiements, constater un retard,
consulter les impayés, enregistrer et confirmer des versements, lire les
rapports financiers.

Ce qu'il ne peut **pas** : gérer les rôles, attribuer des permissions, fermer
une caisse, exempter un membre. Ces quatre-là relèvent de l'administrateur.

---

## 8. Audit

Chaque opération financière laisse une trace : `cashbox.created`,
`cashbox.updated`, `cashbox.closed`, `transaction.recorded`,
`transaction.cancelled`, `campaign.created`, `campaign.closed`,
`campaign.payment_recorded`, `campaign.payment_cancelled`,
`campaign.member_exempted`.

Un règlement de cotisation produit **une seule** entrée d'audit, pas deux :
l'écriture de caisse qu'il engendre n'en écrit pas une de plus, sinon on lirait
deux opérations là où le trésorier n'en a fait qu'une.
