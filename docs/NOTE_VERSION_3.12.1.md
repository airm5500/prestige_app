# Prestige Pharmacien 3.12.1+49 — iOS 15 au minimum ; envoi TestFlight fiabilisé

## Numéro de version

**3.12.1+49** (3.12.1 = correction ; 49 = +1 par rapport à 48). Rien de publié sur Sunmi (`docs/VERSIONS_SUNMI.md`).
Android : aucun changement (même identifiant `com.dici.prestige_app` que la 3.12.0).

## TestFlight : la 3.12.0 est arrivée

Prestige Pharmacien 3.12.0 (build **48.16**) est sur TestFlight (run 39024546067). Apple a signalé un avertissement
**ITMS-90068** : la cible de déploiement iOS 13.0 est trop basse ; **à partir d'avril 2027, iOS 15.0 minimum** sera
exigé.

## iOS 15 au minimum

Partout dans le projet iOS :
- `ios/Podfile` : `platform :ios, '15.0'`, et `IPHONEOS_DEPLOYMENT_TARGET = 15.0` imposé à tous les pods
  (`post_install`) ;
- projet Runner (`project.pbxproj`, Debug / Release / Profile) : `IPHONEOS_DEPLOYMENT_TARGET = 15.0` ;
- `ios/Flutter/AppFrameworkInfo.plist` : `MinimumOSVersion` 15.0.

Appareils concernés : iPhone 6s / SE (1re génération) et plus récents, iPad 5e génération, iPad Air 2, iPad mini 4,
tous les iPad Pro et plus récents. Un iPhone ou iPad resté en iOS 13 ou 14 ne peut plus installer la build depuis
TestFlight (mise à jour d'iOS nécessaire).

Contrôles : `test/unitaires/ios_test.dart` (15.0 partout : projet, Podfile, AppFrameworkInfo) et job **ios** de la CI
(l'application produite doit annoncer `MinimumOSVersion` = 15.0).

## CI et envoi TestFlight (modifications du coordinateur, reprises ici)

- Envoi déclenché aussi par le fichier **`ios/DEMANDE_TESTFLIGHT`** (1re ligne = version de `pubspec.yaml`), en plus
  de l'étiquette `ios-v<version>-<build>` ; ce fichier n'est modifié que sur demande du pharmacien.
- Contrôles avant tout envoi : présence des secrets, format de la clé API et du fichier `.p8`, message clair si la clé
  n'a pas le rôle **Admin**.
- `flutter build ios --config-only --no-codesign` avant l'archive signée.
- Construction avec **Xcode 26 ou plus récent** (Apple exige le SDK iOS 26 : erreur 90725 sinon), dans la CI comme
  dans l'envoi.

## Tests

Toutes les catégories lancées comme la CI (`ci.yml`) avant l'envoi du code ; tests iOS mis à jour (15.0).

**Test dépendant du temps rendu stable** (relevé par ce lancement local) : « Connexion → accueil A · Tableau de bord »
(`test/performance/demarrage_test.dart`) a mesuré 631 ms pour un seuil de 600 ms, alors que les autres accueils
mesuraient 75 à 400 ms. C'était le premier cas de la série : il payait la compilation à la volée (JIT, propre aux
tests) de toute la nouvelle interface, 455 à 631 ms selon la charge de la machine. Un préchauffage non mesuré précède
maintenant la série : 309 et 366 ms ensuite. Le seuil n'a pas été touché ; sur le téléphone (code compilé d'avance),
ce coût n'existe pas.

**Second test instable corrigé** (même lancement) : « CA emplacement, 60 tranches (tablette) — pire image,
défilement » a mesuré 711 ms pour un seuil de 600 ms (288 à 711 ms selon les lancements : une seule image coûteuse).
Cause : sur tablette, le grand tableau (60 colonnes) sortait de la liste en défilant et était **reconstruit en entier**
à chaque retour à l'écran. Il est maintenant gardé en mémoire (`ca_zone_vague2.dart`) : **12 à 20 ms**. Gain réel aussi
pour le pharmacien sur tablette (défilement sans à-coup). Seuil inchangé.

