# Prestige Pharmacien 3.11.0+45 — Tableau de bord à l'accueil, Balance vente / caisse, Sur-stocks et retours du pharmacien

## Numéro de version

**3.11.0+45** (3.11.0 = nouvelles fonctions ; 45 = +1 par rapport à 44). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

Toutes les nouveautés concernent la **nouvelle interface**. L'ancienne interface est inchangée (menus, écrans, droits).
**Aucune demande au serveur** : tout repose sur des routes déjà servies, avec un repli quand une route manque.

## 1. Retours du pharmacien

| Point | Ce qui change |
|---|---|
| Sélecteur de période | « Aujourd'hui », « Hier » et « Personnaliser » restent visibles ; « 7 derniers jours », « Ce mois » et « Mois dernier » passent dans un menu « Autres périodes ». Aucune période perdue. |
| Suggestions | Le curseur se place sur la quantité du premier article ; « Suivant » du clavier passe à l'article suivant (la liste défile) ; « Terminé » sur le dernier enregistre. Les compteurs sont retirés. « Créée le … · Réf. … » tient sur une ligne. Le statut est en face du grossiste. |
| Détail CA | La répartition est affichée en courbes (une courbe par mode, à partir de deux jours). Sur un seul jour : les montants. |
| Accueil | « Actualiser » en haut. « Déconnexion » après « Réglages » : bouton rond rouge (#e74c3c), icône marche/arrêt. Ordre : Actualiser, Réglages, Déconnexion. |
| Pilotage | Un toucher sur « Marge » ou « Nombre de ventes » ouvre la courbe des 7 derniers jours. « Contrôler les chiffres » est retiré (la route `/pilotage/controler` n'est plus jamais appelée). « À suivre » montre le CA par emplacement et par famille ; un toucher sur une ligne ouvre ses produits. « favorable / défavorable » retirés. |
| Tableau : Analyses | Achats du jour en gras ; évolution des ventes par rapport à la veille avec une flèche (le jour précédent est nommé quand ce n'est pas la veille, par exemple après un dimanche fermé). |
| CA par emplacement | « favorable / défavorable » retirés ; chiffres d'une tranche sur une ligne, commentaires dessous ; carte « Lignes » réduite, carte « Évolution » en pleine largeur ; **produits vides corrigés** (voir 3) ; tableau tablette construit à la demande. |
| Évolution Stock | Retiré des menus de l'administrateur et du pharmacien : la courbe est dans la Valorisation. Les autres profils gardent le menu. |
| Analyse des saisies de BL | Nouveau : **temps de saisie moyen par BL** (création → clôture des BL clôturés ; plus de 24 h écartés et comptés à part). |

## 2. Nouveaux écrans

### Tableau de bord (accueil par défaut)

- Devient l'accueil de tous les profils. **Migration une seule fois** : le choix d'avant la 3.11.0 passe au tableau de
  bord ; un choix fait ensuite dans Réglages est gardé. L'ancien accueil reste proposé (A · Chiffres du jour et menus,
  B, C, Automatique).
- Cartes : CA net / Marge / Panier moyen / Achats du jour ; évolution du mois par pas de 5 jours ; fréquentation
  horaire (Aujourd'hui / Hier / Personnaliser, la veille entre parenthèses) ; valorisation du stock ; encaissement du
  jour ; top 10 des ventes du mois par emplacement ou famille ; ventes du mois par taux de TVA.
- **Paramétrable** : bouton « Cartes » (afficher / masquer, monter / descendre), mémorisé sur l'appareil.
- Accès aux menus conservé : « Tous les menus » et la barre du bas.
- **Repli** : chaque carte qui lit une route absente du serveur affiche « Indisponible sur ce serveur » sans gêner les
  autres. Chiffres du jour : `tableau-bord/tuiles`, sinon `recap/dashboard/daily`. Fréquentation : `pilotage/suivi/
  frequentation` (par jour), sinon celle de la semaine. Valorisation : `tableau-bord/valorisation`, sinon la valorisation
  produit.
- Chaque carte se charge à son arrivée à l'écran, une seule fois (gardée en mémoire au retour).

### Balance vente / caisse (groupe « Ventes & caisse », administrateur et pharmacien)

Quatre onglets : **Balance** (PDF), **Analyse comparative**, **Évolution par mode** (même appel que l'analyse) et
**Surveiller et alertes** (le bloc « À surveiller » de l'accueil et les alertes). Routes : `balance/balancesalecash`,
`/analyse`, `/pdf`.

### Sur-stocks (groupe « Stock », administrateur et pharmacien)

Liste paginée par 50 (« Afficher plus »), filtres (mois de consommation, emplacements, familles, recherche), export
**Excel**. La route de création d'inventaire n'est jamais appelée.

### Cloche (alertes)

En plus : **avoirs**, **périmés à 6 mois** et **saisies en périmés** (30 derniers jours ; compte lu avec une seule ligne
demandée, liste à la demande).

### Menus réunis « Détail | Synthèse »

- **Achats Fourn.** = Achats par fournisseur | État de contrôle des achats.
- **CA Crédit** = CA Crédit | Suivi crédit.

Aucune fonction perdue, droits identiques (chaque onglet garde ceux de son ancien menu), ancienne interface inchangée.

### Écran de chargement

Sur le modèle fourni (36.png) : « Prestige Pharmacien », nom de la pharmacie, anneau de chargement, étape en cours
(« Étape n sur 4 · adresse:port ») et version. Nouvelle interface seulement.

## 3. Causes trouvées

- **CA par emplacement, produits vides** : l'application envoyait `ligneFamilleId=` (valeur vide) ; le serveur lit une
  valeur vide comme « sans famille » et ne renvoie rien. La clé n'est plus envoyée hors du regroupement concerné.
- **Pilotage, « À suivre »** : le serveur renvoyait déjà le CA par emplacement et par famille ; l'application ne
  l'affichait pas.
- **Cartes du tableau de bord rechargées** au retour à l'écran (17 requêtes au lieu de 7, relevé par le test de
  performance) : chaque carte est maintenant gardée en vie.
- **Tableau : Analyses sur 3 ans, ouverture à 6,1 s** (seuil 6 s ; 5,2 s avant la 3.11.0) : les 1 096 cartes « jour
  par jour », un peu plus riches (achats en gras, évolution), étaient toutes construites d'un bloc. Sur téléphone, chaque
  carte est maintenant un élément de la liste, construit à son arrivée à l'écran : **1,4 s**. Tablette inchangée
  (tableau).

## 4. Choix à signaler

- Balance et Sur-stocks **réservés à l'administrateur et au pharmacien** : le serveur ne contrôle aucun droit sur ces
  routes.
- Sur-stocks : **PDF non fait** (le serveur renvoie une adresse de page web, pas un fichier) ; Excel fait. Balance :
  PDF fait.
- « Actualiser » absent des accueils B et C : aucun chiffre à y actualiser.
- Téléchargement : un classeur .xls (format du web) est accepté comme le .xlsx.

## 5. Mesures (faux serveur en mémoire, local)

| Mesure | Valeur |
|---|---|
| Connexion → tableau de bord | 293 ms |
| Tableau de bord, pire image du défilement complet | 4,6 ms (téléphone), 3,2 ms (Sunmi) |
| Tableau de bord, requêtes des cartes | 7 (une par carte, aucune relecture) |
| Balance, pire image au changement d'onglet | 132 ms |
| Sur-stocks, 120 produits, défilement | 13 ms |
| Suggestion de 500 lignes, ouverture | 254 ms |
| Suggestion de 500 lignes, « Suivant » d'article en article | 125 ms (pire image) |
| Tableau : Analyses, 3 ans, ouverture | 1,4 s (5,2 s en 3.10.3) |

Seuils inchangés (`test/support/performance.dart`).

## 6. Tests

- Unitaires : `test/unitaires/retours_3_11_0_test.dart`.
- Intégration : `test/integration/vague4_api_test.dart`, `test/integration/retours_3_11_0_test.dart`.
- Bout en bout : `test/e2e/parcours_3_11_0_test.dart`.
- Performance : `test/performance/retours_3_11_0_test.dart`. Réseau : `test/reseau/retours_3_11_0_test.dart`.
- Ergonomie : nouveaux écrans ajoutés aux cas d'affichage (`test/support/cas_retours_3_11_0.dart`, petits écrans,
  contraste, débordements).
- Tests existants adaptés : tableau de bord par défaut, sélecteur de période, menus réunis, Évolution Stock, Pilotage
  sans « Contrôler ».

## 7. Captures (téléphone 411 dp et Sunmi 360 dp)

Dans `docs/maquettes/captures_3_11_0/` (`telephone_*.png` et `sunmi_*.png`), produites par
`CAPTURES_3_11=1 flutter test test/captures_3_11_0_test.dart --update-goldens` :

01 chargement · 02 tableau de bord · 03 suite (fréquentation, valorisation) · 04 fin (top 10, TVA) · 05 Balance ·
06 Analyse comparative · 07 Surveiller et alertes · 08 Sur-stocks · 09 sélecteur de période · 10 Détail CA en courbes ·
11 Suggestions · 12 jour par jour · 13 CA par emplacement · 14 Analyse des saisies de BL · 15 Achats Fourn.
(Détail | Synthèse).
