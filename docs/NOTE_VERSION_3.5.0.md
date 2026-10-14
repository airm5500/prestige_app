# Prestige Pharmacien 3.5.0+33 — refonte module par module, lot 3 (analyses)

Sept modules d'analyse ont une **nouvelle mise en page** dans la nouvelle interface :
**Tableau : Analyses, Tableau : Ratios (et Ratios mensuels), Suivi 20/80, Stat TVA, Marge Produits Vendus,
CA Crédit, CA Global**. Même méthode que les lots 1 et 2 (`NOTE_VERSION_LOT1.md`, `NOTE_VERSION_3.3.0.md`) : **les
données ne changent pas** (mêmes routes du serveur Prestige, mêmes paramètres, mêmes calculs, **norme du ratio
1,51 conservée**). La lecture et les calculs sont partagés par l'écran d'origine et le nouvel écran
(`lib/donnees/tableau_bord_donnees.dart`, `lib/donnees/analyses_ventes_donnees.dart`), et un test compare, module
par module, les requêtes envoyées et les chiffres affichés (points des courbes compris).

L'**ancienne interface garde ses écrans** (aucun changement visible).

Liste vérifiée dans les menus de la nouvelle interface : ces 7 modules sont tous ceux de la famille « Analyses » et
des statistiques de ventes encore à l'ancienne mise en page. Restent à l'ancienne mise en page (hors analyses) :
Récap de caisse, Achats Fourn., Fichier Journal, Annulation Ventes, Présences.

## Numéro de version

**3.5.0+33** (3.5.0 = nouveaux écrans ; 33 = +1 par rapport à 32). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

Captures (données fictives) : `docs/maquettes/captures_lot3/` — téléphone 1080 × 2400 px, tablette 1920 × 1200 px.

| Fichier | Écran |
|---|---|
| `1_analyses.png`, `1b_…_courbe_valeurs.png`, `1c_…_vue_achats.png`, `1d_…_detail_jour.png` | Tableau : Analyses : chiffres, courbe comparée, vue Achats, détail d'un jour |
| `2_ratios.png`, `2b_ratios_calcul_norme.png`, `2c_ratios_mensuels.png` | Tableau : Ratios : ratio jour par jour, calcul selon la norme, Ratios mensuels (barres + norme) |
| `3_suivi_2080.png`, `3b_…_filtres.png`, `3c_…_detail.png` | Suivi 20/80 : articles classés, nombre d'articles, détail |
| `4_stat_tva.png`, `4b_…_part_touchee.png`, `4c_…_filtres.png` | Stat TVA : anneau des parts, part touchée, type de vente |
| `5_marge.png`, `5b_marge_filtres.png`, `5c_marge_filtree.png` | Marge Produits Vendus : liste, filtre de marge, résultat filtré |
| `6_ca_credit.png`, `6b_ca_credit_detail.png` | CA Crédit : ventes à crédit, détail d'une vente |
| `7_ca_global.png`, `7b_ca_global_jours.png` | CA Global : brut / net, modes de paiement, jour par jour |
| `8_droit_manquant.png` | « Droit manquant » (sans « Réessayer ») |
| `9_tablette_analyses.png`, `9b_tablette_stat_tva.png` | Tablette : graphiques larges, tableau dense avec total |

## Ce qui change pour vous (commun aux 7 modules)

