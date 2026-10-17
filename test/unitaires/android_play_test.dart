// Google Play (3.13.0) — projet Android et envoi, sans SDK Android :
//  - signature : clé d'envoi lue dans les variables d'environnement puis android/key.properties (jamais commité) ;
//    repli sur la clé DEBUG avec un avertissement quand elle manque (builds locaux du pharmacien et CI sans secrets
//    inchangés) ;
//  - exigences Play : targetSdk / compileSdk 36, permissions de stockage limitées à Android 12 ;
//  - workflow play.yml : conventions communes aux 4 applications (noms des secrets, android/DEMANDE_PLAY), aucun
//    secret affiché, action d'envoi épinglée par SHA, piste « internal », repli « draft », nettoyage ;
//  - l'APK de ci.yml reste produit comme avant.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String lire(String chemin) => File(chemin).readAsStringSync();

void main() {
  final gradle = lire('android/app/build.gradle.kts');

  group('Signature', () {
    test('clé d\'envoi : variables d\'environnement, puis key.properties ; quatre réglages', () {
      for (final (env, prop) in [
        ('ANDROID_KEYSTORE_PATH', 'storeFile'),
        ('ANDROID_KEYSTORE_PASSWORD', 'storePassword'),
        ('ANDROID_KEY_ALIAS', 'keyAlias'),
        ('ANDROID_KEY_PASSWORD', 'keyPassword'),
      ]) {
        expect(gradle, contains('reglageCle("$env", "$prop")'));
      }
      expect(gradle, contains('rootProject.file("key.properties")'));
      expect(gradle, contains('System.getenv(variable)'), reason: 'la CI passe avant le fichier local');
    });

    test('repli sur la clé DEBUG si la clé manque ou si le fichier n\'existe pas, avec avertissement', () {
      expect(gradle, contains('fichierCle != null && fichierCle.exists()'));
      expect(gradle, contains('if (cleEnvoiComplete) {\n                signingConfigs.getByName("release")'));
      expect(gradle, contains('signingConfigs.getByName("debug")'));
      expect(gradle, contains('logger.warn('));
      expect(gradle, isNot(contains(RegExp(r'storePassword\s*=\s*"'))), reason: 'aucun mot de passe en clair');
    });

    test('key.properties et fichiers de clé jamais commités', () {
      final ignore = lire('android/.gitignore');
      expect(ignore, contains('key.properties'));
      expect(ignore, contains('**/*.jks'));
      expect(ignore, contains('**/*.keystore'));
      expect(File('android/key.properties').existsSync(), isFalse);
    });
  });

  group('Exigences Google Play', () {
    test('API cible 36 pour le SEUL build Google Play (propriété pharmacienTargetSdk) ; APK : 35 comme avant', () {
      expect(gradle, contains('findProperty("pharmacienTargetSdk")'));
      expect(gradle, contains('targetSdk = apiCiblePlay ?: flutter.targetSdkVersion'));
      expect(gradle, contains('compileSdk = apiCiblePlay ?: 35'));
      expect(gradle, isNot(contains('targetSdk = 36')));
      final play = lire('.github/workflows/play.yml');
      final ci = lire('.github/workflows/ci.yml');
      expect(play, contains('flutter build appbundle --release --android-project-arg=pharmacienTargetSdk=36'));
      expect(ci, contains('flutter build appbundle --release --android-project-arg=pharmacienTargetSdk=36'), reason: 'AAB de contrôle sans clé');
      expect(ci, contains('android:targetSdkVersion="35"'), reason: 'l\'APK est contrôlé à 35');
      expect(RegExp(r'run: flutter build apk --release\n').hasMatch(ci), isTrue, reason: 'APK construit sans la propriété');
    });

    test('identifiant com.dici.prestige_app, version tirée de pubspec', () {
      expect(gradle, contains('applicationId = "com.dici.prestige_app"'));
      expect(gradle, contains('versionCode = flutter.versionCode'));
    });

    test('permissions : Internet ; stockage seulement jusqu\'à Android 12 ; nom affiché', () {
      final manifeste = lire('android/app/src/main/AndroidManifest.xml');
      final permissions = RegExp(r'<uses-permission[^>]*android:name="([^"]+)"([^>]*)>').allMatches(manifeste).toList();
      expect(permissions.map((m) => m.group(1)).toSet(),
          {'android.permission.INTERNET', 'android.permission.WRITE_EXTERNAL_STORAGE', 'android.permission.READ_EXTERNAL_STORAGE'});
      for (final m in permissions.where((m) => m.group(1)!.contains('EXTERNAL_STORAGE'))) {
        expect(m.group(2), contains('android:maxSdkVersion="32"'));
      }
      expect(manifeste, contains('android:label="Prestige Pharmacien"'));
      expect(manifeste, contains('android:networkSecurityConfig="@xml/network_security_config"'), reason: 'HTTP vers le serveur local');
    });
  });

  group('Workflow Google Play', () {
    final play = lire('.github/workflows/play.yml');

    test('conventions communes aux 4 applications : secrets et fichier déclencheur', () {
      for (final s in ['ANDROID_KEYSTORE_BASE64', 'ANDROID_KEYSTORE_PASSWORD', 'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD', 'PLAY_SERVICE_ACCOUNT_JSON']) {
        expect(play, contains('secrets.$s'));
      }
      expect(play, contains('android/DEMANDE_PLAY'));
      expect(play, contains('PACKAGE_NAME: com.dici.prestige_app'));
      expect(File('android/DEMANDE_PLAY').existsSync(), isFalse, reason: 'écrit seulement sur demande du pharmacien');
    });

    test('envoi : action épinglée par SHA, piste internal, completed puis draft, artefact AAB, nettoyage', () {
      expect(RegExp(r'uses: r0adkll/upload-google-play@[0-9a-f]{40}').allMatches(play), hasLength(2));
      expect(play, contains('tracks: internal'));
      expect(play, contains('status: completed'));
      expect(play, contains('status: draft'));
      expect(play, contains('name: prestige-pharmacien-aab'));
      expect(play, contains('flutter build appbundle --release --android-project-arg=pharmacienTargetSdk=36'));
      expect(play, contains('CN=Android Debug'), reason: 'un bundle signé en debug est refusé avant l\'envoi');
      expect(play, contains('rm -rf "\$RUNNER_TEMP/cle_android"'));
      expect(play, contains('umask 077'));
      expect(play, isNot(contains(RegExp(r'echo "\$(KS|KSP|KP|SA|ANDROID_KEYSTORE_PASSWORD|ANDROID_KEY_PASSWORD)"'))), reason: 'aucun secret affiché');
    });

    test('l\'APK de ci.yml reste produit comme avant', () {
      final ci = lire('.github/workflows/ci.yml');
      expect(ci, contains('run: flutter build apk --release'));
      expect(ci, contains('name: prestige-pharmacien-apk'));
    });
  });

  // Android 16 (API 36, build Google Play) active le RETOUR PRÉDICTIF par défaut. Flutter le gère avec PopScope ;
  // WillPopScope (ancien) ne fonctionne pas avec lui. Les écrans qui interceptent le retour sont listés ici : tout
  // nouvel écran doit être revu (docs/NOTE_VERSION_3.13.1.md).
  group('Retour prédictif (Android 16)', () {
    test('aucun WillPopScope ; seuls deux écrans interceptent le retour, avec PopScope', () {
      final interceptions = <String>{};
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        final t = f.readAsStringSync();
        expect(t, isNot(contains('WillPopScope(')), reason: f.path);
        if (t.contains('PopScope(')) interceptions.add(f.path.replaceAll('\\', '/'));
      }
      expect(interceptions, {
        'lib/nouvelle_interface/accueil_nouveau.dart', // autre onglet → retour à Accueil
        'lib/nouvelle_interface/modules/annulation_ventes_nouveau.dart', // annulation en cours : retour refusé
      });
    });
  });
}
