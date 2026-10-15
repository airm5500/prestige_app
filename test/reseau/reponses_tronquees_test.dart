// RÉSEAU — réponses TRONQUÉES et JSON PARTIEL :
//  - au niveau HTTP (vrai serveur local 127.0.0.1) : longueur annoncée non atteinte, connexion fermée au milieu du
//    corps → panne RÉSEAU (« Serveur injoignable », réessai possible), jamais une liste vide ni « aucune licence » ;
//  - réponse complète mais JSON partiel → « Réponse inattendue du serveur » (données), jamais une liste vide ;
//  - écritures : quantité d'une suggestion → jamais « enregistrée » sur une réponse coupée ou illisible ; annulation
//    d'une vente → état VÉRIFIÉ par relecture, jamais « refusée » sur une réponse illisible (3.9.1) ;
//  - à l'écran (application entière, faux serveur en mémoire) : message et « Réessayer », jamais « aucun résultat »,
//    puis les données au retour d'une réponse correcte ; chiffres de l'accueil A « Indisponible », pas 0.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/annulation_vente_donnees.dart';
import 'package:prestige_app/donnees/suggestions_donnees.dart';
import 'package:prestige_app/donnees/suivi_credit_donnees.dart';
import 'package:prestige_app/models/vente_stat_model.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suivi_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/visualisation_bl_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import '../outils/contexte_api.dart';
import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_lot2.dart';
import '../support/donnees_lot4.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';
import '../support/reseau.dart';

final serveur = FauxServeurPrestige();

const creditsPartiels = '{"data":[{"libelleTypeTiersPayant":"ASSURANCE","libelleTiersPayant":"ASSURANCE FICT';
const licencePartielle = '{"id":"LIC-ESSAI-0001","dateStart":"2026-01-01","dateE';

/// Appel réseau réel ; renvoie le résultat ou l'erreur levée.
Future<Object?> appel(WidgetTester tester, Future<Object?> Function() f) async {
  Object? resultat;
  await tester.runAsync(() async {
    try {
      resultat = await f();
    } catch (e) {
      resultat = e;
    }
  });
  await tester.pump();
  return resultat;
}

Matcher echec(NatureErreur nature, String texte) =>
    isA<ApiLoadException>().having((e) => e.nature, 'nature', nature).having((e) => e.message, 'message', contains(texte));

