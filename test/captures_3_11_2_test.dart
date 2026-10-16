// Captures PNG RÉELLES du Détail CA, « Jour par jour » (3.11.2 : % d'évolution du Total), à la demande seulement :
//   CAPTURES_3_11=1 PHASE=avant|apres flutter test test/captures_3_11_2_test.dart --update-goldens
// Fichiers produits : docs/maquettes/captures_3_11_2/<appareil>_<phase>_texte_<échelle>.png, téléphone 1080 × 2400 px (411 × 914 dp) et Sunmi
// 720 × 1440 px (360 × 720 dp). Police Roboto du SDK Flutter (sous les noms Lato, voir support/polices.dart).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/detail_ca_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/services/api_service.dart';

import 'support/donnees_lot2.dart';
import 'support/donnees_lot3.dart';
import 'support/donnees_vague1.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/nouvelle_interface.dart';
import 'support/polices.dart';

final _actif = Platform.environment['CAPTURES_3_11'] == '1';
final _phase = Platform.environment['PHASE'] ?? 'apres';

Future<void> _chargerIcones() async {
  final dossier = dossierPolicesSdk();
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(File('$dossier/MaterialIcons-Regular.otf').readAsBytesSync()))))
      .load();
}

/// Appareils : téléphone courant et Sunmi (petit écran).
const appareils = <(String, Size, double)>[
  ('telephone', Size(1080, 2400), 2.625),
  ('sunmi', Size(720, 1440), 2.0),
];

void main() {
  final serveur = FauxServeurPrestige();

  setUpAll(() async {
    if (!_actif) return;
    await chargerPolicesReelles();
    await _chargerIcones();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);

  Future<void> preparer(Presentation p) async {
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true;
    donneesAccueil(serveur);
    listesCommunesVague1(serveur);
    donneesLot2(serveur);
    donneesLot3(serveur);
    preparerNouvelle(serveur, p: p);
    ApiService.client = serveur.clientMemoire();
  }

  Future<void> pomper(WidgetTester tester, {int fois = 10}) async {
    for (var i = 0; i < fois; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> ouvrir(WidgetTester tester, Widget ecran) async {
    Navigator.of(tester.element(find.byType(AccueilNouveau, skipOffstage: false))).push(MaterialPageRoute(builder: (_) => ecran));
    await pomper(tester, fois: 20);
  }

  Future<void> retour(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await pomper(tester);
  }

  for (final (nom, taille, dpr) in appareils) {
    testWidgets('captures 3.11.2 · $nom', (tester) async {
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = taille;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await preparer(Presentation.compact);
      await connecterEnMemoire(tester);
      await pomper(tester, fois: 30);
      for (final echelle in [1.0, 1.3]) {
        tester.platformDispatcher.textScaleFactorTestValue = echelle;
        await ouvrir(tester, const DetailCaNouveau());
        final liste = find.descendant(of: find.byKey(const Key('defilement_module')), matching: find.byType(Scrollable)).first;
        final position = tester.state<ScrollableState>(liste).position;
        position.jumpTo(position.maxScrollExtent);
        await pomper(tester, fois: 10);
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('../docs/maquettes/captures_3_11_2/${nom}_${_phase}_texte_${echelle.toString().replaceAll('.', '_')}.png'));
        await retour(tester);
      }
    }, skip: !_actif);
  }
}
