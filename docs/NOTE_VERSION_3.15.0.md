# Prestige Pharmacien 3.15.0+54 — Affluence (jour × heure) et Péremptions courtes

## Numéro de version

**3.15.0+54** : 3.15.0 parce que la version apporte de nouvelles fonctions, 54 parce que le numéro de build augmente de 1 (53 auparavant). Rien n'a encore été publié sur Sunmi (`docs/VERSIONS_SUNMI.md`).

Serveur de référence : branche `claude/new-session-xm8ptu`, tête `df7ba097`. **Avec un serveur plus ancien, rien ne casse** : chaque nouveauté prévoit un repli, décrit plus bas.

## 1. Tableau de bord : carte « Affluence (jour × heure) »

Elle reprend la carte du tableau de bord web (`TableauBord.js`, af41d77d) dans `lib/nouvelle_interface/vague4/tableau_bord_vague4.dart`.

**Données.** La carte appelle `GET v1/tableau-bord/affluence?date=<lundi de la semaine>&frais=0|1`. Le format a été vérifié dans `TableauBordServiceImpl.affluence` :

```json
{ "debut": "2026-10-19", "fin": "2026-10-25",
  "cases": [ { "jour": 1, "heure": 9, "ventes": 12, "ca": 98000 } ],
  "success": true }
```

- `jour` vaut 1 pour lundi.
- Le serveur n'envoie que les cases qui ont au moins une vente.
- Il garde le résultat en cache 3 minutes.
- Le périmètre des ventes est le même que celui de la fréquentation.

**Choix de la semaine.**
- Les boutons ◀ et ▶ changent de semaine, et le titre « Semaine du 19/10 au 25/10 » l'indique.
- On ne peut pas avancer au-delà de la semaine en cours.
- Le bouton « Revenir à cette semaine » ramène à la semaine du jour.
- Changer de semaine lit le cache du serveur (`frais=0`). ⟳ demande un recalcul (`frais=1`).

**Grille.**
- Il y a une ligne par jour, du lundi au dimanche. Le total de la semaine pour ce jour est affiché sous son nom.
- Il y a une colonne par heure, de la première à la dernière heure de la semaine qui a eu une vente.
- Chaque case affiche son nombre de ventes. Sa couleur va du clair au foncé selon ce nombre. Une case sans vente est grise.
- Le chiffre est en blanc ou à l'encre selon le fond. Le contraste reste d'au moins 4,5 sur toute l'échelle, ce qu'un test vérifie.
- Une légende explique les couleurs : « Moins » ▢▢▢▢▢ « Plus », avec ce que vaut la case la plus foncée.
- Un résumé donne le total de la semaine et la plus forte affluence, par exemple « samedi 10 h – 11 h (42) ».
- Le lecteur d'écran lit chaque case : jour, heure, ventes et CA.

**Téléphone et Sunmi.**
- Les cases font au moins 21 dp de large (8 h → 20 h tient sur un téléphone de 411 dp).
- Si les heures ne tiennent pas dans la largeur (par exemple une garde, 24 heures), elles défilent horizontalement. Les jours restent visibles à gauche.
- Il n'y a de débordement ni à 411 dp ni à 360 dp.

**Affichage de la carte.** Comme les autres cartes, on peut l'afficher, la masquer ou la déplacer avec le bouton « Cartes ». Elle se charge seulement quand elle arrive à l'écran.
- Sur un nouvel appareil, elle est placée après « Fréquentation horaire ».
- Si l'ordre des cartes a déjà été enregistré, elle est ajoutée à la fin, visible.

**Repli.**
- Serveur sans cette route (404) : la carte affiche « Indisponible sur ce serveur (mise à jour de Prestige nécessaire) ».
- Erreur de calcul (`erreur: true`) : la carte affiche « Le serveur n'a pas pu calculer l'affluence » avec un bouton « Réessayer ».
- Dans tous les cas, les autres cartes continuent de s'afficher.

## 2. Nouvel écran « Péremptions courtes »

Il correspond à la demande 36 D12 côté serveur (99a13f57, `ReceptionMobileRessource`). Le code est dans `lib/nouvelle_interface/vague4/peremptions_courtes_vague4.dart`.

