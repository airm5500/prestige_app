# Tests de l'application du pharmacien

Tous les tests tournent avec `flutter test` (aucun émulateur, aucun vrai serveur), en local comme sur la CI Linux
(`.github/workflows/ci.yml` : `flutter analyze` puis `flutter test` complet). Aucune vraie donnée de patient ni
vrai identifiant : uniquement des données fictives (`support/donnees_fictives.dart`).

```
flutter test                      # tout
flutter test test/e2e             # une catégorie
flutter test --plain-name "Connexion"
```

## Catégories

| Dossier | Catégorie | Contenu |
|---|---|---|
| `test/*.dart` | Non-régression | Un fichier par évolution déjà livrée (licence au lancement, erreurs réseau, sécurité, Présences, stock réserve…). Leurs attentes ne doivent jamais être affaiblies. |
| `unitaires/` | Unitaires | Logique pure : dates, licence, modèles, messages d'erreur. |
| `integration/` | Intégration | Services (`ApiService`, `AuthProvider`, `LicenceProvider`, `PresencesApi`) contre le faux serveur joint en HTTP réel : adresses, cookie JSESSIONID, 401, 403, 404, 500, délai, serveur arrêté, règle « serveur injoignable ≠ problème de licence ». |
| `e2e/` | Bout en bout | L'application ENTIÈRE (`applicationPrestige()` de `main.dart`) parle au faux serveur local : lancement → licence → connexion → accueil → chaque module → retour → déconnexion ; session expirée → connexion ; serveur coupé → message réseau. |
| `ergonomie/affichage_ecrans_test.dart` | Ergonomie | Chaque écran à 5 tailles (téléphones 360×640 et 411×891 dp, Sunmi 720×1440 et 1080×1920 px, tablette 1920×1200 px) × texte 1,0 et 1,3 : aucun débordement ni exception, cibles tactiles ≥ 48 dp et libellées, contraste du texte. |
| `ergonomie/coherence_theme_test.dart` | Cohérence d'affichage | Thème (couleurs, Lato, Material 3, français), barres et polices de chaque écran issues du thème, plafond de couleurs codées en dur par fichier. |
| `e2e/parcours_nouvelle_interface_test.dart` | Bout en bout (nouvelle interface) | Nouvelle interface par défaut ; chaque module ouvert/fermé en présentation A, B, C (téléphone) et B (tablette, menu latéral) ; onglets ; retour à l'ancienne interface (immédiat, mémorisé) et retour à la nouvelle ; présentation réservée à l'administrateur ; session expirée, panne, serveur injoignable, licence. |
| `ergonomie/affichage_nouvelle_interface_test.dart` | Ergonomie (nouvelle interface) | Tous les écrans de la nouvelle interface (démarrage, connexion A/B, accueil A/B/C, onglets, écrans C, chaque module) aux mêmes 5 tailles × 2 échelles. Aucun écart toléré sur ses écrans propres ; pour les modules d'origine, seulement leurs écarts déjà connus. |
| `ergonomie/coherence_nouvelle_interface_test.dart` | Cohérence (nouvelle interface) | Charte bleu nuit / ambre, contraste des boutons principaux ≥ 4,5:1, barres bleu nuit, Lato, et aucune zone à l'ancien style (couleurs d'origine ou lavande Material) sur chaque écran, dialogue et sélecteur de date. |
| `unitaires/alertes_accueil_test.dart`, `integration/alertes_accueil_test.dart` | Alertes de l'accueil A | Comptage à la demande : nombre identique aux écrans, « il y a X min », mêmes routes et paramètres que les modules, 401 / 500 / injoignable / délai borné, anti double appui, aucun appel sans appui sur ⟳. Parcours complet (⟳ → nombre → module) dans `e2e/parcours_nouvelle_interface_test.dart`, états rendus par l'ergonomie (« Accueil A · alertes … »). |
| `lot1_non_regression_test.dart` | Non-régression de données (lot 1) | Rapport d'Activité, Détail CA, Analyse Article, Fiche Article, Suivi Péremption, Suivi Crédit : l'écran d'origine et le nouvel écran contre le même faux serveur — mêmes requêtes (période du jour, mois précédent, recherche, filtres) et mêmes chiffres, libellé par libellé. |
| `e2e/parcours_lot1_test.dart` | Bout en bout (lot 1) | Chaque module refait : ouverture, période, filtre (feuille du bas), retour ; erreur du serveur + Réessayer, serveur injoignable, session expirée ; recherche (anti-rebond, réponse remplacée ignorée). |
| `navigation_nouvelle_interface_test.dart` | Navigation | « Fournisseurs » absent de la nouvelle interface (A, B, C, recherche, personnalisation), présent dans l'ancienne ; bouton Réglages en haut à droite ; barre du bas Accueil · Analyses · Équipe. |
| `unitaires/periode_test.dart` | Unitaires (dates) | Sélecteur de période commun (lot 1 et vague 1) : périodes rapides, contrôles (début ≤ fin, pas de futur, 3 ans au maximum) ; période en mois du Suivi Péremption. |
| `unitaires/detail_mobile_test.dart`, `integration/detail_mobile_test.dart` | Détail Mobile Money (Détail CA) | Lecture tolérante de `/stats-recette-caisse/modes` (lignes `mobile:true`), cumul, tri, taux sur les totaux de `/ca-all`, ligne « Autres / écart », champ futur `detailMobile` de `/ca-all` prioritaire ; aucun appel avant dépliage, mêmes dates que `/ca-all`, erreurs 500 / 401 / délai / refus locales à la ligne dépliée. |
| `lot2_non_regression_test.dart` | Non-régression de données (lot 2) | Suggestions, État de Stock, Visualisation BL, État Contrôle Achat, Retours fournisseurs, Évolution stock, Analyse Saisies BL, Suivi Ajustements : écran d'origine et nouvel écran contre le même faux serveur — mêmes requêtes (ouverture, recherche, filtres, détail, page suivante), mêmes chiffres ; Suggestions : **mêmes écritures, corps compris** (`{itemId, qte}`, DELETE, set-pending), quantité refusée et suppression annulée sans envoi. Données : `support/donnees_lot2.dart`. |
| `e2e/parcours_lot2_test.dart` | Bout en bout (lot 2) | Chaque module refait ouvert depuis l'accueil : période, filtres, détail, Exporter, retour ; double appui sur ✓ = un seul POST ; suppression confirmée / annulée ; 500 + Réessayer, droit manquant, serveur injoignable ; session expirée pendant une écriture. |
| `lot2_captures_test.dart` | Captures lot 2 (à la demande) | `CAPTURES_LOT2=1 flutter test test/lot2_captures_test.dart --update-goldens` → `docs/maquettes/captures_lot2/`. |
| `lot3_non_regression_test.dart` | Non-régression de données (lot 3) | Tableau : Analyses (points des 3 graphiques), Tableau : Ratios (ratios, norme 1,51, achat / vente normés, Ratios mensuels), Suivi 20/80, Stat TVA (API v3, parts du TTC), Marge Produits Vendus, CA Crédit, CA Global : écran d'origine et nouvel écran contre le même faux serveur — mêmes requêtes (jour, mois dernier, nombre d'articles, type de vente), filtres et recherches locaux sans requête, mêmes chiffres. Données : `support/donnees_lot3.dart`. |
| `e2e/parcours_lot3_test.dart` | Bout en bout (lot 3) | Chaque module refait ouvert depuis l'accueil : chiffres, période, filtres ou recherche, vue du graphique, détail, « Afficher plus » sans requête, pas de menu Exporter (aucun export à l'origine), retour ; 500 + Réessayer, droit manquant, serveur injoignable ; session expirée pendant un changement de période. |
| `unitaires/lot3_donnees_test.dart` | Unitaires (lot 3) | Calculs partagés : ratio et norme 1,51, cumul mensuel, filtre de marge (7 opérateurs), nombre d'articles du 20/80, parts du TTC, CA brut / net, recherche du CA Crédit, abréviations des axes. |
| `lot3_captures_test.dart` | Captures lot 3 (à la demande) | `CAPTURES_LOT3=1 flutter test test/lot3_captures_test.dart --update-goldens` → `docs/maquettes/captures_lot3/`. |
| `lot4_non_regression_test.dart` | Non-régression de données (lot 4) | Récap de caisse (corps POST `/caisse/fetch-tickez` identique, montants du ticket Z tels que le serveur les rend), Achats Fourn. (jour, mois dernier, recherche et filtre fournisseur locaux, même « Récap Achat »), Fichier Journal (listes, `criteria` / `userId` / `limit=200`, mêmes actions), Annulation Ventes : même recherche, même détail, **même requête d'annulation** `GET /vente/annulation/{id}` entourée des mêmes relectures ; **rien n'est envoyé** tant que la confirmation renforcée n'est pas complète ou après « Ne pas annuler ». Données : `support/donnees_lot4.dart`. |
| `e2e/parcours_lot4_test.dart` | Bout en bout (lot 4) | Chaque module ouvert depuis l'accueil (Fichier Journal aussi par l'onglet Équipe) : chiffres, période, filtres, recherche locale, détail, récapitulatif, pas de menu Exporter (sauf Récap de caisse : PDF du ticket Z, 3.6.1), Journal par pages de 50 (50 puis 100, mêmes filtres), retour ; annulation : « Ne pas annuler » = aucun envoi, **double appui = un seul GET**, retour refusé pendant l'envoi, compte non responsable → **code administrateur** (refusé : aucun envoi ; accepté : un envoi), refus du serveur affiché, détail en échec = aucune action, journal sans référence / client / montant ; 500 + Réessayer, droit manquant, serveur injoignable ; session expirée pendant l'annulation → connexion, rien d'annulé. |
| `unitaires/lot4_donnees_test.dart` | Unitaires (lot 4) | Corps du ticket Z, lecture tolérante, filtre et récapitulatif des achats, paramètres du journal, paramètres et chemins de l'annulation, confirmation renforcée (référence exacte ou « ANNULER »), client du détail, sens des issues. |
| `integration/lot4_retours_test.dart` | Retours sur le lot 4 (3.6.1) | Fichier Journal par pages de 50 : `start` / `limit=50` avec les mêmes filtres, « Afficher plus » = page suivante (50 → 100 → 130, aucune requête de trop), serveur sans « total » = 50 par 50 côté appli **sans aucune requête de plus** et avertissement « limite du serveur », page suivante en échec (message, liste gardée). Récap de caisse : « Exporter » → PDF du ticket Z, chaque ligne et chaque chiffre de l'écran retrouvés tels quels dans le texte du PDF, aucune requête, rien à exporter sans donnée. Unitaires dans `unitaires/lot4_donnees_test.dart` (paramètres et lecture des pages, texte du PDF, mots présents dans le PDF A4), parcours dans `e2e/parcours_lot4_test.dart` (Journal 50 puis 100, Récap : Exporter → PDF). |
| `lot4_captures_test.dart` | Captures lot 4 (à la demande) | `CAPTURES_LOT4=1 flutter test test/lot4_captures_test.dart --update-goldens` → `docs/maquettes/captures_lot4/`. |
| `lot1_captures_test.dart` | Captures lot 1 (à la demande) | `CAPTURES_LOT1=1 flutter test test/lot1_captures_test.dart --update-goldens` → `docs/maquettes/captures_lot1/` (`--plain-name "2b"` : seulement le Mobile Money déplié). |
| `unitaires/vague1_test.dart`, `integration/vague1_api_test.dart`, `e2e/parcours_vague1_test.dart`, `ergonomie/affichage_vague1_test.dart` | Vague 1 des nouveaux menus | Valorisation rayon / réserve / total, Alertes (un seul appel à la demande, partagé avec l'accueil A), Retraits et abandons, Ventes modifiées : lecture tolérante, refus « Droit manquant », 401 / 500 / délai, menus réservés au profil « dashboard » (Valorisation comprise, aussi dans « Personnaliser l'accueil »), réglages des alertes (bornes, paramètres transmis, réglage → ⟳), chaque écran aux 5 tailles × 2 échelles sans écart. Données : `support/donnees_vague1.dart` (routes par défaut du faux serveur). |
| `unitaires/vague2_test.dart`, `integration/vague2_api_test.dart`, `e2e/parcours_vague2_test.dart`, `ergonomie/affichage_vague2_test.dart` | Vague 2 des nouveaux menus | Prévisions, onglet Pilotage (barre du bas, administrateur / pharmacien), Analyse de garde, CA emplacement / famille : lecture tolérante des 4 formats (dont colonnes dynamiques `t_` / `q_` / `e_`), refus distincts (droit manquant / calcul en échec / refus métier / 401 / 500 / injoignable / délai 45 s, 2 min pour les calculs longs demandés), contrôles des saisies, AUCUNE route interdite appelée (`support/requetes_vague2.dart`, vérifié après chaque test), `/pilotage/controler` seulement après confirmation et une fois par appui, calcul long annulable sans relance, chaque écran aux 5 tailles × 2 échelles sans écart. Données : `support/donnees_vague2.dart`. |
| `unitaires/vague2_retours_test.dart`, `integration/vague2_retours_test.dart` | Retours sur la vague 2 (3.2.1) | Pilotage : table des sens (hausse favorable / défavorable / neutre) et rendu des tuiles ; Analyse de garde : pages de 100, produits gardés (tranches → `limit=1`, onglets sans rechargement) ; CA emplacement / famille : choix multiple transmis « id1,id2 », « Tout » / « Aucun » = aucun filtre. |
| `vague2_captures_test.dart` | Captures (à la demande) | `CAPTURES_VAGUE2=1 flutter test test/vague2_captures_test.dart --update-goldens` : PNG dans `docs/maquettes/captures_vague2/`. |
| `unitaires/vague3_test.dart`, `integration/vague3_api_test.dart`, `e2e/parcours_vague3_test.dart`, `ergonomie/affichage_vague3_test.dart` | Vague 3 des nouveaux menus (écritures légères) | Pointage BL, Avis, Rappels traitement : lecture tolérante, contrôles des saisies IDENTIQUES au serveur (séquence 20 / avoir 40 caractères `[A-Za-z0-9 ./-]`, période d'un an, note interne nettoyée comme `Texte.libre`, statuts marquables), refus distincts (droit manquant / refus métier / 401 / 500 / délai / injoignable), AUCUNE route d'envoi, de réglages ou d'actualisation appelée (`requetesInterditesVague3`, vérifié après chaque test), détail d'un avis (qui le marque « lu ») seulement au toucher, anti double envoi, échec → mise à jour optimiste annulée, « Traiter » absent sans le droit, marquer plusieurs rappels avec confirmation, journal sans donnée de client ni de santé, chaque écran aux 5 tailles × 2 échelles sans écart. Données : `support/donnees_vague3.dart` (le faux serveur garde l'état des écritures). |
| `vague3_captures_test.dart` | Captures (à la demande) | `CAPTURES_VAGUE3=1 flutter test test/vague3_captures_test.dart --update-goldens` : PNG dans `docs/maquettes/captures_vague3/`. |
| `unitaires/taille_ecran_test.dart`, `ergonomie/taille_ecran_test.dart`, `e2e/parcours_taille_ecran_test.dart` | Taille de l'écran (3.7.0) | Module repris de Prestige Inventaire / Prestige Mobile (`docs/TAILLE_ECRAN.md`) : facteurs, seuil « petit écran » (V2s 360×720 et V3 360×640 dp → Compact en Automatique ; téléphones 1080×2400 et tablette inchangés), choix manuel prioritaire, persistance, PDF / impressions indépendants de l'écran ; écrans principaux de la nouvelle interface sur V2s en Automatique, Compact et Très compact (×1,0 et ×1,3) sans débordement ni coupure ; réglage protégé par le code, « Plus tard » / « Relancer maintenant » (session gardée), déconnexion automatique, ancienne interface. **Ergonomie** : les profils Sunmi 720×1440, Sunmi 1080×1920 et 360×640 dp sont en Compact automatique ; cibles exigées à 48 dp de l'interface, contraste mesuré à la résolution de l'interface (`support/contraste_interface.dart`). |
| `non_regression/version_sunmi_test.dart` | Non-régression (versions) | `pubspec.yaml` au format `X.Y.Z+N`, aucun `versionCode` / `versionName` en dur dans Gradle ; dès qu'une version est publiée (`docs/VERSIONS_SUNMI.md`, `minimum_sunmi:`), X.Y.Z ≥ publiée et +N strictement supérieur. |
| `version_affichee_test.dart` | Version affichée | « Version X.Y.Z+N » lue à l'exécution, en bas de la connexion et dans les Réglages, dans les deux interfaces. |
| `vague1_captures_test.dart` | Captures (à la demande) | `CAPTURES_VAGUE1=1 flutter test test/vague1_captures_test.dart --update-goldens` : PNG dans `docs/maquettes/captures_vague1/`. |
| `refonte_captures_test.dart` | Captures (à la demande) | `CAPTURES_REFONTE=1 flutter test test/refonte_captures_test.dart --update-goldens` : PNG de la nouvelle interface dans `docs/maquettes/captures_refonte/` (sauté sinon). |

## Outils (`support/`)

- `faux_serveur_prestige.dart` : faux serveur Prestige (`HttpServer` sur 127.0.0.1, port libre). Routes
  scriptables (`serveur.quand('/info', ReponseFausse.json([...]))`, `serveur.route(...)` pour une réponse
  calculée), réponses types (`refus`, `sessionExpiree`, `sessionExpireeEn200`, `erreurServeur`, `introuvable`,
  `vide`, `sansReponse`, `.apres(delai)`), session JSESSIONID exigée sur les routes privées
  (`expirerSessions()`), journal des requêtes (`serveur.recues('/info')`). `clientMemoire()` donne les mêmes
  routes sans socket (tests à horloge simulée).
- `application.dart` : `utiliserReseauReel()`, `preparerTelephone(serveur)` (préférences qui visent le faux
  serveur), `lancerApplication()`, attentes `attendreTexte` / `attendreWidget` / `attendreQue` (horloge simulée
  ET temps réel), `terminer()`, `releverErreurs()`.
- `nouvelle_interface.dart`, `cas_affichage_nouvelle.dart` : téléphone préparé dans la nouvelle interface et la
  présentation voulue (`preparerNouvelle`), chiffres du jour de l'accueil A (`donneesAccueil`), connexion, onglets ;
  écrans de la nouvelle interface rendus par l'ergonomie. `preparerTelephone(serveur)` prépare l'interface
  d'ORIGINE (les tests écrits pour elle) : la nouvelle est celle par défaut de l'application.
- `ecarts_connus.dart` : écarts d'ergonomie connus (communs aux deux interfaces ; la liste ne fait que diminuer).
- `catalogue_ecrans.dart` : modules de l'accueil (tuile, titre de la barre, constructeur) et états supplémentaires.
- `cas_affichage.dart`, `ergonomie.dart` : écrans rendus, appareils, échelles, guides d'accessibilité.
- `polices.dart` : polices réelles (Roboto du SDK, sous les noms Lato de google_fonts) ; sans elles, flutter_test
  dessine des carrés de 1 em et les tests de débordement donneraient de fausses alertes.
- `outils/` (plus ancien) : `monterAvecProviders`, serveur simulé du module Présences.

## Quand on ajoute un écran

1. **Module de l'accueil** : l'ajouter à `modulesAccueil` dans `support/catalogue_ecrans.dart` (titre de la
   tuile, titre de sa barre, constructeur). Le test e2e échoue tant qu'il manque ; il est alors ouvert/fermé par
   le parcours e2e et rendu automatiquement aux 5 tailles × 2 échelles et contrôlé par le test de thème.
2. **Écran secondaire ou état intéressant** (liste remplie, onglet, détail) : l'ajouter à `etatsSupplementaires`
   (ou un `CasAffichage` dans `support/cas_affichage.dart`).
3. **Nouvelle route serveur** : réponse fictive par défaut dans `installerRoutesParDefaut()` (format réel de
   Prestige, données inventées), puis un test d'intégration du service (succès, liste vide, 401, 500, délai).
4. **Parcours métier** : un test e2e dans `e2e/` (ouvrir, saisir, vérifier ce que le serveur a reçu avec
   `serveur.recues(...)`, revenir).
5. **Correction d'un défaut** : un test qui échouait avant la correction, dans le fichier du thème concerné.

Règles : jamais de vraies données ; aucune attente existante affaiblie ; les écarts tolérés (`ecartsConnus`,
`ecartsConnusCommuns`, `plafondCouleursEnDur`) ne doivent que diminuer — on n'y ajoute rien pour faire passer
un écran nouveau ou modifié. Pas de tests « golden » en CI (images de référence fragiles d'une machine à l'autre) :
les captures PNG sont produites à la demande seulement.

Un module ajouté à l'accueil doit aussi être rangé dans `lib/nouvelle_interface/menus.dart` (famille et question) :
le parcours e2e de la nouvelle interface l'ouvre alors dans chaque présentation (`modulesNouvelleInterface` : les
modules de l'accueil d'origine présents dans ces menus, donc sans « Fournisseurs »).

Module refait dans la nouvelle interface (lots de la refonte) : le déclarer dans `modulesLot1` / `modulesLot2` / `modulesLot3` / `modulesLot4`
(`support/catalogue_ecrans.dart`, écran d'origine + nouvel écran ; `modulesRefaits` les réunit), placer la lecture des
données dans `lib/donnees/` (partagée par les deux écrans), ajouter sa comparaison dans `lot1_non_regression_test.dart`
/ `lot2_non_regression_test.dart` / `lot3_non_regression_test.dart` / `lot4_non_regression_test.dart` et ses états dans `casLot1`
(`support/cas_affichage_nouvelle.dart`) / `casLot2` (`support/cas_lot2.dart`) / `casLot3` (`support/cas_lot3.dart`) / `casLot4` (`support/cas_lot4.dart`) : ils sont alors rendus sans aucun écart toléré.
