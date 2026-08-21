# Kadjane Admin — back-office Angular

Console d'administration de Kadjane. Elle consomme **exactement la même API**
que l'application mobile : aucun accès direct à PostgreSQL, aucune donnée
dupliquée.

```
                     PostgreSQL
                         ▲
                         │
                     FastAPI  /api/v1
                ┌────────┴────────┐
                ▼                 ▼
          Flutter Mobile      Angular Admin
```

---

## 1. Démarrer

Le backend doit tourner (voir [`backend.md`](backend.md)) :

```bash
docker compose up -d
```

Puis, en développement :

```bash
npm --prefix apps/admin install
```

```bash
npm --prefix apps/admin start
```

| URL | Contenu |
|---|---|
| <http://localhost:4200> | Back-office |
| <http://localhost:8000/docs> | Swagger de l'API |
| <http://localhost:8000/health> | Santé du service |

Compte de développement : `yeo@kadjane.app` / mot de passe du seed
(`SEED_PASSWORD`, défaut `kadjane`).

### En conteneur

Le service est derrière un profil pour ne pas ralentir le cycle de
développement :

```bash
docker compose --profile admin up -d --build admin
```

Nginx sert l'application construite et relaie `/api/` vers FastAPI.

---

## 2. Pile technique

Angular 22, TypeScript strict, composants **standalone**, **signals** pour
l'état, `provideRouter` avec **chargement différé** de chaque écran,
`HttpClient` avec interceptor fonctionnel, Reactive Forms, Vitest.

Aucune librairie d'interface tierce : le système de design (`src/styles.scss`)
reprend la palette Kadjane — vert `#0e6b54`, accents dorés `#e0a33e`, fonds
clairs, cartes et badges — sans copier l'interface mobile. Le graphique du
tableau de bord est en CSS pur, ce qui évite d'embarquer une librairie de
visualisation pour deux séries.

---

## 3. Architecture

```
apps/admin/src/app/
├── core/
│   ├── models/         api.models.ts (enveloppe, ApiError), domain.models.ts
│   ├── services/       api-client, auth, session, token-store, toast,
│   │                   domain.services.ts (un service par domaine métier)
│   ├── interceptors/   auth.interceptor.ts
│   ├── guards/         auth.guard.ts, permission.guard.ts
│   └── pipes/          money, amount, frDate, label
├── shared/ui.components.ts   badges, tableaux, états, pagination, dialogue…
├── layout/             AdminLayout : sidebar + topbar + router-outlet
└── features/           un dossier par écran
```

Un seul endroit sait que l'API enveloppe ses réponses dans
`{success, data, meta}` : `ApiClient`. Les écrans reçoivent des objets métier
typés et des erreurs `ApiError` déjà traduites.

---

## 4. Authentification et session

| Étape | Route API |
|---|---|
| Connexion | `POST /auth/login` |
| Restauration | `GET /auth/me` |
| Renouvellement | `POST /auth/refresh` |
| Déconnexion | `POST /auth/logout` |

Les jetons vivent dans **`sessionStorage`** : la session meurt avec l'onglet,
ce qui limite l'exposition sur un poste partagé. Aucun mot de passe n'est
conservé.

L'interceptor (`core/interceptors/auth.interceptor.ts`) :

* ajoute `Authorization: Bearer …` sauf sur les routes publiques ;
* sur `401`, déclenche **un seul** renouvellement — les requêtes concurrentes
  attendent le même jeton au lieu de partir en rafale ;
* ne tente jamais de renouveler un `401` venant de `/auth/login` : c'est un
  refus d'identifiants, pas une session expirée ;
* purge la session et renvoie vers `/login` si le renouvellement échoue.

---

## 5. Permissions

> Le frontend **affiche ou masque**. Le backend **autorise ou refuse**.

`SessionService` charge la matrice servie par
`GET /organizations/{id}/roles` et l'expose via `can()` / `canAny()`. Les
routes sensibles portent un `permissionGuard`, et les boutons d'action sont
conditionnés à la même permission.

Ce n'est **pas** une sécurité : masquer un bouton n'a jamais protégé une API.
Chaque opération est de toute façon refusée par FastAPI si le rôle ne la
permet pas — c'est ce que vérifient `backend/tests/test_isolation.py` et les
contrôles de permission des services.

### Deux niveaux d'administration

| Niveau | Périmètre |
|---|---|
| Administration d'organisation | Membres, tontines, cotisations, tirages, versements de **son** organisation |
| Super administrateur plateforme | Vue transverse (`/platform`), rôle `super_admin` |

