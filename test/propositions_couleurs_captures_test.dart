// Captures PNG des PROPOSITIONS de style des icônes (3.9.0) et des autres retours du pharmacien, rendu réel de
// l'application (polices réelles, données fictives, faux serveur en mémoire). Lancées seulement à la demande :
//   CAPTURES_COULEURS=1 flutter test test/propositions_couleurs_captures_test.dart --update-goldens
// Fichiers produits :
//  - docs/maquettes/propositions_couleurs/<style>_1_accueil_A.png, _2_accueil_B.png, _3_liste_menus.png (onglet
//    Analyses, barre du bas comprise), _4_barre_du_bas.png (la barre avec chaque onglet actif), pour les styles
//    actuel, p1, p2, p3 (téléphone 1080 × 2400 px, 411 × 914 dp) ; page de comparaison : index.html ;
//  - docs/maquettes/captures_3_9_0/ : menus par pages (A, B), recherche « contient » de l'onglet Analyses,
//    Pointage BL sans grossiste, Suivi 20/80 « Tous ».
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/apparence_accueil.dart';
import 'package:prestige_app/nouvelle_interface/charte.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/services/api_service.dart';

import 'support/donnees_lot3.dart';
import 'support/donnees_vague1.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/nouvelle_interface.dart';
import 'support/polices.dart';

final _actif = Platform.environment['CAPTURES_COULEURS'] == '1';

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

  Future<void> preparer(Presentation p, {StyleIcones style = StyleIcones.actuel, AffichageMenus affichage = AffichageMenus.unePage}) async {
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true;
    donneesAccueil(serveur);
    listesCommunesVague1(serveur);
    donneesLot3(serveur);
    preparerNouvelle(serveur, p: p, style: style, affichage: affichage);
    ApiService.client = serveur.clientMemoire();
  }

  void telephone(WidgetTester tester) {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
  }

  Future<void> pomper(WidgetTester tester, [int fois = 8]) async {
    for (var i = 0; i < fois; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> photo(WidgetTester tester, String chemin, {Finder? cible}) async {
    await pomper(tester, 6);
    await expectLater(cible ?? find.byType(MaterialApp), matchesGoldenFile('../docs/maquettes/$chemin.png'));
  }

  Future<void> fin(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  }

  Future<void> defiler(WidgetTester tester, Key cle, double dy) async {
    await tester.drag(find.descendant(of: find.byKey(cle), matching: find.byType(Scrollable)).first, Offset(0, -dy));
    await pomper(tester, 6);
  }

  testWidgets('propositions de style des icônes : accueil A, accueil B, liste de menus, barre du bas', (tester) async {
    debugDisableShadows = false;
    telephone(tester);
    for (final s in StyleIcones.values) {
      final d = 'propositions_couleurs/${s.name}';
      // Accueil A : défilé jusqu'aux menus (familles), sous les chiffres du jour.
      await preparer(Presentation.tableauDeBord, style: s);
      await connecterEnMemoire(tester);
      await pomperJusqua(tester, () => find.text('…').evaluate().isEmpty, raison: 'chiffres du jour');
      await defiler(tester, const Key('defilement_accueil'), 470);
      await photo(tester, '${d}_1_accueil_A');
      // Liste de menus : onglet Analyses (barre du bas, onglet Analyses actif).
      await ouvrirOnglet(tester, 'Analyses');
      await pomper(tester);
      await photo(tester, '${d}_3_liste_menus');
      await fin(tester);
      // Accueil B.
      await preparer(Presentation.compact, style: s);
      await connecterEnMemoire(tester);
      await photo(tester, '${d}_2_accueil_B');
      await fin(tester);
      // Barre du bas seule, chaque onglet actif tour à tour (4 onglets : administrateur / pharmacien).
      ApparenceAccueilPrefs.style.value = s;
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => Theme(
            data: themeNouvelleInterface(context),
            child: Scaffold(
              backgroundColor: Charte.page,
              body: Center(
                child: RepaintBoundary(
                  key: const Key('barres'),
                  child: Container(
                    color: Charte.page,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < OngletAccueil.values.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: BarreOnglets(onglets: OngletAccueil.values, onglet: i, choisir: (_) {}, style: s),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await photo(tester, '${d}_4_barre_du_bas', cible: find.byKey(const Key('barres')));
      await fin(tester);
    }
    debugDisableShadows = true;
  }, skip: !_actif);

  testWidgets('autres retours 3.9.0 : menus par pages, recherche « contient », Pointage BL, Suivi 20/80 « Tous »', (tester) async {
    debugDisableShadows = false;
    telephone(tester);
    // Menus par pages : A (page « À surveiller » puis une famille), B.
    await preparer(Presentation.tableauDeBord, affichage: AffichageMenus.parPages);
    await connecterEnMemoire(tester);
    await pomperJusqua(tester, () => find.text('…').evaluate().isEmpty, raison: 'chiffres du jour');
    await photo(tester, 'captures_3_9_0/1_accueil_A_par_pages');
    await tester.tap(find.byKey(const Key('page_menus_suivante')));
    await pomper(tester);
    await photo(tester, 'captures_3_9_0/2_accueil_A_par_pages_ventes');

    // Recherche « contient » de l'onglet Analyses, puis analyse du produit.
    await ouvrirOnglet(tester, 'Analyses');
    await pomper(tester);
    await tester.enterText(find.byKey(const Key('champ_recherche')), 'fictif');
    await tester.pump(const Duration(milliseconds: 600));
    await pomper(tester);
    await photo(tester, 'captures_3_9_0/4_analyses_recherche_contient');
    await tester.tap(find.byKey(const Key('produit_9990001')));
    await pomper(tester, 12);
    await photo(tester, 'captures_3_9_0/5_analyse_du_produit');
    await tester.binding.handlePopRoute();
    await pomper(tester);
    await fin(tester);

    await preparer(Presentation.compact, affichage: AffichageMenus.parPages);
    await connecterEnMemoire(tester);
    await photo(tester, 'captures_3_9_0/3_accueil_B_par_pages');

    // Pointage BL sans grossiste (explication), puis Suivi 20/80 « Tous ».
    await tester.enterText(find.byKey(const Key('recherche_menu')), 'Pointage');
    await pomper(tester, 4);
    await tester.tap(find.descendant(of: find.byKey(const Key('defilement_menus')), matching: find.text('Pointage BL')).first);
    await pomper(tester, 15);
    await photo(tester, 'captures_3_9_0/6_pointage_sans_grossiste');
    await tester.binding.handlePopRoute();
    await pomper(tester);
    await tester.enterText(find.byKey(const Key('recherche_menu')), '20/80');
    await pomper(tester, 4);
    await tester.tap(find.descendant(of: find.byKey(const Key('defilement_menus')), matching: find.text('Suivi 20/80')).first);
    await pomper(tester, 15);
    await tester.tap(find.byKey(const Key('bouton_filtres')));
    await pomper(tester, 6);
    await tester.tap(find.byKey(const Key('filtre_tous')));
    await pomper(tester, 4);
    await photo(tester, 'captures_3_9_0/7_suivi_2080_tous');
    await tester.tap(find.byKey(const Key('filtres_appliquer')));
    await pomper(tester, 15);
    await photo(tester, 'captures_3_9_0/8_suivi_2080_tous_les_articles');
    await fin(tester);
    debugDisableShadows = true;
  }, skip: !_actif);
}
