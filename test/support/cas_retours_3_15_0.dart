// Écrans de la 3.15.0 rendus par les tests d'ergonomie (test/ergonomie/affichage_nouvelle_interface_test.dart, toutes
// tailles d'écran et échelles de texte) : carte « Affluence (jour × heure) » du tableau de bord (semaine du jour, semaine
// précédente), écran « Péremptions courtes » (liste, critères, choix du statut).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague4/peremptions_courtes_vague4.dart';

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

/// Amène la carte de l'affluence (chargée à son arrivée à l'écran) en haut du tableau de bord.
Future<void> _affluence(WidgetTester tester) async {
  final liste = find.descendant(of: find.byKey(const Key('defilement_tableau_bord')), matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(find.byKey(const Key('carte_tableau_bord_affluence')), 300, scrollable: liste, maxScrolls: 40);
  await _pomper(tester, 8);
  // Grand écran (iPad) : la carte peut être construite juste sous le bas de l'écran (hors écran pour le finder).
  await Scrollable.ensureVisible(tester.element(find.byKey(const Key('carte_tableau_bord_affluence'), skipOffstage: false)));
  await _pomper(tester, 4);
}

void _donnees(FauxServeurPrestige s) {
  listesCommunesVague1(s);
  donneesLot2(s);
  donneesLot3(s);
}

final casRetours3150 = <CasAffichage>[
  CasAffichage('3.15.0 · Tableau de bord · affluence (semaine du jour)',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauPrestige, donnees: _donnees, ensuite: _affluence)),
  CasAffichage('3.15.0 · Tableau de bord · affluence (semaine précédente)',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauPrestige, donnees: _donnees, ensuite: (tester) async {
        await _affluence(tester);
        await _toucher('affluence_precedente')(tester);
      })),
  CasAffichage('3.15.0 · Péremptions courtes · liste', enNouvelle(ecranConnecte(() => const PeremptionsCourtesScreen()), donnees: _donnees)),
  CasAffichage('3.15.0 · Péremptions courtes · critères',
      enNouvelle(ecranConnecte(() => const PeremptionsCourtesScreen()), donnees: _donnees, ensuite: _toucher('bouton_filtres'))),
  CasAffichage('3.15.0 · Péremptions courtes · choix du statut',
      enNouvelle(ecranConnecte(() => const PeremptionsCourtesScreen()), donnees: _donnees, ensuite: _toucher('pc_statut_ligne_0'))),
];
