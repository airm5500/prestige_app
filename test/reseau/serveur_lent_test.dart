// RÉSEAU — serveur LENT MAIS QUI RÉPOND (2 s, 5 s, 8 s ; 25 s pour les routes lourdes), faux serveur « en mémoire »
// en temps simulé. Sur la connexion (deux interfaces), l'accueil A, les modules principaux, puis les ÉCRITURES
// (quantité d'une suggestion, pointage d'un BL, annulation d'une vente) :
//  - une attente est visible pendant tout le délai (indicateur, ou « … » des chiffres de l'accueil) ;
//  - AUCUN message d'erreur (« injoignable », « trop de temps », « Réessayer »…) avant le délai de l'application
//    (ApiService : 45 s en lecture, 20 s en écriture ; 2 min pour les calculs longs demandés) ;
//  - l'écran reste utilisable : retour possible pendant l'attente, sans erreur ;
//  - une seconde action pendant l'attente n'envoie RIEN en double (connexion, écritures) ;
//  - la réponse, une fois arrivée, est affichée.
// Routes lourdes à 25 s : recherche d'un article (/info), CA emplacement sur 3 ans, demande sur 36 mois.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/suggestion_model.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/annulation_ventes_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/articles_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/modules/detail_ca_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/fichier_journal_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/rapport_activite_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/recap_caisse_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suggestions_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suivi_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suivi_peremption_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/tableau_analyses_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/visualisation_bl_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague2/ca_zone_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/previsions_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague3/pointage_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague4/balance_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/donnees_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/perimes_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/surstock_vague4.dart';
import 'package:prestige_app/screens/home_screen.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_lot2.dart';
import '../support/donnees_lot3.dart';
import '../support/donnees_lot4.dart';
import '../support/donnees_vague1.dart';
import '../support/donnees_vague2.dart';
import '../support/donnees_vague4.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';
import '../support/reseau.dart';

final serveur = FauxServeurPrestige();

const delais = [Duration(seconds: 2), Duration(seconds: 5), Duration(seconds: 8)];
const lourd = Duration(seconds: 25);

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

/// Module principal : écran, route lue à l'ouverture (rendue lente), réponse, signe que la réponse est affichée.
class ModuleLent {
  final String nom;
  final Widget Function() ecran;
  final String route;
  final String methode;
  final ReponseFausse Function(RequeteRecue r) reponse;
  final Finder affiche;
  const ModuleLent(this.nom, this.ecran, this.route, this.reponse, this.affiche, {this.methode = 'GET'});
}

Finder cle(String k) => find.byKey(Key(k));

