# Contrat d'API Kadjane

Ce document décrit ce que l'application attend du backend REST. Il fait
autorité côté client : les mappers de `lib/data/dto/` implémentent exactement
ce contrat.

> **Si le backend diffère** (snake_case, enveloppes différentes, autres noms de
> routes), seuls deux endroits changent : `ApiRoutes`
> (`lib/core/network/api_client.dart`) et les mappers `lib/data/dto/`. Aucun
> écran, aucun repository, aucune règle métier n'est impacté.

---

## 1. Conventions

| Sujet | Règle |
|---|---|
| Base URL | `AppConfig.apiBaseUrl` (`/v1`) |
| Format | JSON UTF-8, clés en `camelCase` |
| Dates | ISO 8601 (`2026-08-18T14:32:00.000Z`), converties en heure locale |
| Montants | nombres JSON (pas de chaînes), unité entière pour le XOF |
| Énumérations | valeur `code` du domaine (`monthly_draw`, `orange_money`, `draw.completed`…) |
| Enveloppe | `{...}` direct **ou** `{ "data": {...} }` — les deux sont acceptés |
| Collections | `[...]` direct **ou** `{ "data": [...] }` / `{ "items": [...] }` |

### Authentification

Toutes les routes sauf `/auth/*` exigent :

```
Authorization: Bearer <accessToken>
```

### Erreurs

| Statut | Exception levée | Corps attendu |
|---|---|---|
| 400 / 422 | `ValidationException` | `{ "message": "...", "errors": { "phone": "..." } }` |
| 401 | refresh automatique, puis `SessionExpiredException` | — |
| 403 | `PermissionDeniedException` | `{ "message": "..." }` |
| 404 | `NotFoundException` | `{ "message": "..." }` |
| 409 | `BusinessRuleException` | `{ "code": "missingContributions", "message": "...", "missing": 1 }` |
| 5xx | `ServerException` | libre |

Le champ `code` d'un 409 est repris tel quel par l'application : utiliser les
valeurs de `DrawBlockReason` (`missingContributions`, `alreadyDrawn`,
`noEligibleParticipant`, `orderAlreadyDefined`) pour que le message affiché
soit précis.

### Renouvellement de session

Sur `401`, le client appelle **une fois** `POST /auth/refresh` avec
`{ "refreshToken": "..." }`, attend `{ accessToken, refreshToken, expiresAt }`
(ou `{ "tokens": { ... } }`), réécrit le stockage sécurisé puis rejoue la
requête. Un échec purge la session et renvoie l'utilisateur vers la connexion.

---

## 2. Authentification

| Méthode | Route | Corps | Réponse |
|---|---|---|---|
| POST | `/auth/login` | `{ identifier, password }` | `{ user, tokens }` |
| POST | `/auth/register` | `{ firstName, lastName, phone, password, email?, gender }` | `{ user, tokens }` |
| POST | `/auth/refresh` | `{ refreshToken }` | `{ accessToken, refreshToken, expiresAt }` |
| POST | `/auth/otp/request` | `{ target }` | — |
| POST | `/auth/otp/verify` | `{ target, code }` | `{ resetToken }` |
| POST | `/auth/password/reset` | `{ resetToken, newPassword }` | — |
| POST | `/auth/logout` | — | — |
| GET | `/me` | — | `user` |
| PUT | `/me` | `user` | `user` |

```jsonc
// user
{
  "id": "usr_1",
  "firstName": "Yedjane",
  "lastName": "YEO",
  "phone": "+225 07 00 00 00 01",
  "email": "yeo@kadjane.app",     // optionnel
  "avatarUrl": null,               // optionnel
  "gender": "male",                // male | female | unspecified
  "birthDate": null,               // optionnel
  "createdAt": "2025-01-01T00:00:00.000Z"
}
```

---

## 3. Organisations et membres

| Méthode | Route | Réponse |
|---|---|---|
| GET | `/organizations?userId=` | `[organization]` |
| GET | `/organizations/{id}` | `organization` |
| POST | `/organizations` | `organization` |
| PUT | `/organizations/{id}` | `organization` |
| GET | `/organizations/{id}/membership?userId=` | `member` |
| GET | `/organizations/{id}/officers` | `[member]` |
| GET | `/organizations/{id}/members?query=&role=&status=&page=&pageSize=` | `paged<member>` |
| POST | `/organizations/{id}/members` | `member` (+ `temporaryPassword`) |
| DELETE | `/organizations/{id}/members/{memberId}` | `{ "deleted": true }` |
| GET | `/members/{id}` | `member` |
| PUT | `/members/{id}` | `member` |
| GET | `/members/{id}/stats` | `memberStats` |