- **Chiffres clés en cartes** en haut de chaque module.
- **Sélecteur de période commun** (Aujourd'hui · Hier · 7 jours · Ce mois · Mois dernier · Personnalisée, **3 ans
  au plus**), chargé **dès l'ouverture sur « Aujourd'hui »** (les dates par défaut des écrans d'origine) : plus de
  bouton « Afficher… / Charger… / Rechercher ». Les Ratios mensuels gardent leur période d'origine (1er janvier →
  aujourd'hui).
- **Filtres dans la feuille du bas** (bouton ☰, pastille, étiquettes et « Retirer les filtres ») : nombre d'articles
  (20/80), type de vente (TVA), marge (Marge), tiers payant (CA Crédit).
- **Exports** : aucun de ces 7 écrans n'avait d'export ; il n'y a donc pas de menu « Exporter » (vérifié par les tests).
- **Listes** en cartes sur téléphone, **tableau dense** sur tablette (ligne de total), **détail en feuille** au toucher.
  Les listes longues (Marge : jusqu'à 9 999 produits ; 20/80 ; CA Crédit) sont construites **50 par 50**
  (« Afficher plus », **aucune requête** : tout est déjà chargé).
- **États clairs** : chargement, « aucune donnée », *Serveur injoignable*, *Le serveur ne répond pas*, *Erreur du
  serveur* (avec « Réessayer »), *Session expirée* (retour à la connexion), **Droit manquant** (sans « Réessayer »).
- **Recherche contrôlée** (CA Crédit, Marge) : longueur limitée, caractères inutiles refusés, 0,5 s après la frappe.
- **Graphiques** (fl_chart gardé) aux couleurs de la charte, lisibles sur petit écran : légende sous le graphique,
  axes abrégés (« 465 k », « 1,2 M »), **valeurs au toucher** (date + montant), et **distinction pas seulement par la
  couleur** : achats en **pointillés à marqueurs carrés**, ventes en **trait plein à marqueurs ronds** ; ratios avec
  l'étiquette écrite « ≥ norme » / « < norme » / « Sans achat » ; chaque part de TVA porte son taux écrit.

## Module par module

### Tableau : Analyses
Les 3 écrans d'origine (Évolution comparative, des achats, des ventes) deviennent **un graphique** avec le choix
**Comparée / Achats / Ventes** (mêmes points). Chiffres : ventes, achats, écart (ventes − achats), ratio de la
période et sa position par rapport à la norme. Jour par jour (tri par date d'origine), détail d'un jour. Avec un seul
jour, un encadré invite à choisir une période plus longue au lieu d'une courbe plate.

### Tableau : Ratios
Ratio jour par jour (ordre du serveur, comme l'origine) avec étiquette de norme ; chiffres : ratio de la période,
achats, ventes, jours ≥ norme. **Calcul selon la norme** identique (vente → achat normé = vente / 1,51 ; achat →
vente normée = achat × 1,51 ; un champ à la fois). **Ratios mensuels** (bouton et icône de la barre) : même requête,
même cumul par mois, graphique en barres avec la **ligne pointillée de la norme 1,51**, mois sous la norme en barre
ambre foncé à bout carré.

### Suivi 20/80
Rang et part du montant affiché pour chaque article ; nombre d'articles (1 à 9 999, 50 par défaut, vide = 50 comme
avant) dans la feuille des filtres. Mêmes paramètres fixes (`qtyOrCa=false`, `page=1`, `start=0`, codes vides).

### Stat TVA
Même route de l'API v3. Anneau des parts du TTC (mêmes pourcentages que le camembert d'origine) : la part touchée
s'élargit et ses chiffres s'affichent au centre ; légende avec taux et part ; tableau par taux avec total.

### Marge Produits Vendus
Même filtre **local** (=, >, <, ≥, ≤, ≠, environ ± 1) dans la feuille du bas ; recherche locale par produit ou CIP
(nouveau, sans requête) ; chiffres des produits affichés (marge, vente, achat, nombre).

### CA Crédit
Même recherche locale (client, ayant droit, N° de facture, tiers payant) ; filtre par tiers payant (local, parmi
ceux de la période) ; chiffres : montant, ventes, clients, tiers payants.

### CA Global
Mêmes totaux (CA brut, remise, TVA, **CA net = brut − remise**) ; part de chaque mode de paiement dans le CA brut ;
jour par jour dès que la période compte plusieurs jours, détail d'un jour.

## Différences de comportement à connaître

- Chargement à l'ouverture sur « Aujourd'hui » au lieu d'attendre un bouton.
- Le **choix de mois** d'origine (année en cours seulement, jusqu'au dernier jour du mois, futur compris) est
  remplacé par le sélecteur commun : « Mois dernier » envoie exactement les mêmes dates que le choix du mois
  précédent ; « Ce mois » s'arrête à aujourd'hui.
- Les filtres s'appliquent par « Appliquer » dans la feuille (avant : à chaque changement).
- Les ratios s'affichent avec une virgule (« 1,51 » au lieu de « 1.51 »).
- Marge et 20/80 : la feuille de filtres refuse une valeur hors bornes (marge de -999 à 999 %, 1 à 9 999 articles).

## Tests

- `test/lot3_non_regression_test.dart` : écran d'origine et nouvel écran contre le même faux serveur, pour les 7
  modules — mêmes requêtes (jour, mois dernier, nombre d'articles, type de vente, version d'API), mêmes points des
  trois graphiques, mêmes ratios et même règle de norme (couleur d'origine = étiquette nouvelle), mêmes achat /
  vente normés, mêmes ratios mensuels, mêmes totaux et parts du TTC, mêmes produits retenus par le filtre de marge,
  mêmes ventes retenues par la recherche du CA Crédit (sans nouvelle requête).
- `test/e2e/parcours_lot3_test.dart` (application entière, HTTP réel) : chaque module ouvert depuis l'accueil,
  période, filtres, recherche, vue du graphique, valeur au toucher, détail, « Afficher plus » sans requête, absence
  de menu Exporter, retour ; 500 + Réessayer, droit manquant (sans Réessayer), serveur injoignable ; session expirée
  pendant un changement de période → connexion avec message.
- `test/unitaires/lot3_donnees_test.dart` : calculs partagés (norme 1,51, filtres, cumuls, abréviations).
- Ergonomie et cohérence : les 7 nouveaux écrans et 31 états (graphiques remplis, valeurs au toucher, vues, filtres,
  détails, Ratios mensuels, calcul normé, « Afficher plus », un seul jour, vide, erreurs ; `test/support/cas_lot3.dart`)
  aux 5 tailles × texte 1,0 / 1,3, **sans aucun écart toléré** ; charte bleu nuit / ambre.
- Écrans d'origine : leurs tests existants passent sans modification.

## Questions pour le pharmacien

1. **Ouverture sur « Aujourd'hui »** (dates par défaut d'origine) : pour Tableau : Analyses, une courbe d'un jour
   n'a pas de sens ; préférez-vous « 7 jours » ou « Ce mois » à l'ouverture (comme l'Évolution du stock) ?
2. **Ratios mensuels** : limités à l'année en cours comme l'origine (en janvier, un seul mois). Faut-il pouvoir
   choisir l'année, ou voir les 12 derniers mois ?
3. **Récap de caisse et Achats Fourn.** ne sont pas dans ce lot (caisse et fournisseurs, pas analyses) : à refaire
   dans un prochain lot ?
4. **Suivi 20/80** : le serveur reçoit toujours `qtyOrCa=false` (classement au chiffre d'affaires) ; souhaitez-vous
   un choix « par quantité » ?
5. **Exports** : aucun de ces écrans n'en avait ; voulez-vous un PDF ou un CSV (TVA, Marge, CA Crédit) ?
