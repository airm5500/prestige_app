// Écrans de la 3.17.0 rendus par les tests d'ergonomie (test/ergonomie/affichage_nouvelle_interface_test.dart, toutes
// tailles d'écran et échelles de texte), contre le serveur À JOUR (réponse aux demandes 67 et 68,
// support/donnees_3_17_0.dart) : CA crédit paginé (première page, page suivante chargée, lecture lente de la
// période, filtres), carte TVA de l'accueil lue par /tableau-bord/tva.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/analyses_ventes_donnees.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/ca_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';

import 'cas_affichage.dart';
import 'cas_affichage_nouvelle.dart';
import 'donnees_3_17_0.dart';
import 'donnees_lot2.dart';
import 'donnees_lot3.dart';
import 'donnees_vague1.dart';
import 'faux_serveur_prestige.dart';
import 'grandes_donnees.dart';

Future<void> _pomper(WidgetTester tester, [int fois = 6]) async {
  for (var i = 0; i < fois; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void _credit(FauxServeurPrestige s, {Duration? lente}) {
  CaCreditDonnees.oublierModes();
  Donnees3170.installerCaCredit(s, GrandesDonnees.caCredit(130), delai: (p) => lente != null && Donnees3170.premiere(p) ? lente : null);
}

void _accueil(FauxServeurPrestige s) {
  listesCommunesVague1(s);
  donneesLot2(s);
  donneesLot3(s);
  s.route('/tableau-bord/tva', (r) => ReponseFausse.json(Donnees3170.tva()), methode: 'GET');
}

/// Fait défiler la liste du CA crédit jusqu'à la page suivante (chargée d'elle-même près du bas).
Future<void> _pageSuivante(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.drag(find.byKey(const Key('defilement_module')), const Offset(0, -1500));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await _pomper(tester);
}

Future<void> _carteTva(WidgetTester tester) async {
  final liste = find.descendant(of: find.byKey(const Key('defilement_tableau_bord')), matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(find.byKey(const Key('carte_tableau_bord_tva')), 300, scrollable: liste, maxScrolls: 60);
  await _pomper(tester, 8);
  await Scrollable.ensureVisible(tester.element(find.byKey(const Key('carte_tableau_bord_tva'), skipOffstage: false)));
  await _pomper(tester, 4);
}

final casRetours3170 = <CasAffichage>[
  CasAffichage('3.17.0 · CA crédit paginé (serveur à jour)', enNouvelle(ecranConnecte(() => const CaCreditNouveau()), donnees: (s) => _credit(s))),
  CasAffichage('3.17.0 · CA crédit paginé · page suivante',
      enNouvelle(ecranConnecte(() => const CaCreditNouveau()), donnees: (s) => _credit(s), ensuite: _pageSuivante)),
  CasAffichage('3.17.0 · CA crédit paginé · lecture de la période (lente)',
      enNouvelle(ecranConnecte(() => const CaCreditNouveau()), donnees: (s) => _credit(s, lente: const Duration(seconds: 15)))),
  CasAffichage('3.17.0 · CA crédit paginé · filtres',
      enNouvelle(ecranConnecte(() => const CaCreditNouveau()), donnees: (s) => _credit(s), ensuite: (tester) async {
        await tester.tap(find.byKey(const Key('bouton_filtres')));
        await _pomper(tester);
      })),
  CasAffichage('3.17.0 · Tableau de bord · TVA (/tableau-bord/tva)',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauPrestige, donnees: _accueil, ensuite: _carteTva)),
];
