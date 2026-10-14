// Captures PNG RÉELLES des modules refaits du lot 3 (analyses), pour la note de version. Lancées seulement à la
// demande (sinon sautées, pour ne pas dépendre des polices de la machine) :
//   CAPTURES_LOT3=1 flutter test test/lot3_captures_test.dart --update-goldens
// Fichiers produits : docs/maquettes/captures_lot3/*.png, téléphone 1080 × 2400 px (411 × 914 dp), plus des
// captures tablette 1920 × 1200 px (tableau dense). Même mécanisme que lot2_captures_test.dart.
// 3.8.0 : Tableau : Analyses ouvert sur « Ce mois », Ratios des 12 derniers mois, Suivi 20/80 par quantité (3d),
// menus « Exporter » (4d, 5d, 6c) et PDF d'exemple (4e_stat_tva_exemple.pdf, 5e_marge_exemple.pdf,
// 6d_ca_credit_exemple.pdf, données fictives ; leurs aperçus PNG *_pdf.png sont tirés de ces PDF hors test).
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/analyses_pdf.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/services/api_service.dart';

import 'support/catalogue_ecrans.dart';
import 'support/donnees_lot3.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/nouvelle_interface.dart';
import 'support/polices.dart';

final _actif = Platform.environment['CAPTURES_LOT3'] == '1';

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

  Future<void> preparer() async {
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..coupe = false;
    donneesAccueil(serveur);
    donneesLot3(serveur);
    preparerNouvelle(serveur, p: Presentation.automatique);
    ApiService.client = serveur.clientMemoire();
  }

  Future<void> appareil(WidgetTester tester, {bool tablette = false}) async {
    tester.view.devicePixelRatio = tablette ? 1.5 : 2.625;
    tester.view.physicalSize = tablette ? const Size(1920, 1200) : const Size(1080, 2400);
    addTearDown(tester.view.reset);
  }

  Future<void> pomper(WidgetTester tester, [int fois = 10]) async {
    for (var i = 0; i < fois; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> photo(WidgetTester tester, String nom) async {
    await pomper(tester, 6);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/maquettes/captures_lot3/$nom.png'));
  }

  Future<void> fin(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  }

  Future<void> ouvrir(WidgetTester tester, String tuile) async {
    final m = modulesLot3.firstWhere((x) => x.tuile == tuile);
    Navigator.of(tester.element(find.byType(AccueilNouveau))).push(MaterialPageRoute<void>(builder: (_) => m.nouveau()));
    await pomper(tester, 20);
  }

  Future<void> retour(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await pomper(tester, 6);
  }

  Future<void> toucher(WidgetTester tester, Finder f, [int fois = 8]) async {
    await tester.ensureVisible(f.first);
    await pomper(tester, 2);
    await tester.tap(f.first);
    await pomper(tester, fois);
  }

  /// Amène [f] vers le haut de l'écran (graphique, liste).
  Future<void> amener(WidgetTester tester, Finder f, {double alignement = 0.12}) async {
    final s = find.descendant(of: find.byKey(const Key('defilement_module')), matching: find.byType(Scrollable)).first;
    for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
      await tester.drag(s, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await Scrollable.ensureVisible(tester.element(f.first), alignment: alignement);
    await pomper(tester, 3);
  }

  /// Menu « Exporter » ouvert (photo [nom]), puis PDF produit et enregistré sous [fichier] (données fictives).
  Future<void> exporter(WidgetTester tester, String nom, String action, String fichier) async {
    await toucher(tester, find.byKey(const Key('menu_exports')));
    await photo(tester, nom);
    final avant = AnalysesPdf.sortie;
    ContenuAnalysePdf? contenu;
    AnalysesPdf.sortie = (c, _) async => contenu = c;
    await toucher(tester, find.text(action));
    AnalysesPdf.sortie = avant;
    await tester.runAsync(() async => File('docs/maquettes/captures_lot3/$fichier').writeAsBytesSync(await AnalysesPdf.octets(contenu!)));
  }

  testWidgets('captures des modules du lot 3', (tester) async {
    debugDisableShadows = false;
    await preparer();
    await appareil(tester);
    await connecterEnMemoire(tester);

    // 1. Tableau : Analyses : chiffres, courbe comparée (valeurs au toucher), vue Achats, détail d'un jour.
    await ouvrir(tester, 'Tableau: Analyses');
    await photo(tester, '1_analyses');
    await amener(tester, find.byKey(const Key('graphique_comparee')));
    await tester.tapAt(tester.getCenter(find.byType(LineChart)) + const Offset(40, 30));
    await pomper(tester, 3);
    await photo(tester, '1b_analyses_courbe_valeurs');
    await toucher(tester, find.byKey(const Key('graphique_achats')), 3);
    await photo(tester, '1c_analyses_vue_achats');
    await toucher(tester, find.text('07/10/2026'));
    await photo(tester, '1d_analyses_detail_jour');
    await retour(tester);
    await retour(tester);

    // 2. Tableau : Ratios : ratio jour par jour, calcul normé ; Ratios mensuels (barres et norme).
    await ouvrir(tester, 'Tableau: Ratios');
    await photo(tester, '2_ratios');
    await amener(tester, find.byKey(const Key('norme_vente')), alignement: 0.4);
    await tester.enterText(find.byKey(const Key('norme_vente')), '151000');
    await pomper(tester, 3);
    FocusManager.instance.primaryFocus?.unfocus();
    await pomper(tester, 3);
    await photo(tester, '2b_ratios_calcul_norme');
    await toucher(tester, find.byKey(const Key('ratios_mensuels_barre')), 15);
    await photo(tester, '2c_ratios_mensuels');
    await retour(tester);
    await retour(tester);

    // 3. Suivi 20/80 : liste, filtre du nombre d'articles, détail.
    await ouvrir(tester, 'Suivi 20/80');
    await photo(tester, '3_suivi_2080');
    await toucher(tester, find.byKey(const Key('bouton_filtres')));
    await photo(tester, '3b_suivi_2080_filtres');
    await retour(tester);
    await toucher(tester, find.text('3. PRODUIT FICTIF 20-80 N3'));
    await photo(tester, '3c_suivi_2080_detail');
    await retour(tester);
    await tester.scrollUntilVisible(find.byKey(const Key('classement_quantite')), -300,
        scrollable: find.descendant(of: find.byKey(const Key('defilement_module')), matching: find.byType(Scrollable)).first);
    await tester.drag(find.descendant(of: find.byKey(const Key('defilement_module')), matching: find.byType(Scrollable)).first, const Offset(0, 2000));
    await pomper(tester, 4);
    await toucher(tester, find.byKey(const Key('classement_quantite')), 12);
    await photo(tester, '3d_suivi_2080_par_quantite');
    await retour(tester);

    // 4. Stat TVA : anneau (part touchée), filtres.
    await ouvrir(tester, 'Stat TVA');
    await photo(tester, '4_stat_tva');
    await amener(tester, find.byType(PieChart), alignement: 0.2);
    await tester.tapAt(tester.getCenter(find.byType(PieChart)) + const Offset(60, 20));
    await pomper(tester, 3);
    await photo(tester, '4b_stat_tva_part_touchee');
    await toucher(tester, find.byKey(const Key('bouton_filtres')));
    await photo(tester, '4c_stat_tva_filtres');
    await retour(tester);
    await exporter(tester, '4d_stat_tva_exporter', 'PDF des statistiques TVA', '4e_stat_tva_exemple.pdf');
    await retour(tester);

    // 5. Marge Produits Vendus : liste, filtre de marge, détail.
    await ouvrir(tester, 'Marge Produits Vendus');
    await photo(tester, '5_marge');
    await toucher(tester, find.byKey(const Key('bouton_filtres')));
    await toucher(tester, find.byKey(const Key('filtre_operateur_superieur')), 3);
    await tester.enterText(find.byKey(const Key('filtre_marge')), '40');
    await pomper(tester, 3);
    await photo(tester, '5b_marge_filtres');
    await toucher(tester, find.byKey(const Key('filtres_appliquer')));
    await photo(tester, '5c_marge_filtree');
    await exporter(tester, '5d_marge_exporter', 'PDF des marges', '5e_marge_exemple.pdf');
    await retour(tester);

    // 6. CA Crédit : liste, détail.
    await ouvrir(tester, 'CA Crédit');
    await photo(tester, '6_ca_credit');
    await toucher(tester, find.text('CLIENT FICTIF GAMMA'));
    await photo(tester, '6b_ca_credit_detail');
    await retour(tester);
    await exporter(tester, '6c_ca_credit_exporter', 'PDF des ventes à crédit', '6d_ca_credit_exemple.pdf');
    await retour(tester);

    // 7. CA Global.
    await ouvrir(tester, 'CA Global');
    await photo(tester, '7_ca_global');
    await amener(tester, find.text('Jour par jour'.toUpperCase()), alignement: 0.1);
    await photo(tester, '7b_ca_global_jours');
    await retour(tester);

    // 8. Droit manquant (Stat TVA).
    serveur.quand('/tvas', ReponseFausse.texte('Interdit', statut: 403), methode: 'GET');
    await ouvrir(tester, 'Stat TVA');
    await photo(tester, '8_droit_manquant');
    await retour(tester);
    await fin(tester);

    // 9. Tablette : Tableau : Analyses (graphique et tableau dense), Stat TVA.
    await preparer();
    await appareil(tester, tablette: true);
    await connecterEnMemoire(tester);
    await ouvrir(tester, 'Tableau: Analyses');
    await photo(tester, '9_tablette_analyses');
    await retour(tester);
    await ouvrir(tester, 'Stat TVA');
    await photo(tester, '9b_tablette_stat_tva');
    await fin(tester);
    debugDisableShadows = true;
  }, skip: !_actif);
}
