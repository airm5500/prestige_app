// Captures PNG RÉELLES de la 3.18.0 (mode démonstration, données fictives), à la demande seulement :
//   CAPTURES_3_18=1 flutter test test/captures_3_18_0_test.dart --update-goldens
// Fichiers produits : docs/maquettes/captures_3_18_0/*.png, téléphone 1080 × 2400 px (411 × 914 dp) : premier écran
// d'une installation neuve (bouton « Essayer la démonstration »), écran de connexion, accueil de la démonstration avec
// le bandeau, Analyse Article (recherche « para »), CA Crédit, Présences.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/menus.dart';
import 'package:prestige_app/nouvelle_interface/modules/articles_nouveau.dart';

import 'support/application.dart';
import 'support/demo.dart';
import 'support/polices.dart';

final _actif = Platform.environment['CAPTURES_3_18'] == '1';

Future<void> _chargerIcones() async {
  final dossier = dossierPolicesSdk();
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(File('$dossier/MaterialIcons-Regular.otf').readAsBytesSync()))))
      .load();
}

void main() {
  setUpAll(() async {
    if (!_actif) return;
    await chargerPolicesReelles();
    await _chargerIcones();
  });

  testWidgets('captures 3.18.0 · mode démonstration', (tester) async {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    Future<void> photo(String n) async {
      await pomper(tester, fois: 6);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/maquettes/captures_3_18_0/$n.png'));
    }

    Future<void> ouvrir(Widget Function() ecran) async {
      Navigator.of(tester.element(find.byType(AccueilNouveau, skipOffstage: false))).push(MaterialPageRoute(builder: (_) => ecran()));
      await pomper(tester, fois: 30);
    }

    await preparerInstallation();
    await lancerApplication(tester);
    await pomper(tester, fois: 10);
    await photo('01_premier_ecran_installation_neuve');

    await toucherDemo(tester);
    await pomper(tester, fois: 30);
    await photo('02_accueil_demonstration');

    await ouvrir(() => const AnalyseArticleNouveau());
    await tester.enterText(find.byType(TextField).first, 'para');
    await pomper(tester, fois: 30);
    await photo('03_analyse_article_para');
    await tester.binding.handlePopRoute();
    await pomper(tester);

    await ouvrir(menusModules.firstWhere((m) => m.titre == 'CA Crédit').ecran);
    await photo('04_ca_credit');
    await tester.binding.handlePopRoute();
    await pomper(tester);

    await ouvrir(menusModules.firstWhere((m) => m.titre == 'Présences').ecran);
    await photo('05_presences');
    await tester.binding.handlePopRoute();
    await pomper(tester);

    await quitterDemo(tester);
    await photo('06_apres_sortie');
    await finDemo(tester);
  }, skip: !_actif);
}
