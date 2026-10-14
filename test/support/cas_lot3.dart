// États des modules refaits du LOT 3 (analyses) rendus par les tests d'ergonomie et de cohérence de la nouvelle
// interface : écrans remplis (graphiques compris), filtres, détails, page des Ratios mensuels, calcul selon la norme,
// « Afficher plus », erreurs. Écrans propres à la nouvelle interface : aucun écart toléré.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/modules/ca_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/ca_global_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart' show ListeOuTableau;
import 'package:prestige_app/nouvelle_interface/modules/marge_produits_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/stat_tva_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suivi_2080_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/tableau_analyses_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/tableau_ratios_nouveau.dart';
import 'package:prestige_app/utils/constants.dart';

import 'cas_affichage.dart';
import 'cas_affichage_nouvelle.dart';
import 'cas_lot2.dart' show puis;
import 'donnees_lot3.dart';
import 'faux_serveur_prestige.dart';

Future<void> Function(WidgetTester, FauxServeurPrestige) _lot3(Widget Function() ecran,
        {Future<void> Function(WidgetTester)? ensuite, void Function(FauxServeurPrestige)? donnees, String? recherche}) =>
    enNouvelle(ecranConnecte(ecran, recherche: recherche), donnees: (s) {
      donneesLot3(s);
      donnees?.call(s);
    }, ensuite: ensuite);

/// Fait défiler la liste du module jusqu'à ce que [cibler] trouve un élément, puis le touche ; [attendu] : clé qui
/// doit alors être affichée.
Future<void> Function(WidgetTester) defilerPuisToucher(Finder Function() cibler, {String defilement = 'defilement_module', String? attendu}) =>
    (tester) async {
      final s = find.descendant(of: find.byKey(Key(defilement)), matching: find.byType(Scrollable)).first;
      for (var i = 0; i < 60 && cibler().hitTestable().evaluate().isEmpty; i++) {
        await tester.drag(s, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 100));
      }
      final cible = cibler();
      expect(cible, findsWidgets, reason: 'cible à toucher absente');
      await Scrollable.ensureVisible(tester.element(cible.first), alignment: 0.3);
      await tester.pump(const Duration(milliseconds: 300));
      await toucher(cible)(tester);
      if (attendu != null) expect(find.byKey(Key(attendu)), findsWidgets, reason: 'état rendu : $attendu');
    };

Future<void> _filtres(WidgetTester tester) => toucher(find.byKey(const Key('bouton_filtres')))(tester);

/// Touche le graphique [type] à [decalage] de son centre (valeurs au toucher).
Future<void> Function(WidgetTester) toucherGraphique(Type type, Offset decalage) => (tester) async {
      final f = find.byType(type);
      await Scrollable.ensureVisible(tester.element(f), alignment: 0.3);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tapAt(tester.getCenter(f) + decalage);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    };

