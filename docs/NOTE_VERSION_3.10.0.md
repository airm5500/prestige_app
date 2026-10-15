# Prestige Pharmacien 3.10.0+41 — décisions du pharmacien et réponse du serveur

Quatre décisions du pharmacien (15/10/2026) et l'intégration, **avec repli**, de ce que le serveur a livré pour
l'application Pharmacien (`REPONSE_DEMANDES_MOBILES.md` du 15/10/2026, branche serveur `claude/new-session-xm8ptu`,
commit `7ed8a7ac`, non fusionnée dans `dev`). Sur un serveur qui n'a pas ces nouveautés, l'application se comporte
exactement comme la 3.9.1.

## Numéro de version

**3.10.0+41** (3.10.0 = nouveautés ; 41 = +1 par rapport à 40). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

## Résumé

| # | Décision / demande | Dans l'application |
|---|---|---|
| 1 | « Pourquoi ne pas utiliser des icônes réelles ? » | Proposition **P4 « icônes illustrées »** dans le réglage caché « Style des icônes » ; **défaut inchangé** (« Actuel ») ; captures téléphone et Sunmi |
| 2 | « Une rubrique par page, mais présente et on valide les 3 cas » | « Menus de l'accueil » : **tout sur une page** (défaut), **une rubrique par page**, **6 tuiles par page** ; captures des 3 cas |
| 3 | Réglage « Menus de l'accueil » | **Administrateur ou pharmacien seulement** ; autres comptes : verrouillé, avec l'explication (plus de code administrateur pour ce réglage) |
| 4 | Pointage BL : montant par grossiste ou par groupe, jamais « tous les grossistes » | Choix **« Par grossiste » / « Par groupe de grossistes »**, montant mis en avant, détail par grossiste d'un groupe quand le serveur le permet ; demande serveur ; demande « tous » retirée |
| 5 | Réponse du serveur (22, 23, 25, 26, 29, 9) | Filtre « Utilisateur » de Visualisation BL, « Actualiser » d'un avis sans le marquer lu, « Commandes en cours à jour » des Prévisions, Mobile Money par opérateur dans le CA Global, rôle affiché ; réponses aux questions 2 et 26 |

## 1 — P4 « icônes illustrées »

- **Collection** : **Fluent Emoji** de Microsoft, style « 3D », **licence MIT** (usage commercial permis) ; texte de
  la licence embarqué (`assets/icones_illustrees/LICENCE_FLUENT_EMOJI.txt`) et ajouté aux licences de l'application ;
  source, commit et correspondances : **`docs/ICONES_ILLUSTREES.md`**. Fluent UI System Icons « Color » (Microsoft, MIT
  aussi) a été écarté : ~200 icônes d'interface seulement, ni camion, ni colis, ni gélule, ni sablier.
- **Embarquées** dans l'application (38 PNG 144 × 144, ~550 Ko) : **aucun téléchargement**, ni au lancement ni ensuite ;
  décodées à la taille affichée (~1,3 Mo de mémoire pour toutes) ; image manquante → icône d'origine.
- Une icône **par menu** (35) et **par onglet** de la barre du bas (4), choisie pour l'objet du métier : camion
  (Visualisation BL), case cochée (Pointage BL), colis (État de stock), sablier (Péremption), gélule (Rappels
  traitement), sac d'argent (Détail CA), ticket (Récap de caisse), cloche (Alertes), télescope (Prévisions)…
- Où : accueil A (tuiles, sur une page ou en pages), accueil B, « Tous les menus » (C), onglet Analyses ; barre du bas :
  onglet actif en couleur sur une pastille bleu clair, les autres en gris atténué, libellé actif en gras (jamais la
  couleur seule). Décoratives pour le lecteur d'écran (le titre du menu est lu).
- Réglage : Réglages › Apparence › **Style des icônes** (compte « admin ») : Actuel / P1 / P2 / P3 / **P4**.

