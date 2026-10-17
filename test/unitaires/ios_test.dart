// iOS (3.12.0) — couche de capacités et projet iOS, sans Mac :
//  - capacités : Android inchangé ; iPhone / iPad : « Taille de l'écran » masqué et jamais de réduction automatique,
//    export CSV dans l'app Fichiers, partage ancré (iPad) ;
//  - ios/ : Info.plist en français (nom affiché, réseau local, ATS limité au réseau local, AUCUN
//    NSAllowsArbitraryLoads, fichiers visibles, chiffrement exempté, orientations iPhone et iPad), identifiant
//    (bundle ID) en paramètre xcconfig sans « _ », iOS 13 au minimum partout, Podfile, icônes opaques aux bonnes
//    tailles, écran de lancement aux couleurs de l'écran de chargement ;
//  - Android : nouvel applicationId (com.dici.prestige_app), namespace et MainActivity inchangés.
// Lancé aussi sur macOS par le job « ios » de la CI.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/plateforme/capacites.dart';
import 'package:prestige_app/presences/export_fichier.dart';
import 'package:prestige_app/ui/taille_ecran.dart';

String lire(String chemin) => File(chemin).readAsStringSync();

/// Valeur d'une clé simple de l'Info.plist (chaîne, true / false).
String? cle(String plist, String nom) {
  final m = RegExp('<key>$nom</key>\\s*<(string|true|false)\\s*/?>([^<]*)').firstMatch(plist);
  if (m == null) return null;
  return m.group(1) == 'string' ? m.group(2) : m.group(1);
}