void main() {
  group('Services contre le vrai serveur HTTP local', () {
    setUp(() async {
      await serveur.demarrer();
      serveur
        ..oublierRequetes()
        ..controlerSession = false;
      utiliserReseauReel();
      preparerTelephone(serveur);
    });
    tearDown(() async {
      restaurerClient();
      await serveur.arreter();
      serveur
        ..installerRoutesParDefaut()
        ..controlerSession = true;
    });

    testWidgets('liste coupée pendant le transfert → « Serveur injoignable » (réseau), pas une liste vide', (tester) async {
      final ctx = await monterAvecProviders(tester);
      serveur.quand(AppConstants.suiviCreditEndpoint, ReponseFausse.tronquee(creditsPartiels));
      final r = await appel(tester, () => SuiviCredits.charger(ctx, DateTime(2026, 10, 14), DateTime(2026, 10, 14)));
      expect(r, echec(NatureErreur.reseau, 'injoignable'));
      serveur.quand('/common/rayons', ReponseFausse.tronquee('{"data":[{"id":"R1","libelle":"RAY'));
      expect(await appel(tester, () => ApiService().getRayons(ctx)), echec(NatureErreur.reseau, 'injoignable'));
    });

    testWidgets('JSON partiel dans une réponse complète → « Réponse inattendue » (données), pas une liste vide', (tester) async {
      final ctx = await monterAvecProviders(tester);
      serveur.quand(AppConstants.suiviCreditEndpoint, ReponseFausse.json(creditsPartiels));
      final r = await appel(tester, () => SuiviCredits.charger(ctx, DateTime(2026, 10, 14), DateTime(2026, 10, 14)));
      expect(r, echec(NatureErreur.reponse, ApiLoadException.messageReponse));
      serveur.quand('/common/rayons', ReponseFausse.json('{"data":[{"id":"R1","libelle":"RAY'));
      expect(await appel(tester, () => ApiService().getRayons(ctx)), echec(NatureErreur.reponse, 'Réponse inattendue'));
    });

    testWidgets('licence coupée → « injoignable » ; licence en JSON partiel → « réponse inattendue » ; jamais « aucune licence »', (tester) async {
      final licence = LicenceProvider();
      final ctx = await monterAvecProviders(tester, licence: licence);
      serveur.quand('/licence/find', ReponseFausse.tronquee(licencePartielle), methode: 'GET');
      await appel(tester, () => licence.checkLicence(ctx));
      expect(licence.status, LicenceStatus.error, reason: 'serveur en cause, pas la licence');
      expect(licence.dernierEchec?.issue, LicenceIssue.unreachable);
      serveur.quand('/licence/find', ReponseFausse.json(licencePartielle), methode: 'GET');
      await appel(tester, () => licence.checkLicence(ctx));
      expect(licence.status, LicenceStatus.error);
      expect(licence.dernierEchec?.issue, LicenceIssue.unexpectedResponse);
      expect(licence.status, isNot(LicenceStatus.notFound));
    });

    testWidgets('connexion coupée ou illisible : message, pas connecté, pas de session gardée', (tester) async {
      final auth = AuthProvider();
      final ctx = await monterAvecProviders(tester, auth: auth);
      for (final rep in [
        ReponseFausse.tronquee('{"success":true,"str_USER_ID":"USR-TEST-0001","str_FIRST'),
        ReponseFausse.json('{"success":true,"str_USER_ID":"USR-TEST-0001","str_FIRST'),
        ReponseFausse.coupee(),
      ]) {
        serveur.quand(AppConstants.authEndpoint, rep, methode: 'POST');
        final m = await appel(tester, () => auth.login(ctx, DonneesFictives.identifiant, DonneesFictives.motDePasse, false));
        expect(m, isA<String>(), reason: 'message affiché');
        expect(auth.isLoggedIn, isFalse);
      }
    });

    testWidgets('quantité d\'une suggestion : réponse coupée ou illisible → jamais « enregistrée » (exception)', (tester) async {
      final ctx = await monterAvecProviders(tester);
      for (final (rep, nature) in [
        (ReponseFausse.tronquee('{"success":tr'), NatureErreur.reseau),
        (ReponseFausse.json('{"success":tr'), NatureErreur.reponse),
        (ReponseFausse.coupee(), NatureErreur.reseau),
      ]) {
        serveur.quand(AppConstants.suggestionUpdateQteEndpoint, rep, methode: 'POST');
        final r = await appel(tester, () => Suggestions.enregistrerQuantite(ctx, DonneesLot2.article1, 24));
        expect(r, isA<ApiLoadException>().having((e) => e.nature, 'nature', nature));
      }
      expect(serveur.recues(AppConstants.suggestionUpdateQteEndpoint), hasLength(3), reason: 'aucun renvoi automatique');
    });

    for (final (cas, reponse, annuleeSurServeur, issue) in [
      ('JSON partiel, vente annulée par le serveur', ReponseFausse.json('{"success":tr'), true, IssueAnnulation.sansReponseAnnulee),
      ('JSON partiel, vente NON annulée', ReponseFausse.json('{"success":tr'), false, IssueAnnulation.sansReponseNonAnnulee),
      ('réponse coupée, vente annulée par le serveur', ReponseFausse.tronquee('{"success":tr'), true, IssueAnnulation.sansReponseAnnulee),
    ]) {
      testWidgets('annulation d\'une vente ($cas) : état vérifié par relecture, jamais « refusée », aucun renvoi', (tester) async {
        final ctx = await monterAvecProviders(tester);
        donneesLot4(serveur);
        const chemin = '${AppConstants.venteAnnulationEndpoint}/${DonneesLot4.idA}';
        serveur.route(chemin, (_) {
          if (annuleeSurServeur) DonneesLot4.annulees.add(DonneesLot4.idA);
          return reponse;
        }, methode: 'GET');
        final vente = VenteStat.fromJson(Map<String, dynamic>.from(DonneesLot4.vente(DonneesLot4.idA, DonneesLot4.refA, 2500)));
        Future<VenteStat?> relire() async {
          final l = await ApiService().get(ctx, AppConstants.ventesStatsEndpoint, queryParams: {'query': DonneesLot4.refA});
          final data = (l as Map)['data'] as List;
          return data.map((e) => VenteStat.fromJson(Map<String, dynamic>.from(e as Map))).firstWhere((v) => v.lgPREENREGISTREMENTID == DonneesLot4.idA);
        }

        final r = await appel(tester, () => AnnulationVente.executer(ctx, vente, relire: relire));
        expect(r, isA<ResultatAnnulation>().having((x) => x.issue, 'issue', issue), reason: '$r');
        expect((r as ResultatAnnulation).issue, isNot(IssueAnnulation.refusee));
        expect(serveur.recues(chemin), hasLength(1), reason: 'jamais de renvoi automatique');
      });
    }
  });

  group('Écrans (application entière, faux serveur en mémoire)', () {
    setUpAll(() async {
      await chargerPolicesReelles();
      await serveur.demarrer();
    });
    tearDownAll(serveur.arreter);
    setUp(() {
      brancherEnMemoire(serveur);
      preparerNouvelle(serveur, p: Presentation.compact);
      donneesAccueil(serveur);
      donneesLot1(serveur);
      donneesLot2(serveur);
    });

    void telephone(WidgetTester tester) {
      tester.view.devicePixelRatio = 2.625;
      tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
      addTearDown(tester.view.reset);
    }

    for (final (cas, mauvaise, cause) in [
      ('coupée pendant le transfert', ReponseFausse.tronquee(creditsPartiels), 'erreur_reseau'),
      ('en JSON partiel', ReponseFausse.json(creditsPartiels), 'erreur_autre'),
    ]) {
      testWidgets('Suivi Crédit, réponse $cas : message + « Réessayer », jamais « aucun crédit », puis les données', (tester) async {
        telephone(tester);
        var n = 0;
        serveur.route(AppConstants.suiviCreditEndpoint,
            (_) => n++ == 0 ? mauvaise : ReponseFausse.json(DonneesFictives.creditsTiersPayants()), methode: 'GET');
        await ouvrirDepuisAccueil(tester, serveur, const SuiviCreditNouveau());
        await pomper(tester, () => find.byKey(const Key('bouton_reessayer')).evaluate().isNotEmpty, raison: 'Réessayer');
        expect(find.byKey(Key(cause)), findsOneWidget, reason: 'cause expliquée');
        expect(find.text('Aucun crédit sur la période'), findsNothing, reason: 'jamais une liste vide trompeuse');
        await tester.tap(find.byKey(const Key('bouton_reessayer')));
        await pomper(tester, () => find.byKey(const Key('chiffre_montant')).evaluate().isNotEmpty, raison: 'données au nouvel essai');
        expect(erreursAffichees(), findsNothing);
        await fermerApplication(tester);
      });
    }

    testWidgets('Visualisation BL, page coupée : message + « Réessayer », jamais « Aucun BL », puis les bons', (tester) async {
      telephone(tester);
      var n = 0;
      serveur.route('/etat-control-bon/list', (r) => n++ == 0 ? ReponseFausse.tronquee('{"total":23,"data":[{"lgBONLIVRAISONID":"BL-') : DonneesLot2.listeBons(r),
          methode: 'GET');
      await ouvrirDepuisAccueil(tester, serveur, const VisualisationBlNouveau());
      await pomper(tester, () => find.byKey(const Key('bouton_reessayer')).evaluate().isNotEmpty, raison: 'Réessayer');
      expect(find.text('Aucun Bon de Livraison trouvé'), findsNothing);
      await tester.tap(find.byKey(const Key('bouton_reessayer')));
      await pomper(tester, () => find.byKey(const Key('chiffre_ttc')).evaluate().isNotEmpty, raison: 'bons au nouvel essai');
      await fermerApplication(tester);
    });

    testWidgets('accueil A, chiffres du jour en JSON partiel : « Indisponible », jamais 0 F', (tester) async {
      telephone(tester);
      preparerNouvelle(serveur, p: Presentation.tableauDeBord);
      serveur.quand('/recap/dashboard', ReponseFausse.json('{"montantTTC":2480650,"montantNet'), methode: 'GET');
      await lancerApplication(tester);
      await seConnecterNouvelleEnMemoire(tester);
      expect(find.text('Indisponible'), findsWidgets);
      expect(find.text('0 F'), findsNothing, reason: 'jamais un chiffre faux');
      await fermerApplication(tester);
    });
  });

}

/// Connexion de la nouvelle interface (faux serveur en mémoire) jusqu'à l'accueil, puis 3 s.
Future<void> seConnecterNouvelleEnMemoire(WidgetTester tester) async {
  await pomper(tester, () => find.byKey(const Key('connexion_se_connecter')).evaluate().isNotEmpty, raison: 'connexion', max: 100);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), DonneesFictives.identifiant);
  await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), DonneesFictives.motDePasse);
  await tester.tap(find.byKey(const Key('connexion_se_connecter')));
  await pomper(tester, () => find.byType(AccueilNouveau).evaluate().isNotEmpty, raison: 'accueil');
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
