// Étape 0 (socle) : une seule source pour le numéro de version, interrupteur de version d'interface.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/interface_version.dart';
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

    test('applicationId inchangé (mises à jour des installations existantes)', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('applicationId = "com.example.prestige_app"'));
    });
  });

  group('InterfaceVersion', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('par défaut : interface d\'origine', () async {
      await InterfaceVersion.load();
      expect(InterfaceVersion.useNew.value, isFalse);
      expect(InterfaceVersion.home(), isA<HomeScreen>());
      expect(InterfaceVersion.settings(), isA<SettingsScreen>());
    });

    test('le choix est mémorisé (même clé que prestige_vente_app)', () async {
      await InterfaceVersion.setNew(true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('interface_nouvelle_version_v1'), isTrue);
      InterfaceVersion.useNew.value = false;
      await InterfaceVersion.load();
      expect(InterfaceVersion.useNew.value, isTrue);
      // Étape 0 : les deux positions ouvrent encore les écrans d'origine.
      expect(InterfaceVersion.home(), isA<HomeScreen>());
      await InterfaceVersion.setNew(false);
    });
  });
}
