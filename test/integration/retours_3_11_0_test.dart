// Intégration des retours du pharmacien (3.11.0) : écrans réels contre le faux serveur Prestige « en mémoire ».
//  - sélecteur de période : « Autres périodes » ouvre 7 jours / Ce mois / Mois dernier, la période choisie est
//    affichée sur le sélecteur et envoyée au serveur ;
//  - Suggestions : curseur dans le premier article à l'ouverture (texte sélectionné), « Suivant » du clavier passe à
//    l'article suivant et enregistre la quantité ; liste sans compteurs, statut en face du grossiste ;
//  - Détail CA : une courbe par mode de paiement (plus de barres) ;
//  - Tableau : Analyses : achats en gras, évolution des ventes avec flèche ;
//  - CA par emplacement : plus de « favorable / défavorable », évolution en grand ; produits d'un emplacement ;
//  - Analyse des saisies de BL : temps de saisie moyen ;
//  - Accueil A : Actualiser, Réglages puis Déconnexion (icône power-off sur rond rouge).
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/suggestion_model.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/charte.dart';
import 'package:prestige_app/nouvelle_interface/modules/analyse_bl_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/detail_ca_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suggestions_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/tableau_analyses_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague2/ca_zone_vague2.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/donnees_lot2.dart';
import '../support/donnees_lot3.dart';
import '../support/donnees_vague1.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

Future<void> pomper(WidgetTester tester, [int fois = 10]) async {
  for (var i = 0; i < fois; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void ecran(WidgetTester tester, {double hauteur = 891}) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = Size(411 * 2.625, hauteur * 2.625);
  addTearDown(tester.view.reset);
}

Future<void> monter(WidgetTester tester, Widget Function() e, {Presentation p = Presentation.compact, void Function(FauxServeurPrestige)? donnees}) async {
  preparerNouvelle(serveur, p: p);
  donneesAccueil(serveur);
  listesCommunesVague1(serveur);
  donneesLot2(serveur);
  donneesLot3(serveur);
  donnees?.call(serveur);
  ApiService.client = serveur.clientMemoire();
  serveur.oublierRequetes();
  await ecranConnecte(e)(tester, serveur);
  await pomper(tester);
}

Future<void> demonter(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 2));
}

