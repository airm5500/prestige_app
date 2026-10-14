// Captures PNG RÉELLES des modules refaits du lot 1 (rendu de l'application, données fictives), pour la note de
// version. Lancées seulement à la demande (sinon sautées, pour ne pas dépendre des polices de la machine) :
//   CAPTURES_LOT1=1 flutter test test/lot1_captures_test.dart --update-goldens
// Fichiers produits : docs/maquettes/captures_lot1/*.png, téléphone 1080 × 2400 px (411 × 914 dp), plus une
// capture tablette 1920 × 1200 px (tableau dense). Police Roboto du SDK Flutter (sous les noms Lato, voir
// support/polices.dart). Même mécanisme que refonte_captures_test.dart.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/services/api_service.dart';

import 'support/catalogue_ecrans.dart';
import 'support/donnees_fictives.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/nouvelle_interface.dart';
import 'support/polices.dart';

final _actif = Platform.environment['CAPTURES_LOT1'] == '1';

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
      ..controlerSession = true
      ..coupe = false;
    donneesAccueil(serveur);
    donneesLot1(serveur);
    preparerNouvelle(serveur, p: p);
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
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/maquettes/captures_lot1/$nom.png'));
  }

  Future<void> fin(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  }

  /// Ouvre le nouvel écran du module [tuile] par-dessus l'accueil (comme son menu).
  Future<void> ouvrir(WidgetTester tester, String tuile) async {
    final m = modulesLot1.firstWhere((x) => x.tuile == tuile);
    Navigator.of(tester.element(find.byType(AccueilNouveau))).push(MaterialPageRoute<void>(builder: (_) => m.nouveau()));
    await pomper(tester, 20);
  }

  Future<void> retour(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await pomper(tester, 6);
  }

  testWidgets('captures des modules du lot 1', (tester) async {
    debugDisableShadows = false;

    // 0. Accueil A : bouton Réglages (engrenage) en haut à droite, barre Accueil · Analyses · Équipe.
    await preparer(Presentation.automatique);
    await appareil(tester);
    await connecterEnMemoire(tester);
    await pomperJusqua(tester, () => find.text('…').evaluate().isEmpty, raison: 'chiffres du jour chargés');
    await photo(tester, '0_accueil_A_bouton_reglages');

    // 1. Rapport d'Activité, 2. Détail CA.
    await ouvrir(tester, 'Rapport d\'Activité');
    await photo(tester, '1_rapport_activite');
    await retour(tester);
    await ouvrir(tester, 'Détail CA');
    await photo(tester, '2_detail_ca');
    await retour(tester);

    // 3. Analyse Article : résultats puis fiche détaillée.
    await ouvrir(tester, 'Analyse Article');
    await tester.enterText(find.byType(TextField), 'parafictif');
    await pomper(tester, 12);
    await photo(tester, '3_analyse_article_resultats');
    await tester.tap(find.text(DonneesFictives.libelleArticle1));
    await pomper(tester, 8);
    await photo(tester, '3b_analyse_article_fiche');
    await retour(tester);
    await retour(tester);

    // 4. Fiche Article.
    await ouvrir(tester, 'Fiche Article');
    await tester.enterText(find.byType(TextField), 'fictif');
    await pomper(tester, 12);
    await photo(tester, '4_fiche_article_resultats');
    await retour(tester);

    // 5. Suivi Péremption : lots, filtre (feuille du bas), menu Exporter.
    await ouvrir(tester, 'Suivi Péremption');
    await photo(tester, '5_suivi_peremption');
    await tester.tap(find.byKey(const Key('bouton_filtres')));
    await pomper(tester, 8);
    await photo(tester, '5b_suivi_peremption_filtres');
    await retour(tester);
    await tester.tap(find.byKey(const Key('menu_exports')));
    await pomper(tester, 6);
    await photo(tester, '5c_suivi_peremption_exporter');
    await tester.tapAt(const Offset(20, 700));
    await pomper(tester, 6);
    await retour(tester);

    // 6. Suivi Crédit : liste, filtres.
    await ouvrir(tester, 'Suivi Crédit');
    await photo(tester, '6_suivi_credit');
    await tester.tap(find.byKey(const Key('bouton_filtres')));
    await pomper(tester, 8);
    await photo(tester, '6b_suivi_credit_filtres');
    await retour(tester);
    await retour(tester);

    // 7. Erreur : serveur injoignable (Détail CA).
    serveur.coupe = true;
    await ouvrir(tester, 'Détail CA');
    await photo(tester, '7_erreur_serveur_injoignable');
    serveur.coupe = false;
    await retour(tester);
    await fin(tester);

    // 8. Tablette : Suivi Crédit en tableau dense.
    await preparer(Presentation.automatique);
    await appareil(tester, tablette: true);
    await connecterEnMemoire(tester);
    await ouvrir(tester, 'Suivi Crédit');
    await photo(tester, '8_tablette_suivi_credit_tableau');
    await fin(tester);
    debugDisableShadows = true;
  }, skip: !_actif);

  // 2b. Détail CA : Mobile Money déplié (détail par opérateur, taux, ligne « Autres / écart »). Test séparé pour
  // pouvoir ne régénérer que cette capture : --plain-name "2b".
  testWidgets('capture 2b : Détail CA, Mobile Money déplié', (tester) async {
    debugDisableShadows = false;
    await preparer(Presentation.automatique);
    await appareil(tester);
    await connecterEnMemoire(tester);
    await ouvrir(tester, 'Détail CA');
    final cible = find.byKey(const Key('deplier_mobile'));
    final s = find.descendant(of: find.byKey(const Key('defilement_module')), matching: find.byType(Scrollable)).first;
    for (var i = 0; i < 20 && cible.evaluate().isEmpty; i++) {
      await tester.drag(s, const Offset(0, -300));
      await pomper(tester, 2);
    }
    await tester.tap(cible);
    await pomper(tester, 10);
    await Scrollable.ensureVisible(tester.element(cible), alignment: 0.15);
    await photo(tester, '2b_detail_ca_mobile_money');
    await fin(tester);
    debugDisableShadows = true;
  }, skip: !_actif);
}
