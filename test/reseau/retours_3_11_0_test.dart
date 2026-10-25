// RÉSEAU — nouveautés 3.11.0, faux serveur « en mémoire » en temps simulé :
//  - tableau de bord sur un serveur ANCIEN (branche dev : pas de /tableau-bord ni de /pilotage/suivi) : chiffres du
//    jour lus sur /recap/dashboard/daily, cartes sans route « Indisponible sur ce serveur », les autres affichées ;
//  - tableau de bord serveur coupé : chaque carte affiche « Serveur injoignable » avec « Réessayer », sans
//    déconnexion ; au retour du serveur, ⟳ recharge tout ;
//  - Balance : analyse longue (3 ans) annulable, sans relance automatique.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague4/balance_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/donnees_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/tableau_bord_vague4.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/services/api_service.dart';

import '../support/donnees_fictives.dart';
import '../support/donnees_lot3.dart';
import '../support/donnees_vague4.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 3000 * 2.625); // toutes les cartes à l'écran
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
    preparerNouvelle(serveur, p: Presentation.tableauPrestige);
    donneesAccueil(serveur);
    donneesLot3(serveur);
    ProfilAcces.utilisateur.value = AppUser.fromJson(DonneesFictives.utilisateur());
  });
  tearDown(() => ProfilAcces.utilisateur.value = null);

  testWidgets('serveur ancien (dev) : chiffres du jour par /recap/dashboard/daily ; cartes sans route « Indisponible sur ce serveur »', (tester) async {
    telephone(tester);
    for (final r in ['/tableau-bord/tuiles', '/tableau-bord/encaissements', '/tableau-bord/emplacements', '/tableau-bord/frequentation',
      '/pilotage/suivi/frequentation', '/tableau-bord/valorisation', '/tableau-bord/affluence']) {
      serveur.quand(r, ReponseFausse.introuvable());
    }
    await ouvrirEcran(tester, serveur, const AccueilNouveau(), pret: find.byKey(const Key('chiffre_tb_ca')));
    await pomper(tester, () => find.byKey(const Key('carte_indisponible')).evaluate().length >= 4, raison: 'cartes indisponibles');
    expect(serveur.recues(ApiTableauBord.routeDaily), hasLength(1));
    expect(find.text(formaterMontant(1245300)), findsWidgets, reason: 'chiffres du jour de l\'ancien tableau de bord');
    expect(find.byKey(const Key('carte_indisponible')), findsNWidgets(4), reason: 'fréquentation, affluence (3.15.0), encaissements, top 10');
    expect(serveur.recues('/produit/valorisation'), hasLength(1), reason: 'valorisation : calcul du jour');
    expect(find.byType(LoginScreen), findsNothing);
    await fermerApplication(tester);
  });

  testWidgets('serveur coupé : chaque carte « Serveur injoignable » + Réessayer, sans déconnexion ; serveur revenu : ⟳ recharge', (tester) async {
    telephone(tester);
    serveur.coupe = true;
    await ouvrirEcran(tester, serveur, const AccueilNouveau(), pret: find.textContaining(ApiLoadException.messageReseau));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Réessayer'), findsWidgets);
    expect(find.byType(LoginScreen), findsNothing);
    serveur.coupe = false;
    serveur.oublierRequetes();
    await tester.tap(find.byKey(const Key('tableau_bord_actualiser')));
    await pomper(tester, () => find.byKey(const Key('chiffre_tb_ca')).evaluate().isNotEmpty, raison: 'chiffres revenus');
    expect(serveur.recues('/tableau-bord/tuiles'), hasLength(1));
    await fermerApplication(tester);
  });

  testWidgets('Balance : analyse sur 3 ans lente → indication, « Annuler », aucune relance automatique', (tester) async {
    telephone(tester);
    serveur.quand(ApiBalance.routeAnalyse, ReponseFausse.json(DonneesVague4.analyse('TROIS_ANS')).apres(const Duration(seconds: 40)), methode: 'GET');
    await ouvrirEcran(tester, serveur, const BalanceCaisseScreen(initial: OngletBalance.analyse), pret: find.byKey(const Key('chargement_annulable')));
    await tester.tap(find.byKey(const Key('analyse_periode_TROIS_ANS')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('indication_calcul_long')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bouton_annuler_calcul')));
    await tester.pump(const Duration(seconds: 60));
    expect(find.byKey(const Key('chargement_annulable')), findsNothing);
    expect(serveur.recues(ApiBalance.routeAnalyse), hasLength(2), reason: 'ouverture (3 semaines) puis 3 ans, rien de plus');
    await fermerApplication(tester);
  });
}
