# Prestige Pharmacien sur iPhone et iPad — envoi vers TestFlight

Ce guide est pour le pharmacien (titulaire du compte Apple Developer). Il se fait **une fois** ; ensuite, chaque
nouvelle version s'envoie en un clic depuis GitHub.

> **Sécurité.** La clé API (fichier `.p8`) ne doit jamais être envoyée par e-mail, messagerie ou conversation. Vous
> la déposez vous-même dans GitHub (étape 3) ; elle n'est ensuite lisible par personne, ni affichée dans les journaux.

## Ce qu'il faut

| Élément | Valeur pour Prestige Pharmacien |
|---|---|
| Identifiant de l'application (bundle ID) | **`com.dici.prestige-app`** (le « _ » est interdit sur iOS ; Android garde `com.dici.prestige_app`) |
| Compte | Apple Developer Program (payant), accès à App Store Connect |
| Clé API App Store Connect | rôle **Admin** (la signature automatique crée certificat et profil au besoin) |
| iPhone / iPad des testeurs | iOS / iPadOS **15** ou plus récent (iPhone 6s / SE 1re génération et plus récents), application **TestFlight** (gratuite, App Store) |

## 1. Enregistrer l'identifiant et créer l'application

1. <https://developer.apple.com/account> › **Certificates, Identifiers & Profiles** › **Identifiers** › **+** ›
   **App IDs** › **App** › Description « Prestige Pharmacien », Bundle ID **Explicit** : `com.dici.prestige-app` ›
   **Register**. (Aucune « capability » à cocher.)
2. <https://appstoreconnect.apple.com> › **Apps** › **+** › **Nouvelle app** :
   - Plateformes : **iOS** ;
   - Nom : « Prestige Pharmacien » (nom public, modifiable plus tard) ;
   - Langue principale : **Français** ;
   - Identifiant de lot (bundle ID) : `com.dici.prestige-app` ;
   - SKU : par exemple `prestige-pharmacien` ;
   - Accès : complet.

## 2. Retrouver les trois identifiants et la clé

| Secret GitHub | Où le trouver |
|---|---|
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect › **Utilisateurs et accès** › **Intégrations** › **App Store Connect API** : « ID de l'émetteur » (en haut, forme `69a6de7e-…`) |
| `APP_STORE_CONNECT_KEY_ID` | même page › **Clés d'équipe** › **Générer une clé API** (nom « Prestige CI », accès **Admin**) : colonne « ID de la clé » (10 caractères) |
| `APP_STORE_CONNECT_PRIVATE_KEY` | même ligne › **Télécharger la clé API** : fichier `AuthKey_XXXXXXXXXX.p8` (téléchargeable **une seule fois** : le garder en lieu sûr). Le secret est **tout le contenu** du fichier, lignes `-----BEGIN PRIVATE KEY-----` et `-----END PRIVATE KEY-----` comprises. |
| `APPLE_TEAM_ID` | <https://developer.apple.com/account> › **Membership details** : « Team ID » (10 caractères) |

## 3. Déposer les secrets dans GitHub

Dépôt `airm5500/prestige_app` › **Settings** › **Secrets and variables** › **Actions** › onglet **Secrets** ›
**New repository secret**, quatre fois :

1. `APP_STORE_CONNECT_KEY_ID`
2. `APP_STORE_CONNECT_ISSUER_ID`
3. `APP_STORE_CONNECT_PRIVATE_KEY` (ouvrir le `.p8` avec un éditeur de texte, tout copier, coller)
4. `APPLE_TEAM_ID`

Facultatif, onglet **Variables** : `IOS_BUNDLE_ID` si l'identifiant devait changer un jour (sinon la valeur de
`ios/Flutter/Prestige.xcconfig`, `com.dici.prestige-app`, est utilisée).

