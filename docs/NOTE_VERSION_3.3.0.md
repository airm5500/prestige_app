# Prestige Pharmacien 3.3.0+31 — refonte module par module, lot 2 (achats et stock)

Huit modules d'achats et de stock ont une **nouvelle mise en page** dans la nouvelle interface :
**Suggestions, État de Stock, Visualisation BL, État Contrôle Achat, Retours fournisseurs, Évolution stock,
Analyse Saisies BL, Suivi Ajustements**. Même méthode que le lot 1 (`NOTE_VERSION_LOT1.md`) : **les données ne
changent pas** (mêmes routes du serveur Prestige, mêmes paramètres, mêmes calculs, et pour les Suggestions **mêmes
écritures**). La lecture des données est partagée par l'écran d'origine et le nouvel écran (`lib/donnees/`), et un
test compare, module par module, les requêtes envoyées (corps des écritures compris) et les chiffres affichés.

L'**ancienne interface garde ses écrans** (aucun changement visible). La Valorisation (vague 1) n'est pas retouchée,
sauf son bouton « Évolution du stock », qui ouvre désormais le nouvel écran.

## Numéro de version

**3.3.0+31** (3.3.0 = nouveaux écrans ; 31 = +1 par rapport à 30). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

Captures (données fictives) : `docs/maquettes/captures_lot2/` — téléphone 1080 × 2400 px, tablette 1920 × 1200 px.

| Fichier | Écran |
|---|---|
| `1_suggestions.png`, `1b_suggestions_actions.png` | Suggestions : chiffres clés, liste, actions d'une suggestion (ouvrir, CSV, supprimer) |
| `1c_suggestion_ouverte.png`, `1d_…_quantite_enregistree.png`, `1e_…_confirmation_suppression.png` | Suggestion ouverte : montants, quantité enregistrée (message vert, « Enregistrée »), confirmation |
| `2_etat_stock.png`, `2b_etat_stock_filtres.png`, `2c_etat_stock_detail.png` | État de Stock : résultats, filtres, détail d'un article |
| `3_visualisation_bl.png`, `3b_…_filtres.png`, `3c_…_detail.png` | Visualisation BL : période, totaux, filtres, détail d'un bon (écarts) |
| `4_controle_achat.png` | État Contrôle Achat : totaux, groupes |
| `5_retours_fournisseurs.png`, `5b_retour_detail.png` | Retours fournisseurs : liste, détail |
| `6_evolution_stock.png`, `6b_evolution_stock_exporter.png` | Évolution du stock : courbe, jour par jour, menu Exporter |
| `7_analyse_saisies_bl.png` | Analyse des saisies BL |
| `8_suivi_ajustements.png`, `8b_ajustement_detail.png` | Suivi des ajustements : liste, analyse d'un ajustement |
| `9_droit_manquant.png` | « Droit manquant » (sans « Réessayer ») |
| `10_tablette_visualisation_bl.png`, `10b_tablette_suggestion_ouverte.png` | Tablette : tableau dense, lignes larges |

## Ce qui change pour vous (commun aux 8 modules)

- **Chiffres clés en cartes** en haut de chaque module.
- **Sélecteur de période commun** (Aujourd'hui · Hier · 7 jours · Ce mois · Mois dernier · Personnalisée, **3 ans au
  plus**) partout où l'écran d'origine avait des dates : Visualisation BL, État Contrôle Achat, Retours fournisseurs,
  Évolution stock, Analyse Saisies BL, Suivi Ajustements. Chargement **dès l'ouverture** (plus de bouton
  « Rechercher » / « Lancer l'analyse » / « Afficher l'évolution ») et à chaque changement de période.
- **Filtres dans la feuille du bas** (bouton ☰ de la barre, pastille = filtres actifs), étiquettes des filtres sous la
  période et « Retirer les filtres ». **Choix unique** partout : ces routes du serveur n'acceptent qu'un identifiant
  (`codeRayon`, `grossisteId`, `groupeId`, `fourId`, `typeFiltre`) — pas de liste séparée par des virgules comme
  pour le CA emplacement / famille.
- **Exports dans le menu unique « Exporter »** : CSV d'une suggestion (le même fichier « cip;qte » qu'avant) et PDF
  du graphique de l'Évolution du stock (le même PDF qu'avant). Les autres modules n'avaient pas d'export.
