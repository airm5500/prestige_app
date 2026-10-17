// Étape 0 (socle) : une seule source pour le numéro de version, interrupteur de version d'interface.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/interface_version.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/screens/home_screen.dart';
import 'package:prestige_app/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Numéro de version', () {
    test('pubspec.yaml porte nom ET numéro de build', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final m = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', multiLine: true).firstMatch(pubspec);
      expect(m, isNotNull, reason: 'version: X.Y.Z+N attendu dans pubspec.yaml');
      expect(int.parse(m!.group(2)!), greaterThan(1), reason: 'versionCode > 1 (installations existantes : 1)');
    });

    test('Android lit la version dans pubspec (aucune version forcée)', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('versionName = flutter.versionName'));
      expect(gradle, contains('versionCode = flutter.versionCode'));
      expect(RegExp(r'versionName\s*=\s*"').hasMatch(gradle), isFalse);
    });

    test('applicationId : com.dici.prestige_app depuis la 3.12.0 (décision du pharmacien : nouvelle application)', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('applicationId = "com.dici.prestige_app"'));
      expect(gradle, isNot(contains('applicationId = "com.example')));
    });
  });

  group('InterfaceVersion', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    // Étape 3 : la nouvelle interface est livrée et devient celle par défaut (demande du pharmacien) ;
    // l'interface d'origine reste disponible et intacte.
    test('par défaut : nouvelle interface (accueil refondu), configuration commune', () async {
      await InterfaceVersion.load();
      expect(InterfaceVersion.parDefaut, isTrue);
      expect(InterfaceVersion.useNew.value, isTrue);
      expect(InterfaceVersion.home(), isA<AccueilNouveau>());
      expect(InterfaceVersion.settings(), isA<SettingsScreen>());
    });

    test('le choix est mémorisé (même clé que prestige_vente_app) ; retour à l\'interface d\'origine', () async {
      await InterfaceVersion.setNew(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('interface_nouvelle_version_v1'), isFalse);
      InterfaceVersion.useNew.value = true;
      await InterfaceVersion.load();
      expect(InterfaceVersion.useNew.value, isFalse);
      expect(InterfaceVersion.home(), isA<HomeScreen>());

      await InterfaceVersion.setNew(true);
      expect(prefs.getBool('interface_nouvelle_version_v1'), isTrue);
      InterfaceVersion.useNew.value = false;
      await InterfaceVersion.load();
      expect(InterfaceVersion.useNew.value, isTrue);
      expect(InterfaceVersion.home(), isA<AccueilNouveau>());
    });
  });
}