**Accès du membre.** `POST /organizations/{id}/members` accepte un champ
`password` : le mot de passe provisoire que l'administrateur remet au membre.
Omis, le backend en génère un et le renvoie dans `temporaryPassword` — **la
seule fois** où il est lisible, la base n'en gardant qu'une empreinte. Le champ
est ignoré si le numéro correspond à un compte existant : rejoindre une
organisation ne réinitialise pas un accès déjà en place.

Le membre change ensuite son mot de passe lui-même :

| Méthode | Route | Réponse |
|---|---|---|
| POST | `/auth/password/change` | `{ "changed": true }` |

Corps : `currentPassword`, `newPassword` (8 caractères minimum). Requiert une
session. Erreurs : `invalid_current_password` (401), `password_unchanged` (401).
Les autres sessions ouvertes sont fermées.

**Suppression d'un membre** — réservée à `member.delete` (administrateur), elle
est refusée dans trois cas :

| Code | Statut | Cause |
|---|---|---|
| `member_self_delete` | 409 | On ne se supprime pas soi-même |
| `role_escalation_denied` | 403 | Cible d'un rôle supérieur à celui de l'appelant |
| `member_has_history` | 409 | Le membre participe à une tontine |

Le dernier cas protège les données : `tontine_participants` référence
`organization_members` en `CASCADE`, et les cotisations référencent les
participants de la même façon. Supprimer effacerait l'historique financier —
la désactivation (`status: "inactive"`) est la bonne réponse.

```jsonc
// organization
{
  "id": "org_1",
  "name": "Association Solidarité",
  "description": "…",
  "logoUrl": null,
  "currency": "XOF",
  "country": "CI",
  "phone": "+225 27 22 00 00 00",
  "email": "contact@solidarite.ci",
  "address": "Cocody Angré, Abidjan",
  "rules": "…",
  "settings": {
    "requireFullPaymentBeforeDraw": true,
    "allowDrawOverride": true,
    "latePaymentGraceDays": 3,
    "notifyBeforeDueDays": 3
  },
  "createdAt": "2025-08-01T00:00:00.000Z"
}

// member
{
  "id": "mbr_1",
  "organizationId": "org_1",
  "user": { /* user */ },
  "role": "admin",        // super_admin | admin | president | treasurer | auditor | member
  "status": "active",     // active | inactive | suspended | pending
  "joinedAt": "2025-08-15T00:00:00.000Z",
  "memberNumber": "M-001"
}

// paged<T>
{ "items": [ /* T */ ], "page": 0, "hasMore": true, "total": 42 }

// memberStats
{
  "totalPaid": 250000,
  "totalReceived": 600000,
  "tontinesCount": 2,
  "pendingContributions": 0,
  "lateContributions": 1
}
```

---

## 4. Tontines

| Méthode | Route | Réponse |
|---|---|---|
| GET | `/organizations/{id}/tontines?status=&memberId=` | `[tontineSummary]` |
| POST | `/organizations/{id}/tontines` | `tontine` |
| GET | `/tontines/{id}` | `tontine` |
| PUT | `/tontines/{id}` | `tontine` |
| GET | `/tontines/{id}/summary` | `tontineSummary` |
| PATCH | `/tontines/{id}/status` | `tontine` |
| GET | `/tontines/{id}/participants` | `[participant]` |
| PUT | `/tontines/{id}/participants/order` | — |
| GET | `/tontines/{id}/cycles` | `[cycle]` |
| GET | `/tontines/{id}/cycles/current` | `cycle` ou **corps vide** |
| GET | `/cycles/{id}` | `cycle` |

