// Captures PNG RÉELLES de la nouvelle interface (rendu de l'application, pas des maquettes), pour la note de version.
// Lancées seulement à la demande (sinon sautées, pour ne pas dépendre des polices de la machine) :
//   CAPTURES_REFONTE=1 flutter test test/refonte_captures_test.dart --update-goldens
// Fichiers produits : docs/maquettes/captures_refonte/*.png, téléphone 1080 × 2400 px (411 × 914 dp), plus une
// capture tablette 1920 × 1200 px. Police Roboto du SDK Flutter (sous les noms Lato, voir support/polices.dart).
// Données : faux serveur Prestige « en mémoire », données fictives.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/screens/analyse_article_screen.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/services/api_service.dart';

import 'support/application.dart';
import 'support/donnees_fictives.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/nouvelle_interface.dart';
import 'support/polices.dart';

final _actif = Platform.environment['CAPTURES_REFONTE'] == '1';

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
    preparerNouvelle(serveur, p: p);
    ApiService.client = serveur.clientMemoire();
  }

  Future<void> appareil(WidgetTester tester, {bool tablette = false}) async {
    tester.view.devicePixelRatio = tablette ? 1.5 : 2.625;
    tester.view.physicalSize = tablette ? const Size(1920, 1200) : const Size(1080, 2400);
    addTearDown(tester.view.reset);
  }

  Future<void> photo(WidgetTester tester, String nom) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/maquettes/captures_refonte/$nom.png'));
  }

  Future<void> fin(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  }

  testWidgets('captures de la nouvelle interface', (tester) async {
    // Ombres réelles (le banc de test les remplace sinon par des traits noirs) ; rétabli en fin de test.
    debugDisableShadows = false;

    // 1. Connexion (A) et 2. accueil A.
    await preparer(Presentation.automatique);
    await appareil(tester);
    await lancerApplication(tester);
    await pomperJusqua(tester, () => find.byType(LoginScreen).evaluate().isNotEmpty);
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), DonneesFictives.identifiant);
    await photo(tester, '1_connexion');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), DonneesFictives.motDePasse);
    await tester.tap(find.byKey(const Key('connexion_se_connecter')));
    await pomperJusqua(tester, () => find.text('Chiffre d\'affaires').evaluate().isNotEmpty);
    await pomperJusqua(tester, () => find.text('…').evaluate().isEmpty, raison: 'chiffres du jour chargés');
    await photo(tester, '2_accueil_A_tableau_de_bord');

    // 5. Un module (Analyse Article) avec le thème de la nouvelle interface.
    await tester.scrollUntilVisible(find.text('Analyse Article'), 200, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Analyse Article'));
    await pomperJusqua(tester, () => find.byType(AnalyseArticleScreen).evaluate().isNotEmpty);
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField), 'parafictif');
    await pomperJusqua(tester, () => find.text(DonneesFictives.libelleArticle1).evaluate().isNotEmpty);
    await photo(tester, '5_module_analyse_article');
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));

    // 6. Réglages (apparence : nouvelle interface, présentation).
    await ouvrirOnglet(tester, 'Réglages');
    await photo(tester, '6_reglages_apparence');
    await fin(tester);

    // 3. Accueil B (compact) et 4. accueil C (guidé).
    await preparer(Presentation.compact);
    await connecterEnMemoire(tester);
    await photo(tester, '3_accueil_B_compact');
    await fin(tester);
    await preparer(Presentation.guide);
    await connecterEnMemoire(tester);
    await photo(tester, '4_accueil_C_guide');
    await fin(tester);

    // Tablette : présentation B automatique (menu latéral, deux colonnes).
    await preparer(Presentation.automatique);
    await appareil(tester, tablette: true);
    await connecterEnMemoire(tester);
    await photo(tester, '7_tablette_B_menu_lateral');
    await fin(tester);
    debugDisableShadows = true;
  }, skip: !_actif);
}
