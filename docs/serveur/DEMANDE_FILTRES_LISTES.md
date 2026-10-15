# Demande au serveur : filtres des listes encore ignorés par Prestige

Demandeur : application mobile Prestige Pharmacien (nouvelle interface), version 3.8.0+37. Vérifié sur la branche
serveur `claude/new-session-xm8ptu` à jour (commit `d80bd11`), chemins relatifs à la racine du serveur, routes sous
`/prestige/api/v1`.

## 1. Visualisation BL : `GET /etat-control-bon/list` — filtre par utilisateur (`userId`)

### Constat

`EtatControlBonResource.list` lit : `start`, `limit`, `search`, `grossisteId`, `dtStart`, `dtEnd`, `dateType`,
`statutControle`, `ecart` et `groupeId`.

| Paramètre envoyé par le mobile | Lu par le serveur ? | Dans l'application 3.8.0 |
|---|---|---|
| `groupeId` | **Oui** (`cible(grossisteId, groupeId)` : un groupe choisi remplace le grossiste par les grossistes du groupe) | Filtre **gardé** ; la feuille précise « Un groupe choisi remplace le grossiste ». **Rien à demander.** |
| `statutControle` (`TOUS` / `CONTROLE` / `NON_CONTROLE`) | **Oui** (`FiltresControleAchat`, filtré avant la pagination, total juste) | **Utilisé** depuis la 3.8.0 (« Contrôlés » / « Non contrôlés ») à la place de `checked`. **Rien à demander.** |
| `checked` (`TERMINE` / `NON_TRAITE` / `EN_COURS`) | Non | Plus envoyé par la nouvelle interface (vide). L'écran d'origine l'envoie toujours, inchangé. |
| `userId` | **Non** | Filtre **masqué** dans la nouvelle interface (mention « proposé quand le serveur Prestige le prendra en compte ») ; `userId` part vide. |

À vérifier en officine : la version installée doit être au moins celle de la branche ci-dessus pour que `groupeId`
et `statutControle` soient lus (sur une version plus ancienne, ces filtres seraient sans effet, comme `checked`).

### Demande

Ajouter à `GET /etat-control-bon/list` (et, par cohérence, à `GET /etat-control-bon/print`) un paramètre facultatif
**`userId`** : identifiant `lgUSERID` de l'utilisateur qui a saisi le bon (`TBonLivraison.lgUSERID`, celui affiché
dans `user.fullName` de chaque ligne).

- vide, absent ou `ALL` : aucun filtre (comportement actuel) ;
- sinon : seulement les bons de cet utilisateur, **filtrés avant la pagination** (même règle que `statutControle` :
  `total` = nombre de bons retenus, pages régulières) ;
- combinable avec tous les autres critères ; rappelé dans l'en-tête de l'impression (« Utilisateur : … »).

Réponse inchangée (`{total, data}`). L'application remettra alors le filtre « Utilisateur » (liste
`GET /common/users`, déjà chargée) sans autre changement.

### Facultatif : statuts détaillés

`statutControle` distingue « contrôlé » (TERMINE) et « non contrôlé » (NON_TRAITE + EN_COURS). Si le pharmacien
souhaite un jour séparer « Non traité » et « En cours », il faudrait deux valeurs de plus (`NON_TRAITE`, `EN_COURS`)
dans `FiltresControleAchat.Statut`. **Pas demandé pour l'instant** : « Contrôlés / Non contrôlés » suffit à la
décision du pharmacien (3.8.0).

## 2. (Retiré le 15/10/2026, avant transmission)

Ce paragraphe a été retiré : décision du pharmacien (3.10.0), le pointage des BL se lit **par grossiste ou par groupe
de grossistes** ; rien n'est demandé au serveur pour une recherche sur l'ensemble des grossistes. Il ne figurait pas
dans la demande consolidée du 14/10/2026. Demandes et réponses de l'application : regroupé dans prestige_vente_app/docs/serveur/TRANSMISSION_SERVEUR_2026-10-15.md (§ 3).

## 3. Pour information : pas de demande pour les autres points de la 3.8.0

- **Suivi Ajustements** (`GET /ajustement`) : la route pagine déjà (`start` / `limit`, `total`) — utilisé par
  « Afficher plus ».
- **Ratios mensuels** (`GET /ws/ca-achats-ventes`) : la période est comparée en dates complètes
  (`DATE(…) BETWEEN dtStart AND dtEnd`) ; 12 mois à cheval sur deux années en une seule requête.
- **Suivi 20/80** (`GET /statfamillearticle/vingtQuatreVingt`) : `vingtType=QTY` classe par quantité.
  Remarque relevée au passage : la route limite le nombre d'articles avec **`topN`** et ignore `limit` (envoyé par
  les deux interfaces depuis l'origine) ; voir la question 1 de `docs/NOTE_VERSION_3.8.0.md`.
- **Rappels** (`POST /rappels-habitude/actualiser`) et **Avis** (`POST /avis-clients/avis/{id}/traiter`, statut
  `NOUVEAU`) : routes existantes, utilisées telles quelles.
