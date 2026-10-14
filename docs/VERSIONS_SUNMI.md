# Versions publiées sur le magasin Sunmi — Prestige Pharmacien

Ce fichier est **lu par le test** `test/non_regression/version_sunmi_test.dart` : la ligne `minimum_sunmi:`
ci-dessous est la dernière version publiée sur le magasin Sunmi. Garder son format exact
(`minimum_sunmi: X.Y.Z+N`, ou `minimum_sunmi: aucune` tant que rien n'est publié).

**Prestige Pharmacien : pas encore publié sur Sunmi.**

minimum_sunmi: aucune

## Dernières versions publiées sur Sunmi

| Version | versionCode | Date de publication | Remarque |
|---|---|---|---|
| — | — | — | aucune publication pour l'instant |

Version en préparation (pas encore publiée) : **3.7.0+36** (`pubspec.yaml`) : réglage « Taille de l'écran » (Automatique /
Compact / Très compact, `docs/TAILLE_ECRAN.md`, `docs/NOTE_VERSION_3.7.0.md`). Précédentes livraisons :
3.6.1+35 (retours du pharmacien sur le lot 4, `docs/NOTE_VERSION_3.6.1.md`),
3.6.0+34 (lot 4 de la refonte, « le reste », `docs/NOTE_VERSION_3.6.0.md`),
3.5.0+33 (lot 3, analyses, `docs/NOTE_VERSION_3.5.0.md`), Précédentes livraisons : 3.4.0+32 (vague 3, `docs/NOTE_VERSION_3.4.0.md`), 3.3.0+31 (lot 2 de la refonte, `docs/NOTE_VERSION_3.3.0.md`),
3.2.1+30 (Mobile Money du Détail CA, `docs/NOTE_VERSION_3.2.1.md`), 3.2.0+29 (vague 2, `docs/NOTE_VERSION_3.2.0.md`),
3.1.0+28 (lot 1 et vague 1, `docs/NOTE_VERSION_3.1.0.md`).

## Les 3 règles (permanentes)

1. **Une seule source : `pubspec.yaml`** (`version: X.Y.Z+N`). Gradle la reprend
   (`versionCode = flutter.versionCode`, `versionName = flutter.versionName` dans `android/app/build.gradle.kts`),
   **aucun numéro en dur** (ni dans Gradle, ni dans le code : l'application lit sa version à l'exécution avec
   `package_info_plus`, voir `lib/version_app.dart`).
2. **X.Y.Z jamais inférieur** (comparaison nombre par nombre : 3.10.0 > 3.9.9) à la dernière version publiée sur
   Sunmi ; **+N strictement supérieur** au versionCode publié (sinon le magasin refuse la mise à jour). Tant que
   `minimum_sunmi: aucune`, seules la règle 1 et le format `X.Y.Z+N` sont contrôlés.
3. **Chaque livraison augmente +N d'au moins 1** (même pour un APK de test remis à une pharmacie).

## Marche à suivre à chaque publication sur Sunmi

1. Avant de construire : augmenter `version:` dans `pubspec.yaml` (au moins +1 sur N ; X.Y.Z selon les nouveautés).
2. Construire l'APK (`flutter build apk --release`, ou télécharger l'artefact de la CI) et vérifier la version
   affichée en bas de l'écran de connexion et dans les Réglages (« Version X.Y.Z+N »), dans les deux interfaces.
3. Après la publication sur le magasin Sunmi : **mettre à jour ce fichier** — ajouter la ligne en haut du tableau
   (version, versionCode, date), remplacer `minimum_sunmi: aucune` par la version publiée (`minimum_sunmi: X.Y.Z+N`)
   et retirer la phrase « pas encore publié ».
4. Lancer `flutter test test/non_regression/version_sunmi_test.dart` : il échoue si `pubspec.yaml` n'est pas
   au-dessus de `minimum_sunmi`, si N n'est pas strictement supérieur, si le format `X.Y.Z+N` manque ou si Gradle
   contient un `versionCode` / `versionName` en dur. La livraison suivante devra donc d'abord augmenter N.