final modules = <ModuleLent>[
  ModuleLent('Rapport d\'Activité', () => const RapportActiviteNouveau(), AppConstants.dashboardRecapEndpoint,
      (_) => ReponseFausse.json(DonneesFictives.rapportActivite()), cle('chiffre_ttc')),
  ModuleLent('Détail CA', () => const DetailCaNouveau(), AppConstants.caComptantEndpoint, (_) => ReponseFausse.json(DonneesFictives.caParJour()),
      cle('chiffre_total')),
  ModuleLent('Suivi Crédit', () => const SuiviCreditNouveau(), AppConstants.suiviCreditEndpoint,
      (_) => ReponseFausse.json(DonneesFictives.creditsTiersPayants()), cle('chiffre_montant')),
  ModuleLent('Suivi Péremption', () => const SuiviPeremptionNouveau(), AppConstants.suiviPeremptionEndpoint,
      (_) => ReponseFausse.json(DonneesFictives.perimes()), cle('chiffre_lots')),
  ModuleLent('Visualisation BL', () => const VisualisationBlNouveau(), '/etat-control-bon/list', DonneesLot2.listeBons, cle('chiffre_ttc')),
  ModuleLent('Suggestions', () => const SuggestionsNouveau(), AppConstants.suggestionListEndpoint,
      (_) => ReponseFausse.json(DonneesLot2.suggestions()), cle('suggestion_reference_${DonneesLot2.suggestion1}')),
  ModuleLent('Tableau : Analyses', () => const TableauAnalysesNouveau(), AppConstants.tableauBordAchatsVentesEndpoint,
      (_) => ReponseFausse.json(DonneesLot3.achatsVentes()), cle('chiffre_ventes')),
  ModuleLent('Récap de caisse', () => const RecapCaisseNouveau(), '/caisse/fetch-tickez', (_) => ReponseFausse.json(DonneesLot4.ticketZ('ALL')),
      find.byType(LigneDetail),
      methode: 'POST'),
  ModuleLent('Fichier Journal', () => const FichierJournalNouveau(), AppConstants.fichierJournalEndpoint, DonneesLot4.journalPour, cle('chiffre_actions')),
  ModuleLent('Prévisions', () => const PrevisionsScreen(), '/analyse-commande/previsions', (r) => ReponseFausse.json(DonneesVague2.previsions(r.parametres)),
      cle('previsions_total')),
  // 3.11.0
  ModuleLent('Balance vente / caisse', () => const BalanceCaisseScreen(), ApiBalance.route, (_) => ReponseFausse.json(DonneesVague4.balance()),
      cle('chiffre_balance_net')),
  ModuleLent('Sur-stocks', () => const SurstocksScreen(), ApiSurstock.route, (r) => ReponseFausse.json(DonneesVague4.surstocks(r.parametres)),
      cle('chiffre_surstock_total')),
  ModuleLent('Saisies en périmés', () => const SaisiesPerimesScreen(), ApiSaisiesPerimes.route,
      (r) => ReponseFausse.json(DonneesVague4.saisiesPerimes(r.parametres)), cle('saisies_perimes_total')),
];

/// Touche « Se connecter » (nouvelle interface) ou « Connexion » (origine) sans attendre la réponse.
Future<void> seConnecterSansAttendre(WidgetTester tester) async {
  await pomper(tester, () => find.byType(LoginScreen).evaluate().isNotEmpty, raison: 'écran de connexion', max: 100);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), DonneesFictives.identifiant);
  await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), DonneesFictives.motDePasse);
  await tester.tap(boutonConnexion());
  await tester.pump();
}

