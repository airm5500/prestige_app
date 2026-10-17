# Prestige Pharmacien 3.12.0+48 — iPhone et iPad (TestFlight) ; nouvel identifiant Android

> **⚠ Android : NOUVELLE APPLICATION.** L'identifiant Android passe de `com.example.prestige_app` à
> **`com.dici.prestige_app`** (décision du pharmacien). Pour Android, c'est une **autre application** : la 3.12.0
> s'installe **à côté** de l'ancienne « Prestige Pharmacien », sans la mettre à jour, et **ne reprend aucun réglage**
> (Android ne permet pas à une application de lire les données d'une autre ; aucune migration n'est tentée).
>
> **Sur chaque téléphone ou terminal Sunmi :**
> 1. installer la 3.12.0 ;
> 2. la configurer de nouveau (liste ci-dessous) et vérifier la connexion ;
> 3. **désinstaller l'ancienne Prestige Pharmacien** (deux icônes identiques sinon).
>
> **Réglages à ressaisir** (perdus, d'après le code — préférences et stockage sécurisé de l'appareil) :
> - **Configuration du serveur** : adresse IP locale, adresse distante, choix local / distant, port, nom de
>   l'application serveur ;
> - **connexion** : identifiant mémorisé, « Se souvenir de moi » et mot de passe mémorisé (stockage sécurisé) ; la
>   session en cours (reconnexion) ;
> - **code administrateur** (à redéfinir ; son compteur d'essais repart de zéro) ;
> - **interface** : nouvelle / ancienne, présentation de l'accueil (Tableau de bord, A, B, C, Automatique), style
>   des icônes, disposition des menus de l'accueil, ordre et menus masqués de l'ancienne interface ;
> - **tableau de bord** : cartes affichées et leur ordre, affichage de la fréquentation (1 h / 2 h, plage) ;
> - **taille de l'écran** (Sunmi : Automatique / Compact / Très compact) ;
> - **alertes** (délais), seuil de retard des Présences, dernier grossiste / groupe du Pointage BL, délai
>   d'expiration de la session ;
> - données remises en cache d'elles-mêmes (nom de l'officine, profil de l'utilisateur).
>
> Rien ne change côté serveur ni pour la licence. Le namespace et le code Android (`com.example.prestige_app`,
> MainActivity) ne changent pas ; le nom de l'APK reste `prestige-release-<version>.apk`.

## Numéro de version

**3.12.0+48** (3.12.0 = nouvelle plateforme ; 48 = +1 par rapport à 47). Rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

## iPhone et iPad

Prestige Pharmacien se construit pour iOS 13 et plus, iPhone **et** iPad, et s'envoie vers **TestFlight** : mode
d'emploi complet pour le pharmacien dans **`docs/ios/README.md`** (création de l'app dans App Store Connect, Key ID,
Issuer ID, Team ID, secrets GitHub, envoi, testeurs, installation).

### Ce qui marche sur iOS

Toute l'application : connexion (serveur local en http, distant en https), tableau de bord, tous les menus, deux
interfaces, présentations A / B / C et mise en page tablette sur iPad, impressions et PDF (fenêtre d'impression
d'iOS), exports Partager / Ouvrir (feuille de partage, ancrée sur iPad), stockage sécurisé (Keychain).

### Ce qui est masqué ou différent (couche de capacités `lib/plateforme/capacites.dart`)

| Fonction | Android | iOS |
|---|---|---|
| Réglage « Taille de l'écran » (terminaux Sunmi) | inchangé | **masqué** ; aucune réduction automatique (iPhone SE compris) |
| Export CSV d'une suggestion | Téléchargements | app **Fichiers** (Sur mon iPhone / iPad › Prestige Pharmacien) |
| Feuille de partage | inchangée | ancrée au centre de l'écran (obligatoire sur iPad) |

### Projet iOS (`ios/`)

- `Info.plist` : nom affiché « Prestige Pharmacien », français ; **ATS** : `NSAllowsLocalNetworking` seulement (pas
  de `NSAllowsArbitraryLoads`) ; `NSLocalNetworkUsageDescription` (autorisation « réseau local », iOS 14+) ;
  fichiers visibles dans l'app Fichiers ; `ITSAppUsesNonExemptEncryption = false` ; orientations iPhone (portrait,
  paysage) et iPad (les quatre). Aucune autorisation caméra, photos, micro ou localisation : l'application n'en
  utilise pas.