**Où le trouver.** Le menu est dans la famille « Fournisseurs & achats », à la question « Mes fournisseurs ». C'est l'équivalent du menu web GESTION DES COMMANDES. Il est réservé à l'administrateur et au pharmacien, comme les autres nouveaux menus. Son icône illustrée est le calendrier.

**Liste.**
- La route est `GET v1/reception/peremptions-courtes?du=&au=[&grossiste=][&statut=]`, avec les mêmes filtres que l'écran web.
- La période est choisie avec le sélecteur commun. Par défaut, c'est le mois en cours, comme sur le web et le serveur.
- Le grossiste se choisit dans « Critères » (liste `common/grossiste`) et se retire avec « Retirer ».
- Le statut se choisit avec des puces : Tous, À traiter, Réclamé, Avoir reçu.
- En haut de la liste : le nombre de lignes et la **valeur**. La valeur est calculée par le serveur : quantité × PAF.
- Chaque ligne indique :
  - le produit ;
  - la décision (Accepté ou Refusé) ;
  - le statut ;
  - le CIP et le BL ;
  - le grossiste ;
  - le lot, la date de péremption et les jours qui restaient à la réception ;
  - la quantité ;
  - le motif ;
  - la date et l'heure de saisie, et la personne qui l'a faite ;
  - la valeur.

**Exports.** Le menu ⇪ propose Excel (`…/excel`) et PDF (`…/pdf`), avec les mêmes filtres que la liste. On peut ensuite partager ou ouvrir le fichier. Il n'apparaît que si la liste contient des lignes.

**Changement de statut.**
- On touche le statut d'une ligne, puis on choisit À traiter, Réclamé ou Avoir reçu.
- L'application envoie **un seul** `PUT …/{id}/statut?statut=`, et un deuxième appui pendant l'envoi est ignoré.
- Choisir le statut qu'a déjà la ligne n'envoie rien.
- Si l'enregistrement réussit, la ligne est mise à jour et le message « Statut enregistré : Réclamé. » s'affiche.
- C'est le serveur qui vérifie le droit (P_BL_MOBILE_ACCEPTER_PEREMPTION_COURTE). L'application ne connaît pas les droits du compte.
- Si le serveur refuse (403, droit manquant) :
  - le statut ne change pas et l'application affiche « Droit manquant … » ;
  - le changement de statut n'est plus proposé tant que l'écran reste ouvert.

**Repli.**
- Serveur sans la liste (404) : l'écran affiche « Indisponible sur ce serveur » et ne propose aucun export.
- Serveur sans export (404) : l'application affiche « Export indisponible sur ce serveur ».

**Données sur l'appareil.** Rien n'est gardé : ni préférence, ni cache. Seul un fichier exporté est enregistré, comme les autres exports. Le journal de l'application ne note que le chemin des requêtes.

## Tests (comme `ci.yml`)

- `test/integration/retours_3_15_0_test.dart` couvre les deux fonctions, avec 15 tests :
  - les paramètres envoyés, contre le format réel du serveur ;
  - ◀ ▶ et ⟳ ;
  - la grille sur téléphone et sur Sunmi ;
  - le contraste ;
  - les filtres ;
  - le PUT unique ;
  - le refus 403 ;
  - les exports ;
  - le serveur ancien.
- Faux serveur : `test/support/donnees_vague4.dart` (affluence, péremptions courtes, PUT par ligne, refus 403 à la demande).
- Ergonomie : `test/support/cas_retours_3_15_0.dart`, cinq écrans rendus à toutes les tailles et échelles de texte.
- Tests mis à jour :
  - tableau de bord : 8 cartes, une requête chacune (performance) ; 4 cartes « Indisponible » sur un serveur ancien (réseau) ;
  - 36 menus ;
  - liste des menus réservés.
- Captures : `CAPTURES_3_15=1 flutter test test/captures_3_15_0_test.dart --update-goldens` produit `docs/maquettes/captures_3_15_0/` (téléphone et Sunmi).

## Ce qui reste à faire

- **Serveur, facultatif** : donner au mobile les droits de la session (par exemple `peutChangerStatut` dans la réponse de la liste). L'application pourrait alors masquer le changement de statut **avant** qu'un compte sans droit essaie, au lieu d'attendre le refus du serveur.
- La liste n'est pas paginée côté serveur. Les péremptions courtes d'un mois sont peu nombreuses, donc cela convient. Une très longue période renverrait tout d'un coup.
