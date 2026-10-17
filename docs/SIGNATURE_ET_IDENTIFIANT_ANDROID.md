# Signature de l'APK et identifiant Android — procédure recommandée

> Étape 1 : **rien n'a été changé** ici (décision du client). Changer la clé de signature ou
> l'`applicationId` empêcherait la mise à jour des téléphones déjà installés. Ce document décrit la
> situation et la procédure à suivre le moment venu (étape 5, publication).

## Situation actuelle

| Élément | Valeur | Conséquence |
|---|---|---|
| `applicationId` | `com.dici.prestige_app` depuis la 3.12.0 (`android/app/build.gradle.kts` ; avant : `com.example.prestige_app`) | Nouvelle application : réinstaller et ressaisir les réglages (`docs/NOTE_VERSION_3.12.0.md`). Le namespace Kotlin reste `com.example.prestige_app`. |
| Signature release | clé **debug** (`signingConfig = signingConfigs.getByName("debug")`) | La clé debug est propre à **chaque ordinateur** (`~/.android/debug.keystore`). |
| Version | `version:` de `pubspec.yaml` (depuis l'étape 0), ex. `2.3.0+23` | `versionCode` = nombre après `+` : il doit toujours augmenter. |

### Point d'attention immédiat : quel APK installe-t-on chez le pharmacien ?

Android n'accepte une mise à jour que si elle est signée par **la même clé** que l'application
installée. Comme la clé debug dépend de la machine :

- l'APK produit par la **CI GitHub Actions** (artefact `prestige-pharmacien-apk`) est signé avec la clé
  debug du serveur de CI, différente de celle de l'ordinateur qui a construit les versions installées :
  il sert **aux essais** (téléphone de test, après désinstallation) ;
- pour **mettre à jour** les téléphones existants sans perdre leurs réglages, construire l'APK sur
  l'ordinateur qui a produit les versions actuelles (même `~/.android/debug.keystore`), ou faire signer
  la CI avec ce même fichier (voir « Étape transitoire » ci-dessous).

## Étape transitoire (sans rien casser) : signer toujours avec la même clé

1. Récupérer le fichier `~/.android/debug.keystore` de l'ordinateur qui a construit les versions
   installées (mot de passe : `android`, alias : `androiddebugkey`). **Le sauvegarder** (coffre-fort).
2. L'enregistrer comme secret GitHub (`PRESTIGE_KEYSTORE_BASE64` = `base64 debug.keystore`).
3. Dans la CI, avant `flutter build apk`, restaurer le fichier à `~/.android/debug.keystore`.
   Les APK de la CI pourront alors mettre à jour les téléphones existants.

## Procédure recommandée (publication, étape 5)

### 1. Créer une vraie clé de publication

```bash
keytool -genkeypair -v -keystore prestige-release.jks -alias prestige \
  -keyalg RSA -keysize 4096 -validity 10000
```

- Garder `prestige-release.jks` et ses mots de passe **hors du dépôt**, en deux copies sûres. Une clé
  perdue = plus aucune mise à jour possible.
- Créer `android/key.properties` (ignoré par git) :

  ```properties
  storeFile=/chemin/vers/prestige-release.jks
  storePassword=…
  keyAlias=prestige
  keyPassword=…
  ```

- Dans `android/app/build.gradle.kts`, ajouter un `signingConfigs { create("release") { … } }` lu depuis
  `key.properties`, et `signingConfig = signingConfigs.getByName("release")` pour `release`
  (garder le repli sur `debug` si `key.properties` est absent, pour les builds de développement).
- CI : clé et mots de passe en secrets GitHub, fichier recréé pendant le job.

### 2. Passer des téléphones installés (clé debug) à la nouvelle clé

Deux possibilités :

- **Rotation de clé (APK Signature Scheme v3)** — Android 9 et plus : signer le nouvel APK avec la
  nouvelle clé et une preuve de rotation depuis l'ancienne (`apksigner rotate` puis
  `apksigner sign --lineage …`). Les téléphones Android 9+ acceptent la mise à jour ; **les téléphones
  plus anciens (Android 5 à 8) la refusent** : il faudra y désinstaller / réinstaller.
- **Réinstallation** : désinstaller l'ancienne application et installer la nouvelle. Les réglages
  (adresse du serveur, accueil personnalisé) et le mot de passe mémorisé sont perdus : prévoir de les
  ressaisir (noter l'adresse du serveur avant).

### 3. Changer l'`applicationId` (si souhaité, ex. `ci.prestige.pharmacien`)

- Pour Android, c'est **une autre application** : elle s'installe à côté de l'ancienne, sans reprendre
  ses données. À faire **en même temps** que le changement de clé (une seule réinstallation).
- Garder `namespace` et `applicationId` cohérents ; mettre à jour le nom affiché
  (`android:label`, aujourd'hui « prestige_app »).
- Le Play Store exige un identifiant définitif : ne plus le changer ensuite.

### 4. Vérifications avant diffusion

- `versionCode` (pubspec, après `+`) supérieur à celui installé.
- `apksigner verify --print-certs app-release.apk` : empreinte SHA-256 = celle de la clé attendue.
- Essai de mise à jour sur un téléphone qui a l'ancienne version (réglages conservés).
