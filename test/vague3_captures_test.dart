// Captures PNG RÉELLES des écrans de la vague 3 (rendu de l'application, données fictives), à la demande seulement :
//   CAPTURES_VAGUE3=1 flutter test test/vague3_captures_test.dart --update-goldens
// Fichiers produits : docs/maquettes/captures_vague3/*.png, téléphone 1080 × 2400 px (411 × 914 dp), plus deux
// captures tablette 1920 × 1200 px. Police Roboto du SDK Flutter (sous les noms Lato, voir support/polices.dart).
// 3.8.0 : « Remettre en Nouveau » (17, 18) et « Actualiser la liste » des rappels (19, 20, 21).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague3/avis_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/pointage_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/rappels_vague3.dart';
import 'package:prestige_app/services/api_service.dart';

import 'support/donnees_vague1.dart';
import 'support/donnees_vague3.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/nouvelle_interface.dart';
import 'support/polices.dart';

final _actif = Platform.environment['CAPTURES_VAGUE3'] == '1';

Future<void> _chargerIcones() async {
  final dossier = dossierPolicesSdk();
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(File('$dossier/MaterialIcons-Regular.otf').readAsBytesSync()))))
      .load();
}

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
    preparerNouvelle(serveur, p: p);
    ApiService.client = serveur.clientMemoire();
  }

  void appareil(WidgetTester tester, {bool tablette = false}) {
    tester.view.devicePixelRatio = tablette ? 1.5 : 2.625;
    tester.view.physicalSize = tablette ? const Size(1920, 1200) : const Size(1080, 2400);
    addTearDown(tester.view.reset);
  }

  Future<void> pomper(WidgetTester tester, {int fois = 10}) async {
    for (var i = 0; i < fois; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> photo(WidgetTester tester, String nom) async {
    await pomper(tester, fois: 6);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/maquettes/captures_vague3/$nom.png'));
  }

  Future<void> ouvrir(WidgetTester tester, Widget ecran) async {
    Navigator.of(tester.element(find.byType(AccueilNouveau, skipOffstage: false))).push(MaterialPageRoute(builder: (_) => ecran));
    await pomper(tester, fois: 20);
  }

  Future<void> retour(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await pomper(tester);
  }

  Future<void> toucher(WidgetTester tester, String cle, {String? defilement, int fois = 8}) async {
    final f = find.byKey(Key(cle));
    if (defilement != null) {
      final s = find.descendant(of: find.byKey(Key(defilement)), matching: find.byType(Scrollable)).first;
      for (var i = 0; i < 30 && f.evaluate().isEmpty; i++) {
        await tester.drag(s, const Offset(0, -300));
        await pomper(tester, fois: 2);
      }
    }
    await tester.ensureVisible(f.first);
    await pomper(tester, fois: 3);
    await tester.tap(f.first);
    await pomper(tester, fois: fois);
  }

  Future<void> onglet(WidgetTester tester, String nom) async {
    final cible = find.descendant(of: find.byType(TabBar), matching: find.text(nom)).first;
    await tester.tap(cible);
    await pomper(tester, fois: 15);
  }

  Future<void> fin(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  }

  testWidgets('captures de la vague 3', (tester) async {
    debugDisableShadows = false;
    await preparer(Presentation.tableauDeBord);
    appareil(tester);
    await connecterEnMemoire(tester);
    await pomperJusqua(tester, () => find.text('…').evaluate().isEmpty, raison: 'chiffres du jour chargés');

    // 1-4. Pointage BL.
    await ouvrir(tester, const PointageBlScreen());
    await photo(tester, '1_pointage_choisir_grossiste');
    await retour(tester);
    await ouvrir(tester, const PointageBlScreen(grossisteInitial: DonneesVague3.grossiste));
    await photo(tester, '2_pointage_pieces_totaux');
    await toucher(tester, 'pointer_BL:BL-TEST-1', defilement: 'defilement_pointage');
    await photo(tester, '3_pointage_piece_pointee');
    await toucher(tester, 'sequence_BL:BL-TEST-3', defilement: 'defilement_pointage');
    await tester.enterText(find.byKey(const Key('saisie_pointage')), 'S#2026');
    await pomper(tester, fois: 3);
    await tester.tap(find.byKey(const Key('saisie_enregistrer')));
    await pomper(tester, fois: 4);
    await photo(tester, '4_pointage_sequence_refusee');
    await tester.tap(find.byKey(const Key('saisie_annuler')));
    await pomper(tester);
    await retour(tester);

    // 5-9. Avis.
    await ouvrir(tester, const AvisScreen());
    await photo(tester, '5_avis_liste');
    await tester.tap(find.byKey(const Key('bouton_filtres')));
    await pomper(tester, fois: 15);
    await photo(tester, '6_avis_filtres');
    await tester.tap(find.byKey(const Key('filtres_appliquer')));
    await pomper(tester, fois: 10);
    await toucher(tester, 'avis_AVIS-TEST-1', defilement: 'defilement_avis', fois: 15);
    await toucher(tester, 'statut_avis_TRAITE', defilement: 'defilement_detail_avis');
    await photo(tester, '7_avis_detail_traiter');
    await retour(tester);
    await onglet(tester, 'Analyse');
    await photo(tester, '9_avis_analyse');
    await retour(tester);
    await ouvrir(tester, AvisDetailScreen(id: 'AVIS-TEST-4', droits: DroitsAvis.depuis(DonneesVague3.droits())));
    await tester.scrollUntilVisible(find.byKey(const Key('avis_remettre_nouveau')), 300,
        scrollable: find.descendant(of: find.byKey(const Key('defilement_detail_avis')), matching: find.byType(Scrollable)).first);
    await tester.drag(find.descendant(of: find.byKey(const Key('defilement_detail_avis')), matching: find.byType(Scrollable)).first, const Offset(0, -200));
    await pomper(tester, fois: 4);
    await photo(tester, '17_avis_remettre_en_nouveau');
    await tester.tap(find.byKey(const Key('avis_remettre_nouveau')));
    await pomper(tester, fois: 8);
    await photo(tester, '18_avis_confirmation_remettre_en_nouveau');
    await tester.tap(find.byKey(const Key('confirmer_non')));
    await pomper(tester);
    await retour(tester);
    serveur.quand('/avis-clients/droits', ReponseFausse.json(DonneesVague3.droits(repondre: false)), methode: 'GET');
    await ouvrir(tester, AvisDetailScreen(id: 'AVIS-TEST-4', droits: DroitsAvis.depuis(DonneesVague3.droits(repondre: false))));
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.descendant(of: find.byKey(const Key('defilement_detail_avis')), matching: find.byType(Scrollable)).first, const Offset(0, -300));
      await pomper(tester, fois: 2);
    }
    await photo(tester, '8_avis_detail_lecture_seule');
    await retour(tester);

    // 10-13. Rappels traitement.
    await ouvrir(tester, const RappelsScreen());
    await photo(tester, '10_rappels_liste');
    await toucher(tester, 'choisir_RAP-TEST-1');
    await toucher(tester, 'choisir_RAP-TEST-2');
    await photo(tester, '11_rappels_selection');
    await tester.tap(find.byKey(const Key('marquer_PREPARE')));
    await pomper(tester, fois: 8);
    await photo(tester, '12_rappels_confirmation_marquer');
    await tester.tap(find.byKey(const Key('confirmer_non')));
    await pomper(tester);
    await onglet(tester, 'Analyse');
    await photo(tester, '13_rappels_analyse');
    await retour(tester);
    // 3.8.0 : « Actualiser la liste » (confirmation, calcul en cours, liste relue).
    serveur.route('/rappels-habitude/actualiser', (_) => ReponseFausse.json(resultatActualisation).apres(const Duration(seconds: 4)), methode: 'POST');
    await ouvrir(tester, const RappelsScreen());
    await tester.tap(find.byKey(const Key('rappels_recalculer')));
    await pomper(tester, fois: 8);
    await photo(tester, '19_rappels_confirmation_actualiser');
    await tester.tap(find.byKey(const Key('confirmer_oui')));
    await pomper(tester, fois: 8);
    await photo(tester, '20_rappels_actualisation_en_cours');
    await pomperJusqua(tester, () => find.text('Liste actualisée : 2 nouveaux rappels, 1 racheté.').evaluate().isNotEmpty, raison: 'liste relue');
    await photo(tester, '21_rappels_liste_actualisee');
    await retour(tester);

    // 14. Droit manquant.
    serveur.quand('/rappels-habitude/liste', ReponseFausse.json({'success': false, 'msg': 'Vous n\'avez pas accès aux rappels de traitement.'}), methode: 'GET');
    await ouvrir(tester, const RappelsScreen());
    await photo(tester, '14_droit_manquant');
    await fin(tester);

    // 15-16. Tablette.
    await preparer(Presentation.automatique);
    appareil(tester, tablette: true);
    await connecterEnMemoire(tester);
    await ouvrir(tester, const PointageBlScreen(grossisteInitial: DonneesVague3.grossiste));
    await photo(tester, '15_tablette_pointage');
    await retour(tester);
    await ouvrir(tester, const AvisScreen(ongletInitial: 1));
    await photo(tester, '16_tablette_avis_analyse');
    await fin(tester);

    debugDisableShadows = true;
  }, skip: !_actif);
}
