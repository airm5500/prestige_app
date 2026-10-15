# Icônes illustrées (proposition P4) — source, licence, correspondances

Demande du pharmacien (15/10/2026), à propos des propositions de couleurs : « pourquoi ne pas utiliser des icônes
réelles ? pour mieux apprécier, c'est une application professionnelle ».

## Collection retenue

| | |
|---|---|
| **Collection** | **Fluent Emoji** de Microsoft, style « 3D » (<https://github.com/microsoft/fluentui-emoji>) |
| **Version** | dépôt `microsoft/fluentui-emoji`, commit `1ffb34c752ecf5d402f04cfb4b392c77f57c54bc` (branche `main`, lu le 15/10/2026) |
| **Licence** | **MIT** (« Copyright (c) Microsoft Corporation ») : usage commercial, modification et redistribution permis, à condition de joindre le texte de la licence |
| **Texte de la licence** | `assets/icones_illustrees/LICENCE_FLUENT_EMOJI.txt` (copie exacte du fichier `LICENSE` du dépôt), embarqué dans l'application et ajouté à ses licences (`enregistrerLicenceIcones`, `lib/nouvelle_interface/icones_illustrees.dart`) |
| **Embarquées** | oui : `assets/icones_illustrees/*.png`, déclarées dans `pubspec.yaml` ; **aucun téléchargement** (ni au lancement ni ensuite), fonctionne sans Internet |
| **Format** | PNG 144 × 144 px (réduits depuis les 256 × 256 d'origine, sans autre retouche), 38 fichiers, ~550 Ko au total ; décodés à la taille affichée (`cacheWidth`) |

Pourquoi Fluent Emoji plutôt que Fluent UI System Icons « Color » (Microsoft, MIT aussi) : la collection « Color »
ne compte qu'environ 200 icônes d'interface et **n'a ni camion, ni colis, ni gélule, ni sablier** ; Fluent Emoji
représente les **objets réels** du métier (livraison, colis, gélule, caisse, registre…), dans un seul style cohérent
(celui de Microsoft Teams et de Windows 11).

## Où elles s'affichent (style P4 seulement)

Réglages › Apparence › **Style des icônes** › **P4 · Icônes illustrées** — **style par défaut depuis la 3.10.1** (décision du pharmacien) ; le réglage est visible et modifiable par l'administrateur ou le pharmacien :

- accueil **A** (tuiles des familles, en pages ou sur une page) ;
- accueil **B** (lignes de menus), **« Tous les menus »** de C, onglet **Analyses** ;
- **barre du bas** : onglet actif en couleur sur une pastille bleu clair, les autres en gris atténué (le libellé
  actif reste en gras : l'état ne repose jamais sur la couleur seule).

Un utilisateur qui avait choisi un autre style (Actuel, P1, P2, P3) le garde ; sans choix, P4 s'affiche. Une image manquante est remplacée par l'icône
Material du menu. Les icônes sont décoratives pour le lecteur d'écran (le titre du menu est lu).

## Correspondances

### Menus

| Menu | Fichier | Emoji d'origine (Fluent Emoji) |
|---|---|---|
| Détail CA | `sac_argent.png` | Money bag |
| CA Global | `calendrier.png` | Spiral calendar |
| Récap de caisse | `ticket.png` | Receipt |
| Rapport d'Activité | `presse_papiers.png` | Clipboard |
| Stat TVA | `boulier.png` | Abacus |
| Annulation Ventes | `interdit.png` | Prohibited |
| Retraits et abandons | `corbeille.png` | Wastebasket |
| Ventes modifiées | `crayon.png` | Pencil |
| CA Crédit | `carte_bancaire.png` | Credit card |
| Suivi Crédit | `registre.png` | Ledger |
| Avis | `etoile.png` | Star |
| Rappels traitement | `gelule.png` | Pill |
| Marge Produits Vendus | `piece.png` | Coin |
| Tableau: Analyses | `courbe_hausse.png` | Chart increasing |
| Tableau: Ratios | `balance.png` | Balance scale |
| Analyse Article | `loupe.png` | Magnifying glass tilted right |
| Suivi 20/80 | `trophee.png` | Trophy |
| Analyse de garde | `lune.png` | Crescent moon |
| CA emplacement / famille | `classeurs.png` | Card index dividers |
| Suivi Péremption | `sablier.png` | Hourglass not done |
| Evolution Stock | `histogramme.png` | Bar chart |
| Valorisation | `diamant.png` | Gem stone |
| Suivi Ajustements | `outils.png` | Hammer and wrench |
| Suggestions | `ampoule.png` | Light bulb |
| Etat de Stock | `colis.png` | Package |
| Alertes | `cloche.png` | Bell |
| Prévisions | `telescope.png` | Telescope |
| Etat Contrôle Achat | `coche.png` | Check mark button |
| Analyse Saisies BL | `memo.png` | Memo |
| Achats Fourn. | `chariot.png` | Shopping cart |
| Retours Fournisseurs | `fleche_retour.png` | Right arrow curving left |
| Visualisation BL | `camion.png` | Delivery truck |
| Pointage BL | `case_cochee.png` | Check box with check |
| Fichier Journal | `carnet.png` | Notebook |
| Présences | `badge.png` | Identification card |

### Barre du bas

| Onglet | Fichier | Emoji d'origine (Fluent Emoji) |
|---|---|---|
| Accueil | `maison.png` | House |
| Analyses | `courbe_hausse.png` | Chart increasing |
| Équipe | `equipe.png` | Health worker (Default) |
| Pilotage | `boussole.png` | Compass |

## Ajouter ou changer une icône

1. Choisir l'emoji dans le dépôt Fluent Emoji (dossier `assets/<Nom>/3D/`) ;
2. le réduire en PNG 144 × 144 (fond transparent) dans `assets/icones_illustrees/` ;
3. l'associer au titre du menu dans `illustrationsMenus` (`lib/nouvelle_interface/icones_illustrees.dart`) ;
4. le test `test/unitaires/retours_3_10_0_test.dart` vérifie qu'aucun menu n'est sans icône, que chaque fichier
   existe au bon format et que le poids total reste sous 1 Mo.
