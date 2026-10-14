// Version « X.Y.Z+N » affichée, discrète, en bas de l'écran de connexion et dans les Réglages, dans les DEUX
// interfaces (d'origine et nouvelle), LUE À L'EXÉCUTION dans le paquet installé (package_info_plus, simulé ici
// depuis pubspec.yaml) — aucune constante de version dupliquée dans le code ni dans les tests.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:prestige_app/interface_version.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/screens/settings_screen.dart';
import 'package:prestige_app/version_app.dart';

import 'outils/contexte_api.dart';
import 'support/application.dart';
import 'support/donnees_fictives.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/nouvelle_interface.dart';

final serveur = FauxServeurPrestige();

/// `X.Y.Z+N` de pubspec.yaml.
String versionPubspec() =>
    RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;

/// Simule le paquet installé construit depuis pubspec.yaml (versionName X.Y.Z, versionCode N).
String simulerVersionInstallee() {
  final v = versionPubspec().split('+');
  PackageInfo.setMockInitialValues(
      appName: 'Prestige Pharmacien', packageName: 'prestige_app', version: v.first, buildNumber: v[1], buildSignature: '');
  VersionApp.oublier();
  return versionPubspec();
}

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

void main() {
  late String version;

  setUp(() async {
    version = simulerVersionInstallee();
    await serveur.demarrer();
    utiliserReseauReel();
  });

  tearDown(() async {
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..parDefaut = ((_) => ReponseFausse.json(DonneesFictives.listeVide()));
    VersionApp.oublier();
  });

  Finder texteVersion([Finder? dans]) =>
      dans == null ? find.text('Version $version') : find.descendant(of: dans, matching: find.text('Version $version'));

  testWidgets('VersionAffichee : « Version X.Y.Z+N » lue dans le paquet installé', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: VersionAffichee())));
    await tester.pump();
    expect(version, matches(RegExp(r'^\d+\.\d+\.\d+\+\d+$')));
    expect(texteVersion(), findsOneWidget);
    expect(VersionApp.complete, version);
  });

  testWidgets('la version affichée suit le paquet installé (aucune constante dans le code)', (tester) async {
    PackageInfo.setMockInitialValues(appName: 'x', packageName: 'x', version: '9.8.7', buildNumber: '65', buildSignature: '');
    VersionApp.oublier();
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: VersionAffichee())));
    await tester.pump();
    expect(find.text('Version 9.8.7+65'), findsOneWidget);
  });

  for (final nouvelle in [false, true]) {
    final nom = nouvelle ? 'nouvelle interface' : 'interface d\'origine';

    testWidgets('connexion ($nom) : version discrète en bas du formulaire', (tester) async {
      telephone(tester);
      preparerTelephone(serveur, nouvelle: nouvelle);
      await lancerApplication(tester);
      await attendreWidget(tester, find.byType(LoginScreen));
      await stabiliser(tester);
      final v = find.byKey(const Key('version_app'));
      await tester.ensureVisible(v);
      expect(tester.widget<Text>(v).data, 'Version $version');
      final bouton = nouvelle ? find.byKey(const Key('connexion_se_connecter')) : find.widgetWithText(ElevatedButton, 'Connexion');
      expect(tester.getTopLeft(v).dy, greaterThan(tester.getBottomLeft(bouton).dy), reason: 'sous le bouton de connexion');
      expect(tester.widget<Text>(v).style!.fontSize, lessThanOrEqualTo(13), reason: 'discrète');
      await terminer(tester);
    });

    testWidgets('Configuration du serveur ($nom) : version en bas', (tester) async {
      telephone(tester);
      preparerTelephone(serveur, nouvelle: nouvelle);
      await monterAvecProviders(tester, ecran: InterfaceScope(nouvelle: nouvelle, child: const SettingsScreen()));
      await tester.pump();
      final v = find.byKey(const Key('reglages_version'));
      await tester.scrollUntilVisible(v, 300, scrollable: find.byType(Scrollable).first);
      expect(texteVersion(v), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Réglages de la nouvelle interface (bouton engrenage) : version en bas', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur);
    donneesAccueil(serveur);
    await jusquAccueilNouveau(tester);
    await toucherReglages(tester);
    await stabiliser(tester);
    final v = find.byKey(const Key('reglages_version'));
    await tester.scrollUntilVisible(v, 300, scrollable: find.byType(Scrollable).last);
    expect(texteVersion(v), findsOneWidget);
    await terminer(tester);
  });
}
