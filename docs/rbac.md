# RBAC — rôles et permissions

Kadjane n'accorde pas de droits à un **rôle nommé**, mais à un **ensemble de
permissions** que l'administrateur compose depuis le back-office. Le nom du
rôle sert à l'affichage et à la hiérarchie ; ce sont les permissions qui
décident.

---

## 1. Le modèle

```
organization_members.role_id  →  roles  →  role_permissions  →  permissions
```

Un membre porte **deux** choses, et les confondre serait une faille :

| Colonne | Rôle |
|---|---|
| `organization_members.role` | l'**étiquette** (`treasurer`, `admin`…). Elle porte la hiérarchie, donc l'anti-escalade. |
| `organization_members.role_id` | les **droits**, lus dans `role_permissions`. |

Séparer les deux permet à un rôle sur mesure d'exister sans casser
l'anti-escalade : « Responsable Cotisations » n'a pas de rang dans la
hiérarchie, il se range donc au niveau le plus bas.

### Le rôle dépend de l'organisation

Il n'y a **aucun rôle global**, hormis `super_admin` au niveau plateforme. Le
même utilisateur peut être :

```
Trésorier      dans Association A
Membre         dans Association B
Président      dans Association C
```

C'est `organization_members` qui porte cette information, et c'est elle qui
porte déjà l'isolation multi-association : sans ligne correspondante, un
`organizationId` envoyé par un client ne donne accès à rien — la réponse est
404, jamais 403, pour ne pas révéler l'existence de l'organisation.

---

## 2. Résolution des droits

`PermissionService.permissions_for(membership)` cherche dans cet ordre :

1. le rôle explicitement attribué au membre (`role_id`) ;
2. le rôle système **de cette organisation** portant le code de l'étiquette —
   c'est celui que la console personnalise ;
3. le rôle système **global** de même code, semé par la migration ;
4. la matrice statique de `app/rbac/catalog.py`, en dernier recours.

Le quatrième niveau n'est pas décoratif : sur une base restaurée dont le seed
n'a pas encore tourné, il maintient l'API vivante au lieu de tout refuser.

> **Un rôle désactivé ne confère plus rien.** Il ne retombe pas sur
> l'étiquette : c'est le sens de la désactivation, et c'est le comportement
> sûr.

---

## 3. Rôles système

Six rôles, semés une fois avec leurs droits par défaut, puis **laissés
intacts** : repasser dessus au démarrage écraserait un ajustement de
l'administrateur.

| Code | Nom | Résumé |
|---|---|---|
| `super_admin` | Super administrateur | tous les droits |
| `admin` | Administrateur | pilote l'association, les rôles compris |
| `president` | Président | valide les tontines, conduit les tirages |
| `treasurer` | Trésorier | caisse, cotisations, paiements, versements |
| `auditor` | Commissaire aux comptes | lecture des finances et de l'audit |
| `member` | Membre | consulte ce qui le concerne |

### Personnaliser n'affecte que soi

Les rôles système sont d'abord **globaux** (`organization_id IS NULL`) : un
gabarit partagé. À la première modification, l'organisation en reçoit une
**copie** qui lui appartient, portant le même code. Le trésorier d'une
association ne change donc pas parce qu'une autre a ajusté le sien.

Un rôle système ne peut pas être désactivé : désactiver « Membre » priverait
de droits tous ceux qui n'ont pas de rôle explicite.

---

## 4. Rôles sur mesure

L'administrateur crée les rôles qu'il veut :

```json
POST /api/v1/organizations/{id}/roles
{
  "name": "Responsable Cotisations",
  "permissions": ["contribution.view", "contribution.create",
                  "contribution.update", "payment.view"]
}
```

Le code est dérivé du nom (`responsable-cotisations`) s'il n'est pas fourni.

> **On ne peut accorder que ce qu'on possède.** Les permissions demandées sont
> filtrées par celles de l'auteur. Sans ce filtre, `role.create` permettrait
> de fabriquer un rôle portant des droits qu'on n'a pas, puis de se
> l'attribuer : l'escalade se ferait en deux appels parfaitement légitimes
> pris séparément.

---

## 5. Le catalogue des permissions

`app/rbac/catalog.py` décrit ce que le backend **sait protéger**. Il n'est pas
administrable : ajouter une permission suppose du code qui l'exige quelque
part. La console attribue, elle ne crée pas.

Les codes sont en `point.minuscule` — même format que depuis la première
version, pour que les gardes Angular et l'énumération Dart existantes
continuent de fonctionner.

Certaines actions sont couvertes par **deux** codes : `contribution.confirm`,
historique, et `payment.confirm`, plus précis. Les rôles système portent les
deux, si bien qu'aucun comportement ne change ; un rôle sur mesure peut, lui,
n'accorder que le code fin. Les endpoints concernés utilisent `require_any`.

`tests/test_rbac.py` vérifie qu'aucun `require("…")` du code ne vise un code
absent du catalogue — une telle faute rendrait l'endpoint inaccessible à tout
le monde, en silence.

---

## 6. Exiger une permission

```python
PermissionService(db).require(context.membership, "cashbox.create")
```

Jamais :

```python
if user.role == "treasurer":  # à proscrire
```

Le contrôle porte sur la permission, pas sur le nom du rôle — sinon un rôle
sur mesure ne pourrait rien faire.

---

## 7. Le frontend n'est jamais la seule barrière

Angular masque les routes (`permissionGuard`), Flutter masque les boutons.
Les deux lisent `GET /api/v1/me/permissions`. **Le backend refuse de toute
façon** : un appel direct à l'API sans la permission renvoie 403, avec le code
manquant dans `error.details.requiredPermission`.

---

## 8. Endpoints

| Méthode | Route | Permission |
|---|---|---|
| GET | `/permissions` | session |
| GET | `/me/permissions?organizationId=` | session |
| GET | `/organizations/{id}/roles` | membre |
| POST | `/organizations/{id}/roles` | `role.create` |
| PATCH | `/organizations/{id}/roles/{roleId}` | `role.update` |
| PUT | `/organizations/{id}/roles/{roleId}/permissions` | `permission.assign` |
| PATCH | `/organizations/{id}/members/{memberId}/role` | `role.assign` |

`GET /me/permissions` renvoie **toujours un tableau**, une entrée par
appartenance — un membre peut être trésorier ici et simple membre ailleurs, et
l'application doit pouvoir changer d'organisation sans redemander ses droits.

```json
[
  {
    "organizationId": "org_1",
    "memberId": "mbr_1",
    "role": "treasurer",
    "roleId": "rol_1",
    "roleName": "Trésorier",
    "permissions": ["cashbox.view", "cashbox.create", "payment.confirm", "…"]
  }
]
```

---

## 9. Audit

Toute modification de droits laisse une trace : `role.created`,
`role.updated`, `role.permissions_changed`, `member.role_changed`. Le
changement de permissions enregistre les codes **ajoutés** et **retirés**, pas
seulement le nouvel état.

---

## 10. Seed

La migration `a7c1e5d94b30` sème le catalogue et les six rôles système. Pour
rattraper une base restaurée depuis une sauvegarde antérieure :

```bash
python -m app.rbac.seed
```

Idempotent : les permissions existantes voient leur libellé rafraîchi, les
rôles déjà présents ne sont pas touchés, et rien n'est jamais supprimé — une
permission retirée du catalogue reste en base, parce que des rôles la portent
peut-être et qu'une désaffectation silencieuse ouvrirait ou fermerait des
droits sans trace.
