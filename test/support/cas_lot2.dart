// États des modules refaits du LOT 2 (achats et stock) rendus par les tests d'ergonomie et de cohérence de la
// nouvelle interface : listes remplies, feuilles de filtres, détails, menus Exporter, confirmations, quantité
// enregistrée, erreurs. Écrans propres à la nouvelle interface : aucun écart toléré.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/suggestion_model.dart';
import 'package:prestige_app/nouvelle_interface/modules/ajustements_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/analyse_bl_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/controle_achat_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/etat_stock_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/evolution_stock_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/retours_fournisseurs_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suggestions_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/visualisation_bl_nouveau.dart';
import 'package:prestige_app/utils/constants.dart';

import 'cas_affichage.dart';
import 'cas_affichage_nouvelle.dart';
import 'donnees_lot2.dart';
import 'faux_serveur_prestige.dart';

/// Amène [cible] à l'écran (défilement de la liste du module) puis la touche ; [attendu] : clé qui doit alors être
/// affichée (le cas rend bien l'état voulu).
/// [cible] est construite à chaque passage (un Finder garde le résultat de sa dernière recherche).
Future<void> Function(WidgetTester) toucherVisible(Finder Function() cibler, {String? attendu}) => (tester) async {
      final cible = cibler();
      expect(cible, findsWidgets, reason: 'cible à toucher absente');
      // Cible amenée vers le haut de l'écran : un menu ouvert près du bas serait coupé.
      await Scrollable.ensureVisible(tester.element(cible.first), alignment: 0.3);
      await tester.pump(const Duration(milliseconds: 300));
      await toucher(cible)(tester);
      if (attendu != null) expect(find.byKey(Key(attendu)), findsWidgets, reason: 'état rendu : $attendu');
    };

/// Plusieurs étapes à la suite.
Future<void> Function(WidgetTester) puis(List<Future<void> Function(WidgetTester)> etapes) => (tester) async {
      for (final e in etapes) {
        await e(tester);
      }
    };

final suggestionFictive = Suggestion(id: DonneesLot2.suggestion1, name: 'SUGG-FICTIVE-01', status: 'pending', grossiste: DonneesLot2.grossisteA);

Future<void> Function(WidgetTester, FauxServeurPrestige) _lot2(Widget Function() ecran,
        {Future<void> Function(WidgetTester)? ensuite, void Function(FauxServeurPrestige)? donnees, String? recherche}) =>
    enNouvelle(ecranConnecte(ecran, recherche: recherche), donnees: (s) {
      donneesLot2(s);
      donnees?.call(s);
    }, ensuite: ensuite);

Future<void> _filtres(WidgetTester tester) => toucher(find.byKey(const Key('bouton_filtres')))(tester);
Future<void> _exporter(WidgetTester tester) => toucher(find.byKey(const Key('menu_exports')))(tester);

