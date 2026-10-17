# Prestige Pharmacien 3.13.1+51 — API 36 pour le seul paquet Google Play

## Numéro de version

**3.13.1+51** (3.13.1 = correction ; 51 = +1 par rapport à 50). Rien de publié sur Sunmi (`docs/VERSIONS_SUNMI.md`).

## Ce qui change (alignement sur Prestige Inventaire 4.16.0)

La 3.13.0 passait **toute** l'application à l'API cible 36 (Android 16), exigée par Google Play. Or Android 16 active
par défaut le **retour prédictif** (et impose le bord à bord, l'orientation libre sur grand écran), et Prestige
Pharmacien tourne aussi sur les terminaux Sunmi avec des APK construits sur le PC du pharmacien.

Désormais (`android/app/build.gradle.kts`, propriété Gradle `pharmacienTargetSdk`) :
- **build Google Play** (`play.yml` : `flutter build appbundle --release --android-project-arg=pharmacienTargetSdk=36`) :
  targetSdk et compileSdk **36**, contrôlés sur le manifeste fusionné ;
- **APK** (PC du pharmacien, terminaux Sunmi, `ci.yml`) : targetSdk **35** (valeur de Flutter 3.32.8) et compileSdk
  **35**, comme avant la 3.13.0 : aucun changement de comportement, **aucune plateforme « Android 16 » à installer**
  sur le poste ;
- `ci.yml` : contrôle que l'APK est bien en 35, puis construit un **App Bundle de contrôle en 36, sans clé** (signé
  debug, jamais publié) : une incompatibilité d'Android 16 se voit à chaque envoi de code, même sans les secrets.

## Retour prédictif (Android 16, paquet Google Play) : écrans qui interceptent le retour

Avec le retour prédictif, Flutter s'appuie sur **PopScope** ; l'ancien **WillPopScope** ne fonctionne plus. Revue du
code (`lib/`) : **aucun WillPopScope**, **deux** écrans avec PopScope, tous deux compatibles :

| Écran | Fichier | Comportement | Avec le retour prédictif |
|---|---|---|---|
| Accueil de la nouvelle interface (barre du bas) | `lib/nouvelle_interface/accueil_nouveau.dart` | sur un autre onglet que « Accueil », le retour revient à l'onglet Accueil ; sur l'onglet Accueil, il quitte l'application | `canPop` à faux hors de l'onglet Accueil : le geste ramène à l'Accueil sans animation de sortie ; sur l'Accueil, animation système de retour au bureau. Testé : `test/e2e/parcours_retours_3_9_0_test.dart` (retour système → onglet Accueil). |
| Détail d'une vente à annuler (Annulation de ventes) | `lib/nouvelle_interface/modules/annulation_ventes_nouveau.dart` | retour refusé pendant l'envoi de l'annulation (message « Annulation en cours… ») ; sinon retour avec le résultat (la liste se recharge si une annulation est partie) | `canPop` toujours faux, retour géré par l'écran : identique. Testé : `test/reseau/serveur_lent_test.dart` (retour refusé pendant une annulation lente, UN seul envoi). |

Les autres écrans n'interceptent pas le retour (aucune saisie perdue : les enregistrements sont immédiats). Garde-fou :
`test/unitaires/android_play_test.dart` échoue si un WillPopScope apparaît ou si un nouvel écran intercepte le retour
(à revoir alors pour Android 16).

## Tests

- `test/unitaires/android_play_test.dart` mis à jour (API 36 seulement par la propriété, APK à 35 contrôlé dans
  `ci.yml`, AAB de contrôle, revue des écrans qui interceptent le retour).
- Workflows validés par actionlint 1.7.7 avec shellcheck 0.10.0 (`play.yml` sans remarque).
- Toutes les catégories lancées comme `ci.yml` avant l'envoi du code.
