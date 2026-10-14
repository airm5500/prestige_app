# Prestige Pharmacien 3.2.0+29 — vague 2 des nouveaux menus (analyses, lecture seule)

Quatre nouveautés dans la **nouvelle interface**, réservées à l'**administrateur et au pharmacien** (profil
« dashboard », comme la vague 1). Tout est en **lecture seule**. L'**ancienne interface ne change pas** ; le lot 1 et
la vague 1 sont inchangés.

## Numéro de version

**3.2.0+29** (3.2.0 = nouvelles fonctions ; 29 = +1 par rapport à 28). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

## 1. Prévisions (menu « Stock » ; web : Analyse des commandes)

Trois onglets :

- **Prévisions** : synthèse du dernier calcul de la nuit en cartes (à commander et valeur, ruptures et taux,
  surstock, invendus, fiabilité et couverture moyennes) ; puces **Tous · À commander · En rupture · Surstock ·
  Rotation lente · Peu fiables** ; méthode et état du stock dans la feuille « Filtres » ; recherche (nom ou CIP) ;
  pages de 25 (« Afficher plus »). Toucher un produit : historique mensuel en barres, méthode retenue et méthodes
  comparées, **détail du calcul** (ventes par jour, délai, couverture voulue, besoin, sécurité, recommandé) ;
  « Voir les équivalents » à la demande.
- **Analyse suggestion / commande** : suggestions et commandes en cours (lues à la première ouverture de l'onglet),
  puis l'analyse : résumé (lignes, lignes en alerte, valeurs proposée / recommandée) et lignes avec leurs alertes
  (graves en rouge), filtre « Avec alerte ».
- **Analyse de la demande** : **aucun calcul à l'ouverture** ; 12 mois par défaut, 24 et 36 mois proposés
  normalement, rayon et produit facultatifs, bouton **Calculer**. Pendant un calcul sur 24 / 36 mois : indication
  discrète « Calcul sur N mois, peut prendre un moment » et bouton **Annuler** ; si l'on change un choix après
  le calcul, l'écran le signale (pas de relance automatique).

**Jamais depuis le mobile** : appliquer les quantités recommandées, générer une suggestion, créer un inventaire,
recalculer les prévisions, modifier les paramètres de calcul.

## 2. Pilotage : 4ᵉ onglet de la barre du bas

Barre du bas : **Accueil · Analyses · Équipe · Pilotage** pour l'administrateur et le pharmacien (trois onglets pour
les autres profils ; sur tablette, « Pilotage » dans le menu latéral). Le serveur vérifie en plus le droit
`P_SM_PILOTAGE` : sans lui, « Droit manquant ».

- Onglets internes **Synthèse** et **À suivre** ; axe de comparaison : Mois en cours, Vs mois précédent, Vs même mois
  l'an dernier, Cumul annuel, Glissant 12 mois, Période personnalisée (dates contrôlées : début ≤ fin, pas de futur,
  3 ans au plus).
- Chaque tuile : valeur et unité, **variation avec flèche et texte** (jamais la couleur seule), valeur de référence
  et sa période. « À suivre » : points d'attention (critique / à surveiller), produits vendus en rupture, produits
  vendus sous le prix d'achat.
- **Contrôler les chiffres** : le serveur `GET /pilotage/controler` **écrit en base** (il relit ventes et CA des
  mois affichés et recalcule ceux qui ont changé). Le **web** l'appelle **à l'ouverture du menu et sur
  « Actualiser »** (`PilotageCtr.actualiserEtControler`, délai 120 s). Sur le **mobile**, il n'est appelé **que**
  par le bouton « Contrôler les chiffres », après une confirmation (« … recalcule les mois modifiés … peut prendre
  du temps »), une seule fois par appui (bouton désactivé pendant le contrôle), délai borné à 2 min ; puis les
  chiffres sont relus. Ouvrir l'onglet, changer d'axe ou ⟳ ne contrôlent rien.
- **Jamais** : `/pilotage/recalculer`, saisie des charges (`POST /pilotage/charges`).

## 3. Analyse de garde (menu « Analyses »)

Gardes de l'année (la plus récente par défaut, puces des années). Une garde : **Synthèse** (chiffre d'affaires,
ventes, clients, marge et taux, montant par heure, espèces, mobile money, crédit…), **tranches horaires** en
barres (1 à 4 h), résumé ABC ; **Produits** classés A / B / C, triés par montant / quantité / marge, pages de 25 ;
**Vendeurs** (lus à l'ouverture de l'onglet). Aucune création, modification ou suppression de garde, ni inventaire
ni suggestion.

## 4. CA emplacement / famille (menu « Analyses »), comparatif

Période : **3 semaines** (par défaut, à l'ouverture), 3 mois, 6 mois, **3 ans** et période libre (dates
contrôlées, 3 ans au plus). « 3 ans » est un choix normal, sans fenêtre bloquante : pendant le calcul, indication
« Calcul sur 3 ans, peut prendre un moment » et **Annuler** ; délai d'attente plus long (2 min, borné), jamais de
relance automatique. Regroupement Emplacement / Famille / Emplacement et famille, filtres emplacement, famille,
grossiste (feuille « Filtres »). Totaux en cartes et total par tranche ; sur téléphone **une carte par ligne**
(6 dernières tranches avec montant, quantité et évolution ; la tranche en cours est signalée) ; sur tablette
**tableau dense** (défilement horizontal s'il y a beaucoup de tranches). Toucher une ligne : toutes ses tranches et
ses produits. Pas de « Créer inventaire ».

## Erreurs, contrôles, délais

Messages distincts : serveur injoignable, délai dépassé, session expirée (retour à la connexion), **Droit
manquant** (sans « Réessayer », sans déconnexion), erreur du serveur (« Le calcul … a échoué », 500), refus métier
avec le message du serveur (« Cette garde n'existe plus. »). Lecture tolérante (nombres en texte, champs absents,
`null`). Recherche contrôlée avec anti-rebond ; la réponse d'une demande remplacée ou annulée est ignorée. Délais :
45 s, 2 min pour les calculs longs demandés explicitement. Les routes interdites sont listées dans l'application
(`routesInterditesVague2`) et refusées avant tout envoi.

## Remarque serveur (pour information)

Les lectures des prévisions (`tableau`, `previsions`, `produit`, `analyse`) mettent d'abord à jour la colonne « en
cours de commande » de la table des prévisions (`rafraichirEnCours`) : c'est le fonctionnement du web, léger, que
le mobile ne fait que reproduire.

## Tests

Unitaires (`test/unitaires/vague2_test.dart`), intégration contre le faux serveur (`integration/vague2_api_test.dart`),
bout en bout (`e2e/parcours_vague2_test.dart`), ergonomie et cohérence (`ergonomie/affichage_vague2_test.dart` :
30 états × 5 tailles × 2 échelles de texte, aucun écart). Après chaque test d'intégration, de bout en bout et
d'ergonomie : aucune route interdite reçue. Tests existants mis à jour pour la barre à 4 onglets (compte
pharmacien) et les 3 menus réservés supplémentaires.

Captures : `docs/maquettes/captures_vague2/` (téléphone, et une tablette : CA en tableau dense).