- **Listes** en cartes sur téléphone, **tableau dense** sur tablette (avec ligne de total quand elle a un sens).
- **États clairs** : chargement, « aucune donnée », et en cas d'échec la cause précise (*Serveur injoignable*, *Le
  serveur ne répond pas*, *Erreur du serveur*, *Session expirée*, **Droit manquant** sans « Réessayer »).
- **Recherche contrôlée** (État de Stock, Visualisation BL, Retours) : longueur limitée, caractères inutiles
  refusés, lancée 0,5 s après la frappe, une recherche remplacée est ignorée.
- **Détails en page** (bon de livraison, retour, ajustement) ou en feuille (article de l'État de Stock) au lieu de
  petites fenêtres.
- Pages suivantes par **« Afficher plus »** (un appel par appui ; mêmes pages de 15 / 20 lignes qu'avant).

## Module par module

### Suggestions (le seul module qui ÉCRIT)

Écritures **identiques** à l'écran d'origine, vérifiées par les tests (mêmes routes, mêmes corps) :

| Action | Requête | Contrôle |
|---|---|---|
| Ouvrir une suggestion | `GET /suggestion/set-pending/{id}` puis lignes et montants | — |
| Enregistrer une quantité | `POST /suggestion/item/update-qte-cmde {itemId, qte}` puis `GET /suggestion/amount/{id}` | entier de **0 à 99 999** (clavier numérique, 5 chiffres), sinon « Quantité invalide (0 à 99999) : non enregistrée. » et **rien n'est envoyé** |
| Retirer un article | `DELETE /suggestion/item/{itemId}` puis relecture | **confirmation** (« Non » / « Oui, Supprimer ») |
| Supprimer une suggestion | `DELETE /suggestion/suggestion/{id}` puis relecture de la liste | **confirmation** |

Nouveau :
- **Bouton ✓ « Enregistrer la quantité »** sur chaque ligne (la validation du clavier marche toujours).
- **Anti double envoi** : pendant un envoi, le bouton devient un indicateur et le champ est verrouillé ; un second
  appui (ou une seconde validation) **n'envoie rien**. Même protection pour l'ouverture et les suppressions.
- **Message de résultat clair** : vert « Quantité enregistrée : 24 · PARAFICTIF 500MG CPR B/16 » et mention « Enregistrée » sous
  le champ ; rouge « Quantité non enregistrée sur le serveur : <cause> » (réseau, délai, serveur, droit). Idem pour
  « Article retiré… », « Suggestion supprimée… ».
- Chiffres clés : montant d'achat, montant de vente, nombre d'articles, quantité totale à commander.
- Liste : bouton ⋮ par suggestion (feuille du bas : Ouvrir · Exporter (CSV) · Supprimer la suggestion).
- **Aucune commande PharmaML** (prévue en vague 4).

### État de Stock
Recherche contrôlée (nom, code, scan) ; filtres : **emplacement** et **stock** (=, <, >, ≥, ≤, ≠) avec quantité
obligatoire et contrôlée (entier, ± 99 999) — refus sans envoi, comme avant. Comme l'origine, rien n'est cherché à
l'ouverture. Chiffres : articles trouvés (total du serveur), articles à stock nul ou négatif parmi les affichés.

### Visualisation BL
Période (aujourd'hui à l'ouverture), recherche, filtres grossiste · groupe · utilisateur · statut. Chiffres : TTC,
Total BL (serveur), HT, TVA — **somme des bons chargés**, comme l'origine (« sur les N BL affichés » tant que tout
n'est pas chargé). Détail d'un bon en page : lignes avec commandé / reçu / contrôlé / **écart**, stock théorique,
PA, PV, UG ; « Écart » en rouge **et** en texte.

### État Contrôle Achat
Période (aujourd'hui), groupe de grossistes. Chiffres : total achats TTC, bons, marge, ventes TTC ; carte des 6
totaux du serveur ; groupes (tableau avec total sur tablette).

### Retours fournisseurs (lecture seule)
Période (aujourd'hui), recherche, filtres fournisseur · réponse (Tout / Avec réponse / Sans réponse). Chiffres :
montant des retours, nombre de retours, fournisseurs. Détail d'un retour en page ; **produits retournés** de la
période (bouton de la barre). Aucune création (prévue en vague 4).

### Évolution stock
Ouverture sur **« 7 jours »** (une courbe d'un seul jour n'a pas de sens). Chiffres : valeur d'achat à la fin, au
début, variation (montant, %, « hausse » / « baisse » en texte), plus haut ; courbe aux couleurs de la charte ;
**jour par jour** (31 derniers jours, « Afficher tous les jours »). PDF du graphique dans « Exporter ».

### Analyse Saisies BL
Période (aujourd'hui), statut (Tous / Bon / Pas bon) dans la feuille du bas — filtre local, **aucune nouvelle
requête**, comme avant. Chiffres : BL affichés, « Bon » (≤ 1 jour), « Pas bon » (> 1 jour), délai moyen de saisie.

### Suivi Ajustements
Période (aujourd'hui), motif. Détail en page : valeur ajoutée / retirée et leurs parts (mêmes calculs), produits avec
quantité signée, stocks avant / après.

## Différences de comportement à connaître

- Chargement à l'ouverture sur « Aujourd'hui » (Évolution : « 7 jours ») au lieu d'attendre un bouton.
- Les **choix de mois** (Retours, Analyse BL) et les raccourcis « 3 derniers mois » / « 1er semestre » (Ajustements)
  sont remplacés par le sélecteur commun (« Mois dernier », « Personnalisée » couvrent ces besoins).
- Les filtres s'appliquent par « Appliquer » dans la feuille (avant : à chaque changement de liste déroulante).
- Suggestions : si le passage « en cours » (`set-pending`) échoue, la suggestion **ne s'ouvre pas** et la cause est
  affichée (avant : elle s'ouvrait quand même).
- Les dates des sélecteurs d'origine allaient jusqu'en 2030 / 2101 : le sélecteur commun refuse le futur et plus de
  3 ans.

## Tests

- `test/lot2_non_regression_test.dart` : écran d'origine et nouvel écran contre le même faux serveur, pour les 8
  modules — mêmes requêtes (ouverture, recherche, filtres, détail, page suivante) et mêmes chiffres ; **Suggestions :
  mêmes écritures, corps compris** (`{itemId, qte}`), quantité refusée sans envoi, suppression annulée sans envoi.
- `test/e2e/parcours_lot2_test.dart` (application entière, HTTP réel) : chaque module ouvert depuis l'accueil,
  période, filtres, détail, Exporter, retour ; **double appui sur ✓ = un seul POST** ; suppression d'une suggestion
  par son menu ; 500 + Réessayer, droit manquant (sans Réessayer), serveur injoignable ; **session expirée pendant
  l'enregistrement** → connexion avec message.
- Ergonomie et cohérence : les 8 nouveaux écrans et 28 états (remplis, filtres, détails, Exporter, confirmation,
  quantité enregistrée, erreurs ; `test/support/cas_lot2.dart`) aux 5 tailles × texte 1,0 / 1,3, **sans aucun écart
  toléré** ; charte bleu nuit / ambre, aucune zone à l'ancien style.
- Écrans d'origine : leurs tests existants (erreurs réseau, contrôles de saisie) passent sans modification.

## Questions pour le pharmacien

1. **Filtres de Visualisation BL sans effet côté serveur** : `GET /etat-control-bon/list` (version actuelle du
   serveur) ne lit que `search`, `grossisteId`, les dates, `statutControle` et `ecart` ; les paramètres `groupeId`,
   `userId` et `checked` que l'application envoie (ancien et nouvel écran, à l'identique) sont **ignorés**. Faut-il
   passer au filtre de statut du serveur (`statutControle`) et filtrer groupe / utilisateur autrement ?
2. **Choix multiples** : souhaitez-vous plusieurs emplacements / grossistes / fournisseurs à la fois ? Il faudrait
   que ces routes acceptent « id1,id2 » comme `ca-zone-geo` (demande au serveur).
3. **Suivi Ajustements limité à 100** ajustements par période (comme l'origine) : faut-il un « Afficher plus » ?
4. **Évolution du stock** : l'ouverture sur 7 jours vous convient-elle (ou « Ce mois ») ?
5. **Suggestions** : faut-il garder le passage automatique « en cours » à l'ouverture d'une suggestion (comportement
   d'origine) ?
