# Prestige Pharmacien 3.13.0+50 — Google Play (piste « Test interne »)

## Numéro de version

**3.13.0+50** (3.13.0 = nouvelle diffusion ; 50 = +1 par rapport à 49). Rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`). Identifiant Android inchangé depuis la 3.12.0 : `com.dici.prestige_app`.

## Ce qui change

Prestige Pharmacien peut être diffusé par **Google Play, piste « Test interne »** (équivalent de TestFlight : jusqu'à
100 testeurs, sans examen). Mode d'emploi complet pour le pharmacien : **`docs/android/README.md`** (commun aux
quatre applications Prestige).

### Signature (`android/app/build.gradle.kts`)

- Jusqu'ici, la version release était signée avec la clé **debug** : Google Play refuse ce type de paquet.
- Nouvelle configuration « release » : **clé d'envoi** lue dans les variables d'environnement (`ANDROID_KEYSTORE_PATH`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` — CI) puis dans `android/key.properties`
  (poste de travail ; jamais commité, déjà ignoré par `android/.gitignore`).
- **Sans clé : repli sur la clé debug, comme avant**, avec un avertissement dans le journal de construction. Les APK
  construits sur le PC du pharmacien (terminaux Sunmi) et l'APK de la CI ne changent donc pas de signature.

### Exigences Google Play (octobre 2026)

- **targetSdk 36 (Android 16)** : exigé pour toute nouvelle application et toute mise à jour depuis le 31/08/2026
  (Flutter 3.32.8 proposait 35) ; **compileSdk 36**. AGP 8.7.3 est testé jusqu'à 35 :
  `android.suppressUnsupportedCompileSdk=36` (avertissement seulement). Aucun changement de comportement attendu :
  l'application n'utilisait pas l'option de retrait de l'affichage bord à bord (supprimée par Android 16).
  **Poste du pharmacien** : la plateforme « Android 16 (API 36) » doit être installée (SDK Manager d'Android Studio ;
  sinon Gradle la télécharge si les licences du SDK sont acceptées).
- **App Bundle (.aab)** : produit par la CI dès que la clé d'envoi est déposée.
- **Réseau** : `network_security_config.xml` (HTTP vers le serveur local par adresse IP) accepté par Google Play,
  inchangé.
- **Permissions** : Internet ; stockage **limité à Android 12** (`maxSdkVersion="32"` : export CSV dans
  Téléchargements ; non demandé à partir d'Android 13, comme le code le faisait déjà).
- **Nom affiché** sous l'icône : « Prestige Pharmacien » (au lieu de « prestige_app »).

### CI et envoi (`.github/workflows/play.yml`)

- À chaque envoi de code sur `claude/presences` : si les quatre secrets de la clé existent (`ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`), contrôle de leur forme sans rien afficher
  (base64, mot de passe, alias, refus de la clé debug), keystore écrit dans `$RUNNER_TEMP` (droits 600) puis supprimé,
  **App Bundle signé** contrôlé (pas de clé debug) et publié en artefact **`prestige-pharmacien-aab`**.
- **Envoi en Test interne** seulement quand `android/DEMANDE_PLAY` est modifié (1re ligne = version de `pubspec.yaml`)
  et que le secret **`PLAY_SERVICE_ACCOUNT_JSON`** existe : action `r0adkll/upload-google-play` v1.1.5 **épinglée par
  SHA**, paquet `com.dici.prestige_app`, piste `internal`, statut **completed** ; application encore en brouillon côté
  Play → nouvel essai en **draft** avec un message clair. Notes de version en français.
- **Le premier App Bundle d'une nouvelle application doit être envoyé à la main** dans la Play Console (exigence de
  Google) : guide, étape 6.
- L'APK de `ci.yml` est produit comme avant. Conventions communes aux quatre applications : mêmes noms de secrets,
  même fichier `android/DEMANDE_PLAY` (non créé ici : écrit seulement sur demande du pharmacien).

### Attention : Play et APK installés à la main

Une version installée depuis Play est signée par Google (Play App Signing) : elle ne peut pas être mise à jour par un
APK construit sur le PC (clé debug), ni l'inverse. Sur un appareil, choisir l'une ou l'autre source ; pour passer à
Play : désinstaller, installer depuis Play, ressaisir l'adresse du serveur et les réglages.

## Tests

- `test/unitaires/android_play_test.dart` : choix de la signature (environnement puis `key.properties`, repli debug
  avec avertissement, aucun mot de passe en clair, fichiers de clé ignorés par git), targetSdk / compileSdk 36,
  permissions, nom affiché, workflow (noms des secrets, fichier déclencheur, action épinglée, internal, completed /
  draft, artefact, nettoyage, aucun secret affiché), APK de `ci.yml` inchangé.
- Workflows validés par actionlint 1.7.7 avec shellcheck 0.10.0.
- Toutes les catégories lancées comme `ci.yml` avant l'envoi du code ; la construction réelle de l'APK (targetSdk 36)
  est faite par la CI.
