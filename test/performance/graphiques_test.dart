// PERFORMANCE — GRAPHIQUES de la nouvelle interface (téléphone 411 dp), faux serveur « en mémoire » :
//  - Tableau : Analyses sur 3 ans (1 096 jours d'achats et de ventes) : ouverture (lecture, tri, courbes), passage
//    Comparée → Achats → Ventes → Comparée (pire image), toucher de la courbe (valeurs du jour), défilement du
//    « jour par jour » (1 096 cartes) ;
//  - Évolution du stock sur 3 ans (1 096 points) : ouverture, toucher de la courbe, « Afficher tous les jours ».
// La période choisie à l'écran ne change rien au calcul mesuré : le faux serveur rend 3 ans de points.
// Seuils : test/support/performance.dart (README « Seuils de performance »).
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/modules/evolution_stock_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/tableau_analyses_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/faux_serveur_prestige.dart';
import '../support/grandes_donnees.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();
final aujourdhui = DateTime(2026, 10, 14);
const jours3Ans = 1096;

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

/// Touche le graphique [graphique] en 5 points (valeurs d'un jour) : pire image.
Future<ChronoImages> toucherCourbe(WidgetTester tester, Finder graphique) async {
  final chrono = ChronoImages();
  final zone = tester.getRect(graphique);
  for (final f in [0.1, 0.3, 0.5, 0.7, 0.9]) {
    final geste = await tester.startGesture(Offset(zone.left + zone.width * f, zone.center.dy));
    await chrono.pump(tester);
    await geste.up();
    await chrono.pump(tester);
  }
  return chrono;
}

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() {
    brancherEnMemoire(serveur);
    preparerNouvelle(serveur, p: Presentation.compact);
  });

  testWidgets('Tableau : Analyses sur 3 ans (1 096 jours) : ouverture, changement de vue, toucher, défilement', (tester) async {
    telephone(tester);
    serveur.quand(AppConstants.tableauBordAchatsVentesEndpoint, ReponseFausse.json(GrandesDonnees.achatsVentes(jours3Ans, aujourdhui)), methode: 'GET');
    final ms = await ouvrirEcran(tester, serveur, TableauAnalysesNouveau(maintenant: () => aujourdhui), pret: find.byKey(const Key('chiffre_ventes')));
    mesurer('Tableau : Analyses, 3 ans — ouverture (courbes + jour par jour)', ms, seuil: Seuils.ouvertureGraphiqueMs, unite: 'ms');
    expect(find.text('$jours3Ans jours'), findsOneWidget, reason: '3 ans de jours lus');
    final vues = ChronoImages();
    for (final v in ['achats', 'ventes', 'comparee']) {
      await tester.ensureVisible(find.byKey(Key('graphique_$v')));
      await tester.pump();
      await tester.tap(find.byKey(Key('graphique_$v')));
      await vues.pump(tester);
      await tester.pump(const Duration(milliseconds: 400));
    }
    mesurer('Tableau : Analyses, 3 ans — pire image d\'un changement de vue', vues.max, seuil: Seuils.imageGraphiqueMs, unite: 'ms', detail: vues.resume);
    final courbe = find.byType(GraphiqueAchatsVentes);
    await tester.ensureVisible(courbe);
    await tester.pump();
    final toucher = await toucherCourbe(tester, courbe);
    mesurer('Tableau : Analyses, 3 ans — pire image au toucher de la courbe', toucher.max, seuil: Seuils.imageGraphiqueMs, unite: 'ms',
        detail: toucher.resume);
    await deuxPassages(tester, 'Tableau : Analyses, 3 ans (jour par jour)', cle: 'defilement_module');
    await fermerApplication(tester);
  });

  testWidgets('Évolution du stock sur 3 ans (1 096 points) : ouverture, toucher de la courbe, tous les jours', (tester) async {
    telephone(tester);
    serveur.quand(AppConstants.valorisationAllEndpoint, ReponseFausse.json(GrandesDonnees.valorisations(jours3Ans)), methode: 'GET');
    final ms = await ouvrirEcran(tester, serveur, EvolutionStockNouveau(maintenant: () => aujourdhui), pret: find.byKey(const Key('chiffre_fin')));
    mesurer('Évolution du stock, 3 ans — ouverture (courbe)', ms, seuil: Seuils.ouvertureGraphiqueMs, unite: 'ms');
    final graphique = find.byType(LineChart);
    await tester.ensureVisible(graphique);
    await tester.pump();
    final toucher = await toucherCourbe(tester, graphique);
    mesurer('Évolution du stock, 3 ans — pire image au toucher de la courbe', toucher.max, seuil: Seuils.imageGraphiqueMs, unite: 'ms',
        detail: toucher.resume);
    final tous = find.byKey(const Key('evolution_tous_les_jours'));
    final liste = listeDefilante(tester, cle: 'defilement_module');
    for (var i = 0; i < 40 && tous.evaluate().isEmpty; i++) {
      tester.state<ScrollableState>(liste).position.jumpTo(tester.state<ScrollableState>(liste).position.maxScrollExtent);
      await tester.pump();
    }
    await tester.ensureVisible(tous);
    await tester.pump();
    final sw = Stopwatch()..start();
    await tester.tap(tous);
    await tester.pump();
    mesurer('Évolution du stock, 3 ans — « Afficher tous les jours » (1 096 cartes)', sw.elapsedMicroseconds / 1000,
        seuil: Seuils.pageSuivanteMs, unite: 'ms');
    await deuxPassages(tester, 'Évolution du stock, 3 ans (tous les jours)', cle: 'defilement_module');
    await fermerApplication(tester);
  });
}
