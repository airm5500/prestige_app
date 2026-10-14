# Prestige Pharmacien 3.2.1+30 — détail du Mobile Money (Détail CA) et retours sur la vague 2

Évolutions de la **nouvelle interface** demandées par le pharmacien. L'**ancienne interface ne change pas**.

## Numéro de version

**3.2.1+30** (3.2.1 = évolution d'écrans existants ; 30 = +1 par rapport à 29). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

## 1. Détail CA : Mobile Money dépliable par opérateur

- Une **flèche ▸ / ▾** sur la ligne « Total Mobile Money » (carte « Totaux sur la période ») et sur le chiffre clé
  « Mobile Money » (qui déplie la même ligne et l'amène à l'écran). Cible ≥ 48 dp, annoncée « Détail Mobile Money »
  par le lecteur d'écran, avec l'état déplié / replié ; dépliage animé léger.
- Ligne dépliée : chaque opérateur avec son **montant**, sa **part du total Mobile Money** et sa **part du CA
  global**, du plus gros au plus petit. Sur tablette (zone large) : tableau à 4 colonnes (Opérateur · Montant · Part
  Mobile Money · Part du CA). Aucune information portée par la couleur seule.
- **Bases des taux** (toujours celles de `/ca-all`, celles de l'écran) :
  - part du Mobile Money = montant / « Total Mobile Money » (`totMobile` cumulé) ;
  - part du CA = montant / **« Total brut paiements »** (espèces + crédit + mobile + carte + chèque + virement), le
    chiffre mis en avant comme CA de la période par l'écran. Les `part` / `partCa` du serveur ne sont pas utilisés.
- **Données** : aujourd'hui `GET /stats-recette-caisse/modes?dtStart=&dtEnd=` (mêmes dates que `/ca-all`), appelé
  **seulement au premier dépliage** (rien à l'ouverture de l'écran) ; lignes `mobile:true` seulement. Repli et
  nouveau dépliage : pas de nouvel appel. Nouvelle période ou actualisation : ligne repliée, détail redemandé au
  prochain dépliage.
- Cette route ne calcule pas exactement comme `/ca-all` : si la somme des opérateurs diffère du Total Mobile Money,
  une ligne **« Autres / écart »** (= Total Mobile Money − somme) s'affiche en dernier, avec la note « différence de
  calcul entre deux sources du serveur ». Le Total Mobile Money affiché reste celui de `/ca-all`.
- Chargement et erreurs **dans la ligne dépliée** (indicateur, « Erreur du serveur », « Le serveur ne répond pas »,
  « Session expirée », « Droit manquant », avec « Réessayer » sauf droit manquant) : le reste de l'écran reste
  affiché. Une session expirée (401) déclenche toujours le retour à la connexion existant.
- **Compatibilité future** : si `/ca-all` renvoie un jour le champ `detailMobile` par jour (demande au serveur :
  `docs/serveur/DEMANDE_DETAIL_MOBILE_MONEY.md`), il est utilisé en priorité, cumulé sur la période, sans appel
  complémentaire et sans ligne d'écart.
- Les chiffres existants du Détail CA (cartes, répartition, totaux, jour par jour) sont inchangés.

Capture : `docs/maquettes/captures_lot1/2b_detail_ca_mobile_money.png`.

### Tests

- Unitaires `test/unitaires/detail_mobile_test.dart` : lecture tolérante (formats, `mobile` 1 / "true", montants en
  texte, refus), cumul par opérateur, tri, taux, ligne d'écart, champ `detailMobile` prioritaire (complet /
  incomplet), chiffres de `/ca-all` identiques avec ou sans ce champ.
- Intégration `test/integration/detail_mobile_test.dart` (faux serveur) : aucun appel avant dépliage, un seul au
  premier dépliage avec les dates de `/ca-all`, nouvelle période ; 500 / 401 / délai / refus affichés localement ;
  réponse simulée avec `detailMobile` (aucun appel, aucun écart) ; tablette en tableau.
- Bout en bout `test/e2e/parcours_lot1_test.dart` (dépliage, libellé accessible, repliage) ; non-régression
  `test/lot1_non_regression_test.dart` (chiffres inchangés une fois déplié) ; ergonomie (déplié et en erreur, 5
  tailles × texte 1,0 / 1,3, sans écart toléré).

## 2. Retours du pharmacien sur la vague 2

### 2.1 Pilotage : couleurs selon le sens de l'indicateur

- La **flèche suit le sens réel** (↑ hausse, ↓ baisse). La **couleur et le texte** disent si c'est une bonne
  nouvelle : « +40,0 % · défavorable » en rouge pour un taux de rupture en hausse, « −12 % · favorable » en vert
  pour des ruptures en baisse. Jamais la couleur seule.
- Le web (`PilotageManager.js`, `sens()` = hausse / baisse / plat) ne qualifie pas les variations : la table des
  sens est établie dans l'application (`sensIndicateurs`, `lib/nouvelle_interface/vague2/donnees_vague2.dart`) à
  partir des clés de tuiles de `PilotageService` (synthèse, à suivre, marge, achats, caisse, stock, qualité, KPI) :
  - **hausse favorable** : CA TTC / HT, marge et taux de marge, nombre de ventes, panier moyen et son évolution,
    ratio ventes / achats, écart ventes − achats, rotation du stock, encaissé, tiers payant réglé ;
  - **hausse défavorable (couleurs inversées)** : taux de rupture, références en rupture, produits vendus en rupture,
    sous le seuil, stock négatif, stock dormant, péremptions, vendus sous le prix d'achat, ventes ratées à
    commander, remises et taux de remise, porté à crédit, ventes annulées, produits sans prix / rayon / seuil ;
  - **neutres** (gris, sans jugement) : achats, bons de livraison, achat moyen, coût d'achat des ventes, part et
    montant du tiers payant facturé, valeur du stock, heure de pointe ; toute clé inconnue.
  Aucune tuile de « délai » n'existe aujourd'hui côté serveur : à ajouter à la table si elle apparaît.

### 2.2 Analyse de garde : « Afficher plus » par 100

- Le serveur recalcule toute l'analyse de la garde à chaque page demandée (calcul complet puis découpe
  `start` / `limit`). Les produits arrivent désormais **par 100** (au lieu de 25) : 4 fois moins de recalculs.
