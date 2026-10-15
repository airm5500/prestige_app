# Demandes au serveur Prestige — 15/10/2026 (Prestige Pharmacien 3.10.0)

| | |
|---|---|
| **Date** | 15/10/2026 |
| **Demandeur** | application mobile Prestige Pharmacien (dépôt `prestige_app`), version 3.10.0+41 |
| **Destinataire** | session serveur Prestige, dépôt `airm5500/prestige` |
| **Branche lue** | `origin/claude/new-session-xm8ptu` (dernier commit `7ed8a7ac`, 15/10/2026), lecture seule |
| **Fait suite à** | `REPONSE_DEMANDES_MOBILES.md` du serveur (15/10/2026) |

Ce fichier ne remplace aucune demande antérieure ; il en ajoute une (§ 1) et en annule une qui n'avait pas été
transmise (§ 2). Les réponses de l'application aux questions du serveur sont dans
`docs/serveur/REPONSES_APP_PHARMACIEN_2026-10-15.md`.

## 1. Pointage BL : montant de chaque grossiste d'un groupe — P3

### Pourquoi

Décision du pharmacien (15/10/2026) : le pointage des BL se lit **par grossiste ou par groupe de grossistes**. Le
serveur sait déjà chercher par groupe (vérifié) :

- `GET /api/v1/pointage-bl?groupe=<id>&du=&au=&etat=` : `PointageBLRessource.criteres` → grossiste prioritaire, sinon
  `PointageBLService.grossistesDuGroupe(groupe)` (refus « Ce groupe n'a aucun grossiste. » si vide), sinon refus
  « Choisissez un grossiste ou un groupe de grossistes. » ; même règle pour `/pointage-bl/pdf` et `/pointage-bl/nombre` ;
- liste des groupes : `GET /api/v1/common/groupefournisseurs` (`CommonRessource`, entrée « Tous » `ALL` ajoutée en
  tête : l'application la retire et n'envoie jamais `ALL`) ;
- réponse : totaux du groupe (`totalBl`, `totalAvoirs`, `net`, `pointes`, `nonPointes`) et pièces.

**Ce qui manque** : chaque pièce (`PieceVue.json()`) ne dit pas à **quel grossiste** elle appartient, et la réponse
ne donne pas le **montant de chaque grossiste du groupe**. Avec un groupe, le pharmacien voit le total du groupe mais
pas la part de chacun (il doit refaire la recherche grossiste par grossiste).

### Quoi

Dans `GET /pointage-bl` (et, si possible, dans l'édition `GET /pointage-bl/pdf`) :

1. sur **chaque pièce** : `grossisteId` (`lg_GROSSISTE_ID`) et `grossiste` (libellé `str_LIBELLE`) ;
2. **quand la recherche porte sur un groupe** (plus d'un grossiste) : un tableau `parGrossiste`, un élément par
   grossiste du groupe ayant au moins une pièce sur la période, trié par libellé :

```json
"parGrossiste": [
  {"grossisteId": "G1", "libelle": "COPHARMED", "totalBl": 1250000, "totalAvoirs": -35000, "net": 1215000,
   "pieces": 14, "pointes": 9, "nonPointes": 5},
  {"grossisteId": "G2", "libelle": "LABOREX", "totalBl": 830000, "totalAvoirs": 0, "net": 830000,
   "pieces": 6, "pointes": 6, "nonPointes": 0}
]
```

Mêmes règles de calcul que les totaux actuels (`PointageBLService.liste`) : avoirs en négatif, pièces « manquants à
la réception » comptées dans les montants mais pas dans `pointes` / `nonPointes`, calcul sur **toutes** les pièces
de la période quel que soit `etat` (comme `totalBl`). Σ `parGrossiste[].net` = `net`.

### Compatibilité

Champs ajoutés, ignorés par les versions antérieures. **Dans l'application 3.10.0** (déjà prête) :

- `parGrossiste` présent → « Par grossiste du groupe » affiché sous le montant du groupe ;
- sinon, si chaque pièce porte `grossisteId` et que l'état « Toutes » est choisi → le détail est calculé par
  l'application sur les pièces reçues ;
- sinon (serveur actuel) → seul le montant du groupe est affiché, avec la mention « Montant de chaque grossiste du
  groupe : pas encore fourni par ce serveur Prestige ».

### Vérification

```
curl -s -b cj "$B/pointage-bl?groupe=<groupe de 2 grossistes>&du=2026-10-01&au=2026-10-15&etat=TOUS"
```

→ chaque pièce a `grossisteId` / `grossiste` ; `parGrossiste` a deux éléments ; Σ `net` = `net` ; avec
`grossiste=<id>` seul : pas de `parGrossiste` (ou un seul élément), réponse inchangée par ailleurs.

## 2. Annulation : recherche « tous les grossistes » du Pointage BL

La version 3.9.0 de l'application avait rédigé une demande « `tous=true` : toutes les pièces, tous grossistes
confondus » (`docs/serveur/DEMANDE_FILTRES_LISTES.md` § 2). **Cette demande est annulée** : le pharmacien veut le
montant par grossiste ou par groupe de grossistes, et l'application ne demandera jamais « tous les grossistes ».

Elle n'avait **pas été transmise** (elle ne figure pas dans la demande consolidée du 14/10/2026, antérieure à la
3.9.0) ; elle a donc été retirée de `DEMANDE_FILTRES_LISTES.md`. Cette note n'est là que pour la traçabilité :
**rien à faire côté serveur**.

Pour mémoire, `GET /pointage-bl/nombre` sans grossiste ni groupe compte les pièces de **tous les grossistes actifs**
(réponse du serveur, demande 29) : l'application **n'appelle pas** cette route (aucun compteur de pointage à
l'accueil ; voir la réponse sur la demande 29 dans `REPONSES_APP_PHARMACIEN_2026-10-15.md`).
