// Écrans des retours de la 3.11.1 rendus par les tests d'ergonomie (test/ergonomie/affichage_nouvelle_interface_test.dart,
// 5 tailles × 2 échelles de texte) : chiffres du tableau de bord pour « Hier », fréquentation horaire (par heure, par
// 2 h de 7 h à 22 h, menu des plages ouvert), CA par emplacement jour par jour, Balance (camembert par mode et par type
// de vente), Évolution par mode (barres).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/detail_ca_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague2/ca_zone_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/donnees_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague4/balance_vague4.dart';

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

/// Amène la carte de la fréquentation (chargée à son arrivée à l'écran) en haut du tableau de bord.
Future<void> _frequentation(WidgetTester tester) async {
  final liste = find.descendant(of: find.byKey(const Key('defilement_tableau_bord')), matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(find.byKey(const Key('carte_tableau_bord_frequentation')), 300, scrollable: liste, maxScrolls: 40);
  await _pomper(tester, 8);
  // La carte peut être construite juste sous le bas de l'écran (hors écran pour le finder) : 3.15.0, une carte de plus.
  await Scrollable.ensureVisible(tester.element(find.byKey(const Key('carte_tableau_bord_frequentation'), skipOffstage: false)));
  await _pomper(tester, 4);
}

/// Fait venir la répartition de la Balance (liste construite à la demande).
Future<void> _repartition(WidgetTester tester) async {
  final liste = find.descendant(of: find.byKey(const Key('defilement_balance')), matching: find.byType(Scrollable)).first;
  await _pomper(tester, 4);
  await tester.scrollUntilVisible(find.byKey(const Key('balance_modes')), 300, scrollable: liste, maxScrolls: 40);
  await _pomper(tester, 2);
}

void _donnees(FauxServeurPrestige s) {
  listesCommunesVague1(s);
  donneesLot2(s);
  donneesLot3(s);
}

final _jourParJour = FiltresCa(type: TypePeriodeCa.libre, debut: DateTime(2026, 10, 8), fin: DateTime(2026, 10, 14));

final casRetours3111 = <CasAffichage>[
  // 3.11.2 : Détail CA, jour par jour, % d'évolution du Total.
  CasAffichage('3.11.2 · Détail CA · jour par jour', enNouvelle(ecranConnecte(() => const DetailCaNouveau()), donnees: _donnees, ensuite: (tester) async {
    final liste = find.descendant(of: find.byKey(const Key('defilement_module')), matching: find.byType(Scrollable)).first;
    final position = tester.state<ScrollableState>(liste).position;
    position.jumpTo(position.maxScrollExtent);
    await _pomper(tester, 2);
  })),
  CasAffichage('3.11.1 · Tableau de bord · chiffres d\'hier',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauPrestige, donnees: _donnees, ensuite: _toucher('chiffres_hier'))),
  CasAffichage('3.11.1 · Tableau de bord · fréquentation par heure',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauPrestige, donnees: _donnees, ensuite: _frequentation)),
  CasAffichage('3.11.1 · Tableau de bord · fréquentation par 2 h, de 7 h à 22 h',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauPrestige, donnees: _donnees, ensuite: (tester) async {
        await _frequentation(tester);
        await _toucher('frequentation_largeur_2')(tester);
        await _toucher('frequentation_plage')(tester);
        await tester.tap(find.byKey(const Key('frequentation_plage_septVingtDeux')).last);
        await _pomper(tester);
      })),
  CasAffichage('3.11.1 · Tableau de bord · menu des plages d\'heures',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauPrestige, donnees: _donnees, ensuite: (tester) async {
        await _frequentation(tester);
        await _toucher('frequentation_plage')(tester);
      })),
  CasAffichage('3.11.1 · CA par emplacement · jour par jour', enNouvelle(ecranConnecte(() => CaZoneScreen(filtresInitiaux: _jourParJour)), donnees: _donnees)),
  CasAffichage('3.11.1 · Balance · camembert par mode de paiement',
      enNouvelle(ecranConnecte(() => const BalanceCaisseScreen()), donnees: _donnees, ensuite: _repartition)),
  CasAffichage('3.11.1 · Balance · camembert par type de vente',
      enNouvelle(ecranConnecte(() => const BalanceCaisseScreen()), donnees: _donnees, ensuite: (tester) async {
        await _repartition(tester);
        await _toucher('repartition_type')(tester);
      })),
  CasAffichage('3.11.1 · Balance · barres de l\'évolution par mode',
      enNouvelle(ecranConnecte(() => const BalanceCaisseScreen(initial: OngletBalance.modes)), donnees: _donnees)),
];