Facultatif aussi : `TESTFLIGHT_GROUP` (groupe de testeurs pour les envois par étiquette, voir l'étape 4).

Tant que ces quatre secrets n'existent pas, l'envoi ne fait rien (message « Secrets App Store Connect absents ») ;
la construction iOS de contrôle (sans signature) tourne de toute façon à chaque envoi de code (job « ios » de la CI).

## 4. Lancer un envoi TestFlight

L'envoi se lance par une **étiquette (tag) Git** `ios-v<version>-<build>`, où `<version>-<build>` reprend la version
de `pubspec.yaml` avec « - » à la place du « + » : version `3.12.0+48` → étiquette **`ios-v3.12.0-48`**. Une étiquette
qui ne correspond pas à `pubspec.yaml` est refusée (message « Étiquette … attendu … ») ; sans les quatre secrets, rien
n'est envoyé.

**Le plus simple :** demander « envoie sur TestFlight ». L'équipe écrit la version en cours (ex. `3.12.0+48`) dans
le fichier `ios/DEMANDE_TESTFLIGHT` de la branche `claude/presences` : cette modification lance l'envoi (même
contrôle qu'une étiquette : le contenu doit être la version de `pubspec.yaml`). Ce fichier garde aussi la trace de la
dernière version demandée.

**Vous-même, depuis GitHub :**
1. dépôt `airm5500/prestige_app` › **Code** › **Tags** (ou **Releases**) › **Draft a new release** ;
2. **Choose a tag** : saisir `ios-v3.12.0-48` (la version en cours) › **Create new tag on publish** ;
3. **Target** : choisir la branche **`claude/presences`** ;
4. titre libre (ex. « TestFlight 3.12.0 ») › **Publish release** ;
5. suivre l'envoi dans **Actions** › **TestFlight (iOS)**.

Une même étiquette ne sert qu'une fois. Pour renvoyer la même version (correction de dernière minute sans changer
`pubspec.yaml`), relancer le run depuis **Actions** (bouton **Re-run all jobs**) : le numéro de build change tout
seul.

Réglages des envois par étiquette (facultatif, **Settings** › **Secrets and variables** › **Actions** › onglet
**Variables**) : `TESTFLIGHT_GROUP` = nom du groupe de testeurs à qui donner chaque build (sinon : testeurs internes
seulement).