Finder boutonConnexion() {
  final nv = find.byKey(const Key('connexion_se_connecter'));
  return nv.evaluate().isNotEmpty ? nv : find.widgetWithText(ElevatedButton, 'Connexion');
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
    donneesAccueil(serveur);
    donneesLot1(serveur);
    donneesLot2(serveur);
    donneesLot3(serveur);
    donneesLot4(serveur);
    listesCommunesVague1(serveur);
    ProfilAcces.utilisateur.value = AppUser.fromJson(DonneesFictives.utilisateur());
  });
  tearDown(() => ProfilAcces.utilisateur.value = null);

  for (final d in delais) {
    final s = '${d.inSeconds} s';
    group('serveur lent ($s)', () {
      testWidgets('connexion (nouvelle interface) : bouton occupé, second appui sans envoi, puis accueil', (tester) async {
        telephone(tester);
        serveur.quand(AppConstants.authEndpoint, ReponseFausse.json(DonneesFictives.utilisateur(),
            entetes: {'set-cookie': 'JSESSIONID=fictif-lent; Path=/prestige; HttpOnly'}).apres(d), methode: 'POST');
        await lancerApplication(tester);
        await seConnecterSansAttendre(tester);
        await attendreServeurLent(tester, d, 'Connexion', pendant: () async {
          final b = boutonConnexion();
          expect(b, findsNothing, reason: 'bouton remplacé par l\'indicateur pendant la connexion');
          if (b.evaluate().isNotEmpty) await tester.tap(b, warnIfMissed: false);
        });
        expect(serveur.recues(AppConstants.authEndpoint), hasLength(1), reason: 'second appui ignoré pendant l\'attente');
        await pomper(tester, () => find.byType(AccueilNouveau).evaluate().isNotEmpty, raison: 'accueil');
        await fermerApplication(tester);
      });

      testWidgets('connexion (ancienne interface) : un seul envoi, puis accueil d\'origine', (tester) async {
        telephone(tester);
        preparerTelephone(serveur);
        serveur.quand(AppConstants.authEndpoint, ReponseFausse.json(DonneesFictives.utilisateur(),
            entetes: {'set-cookie': 'JSESSIONID=fictif-lent; Path=/prestige; HttpOnly'}).apres(d), methode: 'POST');
        await lancerApplication(tester);
        await seConnecterSansAttendre(tester);
        await attendreServeurLent(tester, d, 'Connexion d\'origine', pendant: () async {
          final b = find.widgetWithText(ElevatedButton, 'Connexion');
          if (b.evaluate().isNotEmpty) await tester.tap(b, warnIfMissed: false);
        });
        expect(serveur.recues(AppConstants.authEndpoint), hasLength(1));
        await pomper(tester, () => find.byType(HomeScreen).evaluate().isNotEmpty, raison: 'accueil d\'origine');
        await fermerApplication(tester);
      });

      testWidgets('accueil A : chiffres du jour lents, « … » affichés pendant l\'attente, puis les chiffres', (tester) async {
        telephone(tester);
        preparerNouvelle(serveur, p: Presentation.tableauDeBord);
        serveur.quand('/recap/dashboard', ReponseFausse.json(DonneesFictives.recapDuJour()).apres(d), methode: 'GET');
        await lancerApplication(tester);
        await seConnecterSansAttendre(tester);
        await pomper(tester, () => find.byType(AccueilNouveau).evaluate().isNotEmpty, raison: 'accueil A', pas: const Duration(milliseconds: 50));
        await attendreServeurLent(tester, d, 'Accueil A', attente: find.text('…'), deja: const Duration(milliseconds: 300));
        expect(find.text('…'), findsNothing, reason: 'chiffres affichés');
        expect(serveur.recues('/recap/dashboard'), hasLength(1), reason: 'une seule lecture des chiffres');
        await fermerApplication(tester);
      });

      for (final m in modules) {
        testWidgets('${m.nom} : chargement visible, retour possible pendant l\'attente, puis données', (tester) async {
          telephone(tester);
          serveur.route(m.route, (r) => m.reponse(r).apres(d), methode: m.methode);
          await ouvrirDepuisAccueil(tester, serveur, m.ecran());
          await attendreServeurLent(tester, d, m.nom, deja: const Duration(milliseconds: 100));
          expect(m.affiche, findsWidgets, reason: '${m.nom} : réponse affichée');
          expect(serveur.recues(m.route, methode: m.methode), hasLength(1), reason: '${m.nom} : une seule lecture');
          // Écran utilisable : on revient pendant une nouvelle attente, sans erreur ni blocage.
          await retourTelephone(tester);
          expect(cle('essai_ouvrir'), findsOneWidget);
          await tester.tap(cle('essai_ouvrir'));
          await tester.pump(const Duration(milliseconds: 300));
          await retourTelephone(tester);
          await tester.pump(d);
          await tester.pump(const Duration(milliseconds: 500));
          expect(cle('essai_ouvrir'), findsOneWidget, reason: 'retour pendant l\'attente');
          expect(erreursAffichees(), findsNothing);
          await fermerApplication(tester);
        });
      }

      testWidgets('Suggestions : enregistrement lent d\'une quantité, appuis répétés = UN envoi', (tester) async {
        telephone(tester);
        serveur.quand(AppConstants.suggestionUpdateQteEndpoint, ReponseFausse.json({'success': true}).apres(d), methode: 'POST');
        final s = Suggestion(id: DonneesLot2.suggestion1, name: 'SUGG-FICTIVE-01', status: 'pending', grossiste: DonneesLot2.grossisteA);
        await ouvrirDepuisAccueil(tester, serveur, SuggestionDetailNouveau(suggestion: s));
        await pomper(tester, () => cle('qte_${DonneesLot2.article1}').evaluate().isNotEmpty, raison: 'lignes');
        final bouton = cle('qte_enregistrer_${DonneesLot2.article1}');
        await tester.enterText(cle('qte_${DonneesLot2.article1}'), '24');
        await tester.ensureVisible(bouton);
        await tester.pump();
        await tester.tap(bouton);
        await tester.tap(bouton, warnIfMissed: false);
        await tester.pump();
        await attendreServeurLent(tester, d, 'Suggestions (quantité)', pendant: () async {
          if (bouton.evaluate().isNotEmpty) await tester.tap(bouton, warnIfMissed: false);
          await tester.showKeyboard(cle('qte_${DonneesLot2.article1}'));
          await tester.testTextInput.receiveAction(TextInputAction.done); // « Terminé » du clavier pendant l'envoi
          await tester.pump();
        });
        expect(serveur.recues(AppConstants.suggestionUpdateQteEndpoint, methode: 'POST'), hasLength(1), reason: 'aucun double envoi');
        expect(serveur.recues(AppConstants.suggestionUpdateQteEndpoint).single.json, {'itemId': DonneesLot2.article1, 'qte': 24});
        expect(find.textContaining('Quantité enregistrée'), findsOneWidget);
        await fermerApplication(tester);
      });

      testWidgets('Pointage BL : pointage lent, appuis répétés = UN envoi, pièce pointée', (tester) async {
        telephone(tester);
        await ouvrirDepuisAccueil(tester, serveur, const PointageBlScreen());
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(cle('pointage_grossiste'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('GROSSISTE FICTIF').last);
        await pomper(tester, () => cle('pointage_total').evaluate().isNotEmpty, raison: 'pièces du grossiste');
        const route = '/pointage-bl/pointer/BL/BL-TEST-1';
        serveur.route(route, (_) => ReponseFausse.json({'success': true, 'msg': ''}).apres(d), methode: 'PUT');
        final bouton = cle('pointer_BL:BL-TEST-1');
        await tester.ensureVisible(bouton);
        await tester.pump();
        await tester.tap(bouton);
        await tester.tap(bouton, warnIfMissed: false);
        await tester.pump();
        await attendreServeurLent(tester, d, 'Pointage BL', pendant: () async {
          if (bouton.evaluate().isNotEmpty) await tester.tap(bouton, warnIfMissed: false);
        });
        expect(serveur.recues(route, methode: 'PUT'), hasLength(1), reason: 'aucun double envoi');
        expect(find.descendant(of: bouton, matching: find.text('Dépointer')), findsOneWidget);
        await fermerApplication(tester);
      });

      testWidgets('Annulation de vente : annulation lente, appuis répétés et retour = UN envoi', (tester) async {
        telephone(tester);
        await ouvrirDepuisAccueil(tester, serveur, const AnnulationVentesNouveau());
        await tester.enterText(cle('champ_recherche'), '261013');
        await pomper(tester, () => cle('vente_${DonneesLot4.idA}').evaluate().isNotEmpty, raison: 'vente trouvée');
        await tester.tap(cle('vente_${DonneesLot4.idA}'));
        await pomper(tester, () => find.text(DonneesLot4.clientA).evaluate().isNotEmpty, raison: 'détail');
        const route = '${AppConstants.venteAnnulationEndpoint}/${DonneesLot4.idA}';
        serveur.route(route, (_) {
          DonneesLot4.annulees.add(DonneesLot4.idA);
          return ReponseFausse.json({'success': true}).apres(d);
        }, methode: 'GET');
        // Compte pharmacien (profil « dashboard ») : pas de code administrateur (cas couvert par les tests e2e).
        ProfilAcces.utilisateur.value = AppUser.fromJson(DonneesFictives.utilisateur());
        await tester.ensureVisible(cle('bouton_annuler_vente'));
        await tester.pump();
        await tester.tap(cle('bouton_annuler_vente'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.enterText(cle('confirmation_saisie'), DonneesLot4.refA);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(cle('confirmation_oui'));
        await tester.tap(cle('confirmation_oui'), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 100));
        await attendreServeurLent(tester, d, 'Annulation', attente: cle('annulation_en_cours'), deja: const Duration(milliseconds: 100),
            pendant: () async {
          await tester.binding.handlePopRoute(); // retour refusé pendant l'envoi
          await tester.pump();
          expect(find.text('Détail de la vente'), findsOneWidget, reason: 'retour refusé pendant l\'annulation');
        });
        await pomper(tester, () => cle('resultat_annulation').evaluate().isNotEmpty, raison: 'résultat');
        expect(serveur.recues(route), hasLength(1), reason: 'aucun double envoi');
        expect(find.textContaining('Vente annulée'), findsWidgets);
        await fermerApplication(tester);
      });
    });
  }

  group('routes lourdes (serveur qui répond en 25 s)', () {
    testWidgets('Analyse Article : recherche /info en 25 s, chargement visible, puis résultats', (tester) async {
      telephone(tester);
      serveur.route(AppConstants.infoEndpoint, (r) => ReponseFausse.json(DonneesFictives.articlesAnalyse()).apres(lourd), methode: 'GET');
      await ouvrirDepuisAccueil(tester, serveur, const AnalyseArticleNouveau());
      await tester.enterText(cle('champ_recherche'), 'PARAFICTIF');
      await tester.pump(const Duration(milliseconds: 600)); // anti-rebond : la requête part
      expect(serveur.recues(AppConstants.infoEndpoint), hasLength(1));
      await attendreServeurLent(tester, lourd, 'Analyse Article (/info)');
      expect(find.byType(CarteLigne), findsWidgets, reason: 'résultats affichés');
      await fermerApplication(tester);
    });

    testWidgets('CA emplacement / famille sur 3 ans en 25 s : calcul visible, puis résultat', (tester) async {
      telephone(tester);
      serveur.route('/ca-zone-geo', (r) {
        final rep = ReponseFausse.json(DonneesVague2.caZone(r.parametres));
        return r.parametres['typePeriode'] == 'TROIS_ANS' ? rep.apres(lourd) : rep;
      }, methode: 'GET');
      await ouvrirDepuisAccueil(tester, serveur, CaZoneScreen(maintenant: () => DateTime(2026, 10, 14)));
      await pomper(tester, () => cle('chiffre_ca_total').evaluate().isNotEmpty, raison: '3 semaines');
      await tester.tap(cle('periode_ca_TROIS_ANS'));
      await tester.pump();
      await attendreServeurLent(tester, lourd, 'CA emplacement (3 ans)');
      expect(cle('chiffre_ca_total'), findsOneWidget);
      expect(serveur.recues('/ca-zone-geo').last.parametres['typePeriode'], 'TROIS_ANS');
      expect(serveur.recues('/ca-zone-geo'), hasLength(2), reason: 'aucune relance pendant le calcul');
      await fermerApplication(tester);
    });

    testWidgets('Prévisions : demande sur 36 mois en 25 s, calcul visible, puis résultat', (tester) async {
      telephone(tester);
      serveur.route('/analyse-commande/demande', (r) => ReponseFausse.json(DonneesVague2.demande(36)).apres(lourd), methode: 'GET');
      await ouvrirDepuisAccueil(tester, serveur, const PrevisionsScreen(ongletInitial: 2));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(cle('demande_mois_36'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(cle('demande_calculer'));
      await tester.pump();
      await tester.tap(cle('demande_calculer'));
      await tester.pump();
      await attendreServeurLent(tester, lourd, 'Prévisions (demande 36 mois)', pendant: () async {
        await tester.tap(cle('demande_calculer'), warnIfMissed: false); // « Calculer » est désactivé pendant le calcul
      });
      expect(cle('demande_resultat'), findsOneWidget);
      expect(serveur.recues('/analyse-commande/demande'), hasLength(1), reason: 'aucune relance');
      expect(serveur.recues('/analyse-commande/demande').single.parametres['mois'], '36');
      await fermerApplication(tester);
    });
  });
}