- **Identifiant (bundle ID)** : `com.dici.prestige-app` (décision du pharmacien ; le « _ » est interdit sur iOS),
  paramètre `PRESTIGE_BUNDLE_ID` de `ios/Flutter/Prestige.xcconfig` (variable GitHub `IOS_BUNDLE_ID` possible).
- **iOS 13** minimum (projet, `AppFrameworkInfo.plist`, `ios/Podfile` versionné, pods).
- **Version** tirée de `pubspec.yaml` (contrôlée sur l'application produite par la CI).
- **Icône** : celle d'Android (mortier vert), sur fond blanc, **opaque** (exigence de l'App Store), toutes tailles.
- **Écran de lancement** : fond et anneau à croix verte de l'écran de chargement « Prestige Pharmacien ».

### CI et TestFlight

- `.github/workflows/ci.yml`, nouveau job **ios** (macOS 15, indépendant du job Android) : tests iOS,
  `flutter build ios --release --no-codesign`, contrôle de l'`Info.plist` produit (version = pubspec, bundle ID,
  ATS, texte « réseau local »).
- `.github/workflows/testflight.yml` (lancé à la main ; ne fait **rien** sans les quatre secrets
  `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_PRIVATE_KEY`, `APPLE_TEAM_ID`) :
  signature automatique par la clé API (`xcodebuild -allowProvisioningUpdates -authenticationKey…`), IPA
  (`app-store-connect`), envoi par **asc** 5.14.3 (App Store Connect CLI, MIT, empreinte SHA-256 vérifiée) avec notes
  « Quoi tester » en français, groupe de testeurs facultatif ; numéro de build `<N>.<numéro de l'envoi>` ; clé `.p8`
  dans le dossier temporaire du runner (droits 600), supprimée à la fin même en cas d'échec ; rien de secret dans le
  dépôt ni les journaux.

### À vérifier sur un vrai iPhone / iPad (TestFlight)

Autorisation « réseau local » puis connexion au serveur de l'officine (IP locale) ; serveur distant ; impression
AirPrint et « Enregistrer dans Fichiers » ; Partager un Excel sur iPad ; export CSV visible dans Fichiers ; rotation
de l'iPad ; Face ID non concerné.

## Tests

- Unitaires : `test/unitaires/ios_test.dart` (capacités Android / iOS, taille de l'écran, ancrage du partage,
  Info.plist, xcconfig, projet Xcode, Podfile, icônes opaques et tailles, écran de lancement, identifiant Android) ;
  `test/socle_test.dart` mis à jour (nouvel applicationId).
- Bout en bout : `test/e2e/parcours_ios_test.dart` (iPhone SE, plateforme iOS : connexion, tableau de bord à la
  taille du système, Réglages sans « Taille de l'écran » ; ancienne interface : absent sur iOS, présent sur Android).
- Ergonomie : `test/ergonomie/ios_affichage_test.dart` — TOUS les écrans de la nouvelle interface en plateforme iOS,
  iPhone 375×667 et 430×932, iPad 768×1024 et 1366×1024, texte ×1 et ×1,3 (1 872 cas), mêmes règles qu'Android.
- Performance : `test/performance/ios_test.dart` (tableau de bord iPhone et iPad : 7 requêtes, pire image).
- Réseau : `test/reseau/ios_test.dart` (serveur coupé, serveur lent, adresses http / https acceptées).
- Captures iPhone SE, iPhone 430 pt et iPad : `docs/maquettes/captures_3_12_0/`
  (`CAPTURES_3_11=1 flutter test test/captures_3_12_0_test.dart --update-goldens`).

## Complément (sans nouvelle version de l'application) — envoi TestFlight par étiquette

Le bouton « Run workflow » de GitHub n'existe que pour la branche par défaut (master), que l'on ne touche pas.
`.github/workflows/testflight.yml` se déclenche donc AUSSI par une étiquette Git **`ios-v<version>-<build>`** (ex.
`ios-v3.12.0-48` pour 3.12.0+48), posée sur `claude/presences` : le job vérifie que l'étiquette correspond à
`pubspec.yaml` (sinon il s'arrête avec un message) et ne fait toujours rien sans les quatre secrets. Groupe de testeurs
des envois par étiquette : variable facultative `TESTFLIGHT_GROUP`. Mode d'emploi : `docs/ios/README.md`, « 4. Lancer un
envoi TestFlight ». Workflows validés par actionlint 1.7.7. Aucun changement de l'application (toujours 3.12.0+48).

