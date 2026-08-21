# Système de tirage

Le tirage est l'opération la plus sensible de Kadjane : elle décide qui reçoit
600 000 FCFA. Elle est donc **entièrement calculée et scellée par le serveur**.

---

## 1. Qui décide

```
Flutter                      FastAPI                       PostgreSQL
   │                            │                              │
   │  POST .../draws            │                              │
   ├───────────────────────────►│                              │
   │                            │  verrou du cycle             │
   │                            ├─────────────────────────────►│
   │                            │  reconstruit les éligibles   │
   │                            │  secrets.choice(...)         │
   │                            │  écrit tirage + bénéficiaire │
   │                            ├─────────────────────────────►│
   │  winnerParticipantId       │                              │
   │◄───────────────────────────┤                              │
   │                            │                              │
   │  anime la roue vers ce gagnant — et rien d'autre          │
```

L'application ne choisit rien : [draw_screen.dart](../lib/features/draw/presentation/screens/draw_screen.dart)
appelle `drawRepository.run(...)`, cherche l'index de `winnerParticipantId`
dans `session.participants`, puis lance l'animation vers ce segment. Le design
de la roue est inchangé ; seule sa source de vérité l'est.

---

## 2. Aléa

```python
secrets.choice(eligible_participants)   # app/services/draw_service.py
```

`secrets` est le générateur cryptographique de Python — imprévisible et non
rejouable. Le champ `randomSourceLabel` vaut `server_secrets_choice` dans la
réponse, ce qui rend la source vérifiable a posteriori.

**Une graine envoyée par le client est ignorée.** Le contrat mobile prévoit un
champ `seed` ; l'accepter reviendrait à laisser l'appelant influencer le
résultat. Le serveur ne le lit pas et stocke `seed = null`.

Pour l'ordre complet (`full_order_draw`), le mélange utilise
`secrets.SystemRandom().shuffle`.

---

## 3. Éligibilité

Le serveur **reconstruit la liste depuis PostgreSQL** — il ne fait jamais
confiance à ce que le client envoie :

```sql
is_active = true AND is_draw_eligible = true AND has_received_payout = false
```

`GET /api/v1/tontines/{id}/cycles/{cycleId}/draw-eligibility`
(alias `…/draw/eligibility`) :

```json
{
  "success": true,
  "data": {
    "allowed": false,
    "reason": "missingContributions",
    "missingContributions": 1,
    "canOverride": true,

    "can_draw": false,
    "participants_count": 12,
    "eligible_count": 12,
    "eligible_participants": [{ "participantId": "…", "displayName": "…" }],
    "remaining_contributions": 1,
    "remaining_amount": 50000,
    "override_allowed": true
  }
}
```

Les clés camelCase servent le contrat mobile, les snake_case le vocabulaire du
cahier des charges backend. Raisons possibles : `none`, `tontineNotActive`,
`alreadyDrawn`, `missingContributions`, `noEligibleParticipant`,
`orderAlreadyDefined`.

---

## 4. Déroulé de `POST /tontines/{id}/draws`

Corps : `{ "cycleId": "...", "override": false, "overrideReason": null }`
(alias : `POST /tontines/{id}/cycles/{cycleId}/draw`).

Le tout dans **une seule transaction** :

1. authentification, puis appartenance à l'organisation de la tontine ;
2. permission `draw.run` ;
3. **verrou de ligne** sur le cycle (`SELECT … FOR UPDATE`) ;
4. tontine active ? sinon `409 tontineNotActive` ;
5. tirage déjà validé sur ce cycle ? `409 alreadyDrawn` ;
6. éligibles reconstruits ; aucun ? `409 noEligibleParticipant` ;
7. cotisations complètes ? sinon `409 missingContributions` (ou override) ;
8. `secrets.choice` → gagnant ;
9. écriture de `draw_sessions` + `draw_participants` (roue figée) ;
10. gagnant : `has_received_payout = true`, `is_draw_eligible = false`,
    **`is_active` reste `true`** ;
11. création du `beneficiaries` (`designated`, montant = cagnotte du cycle) ;
12. cycle → `drawn` ;
13. audit : `draw.completed`, `beneficiary.designated`, plus
    `draw.overridden` si forçage ;
