# Demande à la session serveur : routes de comptage légères pour les alertes de l'accueil

**Contexte.** Depuis la version 3.0.0+26, l'accueil « A · Tableau de bord » de Prestige Pharmacien affiche le
nombre de chaque alerte « À surveiller », **à la demande seulement** (bouton ⟳ de l'alerte ; jamais au
démarrage ni en boucle). Pour ne demander aucune nouvelle route, l'application réutilise exactement les routes et
paramètres des modules, et compte côté application :

| Alerte | Route appelée (identique au module) | Nombre affiché | Poids |
|---|---|---|---|
| Produits proches de la péremption | `GET /api/v1/fichearticle/perimes?query=&nbreMois=&codeRayon=&codeGrossiste=&dtStart=&dtEnd=&page=1&start=0&limit=20` (première page de l'écran Suivi Péremption) | champ `total` (à défaut, nombre de lignes reçues) | Léger : 20 lignes au plus, mais le serveur calcule aussi `metaData` (totaux quantités / valeurs) sur tous les lots |
| Contrôle des bons de livraison | `GET /api/v1/etat-control-bon/list-annuelle?dtStart=<jour>&dtEnd=<jour>&groupeId=&groupBy=GROUP&limit=9999` (filtres par défaut de l'écran Etat Contrôle Achat : jour, tous les groupes) | `metaData.totalNbreBon` (à défaut, somme des `nbreBon`) | **Liste complète** (`limit=9999`) avec montants et totaux, renvoyée seulement pour en extraire un entier |

**Demande.** Ajouter côté serveur deux routes de comptage qui ne renvoient qu'un entier, avec les MÊMES filtres et
la MÊME session (JSESSIONID, mêmes droits) que les routes ci-dessus :

```
GET /api/v1/fichearticle/perimes/nombre?query=&nbreMois=&codeRayon=&codeGrossiste=&dtStart=&dtEnd=
→ {"success": true, "nombre": 3}

GET /api/v1/etat-control-bon/nombre?dtStart=2026-10-14&dtEnd=2026-10-14&groupeId=
→ {"success": true, "nombre": 7}
```

Exigences :

- même résultat que les routes existantes pour les mêmes filtres (le nombre affiché sur l'accueil doit être
  celui que montre l'écran du module à son ouverture : lots listés / « Total Bons ») ;
- un `SELECT COUNT(*)` sans calcul des totaux ni sérialisation des lignes ;
- mêmes réponses d'erreur que le reste de l'API : 401 / `{success:false, message:"Veuillez vous connecter"}` si la
  session a expiré, 403 pour un droit manquant, 5xx en cas de panne.

**Côté application, une fois les routes livrées** : remplacer les deux appels de
`AlertesAccueil._appel` (`lib/nouvelle_interface/alertes_accueil.dart`), garder les tests d'intégration
`test/integration/alertes_accueil_test.dart` (mêmes filtres que les écrans) et ajouter les nouvelles routes au faux
serveur (`test/support/faux_serveur_prestige.dart`). Le comportement visible ne change pas.