final casLot3 = <CasAffichage>[
  // Tableau : Analyses
  CasAffichage('Lot 3 · Analyses rempli', _lot3(() => const TableauAnalysesNouveau())),
  CasAffichage('Lot 3 · Analyses vue Achats', _lot3(() => const TableauAnalysesNouveau(), ensuite: defilerPuisToucher(() => find.byKey(const Key('graphique_achats'))))),
  CasAffichage('Lot 3 · Analyses valeur au toucher', _lot3(() => const TableauAnalysesNouveau(), ensuite: toucherGraphique(LineChart, const Offset(0, 40)))),
  CasAffichage('Lot 3 · Analyses détail d\'un jour',
      _lot3(() => const TableauAnalysesNouveau(), ensuite: defilerPuisToucher(() => find.text('07/10/2026'), attendu: 'feuille_detail'))),
  CasAffichage(
      'Lot 3 · Analyses un seul jour',
      _lot3(() => const TableauAnalysesNouveau(),
          donnees: (s) => s.quand('/ws/ca-achats-ventes', ReponseFausse.json([DonneesLot3.achatsVentes().first]), methode: 'GET'))),
  // Tableau : Ratios
  CasAffichage('Lot 3 · Ratios rempli', _lot3(() => const TableauRatiosNouveau())),
  CasAffichage(
      'Lot 3 · Ratios calcul selon la norme',
      _lot3(() => const TableauRatiosNouveau(), ensuite: (tester) async {
        await defilerPuisToucher(() => find.byKey(const Key('norme_vente')))(tester);
        await tester.enterText(find.byKey(const Key('norme_vente')), '151000');
        await tester.pump(const Duration(milliseconds: 300));
      })),
  CasAffichage('Lot 3 · Ratios mensuels',
      _lot3(() => const TableauRatiosNouveau(), ensuite: defilerPuisToucher(() => find.byKey(const Key('ratios_mensuels')), attendu: 'defilement_detail'))),
  CasAffichage('Lot 3 · Ratios mensuels valeur au toucher',
      _lot3(() => const RatiosMensuelsNouveau(), ensuite: toucherGraphique(BarChart, const Offset(0, 60)))),
  // Suivi 20/80
  CasAffichage('Lot 3 · Suivi 20/80 rempli', _lot3(() => const Suivi2080Nouveau())),
  CasAffichage('Lot 3 · Suivi 20/80 filtres', _lot3(() => const Suivi2080Nouveau(), ensuite: _filtres)),
  CasAffichage('Lot 3 · Suivi 20/80 détail',
      _lot3(() => const Suivi2080Nouveau(), ensuite: defilerPuisToucher(() => find.textContaining('PRODUIT FICTIF 20-80 N3'), attendu: 'feuille_detail'))),
  CasAffichage(
      'Lot 3 · Suivi 20/80 Afficher plus',
      _lot3(() => const Suivi2080Nouveau(),
          ensuite: puis([
            _filtres,
            (tester) async {
              await tester.enterText(find.byKey(const Key('filtre_limite')), '80');
              await tester.pump(const Duration(milliseconds: 200));
            },
            toucher(find.byKey(const Key('filtres_appliquer'))),
            defilerPuisToucher(() => find.byKey(const Key('bouton_afficher_plus'))),
          ]))),
  // Stat TVA
  CasAffichage('Lot 3 · Stat TVA rempli', _lot3(() => const StatTvaNouveau())),
  CasAffichage('Lot 3 · Stat TVA part touchée', _lot3(() => const StatTvaNouveau(), ensuite: toucherGraphique(PieChart, const Offset(60, 20)))),
  CasAffichage('Lot 3 · Stat TVA filtres', _lot3(() => const StatTvaNouveau(), ensuite: _filtres)),
  CasAffichage('Lot 3 · Stat TVA détail d\'un taux',
      _lot3(() => const StatTvaNouveau(), ensuite: defilerPuisToucher(
              () => find.descendant(
                  of: find.byType(ListeOuTableau), matching: find.byWidgetPredicate((w) => w is Text && (w.data == 'TVA 9 %' || w.data == '9 %'))),
              attendu: 'feuille_detail'))),
  // Marge Produits Vendus
  CasAffichage('Lot 3 · Marge rempli', _lot3(() => const MargeProduitsNouveau())),
  CasAffichage('Lot 3 · Marge filtres', _lot3(() => const MargeProduitsNouveau(), ensuite: _filtres)),
  CasAffichage('Lot 3 · Marge détail',
      _lot3(() => const MargeProduitsNouveau(), ensuite: defilerPuisToucher(() => find.text('PRODUIT FICTIF MARGE N2'), attendu: 'feuille_detail'))),
  CasAffichage('Lot 3 · Marge aucun produit', _lot3(() => const MargeProduitsNouveau(), recherche: 'INTROUVABLE')),
  // CA Crédit
  CasAffichage('Lot 3 · CA Crédit rempli', _lot3(() => const CaCreditNouveau())),
  CasAffichage('Lot 3 · CA Crédit recherche', _lot3(() => const CaCreditNouveau(), recherche: 'beta')),
  CasAffichage('Lot 3 · CA Crédit filtres', _lot3(() => const CaCreditNouveau(), ensuite: _filtres)),
  CasAffichage('Lot 3 · CA Crédit détail',
      _lot3(() => const CaCreditNouveau(), ensuite: defilerPuisToucher(() => find.text('CLIENT FICTIF GAMMA'), attendu: 'feuille_detail'))),
  // CA Global
  CasAffichage('Lot 3 · CA Global rempli', _lot3(() => const CaGlobalNouveau())),
  CasAffichage('Lot 3 · CA Global détail d\'un jour',
      _lot3(() => const CaGlobalNouveau(), ensuite: defilerPuisToucher(() => find.text('13/10/2026'), attendu: 'feuille_detail'))),
  // Erreurs
  CasAffichage('Lot 3 · droit manquant',
      _lot3(() => const StatTvaNouveau(), donnees: (s) => s.quand(AppConstants.statTvaEndpoint, ReponseFausse.texte('Interdit', statut: 403)))),
  CasAffichage('Lot 3 · erreur du serveur',
      _lot3(() => const CaGlobalNouveau(), donnees: (s) => s.quand(AppConstants.caAllEndpoint, ReponseFausse.erreurServeur()))),
  CasAffichage('Lot 3 · serveur injoignable', _lot3(() => const TableauAnalysesNouveau(), donnees: (s) => s.coupe = true)),
  CasAffichage('Lot 3 · aucune donnée',
      _lot3(() => const TableauRatiosNouveau(), donnees: (s) => s.quand('/ws/ca-achats-ventes', ReponseFausse.json(const <Object>[]), methode: 'GET'))),
];