14. `commit`.

Une erreur à n'importe quelle étape annule tout : jamais de bénéficiaire sans
tirage, ni l'inverse.

---

## 5. Double tirage : trois verrous

| Niveau | Mécanisme |
|---|---|
| Applicatif | `alreadyDrawn` vérifié après le verrou |
| Transactionnel | `SELECT … FOR UPDATE` sur le cycle : les requêtes concurrentes se sérialisent |
| Base | Index **unique partiel** `uq_draw_sessions_completed_cycle` sur `draw_sessions(cycle_id) WHERE status = 'completed'` |

Un `IntegrityError` remonté par le troisième verrou est traduit en
`409 alreadyDrawn` — donc même un contournement du code applicatif ne peut pas
créer deux gagnants. `beneficiaries` porte la même protection
(`uq_beneficiaries_active_cycle … WHERE status <> 'cancelled'`).

Double clic, rejeu réseau, deux requêtes simultanées : un seul gagnant.

---

## 6. Forcer un tirage

Possible seulement si **toutes** ces conditions sont réunies :

* `tontine.allow_draw_override = true` (sinon `409 override_disabled`) ;
* l'appelant a la permission `draw.override` ;
* une justification est fournie (sinon `409 override_reason_required`).

```json
{ "cycleId": "…", "override": true, "overrideReason": "Décision exceptionnelle validée par le bureau." }
```

Le forçage est **toujours** audité : `draw.overridden`, avec le nombre de
cotisations manquantes et le montant restant dans les métadonnées.

Refus standard sans forçage :

```json
{
  "success": false,
  "error": {
    "code": "missingContributions",
    "message": "1 cotisation reste à régler.",
    "details": { "remaining_count": 1, "remaining_amount": 50000 }
  }
}
```

---

## 7. Annuler, invalider

| Opération | Sur quoi | Effet |
|---|---|---|
| `POST /draws/{id}/cancel` | tirage `scheduled` | passe à `cancelled` |
| `POST /draws/{id}/invalidate` | tirage `completed` | passe à `invalidated` |

**Rien n'est supprimé.** L'invalidation rend le gagnant à nouveau éligible
(`has_received_payout = false`, `is_draw_eligible = true`), annule le
bénéficiaire, remet le cycle en collecte et journalise `draw.invalidated`.
Un nouveau tirage devient alors possible.

---

## 8. Réponse du tirage

```jsonc
{
  "success": true,
  "data": {
    "id": "…", "cycleId": "…", "periodLabel": "Août 2026",
    "status": "completed",
    "participants": [ { "participantId": "…", "displayName": "Awa KOUASSI", "weight": 1 } ],
    "winnerParticipantId": "…", "winnerMemberId": "…", "winnerName": "Awa KOUASSI",
    "proofReference": "KDJ-C15997D5",
    "randomSourceLabel": "server_secrets_choice",
    "overrideUsed": false, "overrideReason": null,

    // Raccourcis du cahier des charges
    "draw_id": "…",
    "winner": { "participant_id": "…", "name": "Awa KOUASSI" },
    "payout_amount": 600000,
    "period": "Août 2026"
  }
}
```

`participants` est la liste **exacte** au moment du tirage : la roue s'aligne
dessus, et l'historique reste vérifiable même si l'éligibilité change ensuite.

---

## 9. Tests

`backend/tests/test_draw.py` :

| Scénario | Test |
|---|---|
| A — le gagnant sort de la roue, pas de la tontine | `test_scenario_a_winner_leaves_the_wheel_but_stays_active` |
| B — il cotise encore au cycle suivant | `test_scenario_b_winner_still_owes_the_next_cycle` |
| C — il est absent de la roue suivante | `test_scenario_c_winner_is_absent_from_the_next_wheel` |
| D — tirage refusé si une cotisation manque | `test_scenario_d_draw_refused_while_a_contribution_is_missing` |
| E — forçage justifié et audité | `test_scenario_e_override_requires_a_reason_and_is_audited` |
| F — un seul gagnant par cycle | `test_scenario_f_a_cycle_can_only_have_one_winner` + test de la contrainte SQL |
| G — cloisonnement entre organisations | `test_scenario_g_another_organization_cannot_touch_the_tontine` |
