// PERFORMANCE — rendu et défilement des LONGUES LISTES de la nouvelle interface (téléphone 411 dp), contre le faux
// serveur Prestige « en mémoire » :
//  - Suivi Crédit : 1 000 tiers payants (une réponse) ;
//  - Suggestions : une suggestion de 500 lignes (un champ de quantité par ligne) ;
//  - Visualisation BL : 1 000 bons, pages de 20 (« Afficher plus » × 49) ;
//  - Fichier Journal : pages de 50 jusqu'à 500 actions (« Afficher plus » × 9) ;
//  - Prévisions : 1 000 produits, pages de 25 (« Afficher plus » × 39) ;
//  - CA emplacement / famille : 60 tranches × 40 lignes (tableau des tranches défilant).
// Pour chaque écran : temps d'ouverture (à froid), pire image d'un « Afficher plus » quand la liste est déjà longue,
// puis chaque image chronométrée pendant un défilement complet — 1er passage (à froid : code compilé à la volée,
// seuil large) puis 2e passage (aucune image au-dessus du budget). Seuils : test/support/performance.dart et README.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/suggestion_model.dart';
import 'package:prestige_app/nouvelle_interface/modules/fichier_journal_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suggestions_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suivi_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/visualisation_bl_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague2/ca_zone_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/previsions_vague2.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/donnees_lot2.dart';
import '../support/donnees_lot4.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/grandes_donnees.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

