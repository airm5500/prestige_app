// États des écrans modifiés en 3.9.0 (retours du pharmacien), rendus par les tests d'ergonomie et de cohérence de la
// nouvelle interface (5 tailles × texte 1,0 et 1,3, aucun écart toléré) :
//  - les 3 propositions de style des icônes (P1, P2, P3) sur l'accueil A, l'accueil B, l'onglet Analyses (liste de
//    menus et barre du bas) et « Tous les menus » (C) ;
//  - menus par pages : accueil A (« À surveiller », puis une famille en P3), accueil B ;
//  - onglet Analyses : recherche « contient », repli « commence par », analyse d'un produit trouvé ;
//  - Pointage BL : explication sans grossiste, dernier grossiste repris ;
//  - Suivi 20/80 : feuille des filtres avec « Tous », liste « Tous les articles » ;
//  - Réglages : « Menus de l'accueil » et « Style des icônes » (administrateur), « Menus de l'accueil » verrouillé.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/apparence_accueil.dart';
import 'package:prestige_app/nouvelle_interface/modules/suivi_2080_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/reglages_nouveaux.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/pointage_vague3.dart';
import 'package:prestige_app/utils/constants.dart';

import 'cas_affichage.dart';
import 'cas_affichage_nouvelle.dart';
import 'donnees_lot3.dart';
import 'donnees_vague1.dart';
import 'faux_serveur_prestige.dart';
import 'nouvelle_interface.dart';

const stylesProposes = [StyleIcones.p1, StyleIcones.p2, StyleIcones.p3];

Future<void> _pomper(WidgetTester tester, [int fois = 10]) async {
  for (var i = 0; i < fois; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> Function(WidgetTester) rechercherProduit(String texte, {String? toucherCle}) => (tester) async {
      await ouvrirOnglet(tester, 'Analyses');
      await _pomper(tester, 4);
      await tester.enterText(find.byKey(const Key('champ_recherche')), texte);
      await tester.pump(const Duration(milliseconds: 600));
      await _pomper(tester);
      if (toucherCle != null) {
        await tester.tap(find.byKey(Key(toucherCle)));
        await _pomper(tester);
      }
    };

/// Avance de [fois] pages (tablette : les menus restent sur une page, rien à faire ; vérifié par le test).
Future<void> Function(WidgetTester) pageSuivante(int fois) => (tester) async {
      final tablette = tester.view.physicalSize.shortestSide / tester.view.devicePixelRatio >= 600;
      expect(find.byKey(const Key('page_menus_suivante')), tablette ? findsNothing : findsOneWidget);
      if (tablette) return;
      for (var i = 0; i < fois; i++) {
        await tester.tap(find.byKey(const Key('page_menus_suivante')));
        await _pomper(tester, 4);
      }
    };

Future<void> _filtresTous(WidgetTester tester, {bool appliquer = true}) async {
  await tester.tap(find.byKey(const Key('bouton_filtres')));
  await _pomper(tester, 6);
  await tester.tap(find.byKey(const Key('filtre_tous')));
  await _pomper(tester, 3);
  if (appliquer) {
    await tester.tap(find.byKey(const Key('filtres_appliquer')));
    await _pomper(tester);
  }
}

final casRetours390 = <CasAffichage>[
  // Propositions de style des icônes (le défaut « Actuel » est rendu par les cas d'origine).
  for (final s in stylesProposes) ...[
    CasAffichage('3.9.0 · Accueil A · style ${s.name}', enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauDeBord, style: s)),
    CasAffichage('3.9.0 · Accueil B · style ${s.name}', enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.compact, style: s)),
    CasAffichage('3.9.0 · Onglet Analyses · style ${s.name}',
        enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauDeBord, style: s, ensuite: onglet('Analyses'))),
    CasAffichage('3.9.0 · Tous les menus (C) · style ${s.name}', enNouvelle(ecranConnecte(() => const TousLesMenusScreen()), style: s)),
  ],
  // Menus par pages.
  CasAffichage('3.9.0 · Accueil A par pages',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauDeBord, affichage: AffichageMenus.parPages)),
  CasAffichage(
      '3.9.0 · Accueil A par pages · famille (P3)',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()),
          p: Presentation.tableauDeBord, affichage: AffichageMenus.parPages, style: StyleIcones.p3, ensuite: pageSuivante(4))),
  CasAffichage('3.9.0 · Accueil B par pages',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.compact, affichage: AffichageMenus.parPages)),
  CasAffichage(
      '3.9.0 · Accueil B par pages · page suivante (P2)',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()),
          p: Presentation.compact, affichage: AffichageMenus.parPages, style: StyleIcones.p2, ensuite: pageSuivante(2))),
  // Recherche de produit de l'onglet Analyses.
  CasAffichage('3.9.0 · Onglet Analyses · recherche « contient »',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauDeBord, ensuite: rechercherProduit('fictif'))),
  CasAffichage(
      '3.9.0 · Onglet Analyses · repli « commence par »',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()),
          p: Presentation.tableauDeBord,
          donnees: (s) => s.quand(AppConstants.rechercheProduitEndpoint, ReponseFausse.introuvable(), methode: 'GET'),
          ensuite: rechercherProduit('para'))),
  CasAffichage('3.9.0 · Onglet Analyses · aucun produit',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauDeBord, ensuite: rechercherProduit('zzzz'))),
  CasAffichage(
      '3.9.0 · Onglet Analyses · analyse du produit trouvé',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()),
          p: Presentation.tableauDeBord, ensuite: rechercherProduit('500mg', toucherCle: 'produit_9990001'))),
  // Pointage BL.
  CasAffichage('3.9.0 · Pointage BL sans grossiste (explication)', enNouvelle(ecranConnecte(() => const PointageBlScreen()), donnees: listesCommunesVague1)),
  CasAffichage(
      '3.9.0 · Pointage BL · dernier grossiste repris',
      enNouvelle(ecranConnecte(() => const PointageBlScreen()),
          donnees: listesCommunesVague1, prefs: {DernierCriterePointage.cle: 'grossiste:GRO-TEST-1'})),
  // Suivi 20/80 « Tous ».
  CasAffichage('3.9.0 · Suivi 20/80 · feuille « Tous »',
      enNouvelle(ecranConnecte(() => const Suivi2080Nouveau()), donnees: donneesLot3, ensuite: (t) => _filtresTous(t, appliquer: false))),
  CasAffichage('3.9.0 · Suivi 20/80 · tous les articles', enNouvelle(ecranConnecte(() => const Suivi2080Nouveau()), donnees: donneesLot3, ensuite: _filtresTous)),
  // Réglages.
  CasAffichage(
      '3.9.0 · Réglages · menus de l\'accueil et style des icônes (administrateur)',
      enNouvelle(ecranConnecte(() => Scaffold(
            appBar: AppBar(title: const Text('Réglages')),
            body: ListView(children: const [
              ChoixAffichageMenus(choix: AffichageMenus.parPages, verrouille: false),
              ChoixStyleIcones(choix: StyleIcones.p1),
            ]),
          )))),
  CasAffichage(
      '3.9.0 · Réglages · menus de l\'accueil (autre compte, verrouillé)',
      enNouvelle(ecranConnecte(() => Scaffold(
            appBar: AppBar(title: const Text('Réglages')),
            body: ListView(children: const [ChoixAffichageMenus(choix: AffichageMenus.unePage, verrouille: true)]),
          )))),
];
