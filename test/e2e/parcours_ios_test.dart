// Bout en bout iOS (3.12.0) : l'application ENTIÈRE, comme sur un iPhone SE (375×667 pt, plateforme iOS), parle en
// HTTP réel au faux serveur Prestige local : connexion, tableau de bord, Réglages — l'interface garde la taille du
// système (aucune réduction « petit écran » : elle ne concerne que les Sunmi Android) et le réglage « Taille de
// l'écran » est absent ; mêmes écrans sur Android : réglage présent (aucune régression).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/interface_version.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/screens/settings_screen.dart';

import '../outils/contexte_api.dart';
import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_vague1.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

void iphoneSe(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = const Size(750, 1334);
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(chargerPolicesReelles);

  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    donneesAccueil(serveur);
    listesCommunesVague1(serveur);
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..parDefaut = ((_) => ReponseFausse.json(DonneesFictives.listeVide()));
  });

  testWidgets('iPhone SE : connexion, tableau de bord à la taille du système, Réglages sans « Taille de l\'écran »', (tester) async {
    iphoneSe(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      preparerNouvelle(serveur, p: Presentation.tableauPrestige);
      await tester.runAsync(InterfaceVersion.load);
      await jusquAccueilNouveau(tester);
      await attendreWidget(tester, find.byKey(const Key('chiffre_tb_ca')));
      final taille = MediaQuery.sizeOf(tester.element(find.byType(AccueilNouveau)));
      expect(taille, const Size(375, 667), reason: 'aucune réduction de l\'interface sur iPhone');
      await toucherReglages(tester);
      await stabiliser(tester);
      final liste = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(find.byKey(const Key('reglages_version')), 300, scrollable: liste);
      expect(find.byKey(const ValueKey('taille-ecran')), findsNothing);
      await terminer(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final ios in [true, false]) {
    testWidgets('Configuration du serveur (ancienne interface) : « Taille de l\'écran » ${ios ? 'absent sur iOS' : 'présent sur Android'}',
        (tester) async {
      iphoneSe(tester);
      if (ios) debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        preparerTelephone(serveur, nouvelle: false);
        await monterAvecProviders(tester, ecran: const SettingsScreen());
        await tester.pump();
        await tester.scrollUntilVisible(find.byKey(const Key('reglages_version')), 300, scrollable: find.byType(Scrollable).first);
        expect(find.byKey(const ValueKey('taille-ecran')), ios ? findsNothing : findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