Captures (téléphone 1080 × 2400 ; Sunmi 720 × 1440) : `docs/maquettes/propositions_couleurs/` —
`<style>_1_accueil_A.png`, `_2_accueil_B.png`, `_3_liste_menus.png`, `_4_barre_du_bas.png`, `_5_sunmi_accueil_A.png`,
`_6_sunmi_accueil_B.png` pour `actuel`, `p1`, `p2`, `p3`, `p4` ; page de comparaison **`index.html`**.

## 2 — « Menus de l'accueil » : trois dispositions

Réglages › Apparence › **Menus de l'accueil** (valeur mémorisée sur l'appareil, pour tous les comptes) :

| Valeur | Disposition | Comportement |
|---|---|---|
| 0 | **Tout sur une page** (défaut) | comme aujourd'hui |
| 1 | **Une rubrique par page** | une famille par page (A : d'abord « À surveiller ») ; c'est le « Par pages » de la 3.9.0 (choix mémorisé repris) |
| 2 | **6 tuiles par page** | comme l'ancienne interface : 6 menus par page, dans l'ordre des familles ; titre = famille(s) de la page |

Balayage gauche / droite, boutons ‹ › de 48 dp, indicateur de page, titre annoncé par le lecteur d'écran. Accueils A et
B sur téléphone (et Sunmi) ; pendant une recherche de menu (B), résultats sur une page ; tablette et C : sur une page.

Captures des 3 cas : `docs/maquettes/captures_3_10_0/` — `telephone_A_<n>_<disposition>_page1/2.png`,
`telephone_B_…`, `sunmi_A_…`, `sunmi_B_…` ; P4 en pages de 6 : `telephone_A_3_parSix_p4.png` ; page **`index.html`**.

## 3 — Réservé à l'administrateur ou au pharmacien

- Modifiable par le compte « admin » et par tout compte de profil **administrateur ou pharmacien** (`xtypeuser`
  « dashboard », ou rôle PHARMACIEN / ADMINISTRATEUR / SUPER_ADMINISTRATEUR / SYSTEME sur un serveur récent).
- Autres comptes : le choix est visible, **verrouillé**, avec « Réservé à l'administrateur ou au pharmacien : ce réglage
  n'est pas modifiable avec ce compte. » ; un toucher le rappelle ; **aucun code administrateur** ne le déverrouille.
- La présentation (A / B / C) et la taille de l'écran gardent leur règle (code administrateur).

## 4 — Pointage BL : par grossiste ou par groupe de grossistes

Vérifié dans le serveur : `GET /pointage-bl?groupe=<id>` → grossistes du groupe (`PointageBLRessource.criteres`,
`PointageBLService.grossistesDuGroupe`), liste des groupes `GET /common/groupefournisseurs` (entrée « Tous » `ALL`
retirée par l'application).

- En tête : **« Par grossiste » / « Par groupe de grossistes »** (une seule liste à la fois ; changer de mode efface le
  choix, sans requête) ; dernier choix (grossiste ou groupe) toujours repris, dans le bon mode ;
- **montant mis en avant** : « Montant du grossiste » / « Montant du groupe », net HT, BL et avoirs ;
- groupe : **montant de chaque grossiste** du groupe si le serveur le donne (`parGrossiste`), ou si chaque pièce porte
  son grossiste (calcul de l'application, état « Toutes ») ; sinon (serveur actuel) mention « pas encore fourni » ;
- l'application ne demande **jamais** « tous les grossistes » (`ALL` refusé comme choix, rien n'est envoyé sans
  grossiste ni groupe) ; l'explication de l'écran ne parle plus d'une demande « tous ».

Serveur : demande (grossiste sur chaque pièce et `parGrossiste`) et annulation de la demande « tous les
grossistes » : **regroupé dans prestige_vente_app/docs/serveur/TRANSMISSION_SERVEUR_2026-10-15.md (§ 3)**. Celle-ci n'avait pas été transmise (absente de la demande consolidée
du 14/10) : elle est retirée de `docs/serveur/DEMANDE_FILTRES_LISTES.md`.

## 5 — Réponse du serveur, intégrée avec repli

« Serveur récent » = le serveur a donné le **rôle** à la connexion (`role {code, libelle}` de `POST /user/auth`,
livré sur la même branche) ; sinon, comportement 3.9.1.

| N° | Livré | Application 3.10.0 | Serveur plus ancien |
|---|---|---|---|
| 26 | `userId` (et `groupeId`) sur `etat-control-bon/list` | Visualisation BL : filtre **« Utilisateur »** de nouveau proposé, `userId` envoyé ; si la liste contient d'autres utilisateurs, avertissement « filtre non appliqué » | filtre masqué, `userId` vide (3.8.0) |
| 22 | `marquerLu=false` | Détail d'un avis : bouton **« Actualiser »** qui relit sans marquer « lu » (utile après « Remettre en Nouveau ») ; l'ouverture marque « lu » comme le web | pas de bouton |
| 23 | `enCoursAJour` | Prévisions : « **Commandes en cours à jour le …** » sous le dernier calcul | ligne absente |
| 25 | `detailMobile` dans `/ca-all` | **CA Global** : « dont Orange Money … » sous « Total Mobile Money », sans appel de plus ; Détail CA : déjà lu depuis la 3.2.1 | rien de plus |
| 9 / 10 | `user/droits`, rôle à la connexion | rôle **affiché** dans Réglages › Compte, compte comme responsable ; `user/droits` pas nécessaire | inchangé |
| 29 | routes `/nombre` | **non utilisées** : aucun écran ne charge une liste pour compter (un seul `GET /tableau-bord/alertes` à la demande) | — |

Réponses aux questions du serveur (n° 2 `POST pharma/reponses` : non utilisé par l'application ; n° 26 `checked` :
valeurs envoyées, filtre attendu = `statutControle`) : **regroupé dans prestige_vente_app/docs/serveur/TRANSMISSION_SERVEUR_2026-10-15.md (§ 3)**.

## Tests

- **Nouveaux** : `unitaires/retours_3_10_0_test.dart`, `integration/retours_3_10_0_test.dart` (serveur récent et
  ancien), `e2e/parcours_retours_3_10_0_test.dart` (application entière), `performance/retours_3_10_0_test.dart`
  (décodage réel des icônes, mémoire, pages de 6 sur téléphone et Sunmi sans requête, requêtes exactes du Pointage par
  groupe), `reseau/retours_3_10_0_test.dart` (Pointage par groupe lent, JSON partiel, coupure ; avis pendant une
  coupure ; CA Global partiel ; icônes sans réseau), `support/cas_retours_3_10_0.dart` (ergonomie et cohérence : 5
  tailles dont les deux Sunmi × texte 1,0 et 1,3, aucun écart toléré). Mesures de démarrage et de requêtes de
  l'accueil complétées (6 tuiles par page, P4).
- **Mis à jour** (règle changée, rien d'affaibli) : `AffichageMenus.parPages` devient `parRubrique` (même valeur 1) et
  la valeur 2 est désormais « 6 tuiles par page » ; parcours 3.9.0 : le compte pharmacien change les menus sans code,
  un compte simple est verrouillé avec explication (auparavant : code administrateur).
- Seuils nouveaux : décodage des icônes, mémoire décodée (`test/support/performance.dart`, `test/README.md`).
- CI : plafond de remarques de `flutter analyze` ramené de 57 à **44** (valeur actuelle, aucune nouvelle remarque).

## Questions au pharmacien

1. **Icônes** : P4 (icônes illustrées) vous convient-il ? Faut-il la combiner avec un élément d'une autre proposition
   (par exemple les en-têtes colorés de P3) ? Une icône à changer ?
2. **Menus par pages** : laquelle des trois dispositions garder par défaut (aujourd'hui : tout sur une page) ?
3. **Pointage BL** : le montant de chaque grossiste d'un groupe dépend du serveur (§ 1 de la demande du 15/10) ; à
   transmettre ?