```jsonc
// tontine
{
  "id": "ton_1",
  "organizationId": "org_1",
  "name": "Tontine Solidarité",
  "description": "…",
  "contributionAmount": 50000,
  "currency": "XOF",
  "frequency": "monthly",           // weekly | biweekly | monthly | custom
  "allocationMode": "monthly_draw", // monthly_draw | full_order_draw | manual_order
  "startDate": "2026-03-01T00:00:00.000Z",
  "dueDayOfPeriod": 5,
  "customPeriodDays": null,
  "status": "active",               // draft | pending | active | suspended | completed | cancelled
  "createdAt": "…", "createdBy": "mbr_1", "closedAt": null
}

// tontineSummary — agrégats calculés côté serveur
{
  "tontine": { /* tontine */ },
  "participantCount": 12,
  "completedCycles": 5,
  "totalCycles": 12,
  "collectedCurrentCycle": 550000,
  "expectedCurrentCycle": 600000,
  "currentCycle": { /* cycle */ },        // optionnel
  "currentBeneficiaryName": "Awa KOUASSI", // optionnel
  "previousBeneficiaryName": "Serge KOFFI" // optionnel
}

// participant — porte la règle métier centrale
{
  "id": "prt_1", "tontineId": "ton_1", "memberId": "mbr_2",
  "displayName": "Awa KOUASSI", "avatarUrl": null,
  "joinedAt": "…",
  "isEligibleForDraw": false,   // false dès qu'il a reçu la cagnotte
  "hasReceivedPot": true,
  "receivedCycleId": "cyc_1",
  "receivedPeriodStart": "2026-03-01T00:00:00.000Z",
  "orderPosition": null,        // modes ordre complet / manuel
  "isActive": true              // reste true : il continue de cotiser
}

// cycle
{
  "id": "cyc_6", "tontineId": "ton_1", "index": 6,
  "periodStart": "2026-08-01T00:00:00.000Z",
  "periodEnd": "2026-08-31T23:59:59.000Z",
  "dueDate": "2026-08-05T23:59:59.000Z",
  "expectedAmount": 600000,
  "status": "collecting",  // upcoming | collecting | ready_for_draw | drawn | paid_out | closed
  "beneficiaryParticipantId": null, "beneficiaryId": null,
  "drawSessionId": null, "payoutId": null,
  "drawScheduledAt": "2026-08-07T00:00:00.000Z"
}
```

> **`isActive` doit rester `true` après réception de la cagnotte.** Seul
> `isEligibleForDraw` bascule à `false`. Cette distinction est la règle
> fondamentale de Kadjane.

---

## 5. Cotisations

| Méthode | Route | Réponse |
|---|---|---|
| GET | `/cycles/{id}/contribution-slots` | `[slot]` |
| GET | `/cycles/{id}/contributions` | `[contribution]` |
| GET | `/tontines/{id}/contributions` | `[contribution]` |
| GET | `/organizations/{orgId}/members/{memberId}/contributions` | `[contribution]` |
| POST | `/tontines/{id}/contributions` | `contribution` |
| POST | `/contributions/{id}/confirm` | `contribution` |
| POST | `/contributions/{id}/cancel` | `contribution` |

```jsonc
// slot — une ligne par participant attendu, payée ou non
{
  "memberId": "mbr_9", "memberName": "Salif OUATTARA",
  "avatarUrl": null, "expectedAmount": 50000,
  "contribution": null            // ou l'objet contribution
}

// contribution
{
  "id": "ctr_1", "organizationId": "org_1", "tontineId": "ton_1",
  "cycleId": "cyc_6", "memberId": "mbr_9", "memberName": "Salif OUATTARA",
  "amount": 50000,
  "status": "confirmed",  // pending | confirmed | rejected | cancelled
  "method": "wave",       // wave | orange_money | mtn_momo | moov_money | bank_transfer | cash | other
  "reference": "WV77451", "comment": null, "attachmentId": null,
  "paidAt": "…", "recordedBy": "mbr_2", "recordedAt": "…",
  "cancelledAt": null, "cancelReason": null
}
```

> Seules les cotisations `confirmed` comptent dans les montants collectés. Une
> cotisation annulée reste dans l'historique.

---

## 6. Tirages

