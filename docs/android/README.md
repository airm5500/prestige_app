# Prestige Pharmacien sur Google Play — piste « Test interne »

Ce guide est pour le pharmacien. La piste **Test interne** de Google Play est l'équivalent de TestFlight : jusqu'à
100 testeurs choisis par e-mail, version disponible en quelques minutes, **sans examen** de Google ni fiche publique.

Il vaut pour les **quatre** applications Prestige (Prestige Pharmacien, Prestige Mobile, PrestigePOS, Prestige
Inventaire) : mêmes étapes, mêmes noms de secrets, même fichier de demande. **Une seule clé d'envoi peut servir aux
quatre** : la créer une fois (étape 3) et déposer les **mêmes** secrets dans chaque dépôt GitHub (`prestige_app`,
`prestige_vente_app`, `prestinv`).

> **Sécurité.** La clé d'envoi (fichier `.jks`), ses mots de passe et la clé JSON du compte de service ne doivent
> jamais être envoyés par e-mail, messagerie ou conversation : vous les déposez vous-même dans GitHub (étapes 4 et 8).

| Élément | Valeur pour Prestige Pharmacien |
|---|---|
| Nom du paquet (package name) | **`com.dici.prestige_app`** (depuis la 3.13.0 ; ne peut plus jamais changer sur Play) |
| Piste | Test interne (`internal`) |
| Format envoyé | App Bundle `.aab`, signé par **votre** clé d'envoi, re-signé par Google (Play App Signing) |
| Android minimum / cible | Android 5.0 (API 21) / Android 16 (API 36, exigé par Google depuis le 31/08/2026 ; pour le seul paquet Google Play) |

## 1. Compte Google Play Console

<https://play.google.com/console/signup> : compte **organisation** (la pharmacie) ou personnel, frais uniques de
**25 $**. Google vérifie l'identité (pièce d'identité, et pour une organisation le numéro D-U-N-S) : compter quelques
jours. Un compte **personnel créé récemment** doit faire un test fermé (12 testeurs pendant 14 jours) avant de
pouvoir publier en production ; la piste **Test interne**, elle, est disponible tout de suite.

## 2. Créer l'application

