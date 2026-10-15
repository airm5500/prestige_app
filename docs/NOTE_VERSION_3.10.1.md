# Prestige Pharmacien 3.10.1+42 — réponses du pharmacien sur la 3.10.0

## Numéro de version

**3.10.1+42** (3.10.1 = ajustements ; 42 = +1 par rapport à 41). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

## Réponses du pharmacien et ce qui change

| # | Réponse | Dans l'application |
|---|---|---|
| 1 | « P4 convient » | P4 « icônes illustrées » gardé tel quel |
| 2 | « Je veux les 3 [dispositions] mais paramétrables, avec par défaut l'affichage P4_1_accueil » | **Par défaut : style P4 + « tout sur une page »** (comme `propositions_couleurs/p4_1_accueil_A.png`) ; les trois dispositions et les autres styles (Actuel, P1, P2, P3) restent au choix ; le réglage « Style des icônes » n'est **plus caché** |
| 3 | Demande « grossiste sur chaque pièce / montant par grossiste d'un groupe » à transmettre | `docs/serveur/DEMANDES_SERVEUR_2026-10-15.md` § 1 complétée et marquée **à transmettre** |

## 1 — P4 par défaut, migration

- Un appareil sur lequel **personne n'a jamais choisi** de style d'icônes affiche **P4** ; la disposition des menus
  reste « tout sur une page » (défaut inchangé).
- Un appareil sur lequel un style a été **choisi explicitement** (Actuel, P1, P2 ou P3, mémorisé) **le garde**.
- La lecture au lancement n'écrit rien : le choix reste « non fait » tant qu'on ne touche pas le réglage. Toucher un
  style (même P4) le mémorise comme choix explicite.

## 2 — « Style des icônes » visible, mêmes droits que « Menus de l'accueil »

Réglages › Apparence › **Style des icônes** : visible pour tous les comptes, P4 marqué « (par défaut) » ;

- compte « admin » et profils **administrateur / pharmacien** : le changent directement (aucun code) ;
- autres comptes : réglage **verrouillé** avec « Réservé à l'administrateur ou au pharmacien : ce réglage n'est pas
  modifiable avec ce compte. » ; un toucher le rappelle ; aucun code administrateur ne le déverrouille.

## 3 — Demande au serveur à transmettre

`docs/serveur/DEMANDES_SERVEUR_2026-10-15.md` § 1 (priorité P2) : `grossisteId` et `grossiste` sur chaque pièce de
`GET /pointage-bl` ; pour une recherche par groupe, tableau `parGrossiste` (BL, avoirs, net, pièces, pointées, à
pointer) calculé sur toutes les pièces quel que soit `etat`, sommes égales aux totaux ; endroit du code serveur à
modifier, règles, compatibilité (application déjà prête), quatre vérifications `curl`.

## Captures

- `docs/maquettes/captures_3_10_1/` : accueil A et B par défaut (P4, tout sur une page) sur téléphone 1080 × 2400 et
  Sunmi 720 × 1440 ; Réglages du pharmacien (style modifiable) et d'un compte simple (verrouillé) ; page `index.html`.
- Régénérées : `docs/maquettes/propositions_couleurs/` (page `index.html` : P4 « par défaut »),
  `docs/maquettes/captures_3_10_0/reglages_menus_et_style.png`.

## Tests

- **Nouveau** : `integration/retours_3_10_1_test.dart` (défaut, migration pour chaque style, droits du réglage,
  refus sans les droits).
- **Mis à jour** (règle changée par le pharmacien, rien d'affaibli) : défaut P4 au lieu d'Actuel dans les tests
  unitaires 3.9.0 et 3.10.0 ; parcours 3.9.0 : le pharmacien change aussi le style, le compte simple le voit verrouillé
  (auparavant : réglage caché) ; parcours 3.10.0 : migration de bout en bout ; performance : connexion → accueil par
  défaut (temps et requêtes) ; réseau : icônes par défaut sans réseau ; ergonomie : accueil A, B, C par défaut et
  réglage verrouillé (5 tailles × 2 échelles).
- Aide de test : `preparerTelephone(styleIcones: null)` simule « jamais choisi » ; sinon le style préparé est mémorisé
  comme un choix explicite (les tests existants restent en « Actuel »).
- `flutter analyze` : 44 remarques, aucune nouvelle.