| Méthode | Route | Réponse |
|---|---|---|
| GET | `/tontines/{id}/cycles/{cycleId}/draw-eligibility` | `eligibility` |
| POST | `/tontines/{id}/draws` | `drawSession` |
| POST | `/tontines/{id}/draws/order` | `drawSession` |
| GET | `/tontines/{id}/draws` | `[drawSession]` |
| GET | `/draws/{id}` | `drawSession` |
| GET | `/cycles/{id}/draw` | `drawSession` ou corps vide |
| POST | `/draws/{id}/cancel` | `drawSession` |
| POST | `/draws/{id}/invalidate` | `drawSession` |

```jsonc
// eligibility
{
  "allowed": false,
  "reason": "missingContributions", // none | tontineNotActive | alreadyDrawn |
                                    // missingContributions | noEligibleParticipant |
                                    // orderAlreadyDefined
  "missingContributions": 1,
  "canOverride": true
}

// POST /tontines/{id}/draws
{ "cycleId": "cyc_6", "actorMemberId": "mbr_1", "override": false, "overrideReason": null, "seed": null }

// drawSession — preuve inaltérable
{
  "id": "drw_1", "organizationId": "org_1", "tontineId": "ton_1", "cycleId": "cyc_6",
  "periodLabel": "Août 2026",
  "participants": [ { "participantId": "prt_3", "memberId": "mbr_1", "displayName": "YEO Yedjane", "weight": 1 } ],
  "status": "completed",   // scheduled | completed | cancelled | invalidated
  "scheduledAt": "…", "executedAt": "…", "createdAt": "…",
  "winnerParticipantId": "prt_3", "winnerMemberId": "mbr_1", "winnerName": "YEO Yedjane",
  "launchedByMemberId": "mbr_1", "launchedByName": "YEO Yedjane",
  "proofReference": "KDJ-9F2A11B0",
  "randomSourceLabel": "server_hmac_drbg",
  "seed": null,
  "overrideUsed": false, "overrideReason": null,
  "closedAt": null, "closeReason": null
}
```

**Responsabilités du serveur :**

1. Le gagnant est **tiré côté serveur** ; l'application ne fait que l'afficher.
   `participants` doit contenir la liste exacte des éligibles au moment du
   tirage : la roue s'aligne dessus.
2. Refuser un second tirage sur un cycle déjà attribué (`409 alreadyDrawn`).
3. Refuser le tirage si des cotisations manquent, sauf `override: true` — et
   alors journaliser le forçage.
4. `invalidate` ne supprime jamais la session : elle passe à `invalidated`,
   le bénéficiaire redevient éligible et le cycle repart en collecte.

---

## 7. Bénéficiaires et versements

| Méthode | Route | Réponse |
|---|---|---|
| GET | `/tontines/{id}/beneficiaries` | `[beneficiary]` |
| GET | `/cycles/{id}/beneficiary` | `beneficiary` ou corps vide |
| POST | `/cycles/{id}/beneficiary` | `beneficiary` |
| GET | `/beneficiaries/{id}` | `beneficiary` |
| GET | `/cycles/{id}/payout` | `payout` ou corps vide |
| GET | `/tontines/{id}/payouts` | `[payout]` |
| POST | `/payouts` | `payout` |
| GET | `/organizations/{orgId}/members/{memberId}/payouts/total` | `{ "total": 600000 }` |

```jsonc
// beneficiary
{
  "id": "ben_1", "organizationId": "org_1", "tontineId": "ton_1", "cycleId": "cyc_6",
  "participantId": "prt_3", "memberId": "mbr_1", "memberName": "YEO Yedjane",
  "avatarUrl": null, "amount": 600000,
  "designatedAt": "…",
  "source": "periodic_draw",  // periodic_draw | order_draw | manual_order
  "drawSessionId": "drw_1", "payoutId": null
}

// payout
{
  "id": "pay_1", "organizationId": "org_1", "tontineId": "ton_1", "cycleId": "cyc_6",
  "beneficiaryId": "ben_1", "memberId": "mbr_1", "memberName": "YEO Yedjane",
  "amount": 600000,
  "status": "paid",     // pending | processing | paid | failed
  "method": "wave", "reference": "WV88120", "comment": null, "attachmentId": null,
  "sentAt": "…", "recordedBy": "mbr_2", "createdAt": "…"
}
```

---

## 7bis. Cotisations de caisse

Sommes dues à l'association **hors tontine** : elles ne sont pas redistribuées.
Voir la section « Tontine ≠ caisse » du README.

