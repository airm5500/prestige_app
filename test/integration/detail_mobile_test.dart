// Intégration du détail Mobile Money du Détail CA (nouvelle interface) contre le faux serveur Prestige (client
// « en mémoire », horloge simulée) :
//  - AUCUN appel à /stats-recette-caisse/modes à l'ouverture ni sans dépliage ; un seul au premier dépliage, avec
//    EXACTEMENT les dates de /ca-all ; repli / redépliage sans nouvel appel ; nouvelle période → replié, nouvel appel
//    au prochain dépliage avec les nouvelles dates ;
//  - montants, taux (part du Mobile Money, part du Total brut paiements), ligne « Autres / écart » et sa note ;
//  - erreurs 500 / 401 / délai / droit : affichées DANS la ligne dépliée, les chiffres de /ca-all restent affichés ;
//  - champ futur « detailMobile » de /ca-all : utilisé sans appel complémentaire, sans ligne d'écart ;
//  - tablette : détail en tableau (4 colonnes).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/detail_ca_donnees.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/modules/detail_ca_nouveau.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/donnees_fictives.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();
const routeModes = DetailCa.routeModes;

Future<void> pomper(WidgetTester tester, [int fois = 10]) async {
  for (var i = 0; i < fois; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void ecran(WidgetTester tester, {double largeur = 411, double hauteur = 5000}) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = Size(largeur * 2.625, hauteur * 2.625);
  addTearDown(tester.view.reset);
}

Future<void> monter(WidgetTester tester) async {
  preparerTelephone(serveur, nouvelle: true);
  ApiService.client = serveur.clientMemoire();
  serveur.oublierRequetes();
  await ecranConnecte(() => const DetailCaNouveau())(tester, serveur);
  await pomper(tester);
}

Future<void> demonter(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 2));
}

Future<void> deplier(WidgetTester tester, {String cle = 'deplier_mobile'}) async {
  await tester.ensureVisible(find.byKey(Key(cle)));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.byKey(Key(cle)));
  await pomper(tester, 5);
}

String chiffre(WidgetTester tester, String id) => tester.widget<Text>(find.byKey(Key('chiffre_$id'))).data!;