void main() {
  tearDown(() {
    Capacites.forcees = null;
    debugDefaultTargetPlatformOverride = null;
  });

  group('Capacités', () {
    test('Android (et tests par défaut) : tout comme avant', () {
      final c = Capacites.actuelles;
      expect(c.systeme, SystemeAppareil.android);
      expect((c.reglageTailleEcran, c.emplacementExport, c.partageAncre), (true, 'Téléchargements', false));
    });

    test('iPhone / iPad : réglage de taille masqué, export dans Fichiers, partage ancré', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final c = Capacites.actuelles;
      expect(c.systeme, SystemeAppareil.ios);
      expect(c.reglageTailleEcran, isFalse);
      expect(c.emplacementExport, contains('Fichiers'));
      expect(c.partageAncre, isTrue);
    });

    test('taille de l\'écran : Android réduit un petit écran (Sunmi) ; iOS jamais (iPhone SE 375×667)', () {
      const se = Size(375, 667);
      expect(TailleEcranReglage.effective(TailleEcran.automatique, se), TailleEcran.compact, reason: 'Android : inchangé');
      Capacites.forcees = const Capacites(SystemeAppareil.ios);
      expect(TailleEcranReglage.effective(TailleEcran.automatique, se), TailleEcran.automatique);
      expect(TailleEcranReglage.effective(TailleEcran.tresCompact, se), TailleEcran.automatique, reason: 'ancien choix ignoré sur iOS');
    });

    testWidgets('partage : ancré au centre de l\'écran qui exporte (iPad)', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox.expand();
      })));
      final r = ExportFichier.ancrageDe(ctx)!;
      expect(r.size, const Size(1, 1));
      expect(r.center, const Offset(400, 300));
    });
  });

  group('Projet iOS', () {
    final plist = lire('ios/Runner/Info.plist');

    test('Info.plist : nom, français, réseau local, ATS sans exception générale, fichiers, chiffrement exempté', () {
      expect(cle(plist, 'CFBundleDisplayName'), 'Prestige Pharmacien');
      expect(cle(plist, 'CFBundleDevelopmentRegion'), 'fr');
      expect(cle(plist, 'CFBundleShortVersionString'), r'$(FLUTTER_BUILD_NAME)', reason: 'version tirée de pubspec.yaml');
      expect(cle(plist, 'CFBundleVersion'), r'$(FLUTTER_BUILD_NUMBER)');
      expect(cle(plist, 'CFBundleIdentifier'), r'$(PRODUCT_BUNDLE_IDENTIFIER)');
      expect(plist, contains('<key>NSAllowsLocalNetworking</key>\n\t\t<true/>'));
      expect(plist, isNot(contains('<key>NSAllowsArbitraryLoads</key>')));
      expect(cle(plist, 'NSLocalNetworkUsageDescription'), allOf(contains('serveur Prestige'), contains('réseau local')));
      expect(cle(plist, 'UIFileSharingEnabled'), 'true');
      expect(cle(plist, 'LSSupportsOpeningDocumentsInPlace'), 'true');
      expect(cle(plist, 'ITSAppUsesNonExemptEncryption'), 'false');
      // Aucune autorisation (caméra, photos, micro, localisation) : l'application n'en utilise pas.
      expect(RegExp(r'NS(Camera|PhotoLibrary|Microphone|Location)\w*UsageDescription').hasMatch(plist), isFalse);
      final ipad = RegExp(r'UISupportedInterfaceOrientations~ipad</key>\s*<array>(.*?)</array>', dotAll: true).firstMatch(plist)!.group(1)!;
      expect(RegExp('UIInterfaceOrientation').allMatches(ipad), hasLength(4), reason: 'iPad : les 4 orientations (multitâche)');
    });

    test('identifiant en paramètre (xcconfig), sans « _ » ; plus aucun com.example ; iOS 13 au minimum', () {
      final xc = lire('ios/Flutter/Prestige.xcconfig');
      final bundle = RegExp(r'^PRESTIGE_BUNDLE_ID = (\S+)$', multiLine: true).firstMatch(xc)!.group(1)!;
      expect(bundle, 'com.dici.prestige-app');
      expect(RegExp(r'^[A-Za-z0-9.-]+$').hasMatch(bundle), isTrue, reason: 'bundle ID iOS : lettres, chiffres, « . » et « - »');
      for (final f in ['ios/Flutter/Debug.xcconfig', 'ios/Flutter/Release.xcconfig']) {
        expect(lire(f), contains('#include "Prestige.xcconfig"'));
        expect(lire(f), contains('#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.'));
      }
      final projet = lire('ios/Runner.xcodeproj/project.pbxproj');
      expect(projet, isNot(contains('com.example')));
      expect(RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = "\$\(PRESTIGE_BUNDLE_ID\)";').allMatches(projet), hasLength(3), reason: 'Debug, Release, Profile');
      final cibles = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);').allMatches(projet).map((m) => m.group(1)).toSet();
      expect(cibles, {'13.0'});
      expect(lire('ios/Podfile'), contains("platform :ios, '13.0'"));
      expect(lire('ios/Flutter/AppFrameworkInfo.plist'), contains('<string>13.0</string>'));
      expect(projet, contains('TARGETED_DEVICE_FAMILY = "1,2";'), reason: 'iPhone ET iPad');
    });

    test('icônes : toutes celles du catalogue, à la bonne taille, OPAQUES (exigence de l\'App Store)', () {
      const dossier = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      final c = jsonDecode(lire('$dossier/Contents.json')) as Map<String, dynamic>;
      final images = (c['images'] as List).cast<Map<String, dynamic>>().where((i) => i['filename'] != null).toList();
      expect(images, isNotEmpty);
      for (final i in images) {
        final o = File('$dossier/${i['filename']}').readAsBytesSync();
        // En-tête PNG : largeur (octets 16–19), type de couleur (octet 25) : 2 = RVB sans transparence.
        final largeur = ByteData.sublistView(o, 16, 20).getUint32(0);
        final pt = double.parse((i['size'] as String).split('x').first);
        final echelle = int.parse((i['scale'] as String).replaceAll('x', ''));
        expect(largeur, (pt * echelle).round(), reason: '${i['filename']}');
        expect(o[25], 2, reason: '${i['filename']} : sans couche alpha');
      }
      final lancement = lire('ios/Runner/Base.lproj/LaunchScreen.storyboard');
      expect(lancement, contains('red="0.92941176470588238" green="0.95294117647058818" blue="0.95686274509803926"'),
          reason: 'fond de l\'écran de chargement « Prestige Pharmacien »');
    });

    test('Podfile : aucune autorisation iOS activée pour permission_handler (stockage : Android seulement)', () {
      expect(lire('ios/Podfile'), isNot(contains('PERMISSION_')));
    });
  });

  group('Android', () {
    test('3.12.0 : nouvel applicationId com.dici.prestige_app ; namespace et MainActivity inchangés', () {
      final gradle = lire('android/app/build.gradle.kts');
      expect(gradle, contains('applicationId = "com.dici.prestige_app"'));
      expect(gradle, contains('namespace = "com.example.prestige_app"'));
      expect(lire('android/app/src/main/kotlin/com/example/prestige_app/MainActivity.kt'), contains('package com.example.prestige_app'));
    });
  });
}