| Méthode | Route | Réponse |
|---|---|---|
| GET | `/organizations/{id}/dues-plans` | `[duesPlan]` (avec `summary`) |
| POST | `/organizations/{id}/dues-plans` | `duesPlan` |
| PATCH | `/organizations/{id}/dues-plans/{planId}` | `duesPlan` |
| GET | `/organizations/{id}/dues-plans/{planId}/entries?period=&memberId=` | `[duesEntry]` |
| GET | `/organizations/{id}/dues-outstanding?memberId=` | `[duesEntry]` non soldées |
| GET | `/me/dues?organizationId=` | `[duesEntry]` du membre connecté |
| POST | `/dues-entries/{entryId}/payments` | `duesPayment` (+ `entry` rafraîchie) |
| POST | `/dues-payments/{paymentId}/cancel` | `duesPayment` |

**Droits** — `dues.view` (tout membre), `dues.record` (trésorier et
administrateur), `dues.manage` (administrateur).

**Génération des échéances.** Les lectures (`dues-plans`, `entries`,
`dues-outstanding`, `/me/dues`) engendrent les périodes écoulées manquantes.
L'opération est idempotente. Un membre ne reçoit pas d'échéance pour une
période close avant son adhésion, et un plan `paused` ou `closed` n'en engendre
plus.

**Trésorerie.** `/organizations/{id}/treasury` expose désormais
`contributionsTotal` (tontines) et `duesTotal` (caisse) en plus de `balance`.

```jsonc
// duesEntry
{
  "id": "…",
  "planId": "…",
  "memberId": "…",
  "member": { /* member */ },
  "sequenceNumber": 3,
  "periodLabel": "Août 2026",
  "dueDate": "2026-08-05T23:59:59Z",
  "expectedAmount": "5000.00",
  "paidAmount": "0.00",
  "remainingAmount": "5000.00",
  "status": "late"        // pending | partial | paid | late | cancelled
}
```

---

## 8. Transverse

| Méthode | Route | Réponse |
|---|---|---|
| GET | `/organizations/{id}/audit-logs?tontineId=&actions=&limit=` | `[auditLog]` |
| POST | `/organizations/{id}/audit-logs` | `auditLog` |
| GET | `/notifications?userId=&organizationId=` | `[notification]` |
| GET | `/notifications/unread-count` | `{ "count": 3 }` |
| POST | `/notifications/{id}/read` | — |
| POST | `/notifications/read-all` | — |
| POST | `/notifications/devices` | — |
| GET | `/organizations/{id}/treasury` | `treasurySnapshot` |
| POST | `/organizations/{id}/transactions` | `transaction` |
| GET | `/organizations/{id}/dashboard?memberId=` | `dashboardSnapshot` |
| GET | `/organizations/{id}/reports` | `reportSnapshot` |
| POST | `/organizations/{id}/reports/export` | `{ "url": "https://…" }` |

```jsonc
// dashboardSnapshot — une seule requête pour tout l'écran d'accueil
{
  "organization": { /* organization */ },
  "membersCount": 12,
  "activeTontines": 2,
  "expectedThisPeriod": 600000,
  "collectedThisPeriod": 550000,
  "lateContributions": 1,
  "myContributionDue": 50000,
  "myContributionPaid": 50000,
  "deadlines": [
    { "tontineId": "ton_1", "tontineName": "…", "cycleId": "cyc_6",
      "periodStart": "…", "dueDate": "…", "amount": 50000, "isPaid": true }
  ],
  "recentActivity": [ /* auditLog */ ],
  "trend": [ { "periodStart": "…", "collected": 550000, "expected": 600000 } ],
  "nextDraw": {
    "tontineId": "ton_1", "tontineName": "…", "cycleId": "cyc_6",
    "periodStart": "…", "scheduledAt": "…",
    "eligibleCount": 7, "potAmount": 600000, "isUnlocked": false
  },
  "currentBeneficiary": {
    "tontineId": "ton_1", "tontineName": "…", "cycleId": "cyc_5",
    "memberName": "Mariam BAMBA", "avatarUrl": null,
    "amount": 600000, "periodStart": "…", "isPaidOut": true
  }
}

// auditLog
{
  "id": "adt_1", "organizationId": "org_1",
  "action": "draw.completed",   // voir AuditAction
  "description": "Awa KOUASSI a été tirée comme bénéficiaire de Mars 2026.",
  "actorMemberId": "mbr_3", "actorName": "Serge KOFFI",
  "targetType": "draw", "targetId": "drw_1", "tontineId": "ton_1",
  "amount": 600000, "metadata": { "proof": "KDJ-…" },
  "createdAt": "…"
}
```


