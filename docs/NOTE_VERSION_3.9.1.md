# Prestige Pharmacien 3.9.1+40 — tests de performance et réseau, rapport de tests de livraison

Le pharmacien exige à chaque livraison, dans les trois applications, des tests unitaires, de non-régression, de bout
en bout, de **performance**, **réseau** et d'ergonomie. Prestige Pharmacien reçoit le même socle que Prestige
Inventaire (mêmes dossiers, mêmes outils, même rapport) : `test/performance/`, `test/reseau/`,
`tool/rapport_tests.dart`, CI par catégorie (détail : `test/README.md`).

Les nouveaux tests ont révélé **cinq défauts**, petits et évidents, corrigés ici (aucun autre changement de
l'application). Tous les tests existants passent sans modification.

## Numéro de version

**3.9.1+40** (3.9.1 = corrections ; 40 = +1 par rapport à 39). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

## Défauts corrigés

| # | Défaut | Révélé par | Correction |
|---|---|---|---|
| D1 | **PDF de plus de 20 pages jamais produit** : Marge Produits Vendus ou CA Crédit de plus de ~800 lignes, Suivi Péremption de plus de ~600 lots → « Erreur lors de la préparation du PDF » (le paquet `pdf` s'arrête à 20 pages par défaut). | `test/performance/pdf_test.dart` (1 000 lignes) | Limite portée à 500 pages (`pagesMaxPdf`, ≈ 20 000 lignes) pour les 5 PDF (`lib/donnees/recap_caisse_pdf.dart`, `analyses_pdf.dart`, `peremption_donnees.dart`). |
| D2 | **PDF du Suivi Péremption impossible sans Internet** : la police était téléchargée chez Google à chaque export ; sur le Wi-Fi de l'officine sans Internet, l'export échouait. | `test/performance/pdf_test.dart` (fabrication hors ligne) | Police téléchargée si Internet répond (8 s au plus), sinon police Helvetica intégrée (comme les autres PDF) : le PDF est toujours produit. Fabrication séparée de l'impression (`SuiviPeremption.octets`). |
| D3 | **Certificat HTTPS refusé confondu avec « serveur injoignable »** : au lancement, « Le serveur ne répond pas — Vérifiez le Wi-Fi » ; dans les modules, titre « Serveur injoignable » ; alertes de l'accueil A, « Serveur injoignable. Vérifiez le réseau. » | `test/reseau/https_test.dart` (vrai HTTPS, certificat auto-signé) | Titre et texte dédiés : « Certificat du serveur refusé » (lancement, deux interfaces ; modules ; alertes). Le message de la connexion et des services était déjà distinct (étape 1h). |
| D4 | **Annulation de vente annoncée « refusée » sur une réponse illisible** (JSON partiel) alors que le serveur a pu annuler la vente. | `test/reseau/reponses_tronquees_test.dart` | Comme sans réponse : l'état est **vérifié par relecture** (« la vente est bien annulée » / « n'est pas annulée, vous pouvez réessayer ») ; jamais de renvoi automatique. |
| D5 | **Requête en double à chaque connexion** : le nom de l'officine (`GET /officine`) était relu deux fois (par la connexion et par l'écran de connexion qui se ferme). | `test/performance/requetes_test.dart` (plafonds exacts) | Une seule lecture (celle de la connexion). |

## Constats de performance (non corrigés : non « petits et évidents »)

- Les listes des modules refaits sont construites **en entier** (`ListeOuTableau` : une colonne de toutes les cartes
  dans la liste défilante). Avec 1 000 lignes, l'ouverture coûte jusqu'à 2,6 s en mode test sur la CI (Suggestions, 500
  lignes) et chaque « Afficher plus » reconstruit toute la liste (Prévisions ou BL à 1 000 lignes : ~0,65 s en mode
  test sur la CI ; jusqu'à ~5 s sur un poste lent ; bien moins dans l'APK « release »). Changer de vue du Tableau : Analyses sur 3 ans reconstruit aussi les 1 096 cartes du
  « jour par jour ». Piste : liste construite à la demande (`SliverList`). Les seuils actuels empêchent toute
  aggravation.
- Le défilement reste fluide une fois la liste construite (voir les mesures du rapport).

## Ce que le pharmacien voit

Rien de nouveau à l'écran, sauf : les PDF longs et le PDF de péremption hors ligne sont produits ; un certificat HTTPS
refusé est annoncé comme tel ; une annulation sur réponse illisible est vérifiée.

## Rapport de tests de livraison

Chaque exécution de la CI publie, dans le résumé du job GitHub et en artefact **`rapport-tests`** : le nombre de tests
par catégorie (réussis, sautés, échecs, durée), chaque mesure de performance et de requêtes avec son seuil et la part
du seuil utilisée, les tests en échec. L'APK n'est construit que si toutes les catégories passent.
