# Prestige Pharmacien 3.14.1+53 — Synchronisation avec le serveur (19/10/2026, tête 965a4d1b)

## Numéro de version

**3.14.1+53** (3.14.1 = correctif / complément ; 53 = +1 par rapport à 52). Rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`). Serveur : branche `claude/new-session-xm8ptu`, tête `965a4d1b` ; **rien n'est cassé avec
un serveur plus ancien**.

## Point par point

| Changement serveur | Statut pour Prestige Pharmacien | Détail |
|---|---|---|
| Demande 45 : `parGrossiste` + `grossisteId` sur `GET pointage-bl` (fe6cdf45) | **Déjà compatible**, complété | Fait côté serveur. Format réel vérifié : chaque pièce porte `grossisteId` / `grossiste` ; `parGrossiste` = `{grossisteId, libelle, totalBl, totalAvoirs (négatif), net, pieces, pointes, nonPointes}` calculé sur toutes les pièces de la période (quel que soit l'état), trié par libellé. L'app 3.10.0+ le lisait déjà (montant par grossiste). **Ajout 3.14.1** : sous chaque grossiste du groupe, « n pièces · x pointées · y à pointer » (seulement si le serveur envoie ces compteurs). Testé contre ce format. |
| 74e9232f : lenteurs CA par emplacement / par grossiste | **Sans objet** | Routes `statfamillearticle/statisticrayons` et `statisticprovider` non appelées par l'app (elle utilise `ca-zone-geo` et `statfamillearticle/vingtQuatreVingt`). |
| ad79533f, ea2ba1b5, 965a4d1b : Pilotage « À suivre » | **Déjà compatible** | L'app envoie toujours `axe` (et `dtStart` / `dtEnd` en période personnalisée), délai 45 s ; le cache serveur (5 min) ne demande rien côté app. 965a4d1b ne change que la documentation. |
| 0f86de59 : refus « ETAT » d'une suggestion déjà commandée | **Sans objet** | L'app n'envoie ni ne commande de suggestions (pas de PharmaML). |
| 99a13f57 : péremptions courtes (écran web) | **Proposition seulement** | `GET v1/reception/peremptions-courtes` (+ `/excel`, `/pdf`, droit P_SM_PEREMPTIONS_COURTES) : pourrait devenir un écran en lecture avec exports. Non intégré (attend une décision). |
| ce2c6c4c (création BL), aa4e2390 (fiche client) | **Sans objet** | Concernent d'autres applications mobiles. |
| `RetourFournisseurDTO.blId` | **Déjà compatible** | Champ ajouté, ignoré par l'écran Retours fournisseurs (lecture seule). |

## Fichiers modifiés

- `lib/nouvelle_interface/vague3/donnees_vague3.dart` : `MontantGrossiste.pointes` / `nonPointes` (facultatifs ;
  absents chez un serveur plus ancien → rien d'affiché, pas « 0 »).
- `lib/nouvelle_interface/vague3/pointage_vague3.dart` : ligne des compteurs (clé `pointage_compteurs_grossiste_<id>`).
- `test/integration/retours_3_14_1_test.dart` : faux serveur reproduisant `PointageBLService.liste` du serveur.

## Ce qui reste à faire

- Décider si l'écran **Péremptions courtes** (lecture + Excel / PDF) doit entrer dans Prestige Pharmacien.
- Rien à demander au serveur pour cette synchronisation.
