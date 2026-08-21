# Backend Kadjane — FastAPI + PostgreSQL

Le backend est la **source de vérité** des données Kadjane. L'application
mobile, la future console Angular et le site web consommeront la même API.

```
Flutter Mobile ─┐
Angular Admin  ─┼─► FastAPI (/api/v1) ─► PostgreSQL
Site web       ─┘
```

---

## 1. Démarrage

```bash
cp .env.example .env
```

```bash
cp backend/.env.example backend/.env
```

```bash
docker compose up -d
```

```bash
docker compose ps
```

| Service | Port hôte | Rôle |
|---|---|---|
| `backend` | 8000 | API FastAPI (migrations appliquées au démarrage) |
| `postgres` | 55432 | PostgreSQL 16 |

> Le port PostgreSQL est **55432** et non 5432 : une installation PostgreSQL
> native occupe souvent déjà 5432 et 5433. Changer `POSTGRES_PORT` dans `.env`
> si besoin — le port *interne* reste 5432, donc le backend n'est pas concerné.

| URL | Contenu |
|---|---|
| <http://localhost:8000/health> | `{"status":"ok","database":"ok"}` (teste vraiment la base) |
| <http://localhost:8000/docs> | Swagger, bouton **Authorize** pour le jeton Bearer |
| <http://localhost:8000/redoc> | Documentation alternative |

Journaux :

```bash
docker compose logs -f backend
```

---

## 2. Jeu de données de développement

```bash
docker compose exec backend python -m app.db.seed
```

Le script est **idempotent** : relancé, il ne duplique rien.

Il crée deux organisations (« Association Solidarité », « Amicale des
Anciens »), douze utilisateurs et dix-sept appartenances, reprenant exactement
les personnes affichées jusqu'ici par l'application.

| Compte | Rôle dans Association Solidarité |
|---|---|
| `+225 07 00 00 00 01` — `yeo@kadjane.app` (YEO Yedjane) | administrateur |
| `+225 07 00 00 00 02` — Awa KOUASSI | trésorière |
| `+225 07 00 00 00 03` — Serge KOFFI | président |
| `+225 07 00 00 00 04` — Fatou DIALLO | commissaire aux comptes |
| `+225 07 00 00 00 05` … `12` | membres |

Il crée aussi la **Tontine Solidarité** : 12 participants, 50 000 FCFA de
cotisation, donc 600 000 FCFA de cagnotte, 12 cycles mensuels — et laisse
**volontairement une cotisation impayée** sur le cycle en cours. L'écran de
tirage affiche alors « 1 cotisation reste à régler », ce qui permet de tester
aussi bien le blocage que le forçage.

Le mot de passe vient de la variable `SEED_PASSWORD` (défaut `kadjane`).
**Développement uniquement** : aucun mot de passe n'est écrit en dur dans le
code, et rien n'est journalisé en clair.

---

## 3. Travailler sans Docker

```bash
cd backend
```

```bash
python -m venv .venv && .venv/Scripts/pip install -r requirements-dev.txt
```

```bash
.venv/Scripts/alembic upgrade head
```

```bash
.venv/Scripts/uvicorn app.main:app --reload
```

`backend/.env` doit alors pointer sur `localhost:55432` (le conteneur
PostgreSQL) ou sur votre instance locale.

---

## 4. Migrations Alembic