Play Console › **Créer une application** :
- Nom : « Prestige Pharmacien » ;
- Langue par défaut : **Français (France) – fr-FR** ;
- Application (pas jeu), **Gratuite** ;
- cocher les déclarations (règles du programme, lois américaines sur l'exportation).

Le nom du paquet n'est pas demandé ici : il est fixé par le **premier App Bundle** envoyé (étape 6).

## 3. Créer la clé d'envoi (une fois pour les 4 applications)

**Avec Android Studio** : ouvrir n'importe quel projet Flutter / Android › **Build** › **Generate Signed App Bundle
or APK** › **Android App Bundle** › **Create new…** :
- Key store path : par exemple `D:\Cles\prestige-envoi.jks` ;
- Password : un mot de passe solide (c'est `ANDROID_KEYSTORE_PASSWORD`) ;
- Alias : `prestige` (c'est `ANDROID_KEY_ALIAS`) ;
- Password de la clé : un mot de passe solide (c'est `ANDROID_KEY_PASSWORD` ; peut être le même) ;
- Validity : **25 ans** au moins ; First and Last Name : nom de la pharmacie ; Country Code : code du pays sur deux lettres (ex. `CI`, `SN`, `FR`) ;
- **OK**, puis **Cancel** (inutile d'aller plus loin : seul le fichier `.jks` compte).

**Ou avec keytool** (PowerShell, dans le dossier `bin` du JDK, ex. `C:\Program Files\Android\Android
Studio\jbr\bin`) :

```powershell
.\keytool.exe -genkeypair -v -keystore D:\Cles\prestige-envoi.jks -alias prestige -keyalg RSA -keysize 2048 -validity 10000
```

> **SAUVEGARDER la clé : fichier `.jks` + mots de passe + alias**, en au moins **deux copies** hors du PC (clé USB au
> coffre, coffre-fort de mots de passe). Avec Play App Signing (étape 6), une clé d'envoi perdue peut être remplacée
> en écrivant au support Google (quelques jours de blocage des mises à jour) ; sans sauvegarde ni Play App Signing,
> plus aucune mise à jour n'est possible. Ne JAMAIS utiliser la clé « debug » d'Android Studio : Google la refuse.

## 4. Déposer les quatre secrets de la clé dans GitHub

Convertir le fichier en texte (base64), dans **PowerShell** :

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("D:\Cles\prestige-envoi.jks")) | Set-Clipboard
```

(le texte est copié dans le presse-papiers ; il ne s'affiche pas.)

Dépôt GitHub › **Settings** › **Secrets and variables** › **Actions** › onglet **Secrets** › **New repository
secret**, quatre fois :

| Secret | Contenu |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | le texte copié par la commande ci-dessus (coller) |
| `ANDROID_KEYSTORE_PASSWORD` | mot de passe du fichier `.jks` |
| `ANDROID_KEY_ALIAS` | alias (ex. `prestige`) |
| `ANDROID_KEY_PASSWORD` | mot de passe de la clé |

À refaire, **identique**, dans chacun des dépôts des quatre applications.

Dès ces quatre secrets déposés, chaque envoi de code sur `claude/presences` produit l'App Bundle signé : **Actions**
› **Google Play (test interne)** › le dernier run › artefact **`prestige-pharmacien-aab`** (fichier zip contenant
`prestige-pharmacien-<version>.aab`). Un secret mal formé est signalé clairement (base64 invalide, mot de passe faux,
alias absent, clé debug), sans jamais être affiché.

## 5. Play App Signing

Activé d'office pour une nouvelle application : Google garde la **clé de signature** de l'application et vous
signez les envois avec votre **clé d'envoi**. Au premier envoi (étape 6), accepter « Laisser Google gérer et protéger
votre clé de signature d'application ».

## 6. Premier envoi : À LA MAIN (exigence de Google)

Google exige que le **premier** App Bundle d'une nouvelle application soit envoyé à la main dans la Play Console
(c'est lui qui fixe le nom du paquet) :

1. GitHub › **Actions** › **Google Play (test interne)** › dernier run réussi › télécharger l'artefact
   **`prestige-pharmacien-aab`**, le décompresser ;
2. Play Console › Prestige Pharmacien › **Tester et publier** › **Tests** › **Test interne** › **Créer une version** ;
3. accepter Play App Signing (étape 5) ;
4. **Importer** le fichier `.aab` ; nom de la version : par ex. « 3.13.0 » ; notes de version en français ;
5. **Suivant** › **Enregistrer et publier**.

Tant que la configuration de l'application n'est pas terminée (tableau de bord de l'application : « Configurer votre
application »), Google peut garder la version en **brouillon** ; le terminer au fur et à mesure.

## 7. Les testeurs

Play Console › **Test interne** › onglet **Testeurs** :
- **Créer une liste d'adresses e-mail** (ex. « Officine ») : jusqu'à 100 comptes Google (Gmail) ;
- cocher la liste, **Enregistrer** ;
- **Copier le lien** d'adhésion et l'envoyer aux testeurs : chacun l'ouvre **sur son téléphone**, connecté au compte
  Google de la liste, **accepte**, puis installe depuis le Play Store.

> Un téléphone qui a déjà Prestige Pharmacien installé **hors Play** (APK, terminaux Sunmi construits sur le PC) ne
> peut pas recevoir la version Play par-dessus (signature différente) : désinstaller d'abord, puis ressaisir
> l'adresse du serveur et les réglages. Les APK construits sur le PC (clé debug locale) restent utilisables comme
> avant sur les appareils qui ne passent pas par Play.

## 8. Envois automatiques : compte de service Google Cloud

Pour que GitHub envoie lui-même les versions suivantes en Test interne :

1. <https://console.cloud.google.com> › créer un **projet** (ex. « Prestige Play ») ;
2. **API et services** › **Bibliothèque** › **Google Play Android Developer API** › **Activer** ;
3. **IAM et administration** › **Comptes de service** › **Créer un compte de service** (ex. « github-play ») ›
   **Créer et continuer** › (aucun rôle Cloud) › **OK** ;
4. ouvrir le compte de service › **Clés** › **Ajouter une clé** › **JSON** : un fichier `.json` est téléchargé (le
   garder en lieu sûr ; il ne se retélécharge pas) ;
5. Play Console › **Utilisateurs et autorisations** › **Inviter de nouveaux utilisateurs** › l'adresse e-mail du
   compte de service (`…@….iam.gserviceaccount.com`) › onglet **Autorisations des applications** › ajouter **les
   applications Prestige** › cocher **Publier en test** (« Release to testing tracks ») et **Voir les informations de
   l'application** › **Inviter** ;
6. GitHub › chaque dépôt › **Settings** › **Secrets and variables** › **Actions** › **New repository secret** :
   **`PLAY_SERVICE_ACCOUNT_JSON`** = **tout** le contenu du fichier `.json` (ouvert avec le Bloc-notes).

Un même compte de service peut servir aux quatre applications (autorisations données à chacune).

## 9. Lancer un envoi en Test interne

Demander « envoie sur Google Play » : l'équipe écrit la version en cours (ex. `3.13.0+50`) en première ligne du
fichier **`android/DEMANDE_PLAY`** de la branche `claude/presences`. Le workflow **Google Play (test interne)** :
vérifie que la demande correspond à `pubspec.yaml`, construit l'App Bundle signé, l'envoie sur la piste **internal**
de `com.dici.prestige_app` avec des notes en français, statut **« completed »** (disponible pour les testeurs après
traitement par Google, quelques minutes). Si l'application est encore en brouillon dans la Play Console, il renvoie
en **« draft »** et l'explique : publier alors la version à la main (Test interne › Modifier la version › Publier).

Chaque envoi exige un **numéro de version plus grand** (le `+N` de `pubspec.yaml`) : une version déjà envoyée est
refusée par Google.

## 10. Au-delà du test interne

Les pistes **fermée**, **ouverte** et la **production** demandent en plus, dans la Play Console : politique de
confidentialité (adresse web), **sécurité des données** (données collectées : identifiants de connexion au serveur
de l'officine, rien n'est envoyé à des tiers), **classification du contenu** (questionnaire), public cible, fiche du
Store (description, captures, icône 512 × 512, image 1024 × 500) et examen par Google. Inutile pour le test interne.

## Pour les développeurs

- Signature : `android/app/build.gradle.kts` lit `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`,
  `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` (environnement) ou `storeFile`, `storePassword`, `keyAlias`,
  `keyPassword` (`android/key.properties`, ignoré par git) ; sinon **repli sur la clé debug** avec un avertissement
  (builds locaux et APK de la CI inchangés).
- API cible : **36 pour le seul build Google Play** (`flutter build appbundle --android-project-arg=pharmacienTargetSdk=36`,
  exigé par Google depuis le 31/08/2026) ; les APK (PC du pharmacien, terminaux Sunmi, `ci.yml`) restent en **35**
  (valeur de Flutter 3.32.8) : aucun changement de comportement pour eux (retour prédictif d'Android 16 non activé) et
  aucune plateforme « Android 16 » à installer sur le poste. AGP 8.7.3 avec compileSdk 36 :
  `android.suppressUnsupportedCompileSdk=36` (`android/gradle.properties`). `ci.yml` contrôle l'APK à 35 et construit
  un App Bundle de contrôle à 36, sans clé.
- Workflow : `.github/workflows/play.yml` (AAB en artefact si la clé existe ; envoi seulement si `android/DEMANDE_PLAY`
  change et si `PLAY_SERVICE_ACCOUNT_JSON` existe ; action `r0adkll/upload-google-play` épinglée par SHA, v1.1.5).
  L'APK reste construit par `ci.yml`.
- Réseau : `network_security_config.xml` autorise le HTTP (serveur local par adresse IP, voir
  `docs/HTTPS_ET_TRAFIC_EN_CLAIR.md`) ; accepté par Google Play. Permissions : Internet ; stockage limité à Android 12
  (`maxSdkVersion="32"`, export CSV dans Téléchargements).
