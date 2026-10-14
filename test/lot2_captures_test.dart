// Captures PNG RÉELLES des modules refaits du lot 2 (achats et stock), pour la note de version. Lancées seulement à
// la demande (sinon sautées, pour ne pas dépendre des polices de la machine) :
//   CAPTURES_LOT2=1 flutter test test/lot2_captures_test.dart --update-goldens
// Fichiers produits : docs/maquettes/captures_lot2/*.png, téléphone 1080 × 2400 px (411 × 914 dp), plus des
// captures tablette 1920 × 1200 px (tableau dense). Même mécanisme que lot1_captures_test.dart.
// 3.8.0 : Visualisation BL (filtre « Contrôle » lu par le serveur, 3b et 3d), Évolution du stock ouverte sur « Ce
// mois » (6), Suivi Ajustements par pages de 100 (8c, 8d).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/services/api_service.dart';

import 'support/catalogue_ecrans.dart';
import 'support/donnees_lot2.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/nouvelle_interface.dart';
import 'support/polices.dart';

final _actif = Platform.environment['CAPTURES_LOT2'] == '1';

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
    donneesLot2(serveur);
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
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/maquettes/captures_lot2/$nom.png'));
  }

  Future<void> fin(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  }

  Future<void> ouvrir(WidgetTester tester, String tuile) async {
    final m = modulesLot2.firstWhere((x) => x.tuile == tuile);
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

  testWidgets('captures des modules du lot 2', (tester) async {
    debugDisableShadows = false;
    await preparer();
    await appareil(tester);
    await connecterEnMemoire(tester);

    // 1. Suggestions : liste, actions, suggestion ouverte, quantité enregistrée, confirmation de suppression.
    await ouvrir(tester, 'Suggestions');
    await photo(tester, '1_suggestions');
    await toucher(tester, find.byKey(const Key('suggestion_menu_${DonneesLot2.suggestion1}')));
    await photo(tester, '1b_suggestions_actions');
    await retour(tester);
    await toucher(tester, find.text(DonneesLot2.grossisteA), 15);
    await photo(tester, '1c_suggestion_ouverte');
    await tester.enterText(find.byKey(const Key('qte_${DonneesLot2.article1}')), '24');
    await toucher(tester, find.byKey(const Key('qte_enregistrer_${DonneesLot2.article1}')), 10);
    await photo(tester, '1d_suggestion_quantite_enregistree');
    await pomper(tester, 50);
    await toucher(tester, find.byKey(const Key('ligne_supprimer_${DonneesLot2.article2}')));
    await photo(tester, '1e_suggestion_confirmation_suppression');
    await toucher(tester, find.byKey(const Key('confirmer_non')));
    await retour(tester);
    await retour(tester);

    // 2. État de Stock : résultats, filtres, détail.
    await ouvrir(tester, 'Etat de Stock');
    await tester.enterText(find.byKey(const Key('champ_recherche')), 'fictif');
    await pomper(tester, 12);
    await photo(tester, '2_etat_stock');
    await toucher(tester, find.byKey(const Key('bouton_filtres')));
    await toucher(tester, find.byKey(const Key('filtre_stock_LESS')), 4);
    await photo(tester, '2b_etat_stock_filtres');
    await retour(tester);
    await toucher(tester, find.text('ARTICLE FICTIF 3'));
    await photo(tester, '2c_etat_stock_detail');
    await retour(tester);
    await retour(tester);

    // 3. Visualisation BL : liste, filtres, détail d'un bon.
    await ouvrir(tester, 'Visualisation BL');
    await photo(tester, '3_visualisation_bl');
    await toucher(tester, find.byKey(const Key('bouton_filtres')));
    await photo(tester, '3b_visualisation_bl_filtres');
    await toucher(tester, find.byKey(const Key('filtre_statut_NON_CONTROLE')));
    await toucher(tester, find.byKey(const Key('filtres_appliquer')));
    await photo(tester, '3d_visualisation_bl_non_controles');
    await toucher(tester, find.byKey(const Key('filtres_retirer')));
    await toucher(tester, find.text(DonneesLot2.grossisteB));
    await photo(tester, '3c_visualisation_bl_detail');
    await retour(tester);
    await retour(tester);

    // 4. État Contrôle Achat.
    await ouvrir(tester, 'Etat Contrôle Achat');
    await photo(tester, '4_controle_achat');
    await retour(tester);

    // 5. Retours fournisseurs : liste, détail.
    await ouvrir(tester, 'Retours Fournisseurs');
    await photo(tester, '5_retours_fournisseurs');
    await toucher(tester, find.text(DonneesLot2.grossisteA));
    await photo(tester, '5b_retour_detail');
    await retour(tester);
    await retour(tester);

    // 6. Évolution du stock : courbe, menu Exporter.
    await ouvrir(tester, 'Evolution Stock');
    await photo(tester, '6_evolution_stock');
    await toucher(tester, find.byKey(const Key('menu_exports')), 6);
    await photo(tester, '6b_evolution_stock_exporter');
    await tester.tapAt(const Offset(20, 700));
    await pomper(tester, 6);
    await retour(tester);

    // 7. Analyse Saisies BL, 8. Suivi Ajustements (liste, détail).
    await ouvrir(tester, 'Analyse Saisies BL');
    await photo(tester, '7_analyse_saisies_bl');
    await retour(tester);
    await ouvrir(tester, 'Suivi Ajustements');
    await photo(tester, '8_suivi_ajustements');
    await toucher(tester, find.text('AJUSTEMENT FICTIF CASSE'));
    await photo(tester, '8b_ajustement_detail');
    await retour(tester);
    await retour(tester);
    // 3.8.0 : plus de 100 ajustements → « Afficher plus » (pages de 100 du serveur).
    serveur.route('/ajustement', (r) {
      final start = int.tryParse(r.parametres['start'] ?? '0') ?? 0;
      return ReponseFausse.json({
        'data': [
          for (var i = start + 1; i <= (start + 100).clamp(0, 230); i++)
            {'lgAJUSTEMENTID': 'AJU-$i', 'description': 'AJUSTEMENT FICTIF N$i', 'userFullName': 'EMPLOYE Fictif', 'dtUPDATED': '13/10/2026', 'heure': '10:15'},
        ],
        'total': 230,
      });
    }, methode: 'GET');
    await ouvrir(tester, 'Suivi Ajustements');
    await photo(tester, '8c_suivi_ajustements_100_sur_230');
    await tester.scrollUntilVisible(find.byKey(const Key('bouton_afficher_plus')), 600,
        scrollable: find.descendant(of: find.byKey(const Key('defilement_module')), matching: find.byType(Scrollable)).first);
    await pomper(tester, 4);
    await photo(tester, '8d_suivi_ajustements_afficher_plus');
    await retour(tester);

    // 9. Droit manquant (Suggestions).
    serveur.quand('/suggestion/list', ReponseFausse.texte('Interdit', statut: 403), methode: 'GET');
    await ouvrir(tester, 'Suggestions');
    await photo(tester, '9_droit_manquant');
    await retour(tester);
    await fin(tester);

    // 10. Tablette : Visualisation BL et suggestion ouverte en tableau / lignes larges.
    await preparer();
    await appareil(tester, tablette: true);
    await connecterEnMemoire(tester);
    await ouvrir(tester, 'Visualisation BL');
    await photo(tester, '10_tablette_visualisation_bl');
    await retour(tester);
    await ouvrir(tester, 'Suggestions');
    await toucher(tester, find.text(DonneesLot2.grossisteA), 15);
    await photo(tester, '10b_tablette_suggestion_ouverte');
    await fin(tester);
    debugDisableShadows = true;
  }, skip: !_actif);
}
