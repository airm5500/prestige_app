// Captures PNG RÉELLES des écrans de la vague 2 (rendu de l'application, données fictives), à la demande seulement :
//   CAPTURES_VAGUE2=1 flutter test test/vague2_captures_test.dart --update-goldens
// Fichiers produits : docs/maquettes/captures_vague2/*.png, téléphone 1080 × 2400 px (411 × 914 dp), plus une
// capture tablette 1920 × 1200 px. Police Roboto du SDK Flutter (sous les noms Lato, voir support/polices.dart).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague2/ca_zone_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/donnees_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/garde_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/previsions_vague2.dart';
import 'package:prestige_app/services/api_service.dart';

import 'support/donnees_vague1.dart';
import 'support/donnees_vague2.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/nouvelle_interface.dart';
import 'support/polices.dart';

final _actif = Platform.environment['CAPTURES_VAGUE2'] == '1';

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
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/maquettes/captures_vague2/$nom.png'));
  }

  Future<void> ouvrir(WidgetTester tester, Widget ecran) async {
    Navigator.of(tester.element(find.byType(AccueilNouveau, skipOffstage: false))).push(MaterialPageRoute(builder: (_) => ecran));
    await pomper(tester, fois: 20);
  }

  Future<void> retour(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await pomper(tester);
  }

  Future<void> onglet(WidgetTester tester, String nom) async {
    final cible = find.descendant(of: find.byType(TabBar), matching: find.text(nom)).first;
    await tester.ensureVisible(cible);
    await pomper(tester, fois: 3);
    await tester.tap(cible);
    await pomper(tester, fois: 15);
  }

  Future<void> fin(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  }

  testWidgets('captures de la vague 2', (tester) async {
    debugDisableShadows = false;
    await preparer(Presentation.tableauDeBord);
    appareil(tester);
    await connecterEnMemoire(tester);
    await pomperJusqua(tester, () => find.text('…').evaluate().isEmpty, raison: 'chiffres du jour chargés');

    // 1-4. Pilotage (onglet de la barre du bas) : synthèse, comparaison, À suivre, confirmation du contrôle.
    await ouvrirOnglet(tester, 'Pilotage');
    await pomper(tester, fois: 15);
    await photo(tester, '1_pilotage_synthese');
    await tester.tap(find.byKey(const Key('axe_VS_M1')));
    await pomper(tester, fois: 15);
    await photo(tester, '2_pilotage_vs_mois_precedent');
    await onglet(tester, 'À suivre');
    await photo(tester, '3_pilotage_a_suivre');
    for (var i = 0; i < 30 && find.byKey(const Key('pilotage_controler')).evaluate().isEmpty; i++) {
      await tester.drag(find.descendant(of: find.byKey(const Key('defilement_pilotage')), matching: find.byType(Scrollable)).first, const Offset(0, -300));
      await pomper(tester, fois: 2);
    }
    await tester.ensureVisible(find.byKey(const Key('pilotage_controler')));
    await tester.tap(find.byKey(const Key('pilotage_controler')));
    await pomper(tester, fois: 8);
    await photo(tester, '4_pilotage_confirmation_controle');
    await tester.tap(find.byKey(const Key('controle_annuler')));
    await pomper(tester);
    await ouvrirOnglet(tester, 'Accueil');
    await pomper(tester);

    // 5-10. Prévisions : liste, détail, analyse d'une commande, demande.
    await ouvrir(tester, const PrevisionsScreen());
    await photo(tester, '5_previsions_liste');
    await ouvrir(tester, const DetailPrevisionScreen(id: 'PRD-PREV-2'));
    await photo(tester, '6_prevision_detail_produit');
    await retour(tester);
    await onglet(tester, 'Analyse suggestion / commande');
    await photo(tester, '7_previsions_a_analyser');
    await tester.tap(find.byKey(const Key('a_analyser_CMD-TEST-1')));
    await pomper(tester, fois: 15);
    await photo(tester, '8_analyse_commande');
    await retour(tester);
    await onglet(tester, 'Analyse de la demande');
    await tester.tap(find.byKey(const Key('demande_mois_24')));
    await pomper(tester);
    await tester.tap(find.byKey(const Key('demande_calculer')));
    await pomper(tester, fois: 15);
    await photo(tester, '9_analyse_demande_24_mois');
    await retour(tester);

    // 10-12. Analyse de garde.
    await ouvrir(tester, const AnalyseGardeScreen());
    await photo(tester, '10_gardes');
    await tester.tap(find.byKey(const Key('garde_GARDE-TEST-1')));
    await pomper(tester, fois: 15);
    await photo(tester, '11_garde_synthese');
    await onglet(tester, 'Produits');
    await photo(tester, '12_garde_produits');
    await retour(tester);
    await retour(tester);

    // 13-15. CA emplacement / famille : comparatif, 3 ans en cours (annulable), détail.
    await ouvrir(tester, const CaZoneScreen());
    await photo(tester, '13_ca_emplacement_3_semaines');
    serveur.route('/ca-zone-geo', (r) => ReponseFausse.json(DonneesVague2.caZone(r.parametres)).apres(const Duration(seconds: 30)), methode: 'GET');
    await tester.tap(find.byKey(const Key('periode_ca_TROIS_ANS')));
    await pomper(tester, fois: 8);
    await photo(tester, '14_ca_3_ans_en_cours_annulable');
    await tester.tap(find.byKey(const Key('bouton_annuler_calcul')));
    await pomper(tester);
    await retour(tester);
    serveur.route('/ca-zone-geo', (r) => ReponseFausse.json(DonneesVague2.caZone(r.parametres)), methode: 'GET');
    final c = ComparatifCa.depuis(Map<String, dynamic>.from(DonneesVague2.caZone({'typePeriode': 'TROIS_MOIS', 'regroupement': 'ZONE'})));
    await ouvrir(tester, CaLigneDetailScreen(filtres: const FiltresCa(type: TypePeriodeCa.troisMois), ligne: c.lignes.first, tranches: c.tranches));
    await photo(tester, '15_ca_detail_ligne');
    await retour(tester);

    // 17. CA : filtres à choix multiple (cases à cocher, « Tout » / « Aucun », compteur).
    await ouvrir(tester, const CaZoneScreen());
    await tester.tap(find.byKey(const Key('bouton_filtres')));
    await pomper(tester, fois: 15);
    await tester.tap(find.byKey(const Key('multi_emplacement')));
    await pomper(tester, fois: 4);
    await tester.tap(find.byKey(const Key('multi_emplacement_ZONE-TEST-1')));
    await pomper(tester, fois: 4);
    await photo(tester, '17_ca_filtres_choix_multiple');
    await fin(tester);

    // 16. Tablette : CA en tableau dense (colonnes dynamiques) et menu latéral avec Pilotage.
    await preparer(Presentation.automatique);
    appareil(tester, tablette: true);
    await connecterEnMemoire(tester);
    await ouvrir(tester, const CaZoneScreen(filtresInitiaux: FiltresCa(type: TypePeriodeCa.troisMois)));
    await photo(tester, '16_tablette_ca_tableau');
    await fin(tester);

    debugDisableShadows = true;
  }, skip: !_actif);
}