String taux(num montant, num total) => '${(montant / total * 100).toStringAsFixed(1).replaceAll('.', ',')} %';

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);

  setUp(() {
    serveur
      ..installerRoutesParDefaut()
      ..coupe = false;
    donneesLot1(serveur);
  });

  tearDown(restaurerClient);

  testWidgets('aucun appel avant dépliage ; un seul au premier dépliage, mêmes dates que /ca-all ; repli sans appel', (tester) async {
    ecran(tester);
    await monter(tester);
    expect(find.byKey(const Key('chiffre_total')), findsOneWidget);
    expect(serveur.recues(AppConstants.caComptantEndpoint), hasLength(1));
    expect(serveur.recues(routeModes), isEmpty, reason: 'pas d\'appel à l\'ouverture');
    expect(find.byKey(const Key('detail_mobile')), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(serveur.recues(routeModes), isEmpty, reason: 'toujours aucun appel sans dépliage');

    await deplier(tester);
    expect(serveur.recues(routeModes), hasLength(1));
    expect(serveur.recues(routeModes).single.parametres, serveur.recues(AppConstants.caComptantEndpoint).single.parametres);
    expect(find.byKey(const Key('detail_mobile')), findsOneWidget);

    // Opérateurs triés, montants, taux (bases : totMobile et Total brut paiements de /ca-all).
    final libelles = ['Orange', 'Wave', 'MTN', 'Moov', 'Autres / écart'];
    final ys = [for (final l in libelles) tester.getTopLeft(find.byKey(Key('mobile_ligne_$l'))).dy];
    expect([...ys]..sort(), ys, reason: 'ordre décroissant, écart en dernier');
    final orange = find.byKey(const Key('mobile_ligne_Orange'));
    expect(find.descendant(of: orange, matching: find.text(formaterMontant(DonneesFictives.mobileOrange))), findsOneWidget);
    expect(
        find.descendant(
            of: orange,
            matching: find.text('${taux(DonneesFictives.mobileOrange, DonneesFictives.totMobileCa)} du Mobile Money · '
                '${taux(DonneesFictives.mobileOrange, DonneesFictives.totalBrutCa)} du CA')),
        findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('mobile_ligne_Autres / écart')), matching: find.text(formaterMontant(2750))), findsOneWidget);
    expect(find.byKey(const Key('mobile_note_ecart')), findsOneWidget);
    expect(find.textContaining('différence de calcul entre deux sources du serveur'), findsOneWidget);
    expect(find.byKey(const Key('mobile_ligne_Espèces')), findsNothing, reason: 'lignes mobile:false de /modes ignorées');
    expect(find.byKey(const Key('mobile_ligne_Carte bancaire')), findsNothing);
    // Les chiffres de /ca-all sont inchangés.
    expect(chiffre(tester, 'total'), formaterMontant(DonneesFictives.totalBrutCa));
    expect(chiffre(tester, 'mobile'), formaterMontant(DonneesFictives.totMobileCa));

    await deplier(tester); // repli
    expect(find.byKey(const Key('detail_mobile')), findsNothing);
    await deplier(tester); // redépliage : déjà chargé
    expect(find.byKey(const Key('detail_mobile')), findsOneWidget);
    expect(serveur.recues(routeModes), hasLength(1));
    await demonter(tester);
  });

  testWidgets('la flèche du chiffre clé déplie le même détail ; nouvelle période → replié, nouvel appel avec les nouvelles dates', (tester) async {
    ecran(tester);
    await monter(tester);
    await deplier(tester, cle: 'deplier_mobile_kpi');
    expect(find.byKey(const Key('detail_mobile')), findsOneWidget);
    expect(serveur.recues(routeModes), hasLength(1));
    await deplier(tester, cle: 'deplier_mobile_kpi');
    expect(find.byKey(const Key('detail_mobile')), findsNothing);
    await deplier(tester, cle: 'deplier_mobile_kpi');

    await choisirAutrePeriode(tester, 'septJours');
    await pomper(tester);
    expect(serveur.recues(AppConstants.caComptantEndpoint), hasLength(2));
    expect(find.byKey(const Key('detail_mobile')), findsNothing, reason: 'nouvelle période : replié');
    expect(serveur.recues(routeModes), hasLength(1), reason: 'pas d\'appel tant qu\'on ne redéplie pas');
    await deplier(tester);
    expect(serveur.recues(routeModes), hasLength(2));
    expect(serveur.recues(routeModes).last.parametres, serveur.recues(AppConstants.caComptantEndpoint).last.parametres);
    await demonter(tester);
  });

  testWidgets('500 : erreur DANS la ligne dépliée (chiffres de /ca-all intacts), « Réessayer » → détail', (tester) async {
    ecran(tester);
    serveur.quand(routeModes, ReponseFausse.erreurServeur(), methode: 'GET');
    await monter(tester);
    await deplier(tester);
    expect(find.byKey(const Key('mobile_erreur_serveur')), findsOneWidget);
    expect(find.byType(EtatErreur), findsNothing, reason: 'l\'écran n\'est pas remplacé par une erreur');
    expect(chiffre(tester, 'total'), formaterMontant(DonneesFictives.totalBrutCa));
    serveur.quand(routeModes, ReponseFausse.json(DonneesFictives.modesPaiement()), methode: 'GET');
    await tester.tap(find.byKey(const Key('mobile_reessayer')));
    await pomper(tester, 5);
    expect(find.byKey(const Key('mobile_ligne_Orange')), findsOneWidget);
    expect(serveur.recues(routeModes), hasLength(2));
    await demonter(tester);
  });

  testWidgets('délai dépassé (${ApiService.delaiGet.inSeconds} s) : chargement puis erreur locale « ne répond pas »', (tester) async {
    ecran(tester);
    serveur.quand(routeModes, ReponseFausse.sansReponse(), methode: 'GET');
    await monter(tester);
    await deplier(tester);
    expect(find.byKey(const Key('mobile_chargement')), findsOneWidget);
    await tester.pump(ApiService.delaiGet + const Duration(seconds: 1));
    await pomper(tester, 3);
    expect(find.byKey(const Key('mobile_erreur_delai')), findsOneWidget);
    expect(find.byKey(const Key('mobile_reessayer')), findsOneWidget);
    expect(chiffre(tester, 'total'), formaterMontant(DonneesFictives.totalBrutCa));
    await demonter(tester);
  });

  testWidgets('401 : « Session expirée » dans la ligne dépliée (et mécanisme de reconnexion existant prévenu)', (tester) async {
    ecran(tester);
    var prevenu = 0;
    serveur.quand(routeModes, ReponseFausse.sessionExpiree(), methode: 'GET');
    await monter(tester);
    final avant = ApiService.surSessionExpiree;
    ApiService.surSessionExpiree = () => prevenu++;
    addTearDown(() => ApiService.surSessionExpiree = avant);
    await deplier(tester);
    expect(find.byKey(const Key('mobile_erreur_session')), findsOneWidget);
    expect(find.byType(EtatErreur), findsNothing);
    expect(chiffre(tester, 'total'), formaterMontant(DonneesFictives.totalBrutCa));
    expect(prevenu, 1, reason: 'la règle « 401 → reconnexion » de l\'application reste appliquée');
    await demonter(tester);
  });

  testWidgets('refus (success:false) : « Droit manquant » local, sans « Réessayer »', (tester) async {
    ecran(tester);
    serveur.quand(routeModes, ReponseFausse.refus('Accès refusé'), methode: 'GET');
    await monter(tester);
    await deplier(tester);
    expect(find.byKey(const Key('mobile_erreur_droit')), findsOneWidget);
    expect(find.byKey(const Key('mobile_reessayer')), findsNothing);
    await demonter(tester);
  });

  testWidgets('champ « detailMobile » de /ca-all (réponse simulée) : utilisé en priorité, AUCUN appel, aucune ligne d\'écart', (tester) async {
    ecran(tester);
    serveur.quand(AppConstants.caComptantEndpoint, ReponseFausse.json(DonneesFictives.caParJourAvecDetail()), methode: 'GET');
    await monter(tester);
    expect(chiffre(tester, 'total'), formaterMontant(DonneesFictives.totalBrutCa), reason: 'chiffres inchangés');
    await deplier(tester);
    expect(serveur.recues(routeModes), isEmpty);
    expect(find.byKey(const Key('mobile_ligne_Orange')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('mobile_ligne_Wave')), matching: find.text(formaterMontant(80750))), findsOneWidget);
    expect(find.byKey(const Key('mobile_ligne_Moov')), findsNothing);
    expect(find.byKey(const Key('mobile_ligne_Autres / écart')), findsNothing);
    expect(find.byKey(const Key('mobile_note_ecart')), findsNothing);
    await demonter(tester);
  });

  testWidgets('aucun Mobile Money sur la période : message, aucun appel', (tester) async {
    ecran(tester);
    serveur.quand(AppConstants.caComptantEndpoint,
        ReponseFausse.json([
          {'mvtDate': '20261013', 'totEsp': 1000, 'totMobile': 0}
        ]),
        methode: 'GET');
    await monter(tester);
    await deplier(tester);
    expect(find.byKey(const Key('mobile_vide')), findsOneWidget);
    expect(serveur.recues(routeModes), isEmpty);
    await demonter(tester);
  });

  testWidgets('tablette : détail en tableau (opérateur, montant, part du Mobile Money, part du CA)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1920, 3000);
    addTearDown(tester.view.reset);
    await monter(tester);
    await deplier(tester);
    expect(find.text('PART MOBILE MONEY'), findsOneWidget);
    expect(find.text('PART DU CA'), findsOneWidget);
    final orange = find.byKey(const Key('mobile_ligne_Orange'));
    expect(find.descendant(of: orange, matching: find.text(taux(DonneesFictives.mobileOrange, DonneesFictives.totMobileCa))), findsOneWidget);
    expect(find.descendant(of: orange, matching: find.text(taux(DonneesFictives.mobileOrange, DonneesFictives.totalBrutCa))), findsOneWidget);
    await demonter(tester);
  });
}
