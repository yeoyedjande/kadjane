# Kadjane

> **La tontine, en toute transparence.**

Kadjane est une plateforme mobile de gestion de tontines et d'associations :
membres, tontines, cotisations, tirages au sort, bénéficiaires, versements,
caisse, rapports et journal d'audit — le tout cloisonné par organisation.

Kadjane, c'est **deux applications** bâties sur un socle unique :

| Application | Cible | Lancement |
|---|---|---|
| **Kadjane Mobile** | membres, trésorier, président, bureau | `flutter run` |
| **Kadjane Admin** | console web d'administration | `flutter run -d chrome -t lib/main_admin.dart` |

Elles partagent le domaine, les repositories, le design system et les
traductions : une règle métier écrite une fois s'applique aux deux.

L'ensemble fonctionne dans **deux modes interchangeables** :

- **mock** (par défaut en développement) — un jeu de données réaliste permet une
  démonstration complète du produit, sans backend ni réseau ;
- **REST** (recette et production) — les mêmes écrans consomment l'API Kadjane.

Le choix se fait par configuration, sans toucher une ligne de la couche
présentation.

---

## Sommaire

1. [Aperçu fonctionnel](#1-aperçu-fonctionnel)
2. [Prérequis](#2-prérequis)
3. [Installation](#3-installation)
4. [Lancement](#4-lancement)
5. [Comptes de démonstration](#5-comptes-de-démonstration)
6. [Architecture](#6-architecture)
7. [Structure des dossiers](#7-structure-des-dossiers)
8. [Règles métier clés](#8-règles-métier-clés)
9. [Conventions de code](#9-conventions-de-code)
10. [Tests](#10-tests)
11. [Environnements](#11-environnements)
12. [Backend REST](#12-backend-rest)
13. [Console d'administration](#13-console-dadministration)
14. [Relances](#14-relances)
15. [Déploiement du backend](#15-déploiement-du-backend)
16. [Roadmap](#16-roadmap)

---

## 1. Aperçu fonctionnel

| Domaine | Contenu |
|---|---|
| **Authentification** | Splash, onboarding, connexion, inscription, mot de passe oublié, OTP, réinitialisation, session sécurisée |
| **Multi-organisation** | Un utilisateur, plusieurs organisations ; sélecteur d'organisation ; cloisonnement total des données |
| **Dashboard** | Progression de la collecte, statistiques, prochain tirage, bénéficiaire courant, échéances, graphique d'évolution, activité récente |
| **Membres** | Liste avec recherche et pagination, fiche détaillée (versé/reçu/retards), création, rôles |
| **Tontines** | Liste filtrable, assistant de création en 4 étapes, page détail à 6 onglets |
| **Cotisations** | Vue par période, lignes par participant, enregistrement de paiement avec justificatif, « Mes cotisations » |
| **Tirage** | Roue animée, conditions de déclenchement, forçage audité, preuve de tirage, invalidation tracée |
| **Bénéficiaires** | Écran dédié, frise d'avancement, enregistrement du versement |
| **Transverse** | Journal d'audit, centre de notifications, caisse, rapports, profil, paramètres d'organisation |
| **Console web** | Pilotage, membres, matrice de permissions éditable, centre de relance, supervision des tontines, audit |
| **Relances** | Détection des impayés, niveaux d'escalade, multi-canal, messages personnalisables, historique audité |
| **Backend** | Client HTTP (Bearer, renouvellement de session, erreurs typées) et 14 repositories REST |
| **Qualité** | Thèmes clair/sombre, FR/EN, états loading/vide/erreur/offline, permissions par rôle |

---

## 2. Prérequis

| Outil | Version validée |
|---|---|
| Flutter | 3.44.8 (stable) |
| Dart | 3.12.2 |
| Android | SDK 21+ |
| iOS | 12+ |
| Docker | 24+ avec Compose v2 (backend + PostgreSQL) |
| Python | 3.12+ (uniquement pour lancer le backend hors Docker) |
| Node.js | 22+ (back-office Angular) |

```bash
flutter --version
flutter doctor
docker compose version
```

---

## 3. Installation

```bash
git clone <url-du-depot> kadjane
```

```bash
cd kadjane && flutter pub get
```

Les fichiers de localisation sont générés automatiquement par `flutter pub get`.
Pour les régénérer manuellement après modification des fichiers ARB :

```bash
flutter gen-l10n
```

### Backend et base de données

Le backend FastAPI et PostgreSQL démarrent avec Docker Compose. Copier d'abord
les variables d'environnement (aucun secret réel n'est versionné) :

```bash
cp .env.example .env
```

```bash
cp backend/.env.example backend/.env
```

Puis démarrer la pile :

```bash
docker compose up -d
```

Les migrations Alembic sont appliquées automatiquement au démarrage du
conteneur. Charger le jeu de données de développement :

```bash
docker compose exec backend python -m app.db.seed
```

Vérifier :

| URL | Contenu |
|---|---|
| <http://localhost:8000/health> | `{"status":"ok","database":"ok"}` |
| <http://localhost:8000/docs> | Swagger, avec authentification Bearer |
| `localhost:55432` | PostgreSQL (5432 et 5433 sont souvent déjà pris) |

Détails, dépannage et procédures : **[`docs/backend.md`](docs/backend.md)**.

### Back-office Angular

```bash
npm --prefix apps/admin install
```

```bash
npm --prefix apps/admin start
```

Le back-office est alors servi sur <http://localhost:4200> et consomme la même
API que l'application mobile. Détails : **[`docs/admin.md`](docs/admin.md)**.

> **Rôle du back-office.** Il **pilote** l'application mobile, il ne la
> reproduit pas. C'est lui qui crée les comptes des membres et qui les
> supprime : l'application mobile n'offre donc ni inscription libre ni accès de
> démonstration. Un membre créé par l'administrateur reçoit un mot de passe
> inutilisable et définit le sien à la première connexion, via
> « Mot de passe oublié ? » (OTP).
>
> Avant d'ajouter un écran au back-office, se demander s'il relève du pilotage
> (oui) ou de l'usage membre (non).

---

## 4. Lancement

Démarrer d'abord le backend (`docker compose up -d`), puis :

```bash
flutter run
```

> **`flutter run` seul vise le backend local.** L'environnement par défaut est
> `development` (`AppConfig.fromDartDefine()`) : c'est voulu. Pour viser le
> backend de la Beta en ligne, il faut le demander explicitement :
>
> ```bash
> flutter run --dart-define=KADJANE_ENV=production
> ```
>
> Attention si vous testez **dans un navigateur** : le navigateur applique les
> CORS, et l'origine `localhost` du serveur de développement n'est pas
> autorisée par le backend en production — les appels échouent en
> « Failed to fetch ». Sur un téléphone ou dans l'APK, la question ne se pose
> pas : il n'y a pas de CORS. Pour tester quand même depuis le navigateur,
> ajouter l'origine locale à `CORS_ORIGINS` côté backend.

L'application de développement utilise le backend réel. L'URL par défaut
dépend de la cible : `10.0.2.2:8000` sur émulateur Android, `localhost:8000`
ailleurs. Sur appareil physique, indiquer l'IP de la machine :

```bash
flutter run --dart-define=KADJANE_API_BASE_URL=http://192.168.1.10:8000/api/v1
```

Repli hors ligne sur les données simulées (aucun backend requis) :

```bash
flutter run --dart-define=KADJANE_USE_MOCK=true
```

Console web d'administration :

```bash
flutter run -d chrome -t lib/main_admin.dart
```

Autres environnements :

```bash
flutter run --dart-define=KADJANE_ENV=staging
```

Build de production Android :

```bash
flutter build apk --release --dart-define=KADJANE_ENV=production
```

Build de la console web :

```bash
flutter build web -t lib/main_admin.dart --output build/admin --release
```

---

## 5. Comptes de démonstration

Le jeu de données crée deux organisations, douze membres et trois tontines
(une par mode d'attribution).

Le seed PostgreSQL (`python -m app.db.seed`) crée les utilisateurs, les deux
organisations, les membres **et** la « Tontine Solidarité » : 12 participants,
50 000 FCFA de cotisation, 600 000 FCFA de cagnotte, avec **une cotisation
volontairement impayée** pour que l'écran de tirage affiche « 1 cotisation
reste à régler » et permette de tester le forçage.

`lib/data/mock/mock_seed.dart` reste disponible pour la démo hors ligne
(`--dart-define=KADJANE_USE_MOCK=true`). Le mot de passe du seed vient de
`SEED_PASSWORD` — **développement uniquement**.

| Champ | Valeur |
|---|---|
| Téléphone | `+225 07 00 00 00 01` (YEO Yedjane, administrateur) |
| Mot de passe | `kadjane` |
| Code OTP | `123456` |

Autres comptes utiles (même mot de passe) :

| Téléphone | Membre | Rôle |
|---|---|---|
| `+225 07 00 00 00 02` | Awa KOUASSI | Trésorier |
| `+225 07 00 00 00 03` | Serge KOFFI | Président |
| `+225 07 00 00 00 04` | Fatou DIALLO | Commissaire aux comptes |
| `+225 07 00 00 00 05` | Ibrahim TRAORÉ | Membre |

### Scénario de démonstration recommandé

1. Connexion avec le compte administrateur → le dashboard indique **1 cotisation
   en retard** sur la tontine « Tontine Solidarité » (11 membres sur 12 ont payé).
2. Ouvrir **Prochain tirage** : le bouton affiche « Tirage indisponible ».
3. Enregistrer la cotisation manquante (Salif OUATTARA) depuis l'écran de période.
4. Revenir au tirage : la roue se débloque → lancer le tirage. La roue tourne à
   l'écran, ralentit, s'arrête sur le gagnant sous la flèche, **puis** la
   fenêtre de félicitations s'ouvre.
5. Le bénéficiaire est désigné, sort de la roue **mais reste cotisant**.
6. Enregistrer le versement depuis l'écran bénéficiaire.
7. Vérifier la trace complète dans l'onglet **Activités** (journal d'audit).

Puis, côté console web (`flutter run -d chrome -t lib/main_admin.dart`) :

8. **Relances** → le membre en retard apparaît avec son niveau d'escalade ;
   sélectionner, choisir les canaux, ajuster le message, envoyer.
9. **Rôles et permissions** → accorder « Lancer » (tirage) au trésorier :
   l'application mobile applique le nouveau droit immédiatement.
10. Le membre relancé retrouve le message dans **Mes cotisations** sur mobile.

---

## 6. Architecture

Clean Architecture à trois couches, organisation *feature-first* pour la
présentation.

```
┌──────────────────────────────────────────────┐
│ presentation (features/…)                    │
│   écrans, widgets, providers Riverpod        │
├──────────────────────────────────────────────┤
│ domain                                       │
│   entités, enums, services métier,           │
│   interfaces de repositories                 │
├──────────────────────────────────────────────┤
│ data                                         │
│   repositories mock (base en mémoire + seed) │
│   repositories REST (client HTTP + DTO)      │
└──────────────────────────────────────────────┘
        ▲ core (config, erreurs, stockage, réseau, utils)
        ▲ design_system (thème, tokens, composants)
```

Principes appliqués :

- **Le domaine ne dépend de rien** : ni Flutter, ni source de données.
- **Les écrans ne connaissent que des interfaces** ; les implémentations sont
  injectées dans `lib/app/di/providers.dart`.
- **Aucune URL, couleur, dimension ou chaîne de caractères en dur** dans les
  écrans : tout passe par `AppConfig`, le design system et les fichiers ARB.
- **Les droits ne sont jamais codés dans l'UI** : les écrans demandent une
  `Permission`, jamais un rôle.
- **Gestion d'état** : Riverpod (`AsyncNotifier`, `Notifier`, `FutureProvider`),
  navigation centralisée avec `go_router` et redirection selon la session.

---

## 7. Structure des dossiers

Le dépôt héberge l'application mobile (à la racine) et le backend :

```
kadjane/
├── lib/ test/ android/ ios/ web/   Application Flutter
├── backend/                        API FastAPI + PostgreSQL
├── apps/admin/                     Back-office Angular
├── docs/                           Contrat d'API, guides backend et admin
├── docker-compose.yml              PostgreSQL + backend (+ admin, au besoin)
└── .env.example
```

### Back-office Angular

```
apps/admin/src/app/
├── core/          modèles, services (un par domaine), interceptor, guards, pipes
├── shared/        composants réutilisables (tables, badges, états, dialogues)
├── layout/        coquille : barre latérale, barre supérieure
└── features/      un dossier par écran, chargé à la demande
```

### Backend

```
backend/
├── app/
│   ├── api/health.py       /health (vérifie réellement PostgreSQL)
│   ├── api/v1/             auth, users, organizations, members, pending
│   ├── core/               config, sécurité JWT, erreurs, enveloppe, dépendances
│   ├── db/                 Base déclarative, session, seed
│   ├── models/             User, Organization, OrganizationMember, RefreshToken
│   ├── schemas/            Pydantic (camelCase automatique)
│   ├── repositories/       Accès aux données
│   ├── services/           Règles métier et permissions
│   └── main.py
├── alembic/                Migrations
├── tests/                  pytest (dont l'isolation multi-association)
└── Dockerfile
```

### Application Flutter

```
lib/
├── app/                    Coquille applicative
│   ├── di/providers.dart   Injection de dépendances (mock ↔ REST)
│   ├── router/             Routes et redirections
│   ├── state/              Session, organisation active, préférences
│   └── app.dart            MaterialApp.router
├── bootstrap.dart          Démarrage (config, stockage, préférences)
├── main.dart               Point d'entrée
├── core/                   Noyau technique
│   ├── config/             Environnements (dev / staging / prod)
│   ├── error/              Exceptions typées + traduction des messages
│   ├── extensions/         Raccourcis de contexte (l10n, thème, couleurs)
│   ├── network/            Contrat API, routes, connectivité
│   ├── services/           Sélection de justificatifs
│   ├── storage/            Secure storage, préférences, stockage fichiers
│   └── utils/              Montants, dates, validation, aléa, logs
├── design_system/          Système de design centralisé
│   ├── theme/              Couleurs, typographie, espacements, ombres, thèmes
│   ├── widgets/            KButton, KCard, KBadge, KAvatar, KAsyncView…
│   └── labels.dart         Traduction des énumérations métier
├── domain/                 Cœur métier
│   ├── entities/           User, Organization, Tontine, Contribution…
│   ├── enums/              Statuts, rôles, permissions, moyens de paiement…
│   ├── repositories/       Contrats + objets de commande (drafts)
│   └── services/           Moteur de tirage, règles de tontine, permissions
├── data/                   Implémentations
│   ├── mock/               Base en mémoire + jeu de données de démonstration
│   ├── remote/             Client HTTP (Bearer, refresh, mapping d'erreurs)
│   ├── dto/                Conversion JSON ⇄ entités
│   └── repositories/       MockXxxRepository et RestXxxRepository
├── admin/                  Console web d'administration
│   ├── router/             Routes de la console
│   ├── shell/              Navigation latérale et en-tête
│   ├── screens/            Pilotage, membres, rôles, relances, audit
│   └── widgets/            Mise en page, sections, tableaux de données
├── main_admin.dart         Point d'entrée de la console
├── features/               Une fonctionnalité = un dossier
│   ├── auth/ dashboard/ members/ tontines/ contributions/
│   ├── draw/ beneficiary/ activity/ notifications/
│   └── treasury/ reports/ profile/ organization/ shell/
└── l10n/                   Fichiers ARB (fr, en) + code généré
test/
├── core/ domain/ data/     Tests unitaires et de repositories
├── widget/                 Tests de widgets et parcours applicatif
├── integration/            Parcours contre le backend réel (hors suite par défaut)
└── helpers/                Contexte de test partagé
```

---

## 8. Règles métier clés

### Sortir de la roue ≠ sortir de la tontine

C'est la règle fondamentale de Kadjane. Lorsqu'un membre reçoit la cagnotte :

| Conséquence | Valeur |
|---|---|
| Éligibilité aux prochains tirages | `false` |
| Participation à la tontine | **inchangée** |
| Obligation de cotiser | **maintenue jusqu'à la fin** |
| Présence dans les rapports | **maintenue** |

Implémentée par `TontineParticipant.markAsBeneficiary()` et vérifiée par les
tests `test/data/draw_repository_test.dart`.

### Modes d'attribution

| Mode | Fonctionnement |
|---|---|
| **Tirage à chaque période** | Un tirage par cycle parmi les membres non encore servis (mode principal) |
| **Ordre complet par tirage** | Un tirage unique au démarrage fixe tout l'ordre de passage |
| **Ordre manuel** | L'administrateur définit lui-même l'ordre |

### Intégrité du tirage

- Le bénéficiaire est calculé par `DrawEngine` **avant** l'animation ; la roue ne
  fait qu'afficher un résultat déjà déterminé.
- La source d'aléa est abstraite (`RandomSource`) : cryptographique côté client,
  déterministe en test, et prête pour un calcul côté serveur.
- Chaque session conserve : participants éligibles, gagnant, auteur, horodatage,
  référence de preuve, source d'aléa et éventuel forçage.
- Un tirage validé n'est **jamais supprimé** : il peut seulement être invalidé,
  avec motif obligatoire et trace d'audit.

### Conditions de tirage

Par défaut, le tirage exige que toutes les cotisations du cycle soient réglées.
Un administrateur peut forcer l'opération si l'organisation l'autorise ; le
forçage est systématiquement historisé (`AuditAction.drawOverridden`).

### Montants collectés

Seules les cotisations **confirmées** entrent dans le montant collecté. Une
cotisation annulée reste visible dans l'historique mais ne compte plus.

---

## 9. Conventions de code

- Types explicites sur les déclarations, `final` par défaut.
- Un fichier = une responsabilité ; pas de fichier géant.
- Documentation `///` sur les classes publiques et les règles métier.
- Les entités ne redéfinissent pas `==` : l'égalité par référence garantit le
  rafraîchissement des vues Riverpod.
- Les mutations passent par un repository, puis `refreshOrganizationData(ref)`
  invalide les lectures concernées.
- Les `TODO(api)` marquent chaque point d'intégration backend restant.

Vérification :

```bash
dart format --set-exit-if-changed lib test
```

```bash
flutter analyze
```

---

## 10. Tests

```bash
flutter test
```

Couverture :

```bash
flutter test --coverage
```

| Fichier | Objet |
|---|---|
| `test/core/formatting_test.dart` | Montants FCFA, dates, validation, calcul des périodes |
| `test/domain/draw_engine_test.dart` | Tirage reproductible, ordre complet, preuve de tirage |
| `test/domain/tontine_rules_service_test.dart` | Éligibilité, collecte, conditions de tirage |
| `test/domain/permission_service_test.dart` | Matrice des droits par rôle |
| `test/data/draw_repository_test.dart` | Règles critiques de bout en bout |
| `test/data/http_api_client_test.dart` | Bearer, requêtes, refresh 401, mapping des erreurs HTTP |
| `test/data/rest_repositories_test.dart` | Routes, corps envoyés et mappers JSON des repositories REST |
| `test/domain/dunning_service_test.dart` | Sélection des impayés, niveaux d'escalade, composition du message |
| `test/data/governance_repositories_test.dart` | Matrice de rôles éditable, campagnes de relance, notifications |
| `test/widget/admin_console_test.dart` | Connexion à la console, navigation, matrice, centre de relance |
| `test/widget/draw_wheel_test.dart` | Alignement du gagnant sous la flèche, animation de la roue |
| `test/widget/design_system_test.dart` | Composants et thèmes clair/sombre |
| `test/widget/app_flow_test.dart` | Onboarding → connexion → dashboard → tontines |
| `test/data/backend_contract_test.dart` | Réponses **réelles** du backend rejouées dans les repositories REST |
| `test/data/tontine_contract_test.dart` | Tontines, cycles, cotisations, tirage, bénéficiaire, versement |
| `test/integration/live_api_test.dart` | Parcours complet contre le backend en marche (hors suite par défaut) |

Règles couvertes explicitement :

- un ancien bénéficiaire ne participe plus au tirage ;
- un ancien bénéficiaire continue de cotiser ;
- un cycle ne peut pas avoir deux bénéficiaires ;
- une cotisation annulée ne compte pas dans le collecté ;
- un tirage validé ne peut pas être modifié directement.

### Tests du backend

```bash
cd backend && .venv/Scripts/python -m pytest
```

Ils tournent sur SQLite en mémoire : aucun conteneur requis. Ils couvrent la
santé du service, l'inscription, la connexion, `/me`, les organisations, les
membres, le métier tontine (cycles, cotisations, paiements, tirage,
bénéficiaire, versement) et — surtout — l'**isolation multi-association** ainsi
que l'impossibilité d'un double tirage.

### Tests du back-office

```bash
npm --prefix apps/admin test
```

```bash
npm --prefix apps/admin run build
```

### Parcours contre le backend réel

```bash
flutter test test/integration/live_api_test.dart --dart-define=KADJANE_LIVE_API=true
```

Nécessite `docker compose up -d` puis le seed. Ignoré sans le drapeau, pour que
`flutter test` reste indépendant d'un serveur. Il rejoue le parcours complet :
connexion → organisation → tontine → cotisations → tirage serveur →
bénéficiaire → versement → cycle suivant.

### Vérification rapide de l'API

```bash
python backend/scripts/smoke_api.py
```

Parcourt le chemin critique (connexion, organisation, membres, tontines, cycle
courant, notifications, rafraîchissement) contre un serveur qui tourne, et sort
en erreur au premier appel inattendu. Utile pour distinguer en quelques secondes
une panne de serveur d'un bug applicatif.

Les requêtes portent une en-tête `Origin`, donc le script valide aussi les CORS.
Pour viser une autre machine — par exemple depuis un téléphone du réseau local :

```bash
python backend/scripts/smoke_api.py --base-url http://192.168.1.10:8000/api/v1
```

---

## 11. Environnements

Configuration centralisée dans `lib/core/config/app_config.dart`.

| Environnement | API | Source de données |
|---|---|---|
| `development` | backend local `:8000/api/v1` | **REST** (mocks en repli) |
| `staging` | `https://kadjane.up.railway.app/api/v1` | **REST** |
| `production` | `https://kadjane.up.railway.app/api/v1` | **REST** |

Recette et production visent le même backend Railway tant qu'aucun domaine
propre n'existe (`AppConfig.betaApiBaseUrl`). Le back-office suit la même URL
dans `apps/admin/src/environments/environment.production.ts`.

Sélection au lancement :

```bash
flutter run --dart-define=KADJANE_ENV=production
```

Variables `--dart-define` reconnues :

| Clé | Effet |
|---|---|
| `KADJANE_ENV` | `development` (défaut), `staging`, `production` |
| `KADJANE_API_BASE_URL` | Force l'URL du backend, quelle que soit la cible |
| `KADJANE_USE_MOCK` | `true` : données simulées ; `false` : backend réel |

Hôte du backend en développement, selon la cible :

| Cible | URL |
|---|---|
| Émulateur Android | `http://10.0.2.2:8000/api/v1` |
| Simulateur iOS, Chrome, bureau | `http://localhost:8000/api/v1` |
| Appareil physique | `http://<IP-de-la-machine>:8000/api/v1` |

Forcer la démo hors ligne sur n'importe quel environnement :

```bash
flutter run --dart-define=KADJANE_USE_MOCK=true
```

### Origines autorisées (CORS)

Le navigateur envoie une requête de pré-vol `OPTIONS` avant chaque appel : si
l'origine n'est pas autorisée, le backend répond **400 « Disallowed CORS
origin »** et l'application affiche « impossible de charger les données ».
Le serveur tourne pourtant : seule l'origine est refusée.

| Variable | Rôle |
|---|---|
| `CORS_ORIGINS` | Liste d'origines exactes, séparées par des virgules |
| `CORS_ORIGIN_REGEX` | Motif d'origines autorisées, en complément de la liste |

En **développement**, tout port de `localhost` / `127.0.0.1` est accepté d'office :
`flutter run -d chrome` sert l'application sur un port tiré au hasard à chaque
lancement, impossible à énumérer à l'avance. Ce repli ne s'applique qu'en
développement — ailleurs, seules les origines listées passent.

En recette et en production, renseigner un motif maîtrisé :

```bash
CORS_ORIGIN_REGEX=^https://([a-z0-9-]+\.)?kadjane\.app$
```

---

## 12. Backend REST

Le backend vit dans **[`backend/`](backend/)** (FastAPI + PostgreSQL) et fait
autorité sur les données : voir **[`docs/backend.md`](docs/backend.md)**. Il
sera partagé avec la console Angular et le site web.

Tout le métier est en base : **utilisateurs, organisations, membres,
authentification, tontines, participants, cycles, cotisations, paiements,
tirages, bénéficiaires, versements, trésorerie, rapports, relances,
notifications, justificatifs et journal d'audit**.

Documentation métier : **[`docs/tontine-domain.md`](docs/tontine-domain.md)**,
**[`docs/draw-system.md`](docs/draw-system.md)**,
**[`docs/payments.md`](docs/payments.md)**.
Back-office : **[`docs/admin.md`](docs/admin.md)**.

La couche REST côté Flutter est implémentée et branchée. Chaque contrat de
`lib/domain/repositories/` possède deux implémentations, choisies dans
`lib/app/di/providers.dart` selon `AppConfig.useMockData` :

```
domain/repositories/XxxRepository   (contrat)
├── data/repositories/mock_xxx_repository.dart   useMockData = true
└── data/repositories/rest_xxx_repository.dart   useMockData = false
```

Aucun écran ne change entre les deux modes.

### Composants

| Fichier | Rôle |
|---|---|
| `lib/core/network/api_client.dart` | Contrat HTTP + table des routes (`ApiRoutes`) |
| `lib/data/remote/http_api_client.dart` | Client `http` : Bearer, refresh 401, timeout, mapping d'erreurs |
| `lib/data/dto/` | Conversion JSON ⇄ entités, lecture défensive |
| `lib/data/repositories/rest_*.dart` | 12 repositories REST |

### Comportements du client

- Injection automatique de `Authorization: Bearer <accessToken>`.
- Sur `401` : un seul appel `POST /auth/refresh`, réécriture du stockage
  sécurisé, puis rejeu de la requête. En cas d'échec, la session est purgée et
  l'utilisateur revient à l'écran de connexion.
- Les codes HTTP deviennent des exceptions typées (`NotFoundException`,
  `BusinessRuleException`, `ValidationException`…) traduites par `ErrorMapper` :
  aucun message technique n'atteint l'utilisateur.
- Les enveloppes `{ "data": … }`, `{ "items": … }` et `{ "success", "data",
  "meta" }` (format du backend Kadjane) sont acceptées indifféremment.
- Un `401` sur `/auth/*` est un refus d'identifiants — pas une session
  expirée : l'écran de connexion affiche le bon message.

### Contrat attendu

Le détail des routes et des payloads est dans
**[`docs/api-contract.md`](docs/api-contract.md)**. Si le backend diffère
(snake_case, autres noms de routes), seuls `ApiRoutes` et `lib/data/dto/`
changent.

Trois responsabilités serveur sont structurantes :

1. **Le tirage est calculé côté serveur** — l'application affiche un résultat
   qu'elle ne peut pas influencer. Le champ `participants` de la session doit
   contenir les éligibles au moment du tirage : la roue s'aligne dessus.
2. **`isActive` reste `true`** pour un participant ayant reçu la cagnotte ;
   seul `isEligibleForDraw` passe à `false`.
3. **Aucune suppression** d'un tirage validé ni d'une cotisation : on invalide
   ou on annule, et l'audit conserve la trace.

### Reste à brancher

| Zone | Intégration attendue |
|---|---|
| `FileStorage` | Stockage objet S3 / MinIO (URL pré-signées) |
| Notifications push | SDK Firebase ; la route `/notifications/devices` est prête |
| Cache hors ligne | Persistance locale et file de synchronisation |

## 13. Console d'administration

`flutter run -d chrome -t lib/main_admin.dart`

Une application Flutter Web distincte (`lib/admin/`, entrée
`lib/main_admin.dart`) qui réutilise **tout** le socle : domaine, repositories,
couche REST, design system, traductions. Seule la présentation change —
navigation latérale persistante, tableaux de données, écrans larges.

| Écran | Contenu |
|---|---|
| **Vue d'ensemble** | Indicateurs, progression de la collecte, courbe d'évolution, points de vigilance actionnables (retards, tirage bloqué, versement en attente) |
| **Membres** | Tableau complet, recherche, changement de rôle et de statut en ligne |
| **Rôles et permissions** | Matrice éditable rôles × droits, badge « personnalisé », retour aux droits par défaut |
| **Relances** | Centre de relance complet (voir section suivante) |
| **Tontines** | Supervision : mode d'attribution, cagnotte, avancement des cycles, statut |
| **Audit** | Journal intégral, filtre sur les seules opérations financières |
| **Paramètres** | Réglages de l'organisation, partagés avec le mobile |

### Rôles et permissions

Chaque organisation part de la matrice par défaut de Kadjane et peut l'ajuster :

- 28 droits répartis en 10 modules (organisation, membres, tontines,
  cotisations, tirages, versements, caisse, relances, rapports, audit) ;
- une case cochée est appliquée **immédiatement**, console **et** mobile —
  `currentPermissionsProvider` lit les surcharges de l'organisation ;
- le super administrateur ne peut pas se verrouiller hors de la console ;
- toute modification est tracée (`role.updated`, `role.reset`).

Les écrans ne testent jamais un rôle mais une `Permission` : accorder « Lancer
le tirage » au trésorier suffit à faire apparaître le bouton dans l'application
mobile, sans une ligne de code.

---

## 14. Relances

Le moteur de relance (`DunningService`) répond à une question simple : **qui
n'a pas payé, depuis combien de temps, et que faut-il lui dire ?**

### Détection et escalade

| Niveau | Déclenchement |
|---|---|
| `upcoming` | dans la fenêtre de rappel avant l'échéance (`notifyBeforeDueDays`) |
| `dueToday` | le jour de l'échéance |
| `late` | après l'échéance, jusqu'au seuil d'escalade (7 jours par défaut) |
| `escalated` | au-delà du seuil : le bureau doit intervenir |

Les anciens bénéficiaires sont inclus : ils continuent de cotiser. Les membres
à jour sont exclus. L'historique des relances déjà envoyées est repris pour
éviter le harcèlement.

### Canaux

`Notification` (opérationnel), `Push`, `SMS`, `WhatsApp`, `Email` — ces quatre
derniers partent en file d'attente jusqu'au branchement des passerelles côté
backend. Le canal interne crée une vraie notification dans l'application.

### Messages

Modèle personnalisable avec variables : `{membre}`, `{montant}`, `{tontine}`,
`{periode}`, `{echeance}`, `{organisation}`, `{retard}`. Laissé vide, le
message s'adapte automatiquement au niveau d'escalade de chaque destinataire.

### Où les relances apparaissent

| Espace | Ce qui est visible |
|---|---|
| Console → **Relances** | Impayés, sélection, canaux, message, aperçu, historique des campagnes |
| Mobile → écran d'une période | Bouton **Relancer (n)** pour notifier tous les impayés en un geste |
| Mobile → **Mes cotisations** | Carte « Mes relances » : messages reçus, non lus mis en avant |
| Mobile → **Notifications** | Chaque relance interne crée une notification |
| **Audit** | `reminder.sent` avec canaux, destinataires et montant en attente |

---

## 15. Déploiement du backend

L'image `backend/Dockerfile` a deux étapes. **`production` est la dernière** :
un `docker build` sans `--target` la sélectionne, ce que font les hébergeurs
manageés. Le développement demande `target: development` (déjà câblé dans
`docker-compose.yml`), seule étape à embarquer pytest et à tourner en root.

L'étape `production` applique les migrations au démarrage, écoute sur `$PORT`
et tourne en utilisateur non privilégié.

### Variables à définir chez l'hébergeur

| Variable | Obligatoire | Remarque |
|---|---|---|
| `DATABASE_URL` | oui | Fournie par le service PostgreSQL. Le schéma sans pilote (`postgresql://`) est réécrit vers psycopg 3 |
| `JWT_SECRET` | **oui** | Sans elle, les jetons sont signés avec `dev-secret-change-me` |
| `ENVIRONMENT` | **oui** | `production`. Sinon le repli CORS localhost, réservé au développement, reste actif |
| `CORS_ORIGINS` | **oui** | Origines réelles du front. La valeur par défaut ne contient que localhost |
| `PORT` | non | Injectée par l'hébergeur ; `8000` à défaut |
| `WEB_CONCURRENCY` | non | Nombre de processus uvicorn ; `1` à défaut |
| `SEED_PASSWORD` | non | À ne pas définir en production |

Générer le secret :

```bash
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

### Premier déploiement

Les migrations créent le schéma, **pas les données** : la base est vide et
aucun compte n'existe. Créer le super administrateur depuis le conteneur :

```bash
python -m app.db.create_admin --phone "+225 07 00 00 00 01" --first-name Yedjande --last-name YEO --organization "Association Solidarité"
```

Le mot de passe est demandé sans écho. En contexte non interactif, le passer
par `KADJANE_ADMIN_PASSWORD` plutôt que par `--password`, qui laisserait une
trace dans l'historique du shell et les journaux de l'hébergeur. Sont refusés :
moins de 12 caractères, et tout mot de passe contenant un terme trop courant
(`kadjane`, `password`, `changeme`…).

Le script est idempotent, et ne crée **que** ce compte et son organisation :
aucune tontine, aucune écriture financière. Le super administrateur ajoute
ensuite les membres depuis le back-office, et chacun définit son mot de passe à
la première connexion par OTP.

> **Ne pas utiliser `python -m app.db.seed` en production.** Ce jeu de
> démonstration crée douze comptes partageant un même mot de passe connu —
> dont un administrateur — les marque comme déjà vérifiés, et injecte onze
> paiements fictifs de 50 000 FCFA dans la trésorerie, les rapports et l'audit.
> Il est réservé au développement.

Puis vérifier depuis un poste, en visant l'URL publique :

```bash
python backend/scripts/smoke_api.py --base-url https://<hôte>/api/v1 --origin https://<front>
```

### Déploiement du back-office

`apps/admin/Dockerfile` construit l'application puis la sert avec nginx.

Deux points le rendent portable :

- **Le port n'est pas figé.** `nginx.conf` est déposé comme *modèle* dans
  `/etc/nginx/templates/` ; l'entrypoint officiel de l'image y applique
  `envsubst` et remplace `${PORT}` au démarrage. `NGINX_ENVSUBST_FILTER=^PORT$`
  restreint la substitution à cette seule variable — sans ce filtre, `envsubst`
  viderait aussi `$uri`, qui est une variable **nginx**, pas d'environnement.
- **Aucun proxy vers l'API.** Le back-office et le backend sont deux services
  d'origines distinctes ; l'application appelle l'API en URL absolue
  (`environment.production.ts`).

L'origine du back-office doit donc figurer dans `CORS_ORIGINS` côté backend,
sans quoi l'interface s'affiche mais tous ses appels échouent en 400.

### Pièges rencontrés

- **`ModuleNotFoundError: No module named 'psycopg2'`** — l'hébergeur injecte
  `postgresql://…` sans pilote, que SQLAlchemy traduit par psycopg2, absent de
  l'image. Normalisé dans `app/core/config.py`.
- **Déploiement « crashed » sans erreur applicative** — le port est figé au
  lieu de suivre `$PORT`, et le healthcheck de l'hébergeur échoue.
- **500 sur toutes les requêtes** — les migrations n'ont pas tourné, le schéma
  n'existe pas.
- **400 « Disallowed CORS origin »** — `CORS_ORIGINS` ne contient pas l'origine
  du front. Voir [§11](#11-environnements).
- **« Application failed to respond » sur le back-office** — nginx écoutait un
  port figé alors que l'hébergeur route vers le sien ; ou son `proxy_pass`
  visait un hôte inexistant hors de docker-compose, ce qui empêche nginx de
  démarrer (`host not found in upstream`).

---

## 16. Roadmap

**Livré (MVP)**

- Architecture, design system, thèmes clair/sombre, FR/EN
- Authentification et session sécurisée
- Multi-organisation et permissions par rôle
- Dashboard, membres, tontines, cotisations
- Moteur de tirage (3 modes), bénéficiaires, versements
- Historique, audit, notifications, caisse, rapports
- Couche REST complète (client HTTP, DTO, 14 repositories)
- Console web d'administration (pilotage, membres, rôles, relances, audit)
- Moteur de relances multi-canal avec escalade et historique audité

**Prochaines étapes**

- Passerelles de relance réelles (SMS, WhatsApp Business, e-mail)
- Relances automatiques planifiées (J-3, J+1, J+7)
- Synchronisation hors ligne et cache local
- Mobile Money (Wave, Orange Money, MTN MoMo, Moov Money)
- Notifications push (FCM), SMS et WhatsApp
- Invitations par lien / QR Code, biométrie
- Documents, réunions, événements, aides sociales
- Console web d'administration, analytics
- Abonnements Kadjane et marketplace de services

---

© Kadjane — La tontine, en toute transparence.
