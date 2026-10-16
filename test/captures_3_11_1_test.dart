// Captures PNG RÉELLES des retours de la 3.11.1 (rendu de l'application, données fictives), à la demande seulement :
//   CAPTURES_3_11=1 flutter test test/captures_3_11_1_test.dart --update-goldens
// Fichiers produits : docs/maquettes/captures_3_11_1/*.png, téléphone 1080 × 2400 px (411 × 914 dp) et Sunmi
// 720 × 1440 px (360 × 720 dp). Police Roboto du SDK Flutter (sous les noms Lato, voir support/polices.dart).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/detail_ca_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague2/ca_zone_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/donnees_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague4/balance_vague4.dart';
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
    testWidgets('captures 3.11.1 · $nom', (tester) async {
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = taille;
      addTearDown(tester.view.reset);
      Future<void> photo(String n) async {
        await pomper(tester, fois: 6);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/maquettes/captures_3_11_1/${nom}_$n.png'));
      }

      Finder defilement() => find.descendant(of: find.byKey(const Key('defilement_tableau_bord')), matching: find.byType(Scrollable)).first;
      Future<void> montrer(String cle) async {
        await tester.scrollUntilVisible(find.byKey(Key(cle)), 200, scrollable: defilement(), maxScrolls: 40);
        await pomper(tester, fois: 10);
      }

      await preparer(Presentation.tableauPrestige);
      await connecterEnMemoire(tester);
      await pomper(tester, fois: 30);
      await photo('01_chiffres_aujourdhui');
      await tester.tap(find.byKey(const Key('chiffres_hier')));
      await pomper(tester, fois: 20);
      await photo('02_chiffres_hier');

      await montrer('frequentation_largeur_2');
      // Haut de la carte (titre et choix) en haut de l'écran.
      await Scrollable.ensureVisible(tester.element(find.byKey(const Key('carte_tableau_bord_frequentation'))), alignment: 0.0);
      await pomper(tester, fois: 10);
      await photo('03_frequentation_par_heure');
      await tester.tap(find.byKey(const Key('frequentation_largeur_2')));
      await pomper(tester, fois: 10);
      await tester.tap(find.byKey(const Key('frequentation_plage')));
      await pomper(tester, fois: 6);
      await photo('04_frequentation_plage');
      await tester.tap(find.byKey(const Key('frequentation_plage_septVingtDeux')).last);
      await pomper(tester, fois: 10);
      await photo('05_frequentation_par_2h');

      for (final (n, echelle) in [('06_ca_jour_par_jour', 1.0), ('07_ca_jour_par_jour_texte_1_3', 1.3)]) {
        tester.platformDispatcher.textScaleFactorTestValue = echelle;
        await ouvrir(tester, CaZoneScreen(filtresInitiaux: FiltresCa(type: TypePeriodeCa.libre, debut: DateTime(2026, 10, 8), fin: DateTime(2026, 10, 14))));
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -330));
        await pomper(tester);
        await photo(n);
        await retour(tester);
      }
      tester.platformDispatcher.clearTextScaleFactorTestValue();

      await ouvrir(tester, const BalanceCaisseScreen());
      await tester.drag(find.byKey(const Key('defilement_balance')), const Offset(0, -1100));
      await pomper(tester);
      await tester.ensureVisible(find.byKey(const Key('repartition_modes_paiement')));
      await pomper(tester);
      await photo('08_balance_camembert_modes');
      await tester.tap(find.byKey(const Key('repartition_type')));
      await pomper(tester);
      await photo('09_balance_camembert_type_vente');
      await tester.tap(find.byKey(const Key('balance_onglet_modes')));
      await pomper(tester, fois: 20);
      await photo('10_balance_barres_modes');
      await retour(tester);

      // Sélecteur de période : [Aujourd'hui ▾] [Hier] [Personnaliser] ; menu ouvert juste en dessous ; « Ce mois ▾ ».
      await ouvrir(tester, const DetailCaNouveau());
      await photo('11_selecteur_periode');
      await tester.tap(find.byKey(const Key('periode_autres')));
      await pomper(tester, fois: 6);
      await photo('12_selecteur_periode_menu');
      await tester.tap(find.byKey(const Key('periode_ceMois')).last);
      await pomper(tester, fois: 20);
      await photo('13_selecteur_periode_ce_mois');
      await retour(tester);
    }, skip: !_actif);
  }
}