- Ce qui est chargé est **gardé** : changer d'onglet (Synthèse · Produits · Vendeurs) ne relit rien ; changer la
  largeur des tranches horaires ne relit que la synthèse (`limit=1`) et **garde les produits déjà chargés**, pages
  comprises. Un changement de tri ou de classe relit la première page (la liste change).

### 2.3 Prévisions : mise à jour de la colonne « en cours de commande »

**Cas (b) : c'est le serveur qui la fait tout seul**, à l'intérieur des routes de lecture, comme pour le web.
`PrevisionCommandeServiceImpl.rafraichirEnCours()` est appelé au début de `GET /analyse-commande/tableau`,
`/previsions` (chaque page), `/produit/{id}`, `/analyse` et des exports : relecture des commandes en cours et
`UPDATE t_prevision_produit` pour chaque produit dont l'en-cours a changé. L'application n'appelle aucune route
d'écriture et ne peut pas l'éviter : **rien n'est changé côté application**. Demande faite au serveur (ne refaire ce
rafraîchissement que s'il date de plus de X minutes, 15 par défaut, et exposer l'heure du dernier) :
`docs/serveur/DEMANDE_ECRITURES_SENSIBLES.md`, point 8.

### 2.4 CA emplacement / famille : choix multiple

- Emplacements, familles et grossistes se choisissent par **cases à cocher** dans la feuille « Filtres », avec
  « Tout » / « Aucun » et un compteur (« 3 sélectionnés », « Aucun filtre (tous) », « Tous (12) »).
- Envoi **comme le web** (contrôleur `CaZoneGeoCtr.js` et `util.FiltreListe` du serveur depuis le 13/10) :
  identifiants **séparés par des virgules** dans `zoneId`, `familleId`, `grossisteId` (`zoneId=Z1,Z3`), aussi pour
  le détail d'une ligne. Rien coché ou tout coché = paramètre vide (aucun filtre ; le serveur borne la liste à 500).
- Étiquettes sous la période : « Emplacement : RAYON A » ou « Emplacements : 3 sélectionnés ».

Captures mises à jour : `docs/maquettes/captures_vague2/` (2, 3 : pilotage ; 12 : produits de garde ; 17 : filtres
à choix multiple).

### Tests

- Unitaires `test/unitaires/vague2_retours_test.dart` : table des sens (toutes les clés), favorable / défavorable /
  neutre, rendu des tuiles (flèche, texte, couleur) ; pages de 100 bornées ; paramètres « id1,id2 », tout coché =
  aucun filtre, compteur.
- Intégration `test/integration/vague2_retours_test.dart` (faux serveur) : paramètres transmis après avoir coché
  (2 sur 3, une famille), « Tout » et « Aucun » ; garde : `limit=100`, tranches → `limit=1` et produits gardés,
  onglets sans rechargement, échec de la synthèse seule.
- Bout en bout (`parcours_vague2_test.dart`) : taux de rupture en hausse « défavorable » ; page suivante à 100.
  Ergonomie : choix multiple ouvert, filtres multiples appliqués, « À suivre » comparé (5 tailles × 2 échelles).
