// Non-régression : numéros de version alignés sur le magasin Sunmi (docs/VERSIONS_SUNMI.md).
//  - une seule source, pubspec.yaml (`version: X.Y.Z+N`) : aucun versionCode / versionName en dur dans Gradle ;
//  - dès qu'une version est publiée (`minimum_sunmi: X.Y.Z+N`) : X.Y.Z jamais inférieur, +N strictement supérieur.
//    Tant que `minimum_sunmi: aucune` (Prestige Pharmacien jamais publié sur Sunmi), ces deux contrôles sont sautés.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Version `X.Y.Z+N` lue dans un texte (null si le format est absent).
({List<int> xyz, int n})? lireVersion(String texte, String cle) {
  final m = RegExp('^$cle:\\s*(\\d+)\\.(\\d+)\\.(\\d+)\\+(\\d+)\\s*\$', multiLine: true).firstMatch(texte);
  if (m == null) return null;
  return (xyz: [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)], n: int.parse(m.group(4)!));
}

/// « minimum_sunmi: aucune » : rien n'a encore été publié.
bool aucunePublication(String doc) => RegExp(r'^minimum_sunmi:\s*aucune\s*$', multiLine: true).hasMatch(doc);

/// Comparaison sémantique X.Y.Z (nombre par nombre : 3.10.0 > 3.9.9).
int comparer(List<int> a, List<int> b) {
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return 0;
}

/// Gradle sans commentaires (`// …`, `/* … */`).
String sansCommentaires(String s) =>
    s.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '').replaceAll(RegExp(r'//.*'), '');

/// versionCode / versionName en dur (nombre ou chaîne), Kotlin (`= 8`, `= "3.4.1"`) ou Groovy (`8`, `'3.4.1'`).
final _enDur = RegExp(r'''\bversion(Code|Name)\s*(=\s*)?(\(?\s*)?["'0-9]''');

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final doc = File('docs/VERSIONS_SUNMI.md').readAsStringSync();
  final gradles = Directory('android/app')
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'build\.gradle(\.kts)?$').hasMatch(f.path))
      .toList();

  group('Versions Sunmi (docs/VERSIONS_SUNMI.md)', () {
    test('pubspec.yaml a le format « version: X.Y.Z+N »', () {
      expect(lireVersion(pubspec, 'version'), isNotNull, reason: 'pubspec.yaml doit contenir « version: X.Y.Z+N »');
    });

    test('docs/VERSIONS_SUNMI.md donne « minimum_sunmi: X.Y.Z+N » ou « minimum_sunmi: aucune »', () {
      expect(lireVersion(doc, 'minimum_sunmi') != null || aucunePublication(doc), isTrue);
    });

    final publie = lireVersion(doc, 'minimum_sunmi');
    final saut = publie == null ? 'Prestige Pharmacien pas encore publié sur Sunmi (minimum_sunmi: aucune)' : false;

    test('X.Y.Z de pubspec.yaml ≥ version publiée sur Sunmi', () {
      final v = lireVersion(pubspec, 'version')!, s = publie!;
      expect(comparer(v.xyz, s.xyz), greaterThanOrEqualTo(0),
          reason: 'pubspec ${v.xyz.join('.')} < Sunmi ${s.xyz.join('.')} : le magasin refuserait la mise à jour');
    }, skip: saut);

    test('+N de pubspec.yaml > versionCode publié sur Sunmi', () {
      final v = lireVersion(pubspec, 'version')!, s = publie!;
      expect(v.n, greaterThan(s.n), reason: 'versionCode ${v.n} ≤ ${s.n} (Sunmi) : augmenter +N dans pubspec.yaml');
    }, skip: saut);

    test('Gradle reprend pubspec.yaml : aucun versionCode / versionName en dur', () {
      expect(gradles, isNotEmpty, reason: 'android/app/build.gradle(.kts) introuvable');
      for (final f in gradles) {
        final g = sansCommentaires(f.readAsStringSync());
        expect(_enDur.allMatches(g).map((m) => m.group(0)).toList(), isEmpty, reason: '${f.path} : numéro en dur');
        expect(g, matches(RegExp(r'versionCode\s*=?\s*flutter\.versionCode')), reason: f.path);
        expect(g, matches(RegExp(r'versionName\s*=?\s*flutter\.versionName')), reason: f.path);
      }
    });

    test('auto-contrôle des règles de lecture', () {
      expect(comparer([3, 10, 0], [3, 9, 9]), 1);
      expect(comparer([3, 1, 0], [3, 1, 0]), 0);
      expect(comparer([3, 0, 9], [3, 1, 0]), -1);
      expect(lireVersion('version: 1.2.0\n', 'version'), isNull, reason: 'sans +N');
      final lu = lireVersion('version: 3.1.0+28\n', 'version')!;
      expect(lu.xyz, [3, 1, 0]);
      expect(lu.n, 28);
      expect(aucunePublication('minimum_sunmi: aucune\n'), isTrue);
      expect(aucunePublication('minimum_sunmi: 3.1.0+28\n'), isFalse);
      expect(lireVersion('minimum_sunmi: aucune\n', 'minimum_sunmi'), isNull);
      for (final dur in ['versionCode = 8', 'versionName = "3.4.1"', 'versionCode 8', "versionName '3.4.1'", 'versionCode=8']) {
        expect(_enDur.hasMatch(sansCommentaires(dur)), isTrue, reason: dur);
      }
      for (final ok in ['versionCode = flutter.versionCode', 'versionName = flutter.versionName', '// versionCode = 8']) {
        expect(_enDur.hasMatch(sansCommentaires(ok)), isFalse, reason: ok);
      }
    });
  });
}
