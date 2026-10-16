// Captures PNG RÉELLES des écrans de la 3.11.0 (rendu de l'application, données fictives), à la demande seulement :
//   CAPTURES_3_11=1 flutter test test/captures_3_11_0_test.dart --update-goldens
// Fichiers produits : docs/maquettes/captures_3_11_0/*.png, téléphone 1080 × 2400 px (411 × 914 dp) et Sunmi
// 720 × 1440 px (360 × 720 dp). Police Roboto du SDK Flutter (sous les noms Lato, voir support/polices.dart).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/analyse_bl_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/detail_ca_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/menu_deux_onglets.dart';
import 'package:prestige_app/nouvelle_interface/modules/suggestions_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/tableau_analyses_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague2/ca_zone_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague4/balance_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/surstock_vague4.dart';
import 'package:prestige_app/screens/splash_screen.dart';
import 'package:prestige_app/services/api_service.dart';

import 'support/donnees_lot2.dart';
import 'support/donnees_lot3.dart';
import 'support/donnees_vague1.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/nouvelle_interface.dart';
import 'support/polices.dart';

final _actif = Platform.environment['CAPTURES_3_11'] == '1';

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
    testWidgets('captures 3.11.0 · $nom', (tester) async {
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = taille;
      addTearDown(tester.view.reset);
      Future<void> photo(String n) async {
        await pomper(tester, fois: 6);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/maquettes/captures_3_11_0/${nom}_$n.png'));
      }

      // Écran de chargement (licence lente).
      await preparer(Presentation.tableauPrestige);
      serveur.quand('/licence/find', ReponseFausse.json({'success': true}).apres(const Duration(seconds: 3)), methode: 'GET');
      await tester.pumpWidget(const MaterialApp(debugShowCheckedModeBanner: false, home: ChargementPrestige(etape: EtapeChargement.serveur)));
      await photo('01_chargement');

      await preparer(Presentation.tableauPrestige);
      await connecterEnMemoire(tester);
      await pomper(tester, fois: 30);
      await photo('02_tableau_de_bord');
      final defilement = find.descendant(of: find.byKey(const Key('defilement_tableau_bord')), matching: find.byType(Scrollable)).first;
      await tester.drag(defilement, const Offset(0, -700));
      await pomper(tester, fois: 20);
      await photo('03_tableau_de_bord_suite');
      await tester.drag(defilement, const Offset(0, -900));
      await pomper(tester, fois: 20);
      await photo('04_tableau_de_bord_fin');

      await ouvrir(tester, const BalanceCaisseScreen());
      await photo('05_balance');
      await tester.tap(find.byKey(const Key('balance_onglet_analyse')));
      await pomper(tester, fois: 20);
      await photo('06_balance_analyse');
      await tester.ensureVisible(find.byKey(const Key('balance_onglet_surveiller')));
      await pomper(tester, fois: 4);
      await tester.tap(find.byKey(const Key('balance_onglet_surveiller')));
      await pomper(tester, fois: 20);
      await photo('07_balance_surveiller');
      await retour(tester);

      await ouvrir(tester, const SurstocksScreen());
      await photo('08_surstocks');
      await retour(tester);

      await ouvrir(tester, const DetailCaNouveau());
      await tester.tap(find.byKey(const Key('periode_autres')));
      await pomper(tester, fois: 6);
      await photo('09_selecteur_periode');
      await tester.tap(find.byKey(const Key('periode_septJours')).last);
      await pomper(tester, fois: 20);
      await tester.drag(find.byKey(const Key('defilement_module')), const Offset(0, -500));
      await pomper(tester);
      await photo('10_detail_ca_courbes');
      await retour(tester);

      await ouvrir(tester, const SuggestionsNouveau());
      await photo('11_suggestions');
      await retour(tester);

      await ouvrir(tester, const TableauAnalysesNouveau());
      await tester.drag(find.byKey(const Key('defilement_module')), const Offset(0, -900));
      await pomper(tester);
      await photo('12_analyses_jour_par_jour');
      await retour(tester);

      await ouvrir(tester, const CaZoneScreen());
      await photo('13_ca_emplacement');
      await retour(tester);

      await ouvrir(tester, const AnalyseBlNouveau());
      await photo('14_analyse_saisies_bl');
      await retour(tester);

      await ouvrir(tester, const AchatsFournisseursMenu());
      await photo('15_achats_detail_synthese');
      await retour(tester);
    }, skip: !_actif);
  }
}