`GET /organizations` ne renvoie que les organisations de l'appelant : le
cloisonnement est appliqué côté serveur, pas côté écran.

---

## 6. Écrans

| Route | Contenu |
|---|---|
| `/login` | Connexion |
| `/dashboard` | KPI, progression, graphique, prochain tirage, bénéficiaire, activité |
| `/organizations`, `/organizations/:id` | Liste, suspension/réactivation, fiche à onglets |
| `/members` | Table paginée, recherche, filtres rôle/statut, création et modification |
| `/tontines`, `/tontines/new`, `/tontines/:id` | Liste, assistant en 5 étapes, fiche à 8 onglets |
| `/contributions` | Attendu / payé / restant par membre, filtres tontine, cycle, statut |
| `/draws` | Historique et détail d'un tirage (participants, preuve, forçage) |
| `/beneficiaries` | Bénéficiaires désignés |
| `/payouts` | Versements : confirmer, marquer en échec |
| `/treasury` | Solde, entrées/sorties, rapport par tontine, mouvements de caisse |
| `/reminders` | Membres à relancer, par niveau d'urgence |
| `/notifications` | Notifications de l'utilisateur |
| `/audit` | Journal filtrable, détail et métadonnées |
| `/settings` | Paramètres de l'organisation |
| `/platform` | Vue transverse et drapeaux à venir |

Prévues mais non développées : Abonnements, Site Internet, Support — visibles
dans la barre latérale, marquées « bientôt » et désactivées.

---

## 7. Tirage depuis le back-office

La console **ne choisit jamais** le gagnant. Avant de lancer, la fiche tontine
affiche ce que renvoie
`GET /tontines/{id}/cycles/{cycleId}/draw-eligibility` : participants
éligibles, collecte, cotisations restantes, cagnotte.

* Cotisations incomplètes → le bouton reste inactif et le message du backend
  est affiché tel quel (« 1 cotisation reste à régler »).
* Si le forçage est autorisé **et** que l'utilisateur a `draw.override`, un
  bouton « Forcer le tirage » demande un **motif obligatoire** puis une
  confirmation. Le forçage est journalisé (`draw.overridden`).
* Le gagnant renvoyé par le serveur est affiché ; aucun écran ne permet de le
  modifier.

---

## 8. Endpoints consommés

Auth (`/auth/*`, `/me`), organisations (`/organizations…`, `/membership`,
`/officers`, `/roles`, `/dashboard`), membres, tontines (`/tontines…`,
`/participants`, `/cycles`), cotisations et paiements
(`/contribution-slots`, `/contributions`, `/confirm`, `/cancel`), tirages
(`/draw-eligibility`, `/draws`, `/invalidate`), bénéficiaires, versements
(`/payouts…`), trésorerie (`/treasury`, `/transactions`, `/reports`),
relances (`/reminder-targets`), notifications, justificatifs
(`POST /attachments`), audit (`/audit-logs`).

Endpoints **ajoutés** pendant cette phase :
`/treasury`, `/transactions`, `/reports`, `/reminder-targets`,
`/notifications*`, `/attachments`. Voir [`backend.md`](backend.md).

---

## 9. Tests

```bash
npm --prefix apps/admin test
```

`src/app/core/core.spec.ts` couvre le déballage de l'enveloppe, la traduction
des erreurs métier, l'interceptor (en-tête, refresh unique, purge, routes
publiques), `AuthService`, `SessionService` et les permissions, ainsi que
`MemberService` et `TontineService`.

```bash
npm --prefix apps/admin run build
```

---

## 10. Environnements

`src/environments/environment.ts` (développement) et
`environment.production.ts`, échangés au build par `fileReplacements`.

```ts
apiBaseUrl: 'http://localhost:8000/api/v1'   // développement
apiBaseUrl: '/api/v1'                        // production, servi par Nginx
```

Aucun service ne contient d'URL en dur.

---

## 11. Reste à faire

| Sujet | État |
|---|---|
| `/app/config` | À écrire côté backend ; `/platform` affiche les drapeaux en lecture seule en attendant |
| Campagnes de relance | Cibles calculées ; envoi SMS / WhatsApp non branché |
| Notifications push | Table et jetons d'appareil prêts, Firebase à intégrer |
| Vue super-admin globale | Bornée aux organisations de l'appelant tant que l'API n'expose pas de portée plateforme |
