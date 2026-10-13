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
un écran nouveau ou modifié. Pas de tests « golden » (images de référence fragiles d'une machine à l'autre).