---

## 9. Rôles et relances

| Méthode | Route | Réponse |
|---|---|---|
| GET | `/organizations/{id}/roles` | `[roleDefinition]` |
| PUT | `/organizations/{id}/roles/{roleCode}` | `roleDefinition` |
| POST | `/organizations/{id}/roles/{roleCode}/reset` | `roleDefinition` |
| GET | `/organizations/{id}/reminder-targets` | `[dunningTarget]` |
| GET | `/tontines/{id}/cycles/{cycleId}/reminder-targets` | `[dunningTarget]` |
| POST | `/reminder-campaigns` | `{ campaign, reminders }` |
| GET | `/organizations/{id}/reminder-campaigns` | `[campaign]` |
| GET | `/organizations/{orgId}/members/{memberId}/reminders` | `[reminder]` |
| GET | `/cycles/{id}/reminders` | `[reminder]` |
| POST | `/reminders/{id}/read` | — |

```jsonc
// roleDefinition — la matrice appliquée par l'application
{
  "id": "rol_org_1_treasurer",
  "organizationId": "org_1",
  "role": "treasurer",
  "permissions": ["contribution.record", "payout.record", "reminder.send"],
  "isCustomized": true,
  "updatedAt": "…",
  "updatedByMemberId": "mbr_1"
}

// dunningTarget — un membre à relancer
{
  "memberId": "mbr_9", "memberName": "Salif OUATTARA",
  "tontineId": "ton_1", "tontineName": "Tontine Solidarité",
  "cycleId": "cyc_6",
  "periodStart": "2026-08-01T00:00:00.000Z",
  "dueDate": "2026-08-05T23:59:59.000Z",
  "amountDue": 50000,
  "level": "late",       // upcoming | due_today | late | escalated
  "daysLate": 4,
  "reminderCount": 1,
  "lastReminderAt": "2026-08-06T09:00:00.000Z"
}

// POST /reminder-campaigns
{
  "tontineId": "ton_1",
  "cycleId": "cyc_6",
  "channels": ["in_app", "sms"],
  "messages": { "mbr_9": "Bonjour Salif, votre cotisation…" },
  "actorMemberId": "mbr_2"
}

// reminder
{
  "id": "rmd_1", "organizationId": "org_1", "tontineId": "ton_1",
  "cycleId": "cyc_6", "memberId": "mbr_9", "memberName": "Salif OUATTARA",
  "channel": "sms",       // in_app | push | sms | whatsapp | email
  "status": "queued",     // queued | sent | read | failed
  "level": "late",
  "message": "Bonjour Salif, votre cotisation…",
  "amountDue": 50000, "dueDate": "…",
  "campaignId": "cmp_1", "createdAt": "…", "sentAt": null, "readAt": null,
  "sentByMemberId": "mbr_2", "sentByName": "Awa KOUASSI",
  "failureReason": null
}
```

**Responsabilités du serveur :**

1. `permissions` fait autorité : l'application applique la matrice reçue, y
   compris dans les écrans mobiles. Le rôle `super_admin` conserve tous les
   droits quelle que soit la réponse.
2. Les cibles de relance excluent les membres à jour et **incluent** les
   anciens bénéficiaires (ils cotisent encore).
3. Une campagne journalise `reminder.sent` dans l'audit et déclenche l'envoi
   sur chaque canal demandé ; un canal indisponible reste en `queued` plutôt
   que d'échouer silencieusement.

---

## 10. Reste à faire côté application

| Sujet | État |
|---|---|
| Justificatifs (upload) | `LocalFileStorage` ; `S3FileStorage` à écrire (URL pré-signées) |
| Notifications push | route `/notifications/devices` prête, SDK Firebase à intégrer |
| Passerelles de relance | SMS / WhatsApp / e-mail : le contrat est prêt, les envois restent à brancher |
| Cache hors ligne | `NetworkInfo` en place, persistance locale à ajouter |
