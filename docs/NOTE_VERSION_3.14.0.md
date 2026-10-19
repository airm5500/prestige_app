# Prestige Pharmacien 3.14.0+52 — Réponse du serveur du 19/10/2026 (décision 38) : rappels et ajustements

## Numéro de version

**3.14.0+52** (3.14.0 = nouvelles fonctions ; 52 = +1 par rapport à 51). Rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`). Serveur : branche `claude/new-session-xm8ptu` du 19/10/2026 ; **rien n'est cassé avec un
serveur plus ancien** (repli décrit pour chaque point).

## Rappels traitement (`lib/nouvelle_interface/vague3/rappels_vague3.dart`)

- **« Racheté » à la main** : la barre « marquer » propose maintenant **Préparé, Racheté, Écarté, À préparer** (deux
  rangées de deux boutons, lisibles sur un Sunmi de 360 dp). Même parcours que les autres statuts : sélection,
  **confirmation** (« Aucun message n'est envoyé au client »), **un seul envoi** (`POST
  v1/rappels-habitude/marquer?statut=ACHETE {ids}`, anti double appui), message « n rappels marqués « Racheté » »,
  puis **mise à jour** de la liste (la ligne quitte « À préparer ») et du compteur.
- **Serveur plus ancien** (il refuse « Racheté » : « Statut inconnu. ») : message « « Racheté » à la main demande la
  mise à jour du serveur Prestige (octobre 2026). », rien n'est modifié ; les autres statuts marchent comme avant.
- **« Actualiser la liste »** (`POST v1/rappels-habitude/actualiser`) : **déjà en place depuis la 3.8.0** (bouton,
  confirmation, anti double appui, indicateur « Actualisation en cours… », message du serveur, relecture) ; inchangé.
- Droits : ceux du module (P_SM_RAPPELS_HABITUDE, vérifié par le serveur), inchangés.

## Suivi des ajustements (`lib/nouvelle_interface/modules/ajustements_nouveau.dart`)

`GET v1/ajustement` était déjà lu par pages de 100 avec « Afficher plus » (3.8.0 : `start`, `limit`, `total`, mêmes
filtres). **Nouveau** : en approchant du bas de la liste, la **page suivante est demandée d'elle-même** (une à la
fois, `start` = ajustements déjà chargés, mêmes filtres, s'arrête au « total » du serveur). Après un échec, pas de
relance automatique en boucle : « Afficher plus » relance. Serveur sans « total » : comme avant (100 premiers et
avertissement, aucune page suivante).

## Le reste de la réponse du serveur : rien à faire dans Prestige Pharmacien

| N° | Sujet | Prestige Pharmacien |
|---|---|---|
| 12 | Validation des BL (produits non saisis), droit `P_BL_MOBILE_SCANNER` | ne valide ni ne scanne de BL (Visualisation et Pointage BL en lecture) |
| 17 D7 | Retour fournisseur, motif différent | Retours fournisseurs en lecture seule |
| 36 D18, 39, 2, 24, 32, 10, 34 | Boîte déjà scannée, calcul des gardes gardé 5 min (pages suivantes plus rapides, rien à changer), PharmaML… | rien |
| 51 | Pointer avec la session (`v1/rh/moi`) | le module Présences consulte les présences et affiche le QR du jour : il ne pointe pas pour le compte connecté |
| 52 | Droit `P_RH_POINTER` (terminal de pointage) | concerne le poste de pointage, pas cette application |

## Tests

- `test/integration/retours_3_14_0_test.dart` : « Racheté » (confirmation, un envoi `statut=ACHETE`, ligne et compteur
  mis à jour, aucun message envoyé), serveur ancien (message, rien modifié, autres statuts toujours possibles),
  « Actualiser la liste » présent ; ajustements : pages suivantes au défilement (start 100 puis 200, mêmes filtres,
  aucune requête de trop), échec sans relance en boucle puis « Afficher plus ».
- `test/unitaires/vague3_test.dart` mis à jour (statuts marquables : Racheté compris) ; faux serveur : `ACHETE`
  accepté, option « serveur ancien ».
- Toutes les catégories lancées exactement comme `ci.yml` avant l'envoi du code.
