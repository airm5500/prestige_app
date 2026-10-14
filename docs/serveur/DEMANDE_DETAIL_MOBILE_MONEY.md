# Demande au serveur : détail du Mobile Money par opérateur dans `/ca-all`

Demandeur : application mobile Prestige Pharmacien (module « Détail CA » de la nouvelle interface), version 3.2.1+30.

## Pourquoi

Le pharmacien veut déplier la ligne « Mobile Money » du Détail CA pour voir chaque opérateur (Orange, Wave, MTN,
Moov, Djamo…) avec son montant, sa part du total Mobile Money et sa part du chiffre d'affaires.

Aujourd'hui, `GET /ca-all` (`ErpRessource` → `ErpServiceImpl.caAll`, DTO `ErpCaComptant`) ne renvoie que le total
`totMobile` par jour. Le détail par opérateur est pourtant **déjà calculé** par la requête des encaissements
(`SELECT sum(v.montant_attentu) AS montantVerse, m.mvtdate, v.type_regelement … GROUP BY m.mvtdate,
v.type_regelement`), puis **perdu** dans le `switch` qui additionne les codes mobiles (7, 8, 9, 10, 19, 70, 80 et les
modes `str_CATEGORIE='MOBILE_MONEY'` reconnus par `MobileMoney.est`) dans `totMobile`.

En attendant, l'application appelle au premier dépliage `GET /stats-recette-caisse/modes` (mêmes `dtStart` /
`dtEnd`) et garde les lignes `mobile:true`. Mais cette route ne fait pas le même calcul : date du règlement
(`vr.mvtDate`) au lieu de `m.mvtdate`, statut `is_Closed` au lieu de `m.checked`, exclusions différentes (ventes
exclues, dépôts, importées), emplacement de l'utilisateur au lieu de `'1'`. La somme des opérateurs peut donc
différer de `totMobile` : l'application affiche alors une ligne « Autres / écart » (« différence de calcul entre
deux sources du serveur »), ce qui n'est pas satisfaisant pour le pharmacien. Elle coûte aussi une requête de plus.

## Quoi (recommandé) : enrichir `/ca-all`, rétrocompatible

1. Ajouter à `ErpCaComptant` un champ **`detailMobile`** : liste de `{modeId, libelle, montant}` pour le jour.
   - `modeId` : `v.type_regelement` (identifiant du mode, en texte) ;
   - `libelle` : `t_type_reglement.str_NAME` ;
   - `montant` : la même somme `montant_attentu` que celle ajoutée à `totMobile`.
2. Dans `ErpServiceImpl.caAll`, requête des encaissements : ajouter
   `JOIN t_type_reglement r ON r.lg_TYPE_REGLEMENT_ID = v.type_regelement`, `r.str_NAME` au `SELECT` et au
   `GROUP BY`.
3. Dans **chaque branche mobile** du `switch` (codes 7, 8, 9, 10, 19 et la branche par défaut
   `MobileMoney.est(code)`), en plus de `setTotMobile(...)`, ajouter `{modeId, libelle, montant}` à `detailMobile`.
   Ainsi Σ `detailMobile.montant` = `totMobile` **par construction** (même requête, mêmes filtres, mêmes annulations).
4. Jour sans Mobile Money : `detailMobile: []` (ou champ absent).

Exemple (un jour) :

```json
{"mvtDate": "20261013", "totEsp": 512300, "totMobile": 98200, "…": "…",
 "detailMobile": [{"modeId": "7", "libelle": "Orange", "montant": 50000},
                  {"modeId": "10", "libelle": "Wave", "montant": 30200},
                  {"modeId": "9", "libelle": "MTN", "montant": 18000}]}
```

**Rétrocompatible** : les anciennes versions de l'application ignorent ce champ. **Déjà prise en charge** par
l'application 3.2.1+30 : dès que chaque jour ayant du Mobile Money porte `detailMobile`, elle le cumule sur la
période, n'appelle plus `/stats-recette-caisse/modes` et n'affiche plus de ligne d'écart (testé avec une réponse
simulée).

## Variante : route séparée

Si l'on préfère ne pas toucher au DTO : `GET /ca-all/mobile?dtStart=AAAA-MM-JJ&dtEnd=AAAA-MM-JJ`, avec **exactement**
les filtres de la requête des encaissements de `caAll` (`m.checked=1`, `typeTransaction IN (0,1)`,
`lg_EMPLACEMENT_ID='1'`, `DATE(m.mvtdate) BETWEEN …`), restreinte à `MobileMoney.identifiants()`. Réponse :

```json
{"totMobile": 237750,
 "operateurs": [{"modeId": "7", "libelle": "Orange", "montant": 120000}, …]}
```

triée par montant décroissant, `totMobile` identique à la somme des `totMobile` de `/ca-all` sur la même période.
L'application devra alors être adaptée (un appel au dépliage, comme aujourd'hui) ; la solution 1 est préférée.