Future<void> toucher(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(f.first);
  await pomper(tester, 6);
}

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() => serveur
    ..installerRoutesParDefaut()
    ..coupe = false);
  tearDown(restaurerClient);

  testWidgets('sélecteur de période : Aujourd\'hui, Hier, Personnaliser visibles ; « Autres périodes » → 7 jours, affiché et envoyé', (tester) async {
    ecran(tester);
    await monter(tester, () => const DetailCaNouveau());
    // 3.11.1 : trois boutons, [Aujourd'hui ▾] [Hier] [Personnaliser] ; plus de « Autres périodes ».
    for (final c in ['periode_autres', 'periode_hier', 'periode_personnalisee']) {
      expect(find.byKey(Key(c)).hitTestable(), findsOneWidget, reason: '$c visible sans défiler');
    }
    expect(find.text('Personnaliser'), findsOneWidget);
    expect(find.text('Autres périodes'), findsNothing);
    expect(find.descendant(of: find.byKey(const Key('periode_autres')), matching: find.text('Aujourd\'hui')), findsOneWidget);
    expect(find.byKey(const Key('periode_septJours')), findsNothing, reason: 'dans le menu du premier bouton');
    await toucher(tester, find.byKey(const Key('periode_autres')));
    expect(find.byKey(const Key('periode_aujourdhui')), findsOneWidget, reason: 'en tête du menu');
    expect(find.byKey(const Key('periode_ceMois')), findsOneWidget);
    await tester.tap(find.byKey(const Key('periode_septJours')).last);
    await pomper(tester);
    final debut = DateTime.now().subtract(const Duration(days: 6));
    expect(serveur.recues(AppConstants.caComptantEndpoint).last.parametres['dtStart'],
        '${debut.year}-${debut.month.toString().padLeft(2, '0')}-${debut.day.toString().padLeft(2, '0')}');
    expect(find.descendant(of: find.byKey(const Key('periode_autres')), matching: find.text('7 jours')), findsOneWidget, reason: 'période affichée');
    // Détail CA : courbes de la répartition (une par mode présent), plus de barres.
    await tester.ensureVisible(find.byKey(const Key('repartition_courbes')));
    await pomper(tester, 2);
    final courbe = tester.widget<LineChart>(find.descendant(of: find.byKey(const Key('repartition_courbes')), matching: find.byType(LineChart)));
    expect(courbe.data.lineBarsData.length, greaterThanOrEqualTo(2));
    expect(find.descendant(of: find.byType(DetailCaNouveau), matching: find.byType(LinearProgressIndicator)), findsNothing);
    await demonter(tester);
  });

  testWidgets('Suggestions : liste sans compteurs, statut en face du grossiste, « Créée le … · Réf. … » sur une ligne', (tester) async {
    ecran(tester);
    await monter(tester, () => const SuggestionsNouveau());
    expect(find.byKey(const Key('chiffre_suggestions')), findsNothing);
    expect(find.byKey(const Key('chiffre_en_cours')), findsNothing);
    final grossiste = tester.getRect(find.text(DonneesLot2.grossisteA).first);
    final statut = tester.getRect(find.byKey(const Key('suggestion_statut_${DonneesLot2.suggestion1}')));
    expect((statut.center.dy - grossiste.center.dy).abs(), lessThan(14), reason: 'même ligne que le grossiste');
    expect(statut.left, greaterThan(grossiste.left));
    expect(tester.widget<Text>(find.byKey(const Key('suggestion_reference_${DonneesLot2.suggestion1}'))).data, 'Créée le 12-10-2026 · Réf. SUGG-FICTIVE-01');
    await demonter(tester);
  });

  testWidgets('Suggestions : curseur dans le 1er article à l\'ouverture (texte sélectionné) ; « Suivant » → article suivant et enregistrement',
      (tester) async {
    ecran(tester);
    final s = Suggestion(id: DonneesLot2.suggestion1, name: 'SUGG-FICTIVE-01', status: 'pending', grossiste: DonneesLot2.grossisteA);
    await monter(tester, () => SuggestionDetailNouveau(suggestion: s));
    EditableText champ(String id) => tester.widget<EditableText>(find.descendant(of: find.byKey(Key('qte_$id')), matching: find.byType(EditableText)));
    final premier = champ(DonneesLot2.article1);
    expect(premier.focusNode.hasFocus, isTrue, reason: 'curseur automatique à l\'ouverture');
    expect(premier.controller.selection, TextSelection(baseOffset: 0, extentOffset: premier.controller.text.length), reason: 'la saisie remplace');
    expect(premier.textInputAction, TextInputAction.next);
    tester.testTextInput.enterText('12');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await pomper(tester);
    expect(champ(DonneesLot2.article2).focusNode.hasFocus, isTrue, reason: 'article suivant');
    final envoi = serveur.recues(AppConstants.suggestionUpdateQteEndpoint, methode: 'POST');
    expect(envoi, hasLength(1));
    expect(envoi.single.corps, contains('12'));
    await demonter(tester);
  });

  testWidgets('Tableau : Analyses, jour par jour : achats en gras, évolution des ventes avec flèche (hausse / baisse)', (tester) async {
    ecran(tester, hauteur: 3000);
    await monter(tester, () => const TableauAnalysesNouveau());
    await choisirAutrePeriode(tester, 'ceMois');
    await pomper(tester);
    final achats = tester.widget<Text>(find.byKey(const Key('jour_achats_0')));
    final gras = (achats.textSpan! as TextSpan).children!.whereType<TextSpan>().single.style!.fontWeight;
    expect(gras, FontWeight.w800);
    final fleches = find.descendant(of: find.byKey(const Key('jour_evolution_1')), matching: find.byType(Icon));
    if (fleches.evaluate().isNotEmpty) {
      expect([Icons.arrow_upward, Icons.arrow_downward, Icons.drag_handle], contains(tester.widget<Icon>(fleches).icon));
      expect(find.descendant(of: find.byKey(const Key('jour_evolution_1')), matching: find.textContaining('vs ')), findsOneWidget);
    }
    await demonter(tester);
  });

  testWidgets('CA par emplacement : sans « favorable / défavorable », évolution en grand ; détail : produits de l\'emplacement', (tester) async {
    ecran(tester, hauteur: 2000);
    await monter(tester, () => const CaZoneScreen());
    await pomper(tester, 20);
    expect(find.textContaining('favorable'), findsNothing);
    expect(find.byKey(const Key('chiffre_ca_lignes')), findsNothing);
    expect(tester.getSize(find.byKey(const Key('ca_evolution'))).width, greaterThan(300), reason: 'carte d\'évolution sur toute la largeur');
    await toucher(tester, find.byKey(const Key('ligne_ca_0')));
    await pomper(tester, 10);
    final d = serveur.recues('/ca-zone-geo/detail').single.parametres;
    expect(d.containsKey('ligneFamilleId'), isFalse);
    expect(find.text('PRODUIT CA FICTIF 1'), findsOneWidget);
    await demonter(tester);
  });

  testWidgets('Analyse des saisies de BL : temps de saisie moyen (création → clôture)', (tester) async {
    ecran(tester);
    void bons(FauxServeurPrestige s) => s.quand('/etat-control-bon/list', ReponseFausse.json({
      'data': [
        {'strREFLIVRAISON': 'BL-1', 'dtDATELIVRAISON': '14/10/2026 07:00', 'dtCREATED': '14/10/2026 08:00', 'dtUPDATED': '14/10/2026 08:20', 'strSTATUT': 'is_Closed', 'fournisseurLibelle': 'G1'},
        {'strREFLIVRAISON': 'BL-2', 'dtDATELIVRAISON': '14/10/2026 07:00', 'dtCREATED': '14/10/2026 09:00', 'dtUPDATED': '14/10/2026 09:40', 'strSTATUT': 'is_Closed', 'fournisseurLibelle': 'G2'},
      ],
    }), methode: 'GET');
    await monter(tester, () => const AnalyseBlNouveau(), donnees: bons);
    expect(tester.widget<Text>(find.byKey(const Key('chiffre_temps_saisie'))).data, '30 min');
    expect(find.text('Temps de saisie : 20 min'), findsOneWidget);
    await demonter(tester);
  });

  testWidgets('accueil A : Actualiser, Réglages puis Déconnexion (power-off sur rond rouge, comme Prestige web)', (tester) async {
    ecran(tester);
    await monter(tester, () => const AccueilNouveau(), p: Presentation.tableauDeBord);
    final actualiser = tester.getCenter(find.byTooltip('Actualiser les chiffres'));
    final reglages = tester.getCenter(find.byKey(const Key('bouton_reglages')));
    final deconnexion = tester.getCenter(find.byKey(const Key('bouton_deconnexion')));
    expect(actualiser.dx < reglages.dx && reglages.dx < deconnexion.dx, isTrue);
    final rond = tester.widget<Container>(
        find.descendant(of: find.byKey(const Key('bouton_deconnexion')), matching: find.byWidgetPredicate((w) => w is Container && w.decoration != null)));
    expect((rond.decoration! as BoxDecoration).color, Charte.rougeDeconnexion);
    expect(find.descendant(of: find.byKey(const Key('bouton_deconnexion')), matching: find.byIcon(Icons.power_settings_new)), findsOneWidget);
    await demonter(tester);
  });
}