| Commande | Effet |
|---|---|
| `alembic upgrade head` | Applique les migrations (part d'une base vide) |
| `alembic revision --autogenerate -m "..."` | Génère une migration depuis les modèles |
| `alembic downgrade base` | Revient à une base vide |
| `alembic current` | Révision appliquée |

Dans Docker :

```bash
docker compose exec backend alembic upgrade head
```

L'URL vient toujours de `DATABASE_URL` (`alembic/env.py`) : jamais de
`alembic.ini`, qui ne contient donc aucun secret.

---

## 5. Tests

```bash
cd backend && .venv/Scripts/python -m pytest
```

Les tests tournent sur SQLite en mémoire — pas de conteneur requis, et le
schéma testé reste celui de PostgreSQL grâce à des types portables (`Uuid`,
`JSON`).

| Fichier | Couverture |
|---|---|
| `tests/test_auth.py` | santé, inscription, connexion, `/me`, rotation du refresh, déconnexion |
| `tests/test_organizations.py` | création, liste restreinte, mise à jour, tableau de bord, matrice des rôles |
| `tests/test_members.py` | pagination, recherche, filtres, création, mise à jour, permissions |
| `tests/test_tontines.py` | cycles, cagnotte calculée, cotisations, paiements, ordres |
| `tests/test_draw.py` | scénarios A→H : tirage, forçage, double tirage, versement |
| `tests/test_treasury.py` | trésorerie, rapports, clôture automatique, notifications, relances, justificatifs |
| `tests/test_isolation.py` | **isolation multi-association** |

Côté Flutter, `test/integration/live_api_test.dart` rejoue le parcours complet
contre ce backend :

```bash
flutter test test/integration/live_api_test.dart --dart-define=KADJANE_LIVE_API=true
```

---

## 6. Format des réponses

Succès :

```json
{ "success": true, "data": {}, "meta": {} }
```

Erreur :

```json
{ "success": false, "error": { "code": "invalid_credentials", "message": "…", "details": null } }
```

Le client Flutter déballe l'enveloppe dans `HttpApiClient` ; les mappers de
`lib/data/dto/` n'en savent rien. Les clés métier sont en **camelCase**, comme
le spécifie [`api-contract.md`](api-contract.md).

Les listes paginées renvoient dans `data` la forme `paged<T>` attendue par
l'application, et rappellent la pagination dans `meta` :

```json
{
  "success": true,
  "data": { "items": [], "page": 0, "pageSize": 20, "hasMore": true, "total": 12 },
  "meta": { "page": 0, "page_size": 20, "total": 12, "has_more": true }
}
```

`page` est indexée **à partir de 0**.

| Statut | `error.code` typique | Exception Flutter |
|---|---|---|
| 401 sur `/auth/*` | `invalid_credentials` | `AuthException` |
| 401 ailleurs | `session_expired` | `SessionExpiredException` (déclenche le refresh) |
| 403 | `permission_denied` | `PermissionDeniedException` |
| 404 | `not_found`, `organization_not_found` | `NotFoundException` |
| 409 | `phone_already_used` | `BusinessRuleException` |
| 422 | `validation_error` (+ `details.errors`) | `ValidationException` |

---

## 7. Endpoints

Préfixe : `/api/v1`. Toutes les routes hors `/auth/*` exigent
`Authorization: Bearer <accessToken>`.

### Authentification

| Méthode | Route |
|---|---|
| POST | `/auth/register` |
| POST | `/auth/login` — `{identifier, password}`, téléphone **ou** e-mail |
| POST | `/auth/refresh` — rotation : l'ancien jeton devient inutilisable |
| POST | `/auth/logout` |
| GET | `/auth/me`, `/me` |
| PUT | `/me` |
| POST | `/auth/otp/request`, `/auth/otp/verify`, `/auth/password/reset` |

### Organisations

| Méthode | Route |
|---|---|
| GET | `/organizations` — **uniquement les miennes** |
| POST | `/organizations` — le créateur devient administrateur |
| GET / PUT / PATCH | `/organizations/{id}` |
| GET | `/organizations/{id}/membership`, `/officers`, `/roles` |
| GET | `/organizations/{id}/dashboard` |

### Membres

| Méthode | Route |
|---|---|
| GET | `/organizations/{id}/members?page=&pageSize=&query=&role=&status=` |
| POST | `/organizations/{id}/members` |
| GET / PATCH | `/organizations/{id}/members/{member_id}` |
| GET / PUT / PATCH | `/members/{member_id}` |
| GET | `/members/{member_id}/stats` |

### Tontines et cycles

| Méthode | Route |
|---|---|
| GET / POST | `/organizations/{id}/tontines` |
| GET / PATCH / PUT | `/tontines/{id}` |
| GET | `/tontines/{id}/summary`, `/tontines/{id}/participants` |
| PATCH | `/tontines/{id}/status` |
| PUT | `/tontines/{id}/participants/order` |
| GET | `/tontines/{id}/cycles`, `/cycles/current`, `/cycles/{cycleId}` |
| GET | `/cycles/{id}` |

### Cotisations et paiements

| Méthode | Route |
|---|---|
| GET | `/cycles/{id}/contribution-slots`, `/cycles/{id}/contributions` |
| GET | `/tontines/{id}/cycles/{cycleId}/contributions` (attendu / payé / restant) |
| GET | `/tontines/{id}/contributions` |
| POST | `/tontines/{id}/contributions`, `/contributions/{id}/payments` |
| POST | `/contributions/{id}/confirm`, `/reject`, `/cancel` |

### Tirage

| Méthode | Route |
|---|---|
| GET | `/tontines/{id}/cycles/{cycleId}/draw-eligibility` (alias `/draw/eligibility`) |
| POST | `/tontines/{id}/draws` (alias `/tontines/{id}/cycles/{cycleId}/draw`) |
| POST | `/tontines/{id}/draws/order` |
| GET | `/tontines/{id}/draws`, `/draws/{id}`, `/cycles/{id}/draw` |
| POST | `/draws/{id}/cancel`, `/draws/{id}/invalidate` |

### Bénéficiaires et versements

| Méthode | Route |
|---|---|
| GET | `/tontines/{id}/beneficiaries`, `/cycles/{id}/beneficiary`, `/beneficiaries/{id}` |
| POST | `/cycles/{id}/beneficiary` (désignation manuelle) |
| GET | `/tontines/{id}/payouts`, `/cycles/{id}/payout` |
| POST | `/payouts`, `/payouts/{id}/confirm`, `/payouts/{id}/fail` |

### Trésorerie et rapports

| Méthode | Route |
|---|---|
| GET | `/organizations/{id}/treasury` — solde, entrées, sorties, journal |
| POST | `/organizations/{id}/transactions` — mouvement de caisse |
| GET | `/organizations/{id}/reports` — attendu / collecté / distribué par tontine |

### Relances et notifications

| Méthode | Route |
|---|---|
| GET | `/organizations/{id}/reminder-targets?tontineId=` |
| GET | `/tontines/{id}/cycles/{cycleId}/reminder-targets` |
| GET | `/notifications`, `/notifications/unread-count` |
| POST | `/notifications/read-all`, `/notifications/{id}/read`, `/notifications/devices` |

### Justificatifs

| Méthode | Route |
|---|---|
| POST | `/attachments` — image ou PDF, 5 Mo max ; renvoie une URL utilisable en `proofUrl` |

### Audit

| Méthode | Route |
|---|---|
| GET | `/organizations/{id}/audit-logs?tontineId=&actions=&limit=` |

---

## 8. Isolation multi-association

Règle non négociable : **un membre de l'organisation A n'atteint jamais les
données de l'organisation B.**

Mise en œuvre :

1. L'identité vient **du jeton**, jamais du corps ou de l'URL. Un `?userId=`
   envoyé par le client est ignoré.
2. Toute route d'organisation dépend de `get_organization_context`
   (`app/core/deps.py`), qui exige une ligne `organization_members` reliant
   l'appelant à l'organisation demandée.
3. Sans appartenance, la réponse est **404** et non 403 : l'existence même de
   l'organisation n'est pas divulguée.
4. Les routes courtes `/members/{id}` déduisent l'organisation du membre visé,
   puis appliquent le même contrôle.
5. Les actions sensibles exigent en plus une permission
   (`app/services/permission_service.py`) et personne ne peut attribuer un rôle
   supérieur au sien.

`tests/test_isolation.py` verrouille chacun de ces points.

---

## 9. Structure

```
backend/
├── app/
│   ├── api/
│   │   ├── health.py            /health (SELECT 1 réel)
│   │   └── v1/                  auth, users, organizations, members, pending
│   ├── core/                    config, sécurité, erreurs, enveloppe, dépendances
│   ├── db/                      Base, session, seed
│   ├── models/                  User, Organization, OrganizationMember, RefreshToken
│   ├── schemas/                 Pydantic, camelCase automatique
│   ├── repositories/            accès aux données, sans règle métier
│   ├── services/                règles métier
│   └── main.py                  application et gestion centralisée des erreurs
├── alembic/                     migrations
├── tests/
├── Dockerfile
└── .env.example
```

Il n'y a plus de routes de remplissage : chaque endpoint lit ou écrit de
vraies données. Le métier est documenté dans
[`tontine-domain.md`](tontine-domain.md), [`draw-system.md`](draw-system.md)
et [`payments.md`](payments.md) ; le back-office dans [`admin.md`](admin.md).

**Trésorerie** — les montants ne sont pas ressaisis : ils sont agrégés depuis
les paiements confirmés (entrées) et les versements payés (sorties), plus les
mouvements de caisse manuels. Une même somme n'existe jamais deux fois.

**Justificatifs** — `app/services/storage_service.py` expose `save()` et
`url_for()`. Le stockage disque d'aujourd'hui se remplacera par S3/MinIO sans
toucher aux appelants.

**Clôture automatique** — quand le dernier cycle d'une tontine est versé, la
tontine passe seule en `completed`, avec une ligne d'audit
(`metadata.automatic = true`).

---

## 10. Sécurité

- Mots de passe hachés avec **bcrypt** ; jamais stockés ni journalisés en clair.
- **JWT** : jeton d'accès court (30 min), jeton de renouvellement long (30 j).
- Les jetons de renouvellement sont stockés **hachés en SHA-256** et
  révocables ; changer de mot de passe révoque toutes les sessions.
- Aucun secret dans Git : `.env` est ignoré, seuls les `.env.example` sont
  versionnés. Générer une clé de production :

```bash
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

---

## 11. Suite

1. Campagnes de relance : passerelles SMS / WhatsApp / e-mail.
2. Notifications push : consommer `device_tokens` via Firebase.
3. Justificatifs : basculer `LocalStorage` vers S3/MinIO (URL pré-signées).
4. `/app/config` : drapeaux de plateforme pilotables depuis le back-office.
5. Portée « super administrateur plateforme » côté API (voir toutes les
   organisations).