/// Touche « Afficher plus » jusqu'à ce que le serveur ait reçu [pages] requêtes sur [route] (une par page) ; chaque
/// page suivante est chronométrée, de l'appui à l'image où elle est ajoutée.
Future<ChronoImages> toutAfficher(WidgetTester tester, String cleListe, String route, int pages) async {
  final chrono = ChronoImages();
  final bouton = find.byKey(const Key('bouton_afficher_plus'));
  final liste = listeDefilante(tester, cle: cleListe);
  while (serveur.recues(route).length < pages) {
    // Le bouton est au bas de la liste (construite à la demande) : on y va directement.
    final etat = tester.state<ScrollableState>(liste);
    for (var i = 0; i < 20 && bouton.hitTestable().evaluate().isEmpty; i++) {
      etat.position.jumpTo(etat.position.maxScrollExtent);
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(bouton.hitTestable(), findsOneWidget, reason: '« Afficher plus » (${serveur.recues(route).length} pages sur $pages)');
    final avant = serveur.recues(route).length;
    final sw = Stopwatch()..start();
    await tester.tap(bouton);
    await tester.pump(); // appui : indicateur, requête
    await tester.pump(); // réponse du faux serveur : page ajoutée
    chrono.ms.add(sw.elapsedMicroseconds / 1000);
    expect(serveur.recues(route).length, avant + 1, reason: 'un appui = une requête');
    await tester.pump(const Duration(milliseconds: 100));
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

  testWidgets('Suivi Crédit : 1 000 tiers payants, ouverture puis défilement fluide', (tester) async {
    telephone(tester);
    serveur.quand(AppConstants.suiviCreditEndpoint, ReponseFausse.json(GrandesDonnees.credits(1000)), methode: 'GET');
    final ms = await ouvrirEcran(tester, serveur, const SuiviCreditNouveau(), pret: find.byKey(const Key('chiffre_montant')));
    mesurer('Suivi Crédit, 1 000 lignes — ouverture', ms, seuil: Seuils.ouvertureListeMs, unite: 'ms');
    expect(find.text('1 000'), findsOneWidget, reason: '1 000 tiers payants comptés');
    await deuxPassages(tester, 'Suivi Crédit, 1 000 lignes', cle: 'defilement_module');
    expect(find.text('TIERS PAYANT FICTIF 1000'), findsOneWidget, reason: 'dernière ligne atteinte');
    await fermerApplication(tester);
  });

  testWidgets('Suggestions : une suggestion de 500 lignes (un champ par ligne), ouverture puis défilement', (tester) async {
    telephone(tester);
    donneesLot2(serveur);
    serveur
      ..quand(AppConstants.suggestionListItemsEndpoint, ReponseFausse.json(GrandesDonnees.lignesSuggestion(500)), methode: 'GET')
      ..quand('${AppConstants.suggestionAmountEndpoint}/SUG-PERF', ReponseFausse.json(DonneesLot2.montantSuggestion()), methode: 'GET');
    final s = Suggestion(id: 'SUG-PERF', name: 'SUGG-FICTIVE-PERF', status: 'pending', grossiste: DonneesLot2.grossisteA);
    final ms = await ouvrirEcran(tester, serveur, SuggestionDetailNouveau(suggestion: s), pret: find.byKey(const Key('ligne_ITEM-PERF-1')));
    mesurer('Suggestions, 500 lignes — ouverture', ms, seuil: Seuils.ouvertureListeMs, unite: 'ms');
    await deuxPassages(tester, 'Suggestions, 500 lignes', cle: 'defilement_detail');
    expect(find.byKey(const Key('ligne_ITEM-PERF-500')), findsOneWidget, reason: 'dernière ligne atteinte');
    await fermerApplication(tester);
  });

  testWidgets('Visualisation BL : 1 000 bons par pages de 20 (« Afficher plus » × 49), puis défilement', (tester) async {
    telephone(tester);
    donneesLot2(serveur);
    serveur.route('/etat-control-bon/list', (r) => GrandesDonnees.pageBons(r, 1000), methode: 'GET');
    final ms = await ouvrirEcran(tester, serveur, const VisualisationBlNouveau(), pret: find.byKey(const Key('chiffre_ttc')));
    mesurer('Visualisation BL — ouverture (1re page de 20)', ms, seuil: Seuils.ouvertureListeMs, unite: 'ms');
    final pages = await toutAfficher(tester, 'defilement_module', '/etat-control-bon/list', 50);
    expect(serveur.recues('/etat-control-bon/list'), hasLength(50), reason: '1 000 bons = 50 pages de 20, une requête chacune');
    mesurer('Visualisation BL — pire « Afficher plus » (jusqu\'à 1 000 bons)', pages.max, seuil: Seuils.pageSuivanteMs, unite: 'ms', detail: pages.resume);
    await deuxPassages(tester, 'Visualisation BL, 1 000 bons', cle: 'defilement_module');
    expect(find.textContaining('BL BL-PERF-1000 '), findsOneWidget, reason: 'dernier bon atteint');
    await fermerApplication(tester);
  });

  testWidgets('Fichier Journal : pages de 50 jusqu\'à 500 actions (« Afficher plus » × 9), puis défilement', (tester) async {
    telephone(tester);
    donneesLot4(serveur);
    serveur.route(AppConstants.fichierJournalEndpoint, (r) => DonneesLot4.journalPour(r, nombre: 500), methode: 'GET');
    final ms = await ouvrirEcran(tester, serveur, const FichierJournalNouveau(), pret: find.byKey(const Key('chiffre_actions')));
    mesurer('Fichier Journal — ouverture (1re page de 50)', ms, seuil: Seuils.ouvertureListeMs, unite: 'ms');
    final pages = await toutAfficher(tester, 'defilement_module', AppConstants.fichierJournalEndpoint, 10);
    expect(serveur.recues(AppConstants.fichierJournalEndpoint), hasLength(10), reason: '500 actions = 10 pages de 50');
    mesurer('Fichier Journal — pire « Afficher plus » (jusqu\'à 500 actions)', pages.max, seuil: Seuils.pageSuivanteMs, unite: 'ms', detail: pages.resume);
    await deuxPassages(tester, 'Fichier Journal, 500 actions', cle: 'defilement_module');
    await fermerApplication(tester);
  });

  testWidgets('Prévisions : 1 000 produits par pages de 25 (« Afficher plus » × 39), puis défilement', (tester) async {
    telephone(tester);
    serveur.route('/analyse-commande/previsions', (r) => ReponseFausse.json(GrandesDonnees.previsions(r.parametres, 1000)), methode: 'GET');
    final ms = await ouvrirEcran(tester, serveur, const PrevisionsScreen(), pret: find.byKey(const Key('previsions_total')));
    mesurer('Prévisions — ouverture (1re page de 25)', ms, seuil: Seuils.ouvertureListeMs, unite: 'ms');
    final pages = await toutAfficher(tester, 'defilement_previsions', '/analyse-commande/previsions', 40);
    expect(serveur.recues('/analyse-commande/previsions'), hasLength(40), reason: '1 000 produits = 40 pages de 25');
    mesurer('Prévisions — pire « Afficher plus » (jusqu\'à 1 000 produits)', pages.max, seuil: Seuils.pageSuivanteMs, unite: 'ms', detail: pages.resume);
    await deuxPassages(tester, 'Prévisions, 1 000 produits', cle: 'defilement_previsions');
    expect(find.byKey(const Key('prevision_PRD-PREV-1000')), findsOneWidget, reason: 'dernier produit atteint');
    await fermerApplication(tester);
  });

  testWidgets('CA emplacement / famille (téléphone) : 60 tranches × 40 lignes, ouverture puis défilement', (tester) async {
    telephone(tester);
    serveur.route('/ca-zone-geo', (r) => ReponseFausse.json(GrandesDonnees.caZone(tranches: 60, lignes: 40)), methode: 'GET');
    final ms = await ouvrirEcran(tester, serveur, CaZoneScreen(maintenant: () => DateTime(2026, 10, 14)), pret: find.byKey(const Key('chiffre_ca_total')));
    mesurer('CA emplacement, 60 tranches × 40 lignes (téléphone) — ouverture', ms, seuil: Seuils.ouvertureListeMs, unite: 'ms');
    await deuxPassages(tester, 'CA emplacement, 60 tranches × 40 lignes (téléphone)', cle: 'defilement_ca');
    expect(find.byKey(const Key('ligne_ca_39')), findsOneWidget, reason: 'dernière ligne atteinte');
    await fermerApplication(tester);
  });

  testWidgets('CA emplacement / famille (tablette) : tableau de 60 tranches, défilements vertical et horizontal', (tester) async {
    tester.view.devicePixelRatio = 1.5;
    tester.view.physicalSize = const Size(1920, 1200);
    addTearDown(tester.view.reset);
    serveur.route('/ca-zone-geo', (r) => ReponseFausse.json(GrandesDonnees.caZone(tranches: 60, lignes: 40)), methode: 'GET');
    final ms = await ouvrirEcran(tester, serveur, CaZoneScreen(maintenant: () => DateTime(2026, 10, 14)), pret: find.byKey(const Key('chiffre_ca_total')));
    mesurer('CA emplacement, 60 tranches × 40 lignes (tablette) — ouverture', ms, seuil: Seuils.ouvertureListeMs, unite: 'ms');
    await deuxPassages(tester, 'CA emplacement, 60 tranches (tablette)', cle: 'defilement_ca', minPas: 5);
    final tableau = find.byKey(const Key('ca_tableau_defilement'));
    await tester.ensureVisible(tableau);
    await tester.pump();
    final s = find.descendant(of: tableau, matching: find.byType(Scrollable)).first;
    final chrono = ChronoImages();
    await defilerJusquEnBas(tester, s, chrono, pas: 200);
    expect(chrono.nombre, greaterThanOrEqualTo(5), reason: '60 colonnes : le tableau défile en largeur');
    mesurer('CA emplacement, 60 tranches (tablette) — pire image, défilement horizontal du tableau', chrono.max,
        seuil: Seuils.imageDefilementMs, unite: 'ms', detail: chrono.resume);
    await fermerApplication(tester);
  });
}
