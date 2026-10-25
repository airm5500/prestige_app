// PERFORMANCE — nouveautés 3.11.0 (téléphone 411 dp et Sunmi 360 dp), contre le faux serveur Prestige « en mémoire » :
//  - tableau de bord : ouverture, défilement complet (chaque carte charge à son arrivée : une requête par carte),
//    pire image ; requêtes exactes ;
//  - Balance vente / caisse : requêtes par onglet (Balance 1 ; Analyse 1 ; Évolution par mode 0 : même appel ;
//    Surveiller 0 : comptage à la demande) ; pire image au changement d'onglet ;
//  - Sur-stocks : 120 produits par pages de 50 (« Afficher plus ») puis défilement complet ;
//  - Suggestion de 500 lignes : passage d'un article au suivant (« Suivant » du clavier), image par image.
// Seuils : test/support/performance.dart et test/README.md (« Seuils de performance »).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/suggestion_model.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suggestions_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague4/balance_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/donnees_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/surstock_vague4.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/donnees_lot2.dart';
import '../support/donnees_lot3.dart';
import '../support/donnees_vague1.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/grandes_donnees.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

void appareil(WidgetTester tester, {double dpr = 2.625, Size dp = const Size(411, 891)}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(dp.width * dpr, dp.height * dpr);
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() {
    brancherEnMemoire(serveur);
    donneesAccueil(serveur);
    listesCommunesVague1(serveur);
    donneesLot2(serveur);
    donneesLot3(serveur);
  });

  for (final (nom, dp) in const [('téléphone', Size(411, 891)), ('Sunmi', Size(360, 720))]) {
    testWidgets('tableau de bord ($nom) : ouverture, défilement complet, une requête par carte', (tester) async {
      appareil(tester, dpr: nom == 'Sunmi' ? 2.0 : 2.625, dp: dp);
      preparerNouvelle(serveur, p: Presentation.tableauPrestige, style: null);
      brancherEnMemoire(serveur);
      donneesAccueil(serveur);
      donneesLot3(serveur);
      final rs = await compter(serveur, () async {
        final ms = await ouvrirEcran(tester, serveur, const AccueilNouveau(), pret: find.byKey(const Key('chiffre_tb_ca')));
        mesurer('Tableau de bord ($nom) — ouverture', ms, seuil: Seuils.ouvertureListeMs, unite: 'ms');
        await deuxPassages(tester, 'Tableau de bord ($nom)', minPas: 4, cle: 'defilement_tableau_bord');
      });
      final cartes = rs.where((r) => r.chemin != '/officine' && r.chemin != '/licence/find' && r.chemin != AppConstants.authEndpoint).toList();
      // 8 cartes (3.15.0 : + Affluence), une lecture chacune (aucune relecture au second défilement).
      mesurer('Tableau de bord ($nom) — requêtes des cartes', cartes.length, seuil: 8, unite: 'requêtes', detail: detailRequetes(cartes));
      expect(cartes.map((r) => r.chemin).toSet(), {
        '/tableau-bord/tuiles', '/ws/ca-achats-ventes', '/pilotage/suivi/frequentation', '/tableau-bord/valorisation', '/tableau-bord/encaissements',
        '/tableau-bord/emplacements', '/tvas', '/tableau-bord/affluence',
      });
      await fermerApplication(tester);
    });
  }

  testWidgets('Balance vente / caisse : requêtes par onglet ; pire image au changement d\'onglet', (tester) async {
    appareil(tester);
    final ouverture = await compter(serveur, () async {
      final ms = await ouvrirEcran(tester, serveur, const BalanceCaisseScreen(), pret: find.byKey(const Key('chiffre_balance_net')));
      mesurer('Balance — ouverture', ms, seuil: Seuils.ouvertureListeMs, unite: 'ms');
    });
    expect(ouverture.where((r) => r.chemin.startsWith('/balance')).map((r) => r.chemin), [ApiBalance.route]);
    final chrono = ChronoImages();
    Future<List<RequeteRecue>> onglet(String cle) => compter(serveur, () async {
          await tester.tap(find.byKey(Key(cle)));
          for (var i = 0; i < 30; i++) {
            await chrono.pump(tester, const Duration(milliseconds: 16));
          }
        });
    expect((await onglet('balance_onglet_analyse')).map((r) => r.chemin), [ApiBalance.routeAnalyse]);
    expect(await onglet('balance_onglet_modes'), isEmpty, reason: 'même appel que l\'analyse');
    expect(await onglet('balance_onglet_surveiller'), isEmpty, reason: 'alertes comptées à la demande seulement');
    expect(await onglet('balance_onglet_balance'), isEmpty, reason: 'balance déjà chargée');
    mesurer('Balance — pire image au changement d\'onglet', chrono.max, seuil: Seuils.imageDefilementMs, unite: 'ms', detail: chrono.resume);
    await fermerApplication(tester);
  });

  testWidgets('Sur-stocks : 120 produits par pages de 50, puis défilement', (tester) async {
    appareil(tester);
    final ms = await ouvrirEcran(tester, serveur, const SurstocksScreen(), pret: find.byKey(const Key('chiffre_surstock_total')));
    mesurer('Sur-stocks — ouverture (1re page de 50)', ms, seuil: Seuils.ouvertureListeMs, unite: 'ms');
    final liste = listeDefilante(tester, cle: 'defilement_surstock');
    final chrono = ChronoImages();
    for (var page = 2; page <= 3; page++) {
      final etat = tester.state<ScrollableState>(liste);
      // Liste construite à la demande : son étendue grandit à mesure qu'on descend.
      for (var i = 0; i < 20 && find.byKey(const Key('bouton_afficher_plus')).hitTestable().evaluate().isEmpty; i++) {
        etat.position.jumpTo(etat.position.maxScrollExtent);
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('bouton_afficher_plus')));
      await chrono.pump(tester);
      await pomper(tester, () => serveur.recues(ApiSurstock.route).length == page, raison: 'page $page');
      await chrono.pump(tester);
    }
    mesurer('Sur-stocks — pire « Afficher plus »', chrono.max, seuil: Seuils.pageSuivanteMs, unite: 'ms', detail: chrono.resume);
    expect(serveur.recues(ApiSurstock.route).map((r) => r.parametres['start']), ['0', '50', '100']);
    await deuxPassages(tester, 'Sur-stocks, 120 produits', cle: 'defilement_surstock');
    expect(serveur.recues(ApiSurstock.routeInterdite), isEmpty);
    await fermerApplication(tester);
  });

  testWidgets('Suggestion de 500 lignes : « Suivant » du clavier, d\'article en article (20 fois)', (tester) async {
    appareil(tester);
    serveur
      ..quand(AppConstants.suggestionListItemsEndpoint, ReponseFausse.json(GrandesDonnees.lignesSuggestion(500)), methode: 'GET')
      ..quand('${AppConstants.suggestionAmountEndpoint}/SUG-PERF', ReponseFausse.json(DonneesLot2.montantSuggestion()), methode: 'GET');
    final s = Suggestion(id: 'SUG-PERF', name: 'SUGG-FICTIVE-PERF', status: 'pending', grossiste: DonneesLot2.grossisteA);
    await ouvrirEcran(tester, serveur, SuggestionDetailNouveau(suggestion: s), pret: find.byKey(const Key('ligne_ITEM-PERF-1')));
    final chrono = ChronoImages();
    for (var i = 0; i < 20; i++) {
      await tester.testTextInput.receiveAction(TextInputAction.next);
      for (var k = 0; k < 4; k++) {
        await chrono.pump(tester, const Duration(milliseconds: 50));
      }
    }
    final focus = tester.widget<EditableText>(find.descendant(of: find.byKey(const Key('qte_ITEM-PERF-21')), matching: find.byType(EditableText)));
    expect(focus.focusNode.hasFocus, isTrue, reason: '21e article atteint');
    mesurer('Suggestion de 500 lignes — pire image d\'un article au suivant', chrono.max, seuil: Seuils.imageDefilementMs, unite: 'ms', detail: chrono.resume);
    await fermerApplication(tester);
  });
}
