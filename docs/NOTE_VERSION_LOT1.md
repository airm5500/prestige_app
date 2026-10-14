# Prestige Pharmacien 3.0.0+27 — refonte module par module, lot 1 (consultation quotidienne)

> **Mise à jour 3.1.0+28** : période limitée à **3 ans** (et non plus 366 jours), Suivi Péremption avec une période en mois en tête d'écran, composants communs aussi utilisés par la vague 1 : voir `NOTE_VERSION_3.1.0.md`.

Six modules de consultation quotidienne ont une **nouvelle mise en page** dans la nouvelle interface :
**Rapport d'Activité, Détail CA, Analyse Article, Fiche Article, Suivi Péremption, Suivi Crédit**.
**Les données ne changent pas** : mêmes routes du serveur Prestige, mêmes paramètres, mêmes calculs. La lecture
des données est désormais partagée entre l'écran d'origine et le nouvel écran (`lib/donnees/`), et un test compare,
module par module, les requêtes envoyées et les chiffres affichés par les deux écrans.

L'**ancienne interface garde ses écrans** (aucun changement visible).

Captures (téléphone 1080 × 2400, données fictives) : `docs/maquettes/captures_lot1/`

| Fichier | Écran |
|---|---|
| `0_accueil_A_bouton_reglages.png` | Accueil A : bouton Réglages (engrenage) en haut à droite, barre Accueil · Analyses · Équipe |
| `1_rapport_activite.png` | Rapport d'Activité : période, chiffres clés, sections |
| `2_detail_ca.png` | Détail CA : chiffres clés, répartition par mode de paiement, totaux |
| `3_analyse_article_resultats.png`, `3b_analyse_article_fiche.png` | Analyse Article : résultats, fiche détaillée |
| `4_fiche_article_resultats.png` | Fiche Article : résultats |
| `5_suivi_peremption.png`, `5b_…_filtres.png`, `5c_…_exporter.png` | Suivi Péremption : lots, filtre, menu Exporter (PDF) |
| `6_suivi_credit.png`, `6b_suivi_credit_filtres.png` | Suivi Crédit : liste, filtres dans une feuille du bas |
| `7_erreur_serveur_injoignable.png` | Erreur claire avec « Réessayer » |
| `8_tablette_suivi_credit_tableau.png` | Tablette : tableau dense avec total |

## Ce qui change pour vous

- **Chiffres clés en cartes en haut** de chaque module (ex. Rapport : TTC, marge brute avec % du TTC, crédit,
  réglé ; Détail CA : total brut, espèces, crédit, mobile money ; Péremption : lots, quantité, valeurs ; Crédits :
  montant, tiers payants, bons, clients).
- **Même sélecteur de période partout** (Rapport, Détail CA, Suivi Crédit) : *Aujourd'hui · Hier · 7 jours ·
  Ce mois · Mois dernier · Personnalisée*. Le module se charge **dès l'ouverture** (aujourd'hui) et à chaque
  changement de période : plus de bouton « Générer / Afficher ». Dates contrôlées : début avant fin, rien dans le
  futur, pas avant le 01/01/2000, 366 jours au plus (calendrier limité, message sinon).
- **Listes lisibles sur téléphone** (une carte par ligne) et **tableau dense sur tablette** (avec ligne de total).
- **États clairs** : chargement, « aucune donnée », et en cas d'échec la cause précise — *Serveur injoignable*,
  *Le serveur ne répond pas*, *Erreur du serveur*, *Session expirée* (retour à la connexion comme avant), *Accès
  refusé* — avec un bouton **Réessayer**.
- **Filtres dans une feuille du bas** (bouton ☰ réglages de la barre, pastille = filtres actifs) : Suivi Crédit
  (tiers payant, type de tiers payant), Suivi Péremption (mois avant péremption, 0 à 120).
- **Exports dans un menu unique** (bouton Partager de la barre) : PDF de la liste du Suivi Péremption (le même
  PDF qu'avant).
- **Recherche contrôlée** (Analyse Article, Fiche Article, Suivi Péremption) : longueur limitée, caractères
  inutiles refusés, recherche lancée 0,5 s après la frappe, et une recherche remplacée par une autre est ignorée.
- **Analyse / Fiche Article** : la fiche détaillée s'ouvre en page (et non plus en petite fenêtre), avec chiffres
  clés, stock rayon / réserve, historique et ventes mensuelles en barres.
- **Détail CA** : le camembert et la courbe sont remplacés par des barres de répartition (mêmes pourcentages) et
  la liste **jour par jour**.

## Navigation

- Le menu **« Fournisseurs »** (liste des fournisseurs) n'apparaît plus dans la nouvelle interface (accueils A, B,
  C, recherche de menu, personnalisation). Il reste dans l'ancienne interface.
- **Réglages** n'est plus un onglet : bouton **engrenage en haut à droite de l'accueil** (A, B, C ; sur tablette
  aussi dans le menu latéral). La barre du bas devient **Accueil · Analyses · Équipe** (prête à recevoir un futur
  onglet « Pilotage »).

## Différences de comportement à connaître

- « Ce mois » s'arrête à **aujourd'hui** (l'ancien choix de mois allait jusqu'au dernier jour du mois, futur
  compris) : les montants sont identiques, seul le paramètre de fin diffère.
- Le choix de mois de l'ancienne interface ne permettait que l'année en cours ; « Mois dernier » fonctionne aussi
  en janvier (décembre précédent) et « Personnalisée » couvre toute date depuis 2000.
- Suivi Péremption : la recherche part pendant la frappe (avant : à la validation du clavier).

## Tests

- `test/lot1_non_regression_test.dart` : écran d'origine et nouvel écran contre le même faux serveur — mêmes
  requêtes (jour, mois précédent, recherche, filtres) et mêmes chiffres, libellé par libellé.
- `test/e2e/parcours_lot1_test.dart` : ouverture de chaque module, période, filtre, retour ; erreur du serveur et
  Réessayer ; serveur injoignable ; session expirée ; recherche (anti-rebond, réponse remplacée ignorée).
- `test/navigation_nouvelle_interface_test.dart` : Fournisseurs absent de la nouvelle interface et présent dans
  l'ancienne ; bouton Réglages en haut à droite (48 dp, libellé) ; barre du bas sans Réglages.
- `test/unitaires/periode_test.dart` : périodes rapides et contrôles des dates.
- Ergonomie et cohérence : nouveaux écrans et leurs états (remplis, filtres, détail, exports, erreurs) aux 5
  tailles × texte 1,0 / 1,3, sans aucun écart toléré.
