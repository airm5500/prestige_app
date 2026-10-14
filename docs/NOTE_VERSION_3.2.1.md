# Prestige Pharmacien 3.2.1+30 — détail du Mobile Money (Détail CA)

Évolution de la **nouvelle interface** demandée par le pharmacien. L'**ancienne interface ne change pas**.

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