Détails : numéro de build automatique `<numéro de pubspec>.<numéro de l'envoi>` (ex. `48.3`, toujours différent comme
l'exige Apple) ; notes « Quoi tester » en français. Le bouton **Actions** › **TestFlight (iOS)** › **Run workflow**
(numéro de build, groupe et notes au choix) n'apparaît que lorsque le workflow est sur la branche par défaut du dépôt.

Compter 20 à 40 minutes : construction, signature automatique, envoi, puis traitement par Apple (la build passe
« En traitement » puis « Prête à tester » dans App Store Connect › TestFlight). Apple envoie un e-mail en cas de
problème.

## 5. Les testeurs

- **Testeurs internes** (jusqu'à 100, membres de votre équipe App Store Connect) : App Store Connect › **TestFlight**
  › **Testeurs internes** › **+** › créer un groupe (ex. « Officine ») › ajouter les personnes (elles doivent d'abord
  être invitées dans **Utilisateurs et accès**). Ils reçoivent chaque build traitée, **sans examen** d'Apple.
- **Testeurs externes** (jusqu'à 10 000, par e-mail ou lien public) : **TestFlight** › **Testeurs externes** › **+**
  › groupe › ajouter des adresses e-mail ou activer un **lien public**. La **première** build d'une version passe un
  court **examen bêta** d'Apple (24 à 48 h en général) : renseigner « Informations de test » (adresse e-mail de
  contact, et un **compte de démonstration** si l'examinateur doit se connecter — sans serveur Prestige joignable,
  expliquer que l'application se connecte au serveur de l'officine sur son réseau local).

## 6. Installer sur l'iPhone ou l'iPad

1. Installer **TestFlight** depuis l'App Store.
2. Ouvrir l'invitation (e-mail ou lien public) sur l'appareil › **Accepter** › **Installer**.
3. Premier lancement : iOS demande l'autorisation **« réseau local »** : répondre **Autoriser** (sinon le serveur de
   l'officine est injoignable ; à rétablir dans Réglages › Confidentialité et sécurité › Réseau local).
4. Saisir l'adresse du serveur comme sur Android (Configuration du serveur).

## Ce qui marche sur iPhone et iPad, ce qui est masqué

| Fonction | iPhone / iPad |
|---|---|
| Connexion, tableau de bord, tous les menus, deux interfaces, présentations A / B / C, tablette (iPad) | comme Android |
| Serveur local en **http** (adresse IP, nom du réseau local) et serveur distant en **https** | comme Android (autorisation « réseau local » demandée une fois) |
| Impressions et PDF (Récap caisse, Évolution stock, Suivi péremption, analyses) | fenêtre d'impression d'iOS (AirPrint, « Enregistrer dans Fichiers », partage) |
| Exports Excel / PDF (Présences, Balance, Sur-stocks) : Partager / Ouvrir | feuille de partage d'iOS (ancrée sur iPad) |
| Export CSV d'une suggestion | dans l'app **Fichiers** › Sur mon iPhone / iPad › Prestige Pharmacien (au lieu de Téléchargements) |
| Mot de passe mémorisé, cookie de session, code administrateur | trousseau iOS (Keychain) |
| Réglage **« Taille de l'écran »** (réduction pour les terminaux Sunmi) | **masqué** : iOS garde sa taille de texte (réglage Accessibilité de l'appareil) |

## Pour les développeurs

- Projet iOS : iOS 15 minimum (depuis la 3.12.1 ; Apple l’exigera à partir d’avril 2027, avertissement ITMS-90068), iPhone + iPad (`TARGETED_DEVICE_FAMILY = 1,2`), version lue dans `pubspec.yaml`,
  identifiant dans `ios/Flutter/Prestige.xcconfig` (`PRESTIGE_BUNDLE_ID`), `ios/Podfile` versionné.
- `Info.plist` : nom affiché « Prestige Pharmacien », français ; ATS : **`NSAllowsLocalNetworking`** seulement (HTTP
  limité au réseau local ; **pas** de `NSAllowsArbitraryLoads`, que l'examen d'Apple demande de justifier). Les
  requêtes de l'application passent par `dart:io` (package `http`), que l'ATS ne filtre pas : un serveur distant en
  http par adresse IP reste joignable comme sur Android ; un serveur nommé sur Internet devrait de toute façon être
  en https. `NSLocalNetworkUsageDescription` (texte de l'autorisation « réseau local »), `UIFileSharingEnabled`,
  `ITSAppUsesNonExemptEncryption = false` (HTTPS et Keychain du système seulement).
- Capacités par plateforme : `lib/plateforme/capacites.dart` (tests : `test/unitaires/ios_test.dart`,
  `test/e2e/parcours_ios_test.dart`, `test/ergonomie/ios_affichage_test.dart`, `test/performance/ios_test.dart`,
  `test/reseau/ios_test.dart`).
- CI : job **ios** de `.github/workflows/ci.yml` (macOS : tests iOS, `flutter build ios --release --no-codesign`,
  contrôle de l'`Info.plist` produit). Envoi : `.github/workflows/testflight.yml`, déclenché par une étiquette
  `ios-v*` (vérifiée contre `pubspec.yaml`) ou à la main depuis la branche par défaut.
- Outil d'envoi : **asc** (App Store Connect CLI, <https://github.com/rorkai/App-Store-Connect-CLI>, licence MIT),
  version **5.14.3** épinglée, binaire macOS arm64 vérifié par son empreinte SHA-256 écrite dans le workflow ;
  télémétrie coupée (`ASC_TELEMETRY_DISABLED`, `DO_NOT_TRACK`) ; authentification par variables d'environnement
  (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY_PATH`, `ASC_BYPASS_KEYCHAIN`). Commandes : `asc builds upload
  --app <bundle ID> --ipa … --test-notes … --locale fr-FR --wait`, puis `asc builds add-groups … --group …`. Choisi
  plutôt que `xcrun altool` (déprécié par Apple pour l'envoi, sans gestion des notes ni des groupes) et sans fastlane
  (Ruby, dépendances lourdes).
- Signature : automatique, `xcodebuild archive` / `-exportArchive` avec `-allowProvisioningUpdates
  -authenticationKeyPath/-ID/-IssuerID` (ExportOptions : `app-store-connect`, `automatic`, Team ID), sans
  certificat ni profil à gérer.
