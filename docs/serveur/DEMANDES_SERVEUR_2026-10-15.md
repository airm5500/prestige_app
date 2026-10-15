# Demandes au serveur Prestige — 15/10/2026 (Prestige Pharmacien 3.10.0)

| | |
|---|---|
| **Date** | 15/10/2026 |
| **Demandeur** | application mobile Prestige Pharmacien (dépôt `prestige_app`), version 3.10.0+41 |
| **Destinataire** | session serveur Prestige, dépôt `airm5500/prestige` |
| **Branche lue** | `origin/claude/new-session-xm8ptu` (dernier commit `7ed8a7ac`, 15/10/2026), lecture seule |
| **Fait suite à** | `REPONSE_DEMANDES_MOBILES.md` du serveur (15/10/2026) |

Ce fichier ne remplace aucune demande antérieure ; il en ajoute une (§ 1, **à transmettre**, validée par le
pharmacien le 15/10/2026) et en annule une qui n'avait pas été transmise (§ 2). Les réponses de l'application aux questions du serveur sont dans
`docs/serveur/REPONSES_APP_PHARMACIEN_2026-10-15.md`.

## 1. Pointage BL : grossiste sur chaque pièce et montant de chaque grossiste d'un groupe — P2

**Statut** : **validée par le pharmacien le 15/10/2026, à transmettre** (réponse à la question 3 de la note 3.10.0).

### Pourquoi

Décision du pharmacien : le pointage des BL se lit **par grossiste ou par groupe de grossistes** (jamais « tous les
grossistes »). Le serveur sait déjà chercher par groupe (vérifié sur `origin/claude/new-session-xm8ptu`, `7ed8a7ac`) :

- `GET /api/v1/pointage-bl?groupe=<id>&du=&au=&etat=` : `PointageBLRessource.criteres` → grossiste prioritaire, sinon
  `PointageBLService.grossistesDuGroupe(groupe)` (refus « Ce groupe n'a aucun grossiste. » si vide), sinon refus
  « Choisissez un grossiste ou un groupe de grossistes. » ; même règle pour `/pointage-bl/pdf` ;
- liste des groupes : `GET /api/v1/common/groupefournisseurs` (`CommonRessource` ; l'entrée « Tous » `ALL` est retirée
  par l'application, qui n'envoie jamais `ALL`) ;
- réponse : totaux du groupe (`totalBl`, `totalAvoirs`, `net`, `pointes`, `nonPointes`) et pièces (`data`).

**Ce qui manque** : chaque pièce (`PointageBLService.PieceVue.json()`) ne dit pas à **quel grossiste** elle appartient,
et la réponse ne donne pas le **montant de chaque grossiste du groupe**. Avec un groupe, le pharmacien voit le total du
groupe mais pas la part de chacun ; il doit refaire la recherche grossiste par grossiste.

### Quoi

**A. Sur chaque pièce** de `GET /pointage-bl` (que la recherche porte sur un grossiste ou sur un groupe) :

| Champ | Type | Contenu |
|---|---|---|
| `grossisteId` | texte | `t_grossiste.lg_GROSSISTE_ID` de la pièce (BL, retour ou manquants à la réception) |
| `grossiste` | texte | `t_grossiste.str_LIBELLE` |

Le grossiste est déjà connu dans `PointageBLService.liste(List<String> grossistes, …)` : la boucle
`for (String g : grossistes) toutes.addAll(pieces(g, …))` le donne pour chaque lot de pièces ; le libellé se lit une
fois par grossiste (`SELECT lg_GROSSISTE_ID, str_LIBELLE FROM t_grossiste WHERE lg_GROSSISTE_ID IN (…)`).

**B. Seulement quand la recherche porte sur un groupe** (paramètre `groupe`, sans `grossiste`) : un tableau
`parGrossiste`, un élément par grossiste du groupe **ayant au moins une pièce** sur la période, trié par libellé :

```json
"parGrossiste": [
  {"grossisteId": "G1", "libelle": "COPHARMED", "totalBl": 1250000, "totalAvoirs": -35000, "net": 1215000,
   "pieces": 14, "pointes": 9, "nonPointes": 5},
  {"grossisteId": "G2", "libelle": "LABOREX", "totalBl": 830000, "totalAvoirs": 0, "net": 830000,
   "pieces": 6, "pointes": 6, "nonPointes": 0}
]
```

Règles (les mêmes que les totaux actuels de `PointageBLService.liste`) :

- montants HT entiers, en francs, avoirs **en négatif** (comme `totalAvoirs`) ; `net = totalBl + totalAvoirs` ;
- pièces « manquants à la réception » (`RECEPTION`) comptées dans les montants et dans `pieces`, **pas** dans
  `pointes` / `nonPointes` ;
- calcul sur **toutes** les pièces de la période, **quel que soit `etat`** (comme `totalBl` aujourd'hui) ;
- contrôles : Σ `parGrossiste[].totalBl` = `totalBl`, Σ `totalAvoirs` = `totalAvoirs`, Σ `net` = `net`,
  Σ `pointes` = `pointes`, Σ `nonPointes` = `nonPointes` ;
- recherche par **grossiste** : pas de `parGrossiste` (le reste de la réponse est inchangé).

**C. Facultatif** : dans l'édition `GET /pointage-bl/pdf` d'un groupe, une colonne « Grossiste » et un sous-total par
grossiste.

Rien d'autre ne change : paramètres, refus, écritures (`pointer`, `sequence`, `avoir`), route `/pointage-bl/nombre`.

### Compatibilité

Champs ajoutés, ignorés par les versions antérieures des applications. **L'application 3.10.0 et suivantes est déjà
prête** :

- `parGrossiste` présent → bloc « Par grossiste du groupe » affiché sous le montant du groupe ;
- sinon, si chaque pièce porte `grossisteId` et que l'état « Toutes » est choisi → détail calculé par l'application ;
- sinon (serveur actuel) → seul le montant du groupe est affiché, avec la mention « Montant de chaque grossiste du
  groupe : pas encore fourni par ce serveur Prestige ».

### Vérification

```
curl -s -b cj "$B/pointage-bl?groupe=<groupe de 2 grossistes>&du=2026-10-01&au=2026-10-15&etat=TOUS"
curl -s -b cj "$B/pointage-bl?groupe=<même groupe>&du=2026-10-01&au=2026-10-15&etat=NON_POINTES"
curl -s -b cj "$B/pointage-bl?grossiste=<un grossiste du groupe>&du=2026-10-01&au=2026-10-15&etat=TOUS"
```

1. chaque pièce a `grossisteId` / `grossiste` ;
2. `parGrossiste` a un élément par grossiste ayant des pièces ; les sommes égalent les totaux ;
3. avec `etat=NON_POINTES`, `parGrossiste` est **identique** à celui de `etat=TOUS` (seules les pièces listées changent) ;
4. avec `grossiste=` : pas de `parGrossiste` ; ses montants égalent l'élément du même grossiste dans la réponse du groupe.

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
