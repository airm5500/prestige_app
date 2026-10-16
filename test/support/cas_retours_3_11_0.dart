// Écrans de la 3.11.0 rendus par les tests d'ergonomie (test/ergonomie/affichage_nouvelle_interface_test.dart) :
// écran de chargement, tableau de bord (haut, milieu, bas, choix des cartes), Balance vente / caisse (quatre
// onglets), Sur-stocks (liste, critères), saisies en périmés, menus réunis (Détail | Synthèse), sélecteur de période
// ouvert, courbes du Détail CA, Suggestions, jour par jour du Tableau : Analyses, Analyse des saisies de BL.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/analyse_bl_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/detail_ca_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/menu_deux_onglets.dart';
import 'package:prestige_app/nouvelle_interface/modules/suggestions_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/tableau_analyses_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague4/balance_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/perimes_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/surstock_vague4.dart';
import 'package:prestige_app/screens/splash_screen.dart';

import 'cas_affichage.dart';
import 'cas_affichage_nouvelle.dart';
import 'donnees_lot2.dart';
import 'donnees_lot3.dart';
import 'donnees_vague1.dart';
import 'faux_serveur_prestige.dart';

Future<void> _pomper(WidgetTester tester, [int fois = 6]) async {
  for (var i = 0; i < fois; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> Function(WidgetTester) _toucher(String cle) => (tester) async {
      await tester.ensureVisible(find.byKey(Key(cle)).first);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(Key(cle)).first);
      await _pomper(tester);
    };

/// Fait défiler le tableau de bord de [dy] dp vers le bas.
Future<void> Function(WidgetTester) _defilerTableauBord(double dy) => (tester) async {
      final liste = find.descendant(of: find.byKey(const Key('defilement_tableau_bord')), matching: find.byType(Scrollable)).first;
      tester.state<ScrollableState>(liste).position.jumpTo(dy);
      await _pomper(tester, 8);
    };

void _donnees(FauxServeurPrestige s) {
  listesCommunesVague1(s);
  donneesLot2(s);
  donneesLot3(s);
}

final casRetours3110 = <CasAffichage>[
  CasAffichage('3.11.0 · Écran de chargement', enNouvelle(ecranConnecte(() => const SplashScreen(etape: EtapeChargement.serveur)))),
  CasAffichage('3.11.0 · Tableau de bord · haut', enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauPrestige, donnees: _donnees)),
  CasAffichage('3.11.0 · Tableau de bord · fréquentation et valorisation',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauPrestige, donnees: _donnees, ensuite: _defilerTableauBord(700))),
  CasAffichage('3.11.0 · Tableau de bord · top 10 et TVA',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauPrestige, donnees: _donnees, ensuite: _defilerTableauBord(100000))),
  CasAffichage('3.11.0 · Tableau de bord · choix des cartes',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauPrestige, donnees: _donnees, ensuite: (tester) async {
        await tester.tap(find.text('Cartes'));
        await _pomper(tester);
      })),
  CasAffichage('3.11.0 · Balance · Balance', enNouvelle(ecranConnecte(() => const BalanceCaisseScreen()), donnees: _donnees)),
  CasAffichage('3.11.0 · Balance · Analyse comparative',
      enNouvelle(ecranConnecte(() => const BalanceCaisseScreen(initial: OngletBalance.analyse)), donnees: _donnees)),
  CasAffichage('3.11.0 · Balance · Évolution par mode', enNouvelle(ecranConnecte(() => const BalanceCaisseScreen(initial: OngletBalance.modes)), donnees: _donnees)),
  CasAffichage('3.11.0 · Balance · Surveiller et alertes',
      enNouvelle(ecranConnecte(() => const BalanceCaisseScreen(initial: OngletBalance.surveiller)), donnees: _donnees)),
  CasAffichage('3.11.0 · Sur-stocks · liste', enNouvelle(ecranConnecte(() => const SurstocksScreen()), donnees: _donnees)),
  CasAffichage('3.11.0 · Sur-stocks · critères', enNouvelle(ecranConnecte(() => const SurstocksScreen()), donnees: _donnees, ensuite: _toucher('bouton_filtres'))),
  CasAffichage('3.11.0 · Saisies en périmés', enNouvelle(ecranConnecte(() => const SaisiesPerimesScreen()), donnees: _donnees)),
  CasAffichage('3.11.0 · Achats Fourn. · Synthèse', enNouvelle(ecranConnecte(() => const AchatsFournisseursMenu(initial: 1)), donnees: _donnees)),
  CasAffichage('3.11.0 · CA Crédit · Synthèse', enNouvelle(ecranConnecte(() => const CreditsMenu(initial: 1)), donnees: _donnees)),
  CasAffichage('3.11.0 · Sélecteur de période · autres périodes', enNouvelle(ecranConnecte(() => const DetailCaNouveau()), donnees: _donnees, ensuite: _toucher('periode_autres'))),
  CasAffichage('3.11.0 · Détail CA · courbes de la répartition',
      enNouvelle(ecranConnecte(() => const DetailCaNouveau()), donnees: _donnees, ensuite: (tester) async {
        await _toucher('periode_autres')(tester);
        await tester.tap(find.byKey(const Key('periode_septJours')).last);
        await _pomper(tester);
        await tester.ensureVisible(find.byKey(const Key('repartition_courbes')));
        await _pomper(tester, 2);
      })),
  CasAffichage('3.11.0 · Suggestions · liste', enNouvelle(ecranConnecte(() => const SuggestionsNouveau()), donnees: _donnees)),
  CasAffichage('3.11.0 · Tableau : Analyses · jour par jour',
      enNouvelle(ecranConnecte(() => const TableauAnalysesNouveau()), donnees: _donnees, ensuite: (tester) async {
        // Bas de la liste : jour par jour (achats en gras, évolution par rapport à la veille).
        final liste = find.descendant(of: find.byKey(const Key('defilement_module')), matching: find.byType(Scrollable)).first;
        final position = tester.state<ScrollableState>(liste).position;
        position.jumpTo(position.maxScrollExtent);
        await _pomper(tester, 2);
      })),
  CasAffichage('3.11.0 · Analyse des saisies de BL · temps de saisie', enNouvelle(ecranConnecte(() => const AnalyseBlNouveau()), donnees: _donnees)),
];
