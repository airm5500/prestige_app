# Prestige Pharmacien 3.17.2+59 — `tableau-bord/version` sans session n'est plus prise pour un serveur antérieur

## Numéro de version

**3.17.2+59** : 3.17.2 parce qu'il s'agit d'un correctif de la 3.17.1 (aucun écran ni route nouvelle), 59 parce que le
numéro de build augmente de 1. Rien n'a encore été publié sur Sunmi (`docs/VERSIONS_SUNMI.md`).

## 1. Ce que le serveur a précisé (réponse du 21/11)

Référence : `docs/notices/REPONSE_RETOUR_DEMANDES67_68_2026-11-20.md` (§6) sur la branche serveur
`integration/recette-2026-10-29`.

- `GET v1/tableau-bord/version` **exige une session**, comme les autres routes du tableau de bord. Sans session, elle
  répond HTTP 200 `{ "success": false, "msg": "Veuillez vous connecter" }`, **sans** `version` ni `routes`.
- `routes` ne dépend pas du réglage `KEY_TABLEAU_BORD_VERSION` (même liste en `ANCIEN` et `NOUVEAU`).
- Un serveur qui n'a pas `routes` est antérieur.

## 2. Le défaut de la 3.17.1

La 3.17.1 lit `tableau-bord/version` une fois, en arrière-plan, après un succès de `/tableau-bord/tva`. Toute réponse
sans liste `routes` était prise pour « serveur antérieur » et retenue 24 h sur l'appareil. Une réponse `success: false`
(session expirée à ce moment-là, ou autre refus), une réponse vide ou qui n'est pas un objet conduisait donc à retenir
à tort « serveur antérieur » : la lecture n'était plus refaite pendant 24 h.

(La réponse exacte « Veuillez vous connecter » était déjà traitée comme une session expirée par `ApiService`, sans rien
retenir ; c'étaient les autres messages et formes inattendues qui étaient mal lus.)

## 3. Correctif (`lib/donnees/routes_serveur.dart`, `RoutesServeur.lireVersion`)

| Réponse de `tableau-bord/version` | 3.17.1 | 3.17.2 |
|---|---|---|
| `success: true` avec `routes` | routes annoncées retenues | inchangé |
| `success: true` sans `routes` | serveur antérieur retenu 24 h | inchangé |
| `success: false` (« Veuillez vous connecter ») | rien retenu, retour à la connexion | inchangé (seul cas déjà correct) |
| `success: false`, autre message | **serveur antérieur retenu 24 h** | rien retenu ni changé |
| réponse vide, liste, `success` absent, `routes` illisible | **serveur antérieur retenu 24 h** | rien retenu ni changé |
| 401, 403, 404, 5xx, coupure, délai | rien retenu | inchangé |

- Réponse « inconnue » : **rien n'est enregistré et l'état déjà retenu ne change pas**. La lecture est refaite à la
  session suivante (prochaine ouverture de l'accueil après reconnexion), **jamais deux fois dans la même session** (⟳
  compris) : ni boucle, ni requête de plus.
- Session expirée : `{ success: false, msg: "Veuillez vous connecter" }` déclenche le **mécanisme habituel** de
  l'application, le même que pour les autres routes du tableau de bord (`ApiService` → `surSessionExpiree` →
  `AuthProvider.forceLogout` : retour à l'écran de connexion avec le message « Votre session a expiré »). Aucun
  mécanisme nouveau.
- Plafonds de requêtes de l'accueil inchangés : 11 / 9 à la première connexion sur un serveur jamais vu, 10 / 8
  ensuite. Une réponse inconnue à la première connexion fait relire `version` une fois à la connexion suivante, dans
  le plafond de la première connexion (11 / 9).

## 4. Serveur : paquet officine en attente d'installation

Le paquet officine `2f609bc4a` (intégration `integration/recette-2026-10-29`) regroupe les demandes **66, 67/68
(avec le retour du 20/11 et la précision du 21/11), 70 et 71**. Il est prêt mais **pas encore installé** en officine :
le serveur déployé reste `76aa5fc1`. L'application fonctionne avec les deux (comportements décrits dans
`docs/NOTE_VERSION_3.17.0.md` et `docs/NOTE_VERSION_3.17.1.md`).

- Demande 70 (image du ticket en 58 mm, côté serveur) et demande 71 (Analyse Article : dernière vente lue d'abord sur
  7 jours, lectures groupées, côté serveur) : **rien à changer dans l'application**. La 71 rend plus rapide
  `GET /info?search=<CIP>`, que la 3.17.1 n'attend déjà plus pour ouvrir la fiche.

## 5. Tests

- `test/integration/retours_3_17_2_test.dart` (faux serveur en mémoire, horloge simulée, données fictives) :
  - `success: false` « Veuillez vous connecter » : état déjà retenu conservé à l'identique, retour à la connexion
    demandé une fois, aucune requête de plus dans la session (⟳), relue après reconnexion puis routes retenues ;
  - `success: false` avec un autre message : rien retenu, pas de déconnexion, relue à la session suivante ;
  - `success: true` sans `routes` : serveur antérieur retenu 24 h (pas de relecture à 23 h 59), relu passé 24 h ;
  - `success: true` avec `routes` : routes annoncées ;
  - 401, 403, 404, 500, 503, coupure, délai dépassé, réponse vide, liste, JSON illisible, `success` absent, `routes`
    illisible : rien retenu, une lecture par session, nouvel essai et routes retenues à la session suivante ;
  - `RoutesServeur.lireVersion` : seule `success: true` conclut.
  - Sur la 3.17.1, 5 de ces cas échouent (autre message, réponse vide, liste, `success` absent, `routes` illisible).
- `test/performance/retours_3_17_1_test.dart` : cas 3.17.2, version sans session à la 1re connexion → 11 / 9, connexion
  suivante (relecture) → 11 / 9, puis 10 / 8.
- Toutes les catégories de la CI jouées localement (unitaires et non-régression, intégration, bout en bout,
  ergonomie, performance, réseau), analyse statique sous le plafond de 44 remarques.