final casLot2 = <CasAffichage>[
  // Suggestions
  CasAffichage('Lot 2 · Suggestions remplies', _lot2(() => const SuggestionsNouveau())),
  CasAffichage('Lot 2 · Suggestions menu ⋮',
      _lot2(() => const SuggestionsNouveau(), ensuite: toucherVisible(() => find.byKey(const Key('suggestion_menu_${DonneesLot2.suggestion1}')), attendu: 'suggestion_supprimer'))),
  CasAffichage('Lot 2 · Suggestion ouverte', _lot2(() => SuggestionDetailNouveau(suggestion: suggestionFictive))),
  CasAffichage(
      'Lot 2 · Suggestion quantité enregistrée',
      _lot2(() => SuggestionDetailNouveau(suggestion: suggestionFictive), ensuite: (tester) async {
        await tester.enterText(find.byKey(const Key('qte_${DonneesLot2.article1}')), '24');
        await toucherVisible(() => find.byKey(const Key('qte_enregistrer_${DonneesLot2.article1}')))(tester);
        expect(find.text('Enregistrée'), findsOneWidget);
      })),
  CasAffichage('Lot 2 · Suggestion confirmation de suppression',
      _lot2(() => SuggestionDetailNouveau(suggestion: suggestionFictive), ensuite: toucherVisible(() => find.byKey(const Key('ligne_supprimer_${DonneesLot2.article2}')), attendu: 'confirmer_oui'))),
  CasAffichage('Lot 2 · Suggestion menu Exporter', _lot2(() => SuggestionDetailNouveau(suggestion: suggestionFictive), ensuite: _exporter)),
  // État de Stock
  CasAffichage('Lot 2 · État de Stock résultats', _lot2(() => const EtatStockNouveau(), recherche: 'fictif')),
  CasAffichage('Lot 2 · État de Stock filtres', _lot2(() => const EtatStockNouveau(), ensuite: puis([_filtres, toucherVisible(() => find.byKey(const Key('filtre_stock_LESS')))]))),
  CasAffichage('Lot 2 · État de Stock détail article',
      _lot2(() => const EtatStockNouveau(), recherche: 'fictif', ensuite: toucherVisible(() => find.text('ARTICLE FICTIF 3'), attendu: 'detail_article'))),
  // Visualisation BL
  CasAffichage('Lot 2 · Visualisation BL remplie', _lot2(() => const VisualisationBlNouveau())),
  CasAffichage('Lot 2 · Visualisation BL filtres', _lot2(() => const VisualisationBlNouveau(), ensuite: _filtres)),
  CasAffichage('Lot 2 · Visualisation BL détail',
      _lot2(() => const VisualisationBlNouveau(), ensuite: toucherVisible(() => find.text(DonneesLot2.grossisteB), attendu: 'defilement_detail'))),
  // État Contrôle Achat
  CasAffichage('Lot 2 · Contrôle Achat rempli', _lot2(() => const ControleAchatNouveau())),
  CasAffichage('Lot 2 · Contrôle Achat filtres', _lot2(() => const ControleAchatNouveau(), ensuite: _filtres)),
  // Retours fournisseurs
  CasAffichage('Lot 2 · Retours remplis', _lot2(() => const RetoursFournisseursNouveau())),
  CasAffichage('Lot 2 · Retours filtres', _lot2(() => const RetoursFournisseursNouveau(), ensuite: _filtres)),
  CasAffichage('Lot 2 · Retour détail',
      _lot2(() => const RetoursFournisseursNouveau(), ensuite: toucherVisible(() => find.text(DonneesLot2.grossisteA), attendu: 'defilement_detail'))),
  CasAffichage('Lot 2 · Produits retournés',
      _lot2(() => const RetoursFournisseursNouveau(), ensuite: toucherVisible(() => find.byKey(const Key('retours_produits')), attendu: 'defilement_detail'))),
  // Évolution du stock
  CasAffichage('Lot 2 · Évolution stock remplie', _lot2(() => const EvolutionStockNouveau())),
  CasAffichage('Lot 2 · Évolution stock menu Exporter', _lot2(() => const EvolutionStockNouveau(), ensuite: _exporter)),
  // Analyse Saisies BL
  CasAffichage('Lot 2 · Analyse BL remplie', _lot2(() => const AnalyseBlNouveau())),
  CasAffichage('Lot 2 · Analyse BL filtres', _lot2(() => const AnalyseBlNouveau(), ensuite: _filtres)),
  // Suivi Ajustements
  CasAffichage('Lot 2 · Ajustements remplis', _lot2(() => const AjustementsNouveau())),
  CasAffichage('Lot 2 · Ajustements filtres', _lot2(() => const AjustementsNouveau(), ensuite: _filtres)),
  CasAffichage('Lot 2 · Ajustement détail',
      _lot2(() => const AjustementsNouveau(), ensuite: toucherVisible(() => find.text('AJUSTEMENT FICTIF CASSE'), attendu: 'defilement_detail'))),
  // Erreurs
  CasAffichage('Lot 2 · droit manquant',
      _lot2(() => const SuggestionsNouveau(), donnees: (s) => s.quand(AppConstants.suggestionListEndpoint, ReponseFausse.texte('Interdit', statut: 403)))),
  CasAffichage('Lot 2 · erreur du serveur',
      _lot2(() => const ControleAchatNouveau(), donnees: (s) => s.quand(AppConstants.etatControleAchatEndpoint, ReponseFausse.erreurServeur()))),
  CasAffichage('Lot 2 · serveur injoignable', _lot2(() => const EvolutionStockNouveau(), donnees: (s) => s.coupe = true)),
];
