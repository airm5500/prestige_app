// RÉSEAU — ALTERNANCE coupure → retour, plusieurs fois (faux serveur « en mémoire » : connexion refusée comme un
// serveur éteint ou un Wi-Fi coupé, puis serveur de nouveau joignable) :
//  - lancement serveur coupé → écran « serveur injoignable » (licence non en cause) → retour du serveur → réessai
//    automatique (10 s) → connexion ;
//  - connexion pendant la coupure → « Serveur injoignable » (3.10.3 : serveur arrêté), saisie gardée → retour → connexion ;
//  - module (Suivi Crédit) : trois cycles coupure / retour (ouverture, changement de période, « Réessayer ») : message
//    réseau à chaque coupure, jamais « aucun crédit », données à chaque retour, aucune requête en rafale ;
//  - accueil A : chiffres « Indisponible » pendant la coupure, puis relus par ⟳ ;
//  - écritures pendant la coupure : quantité « non enregistrée » (valeur gardée), pointage annulé à l'écran ; au
//    retour, UN envoi qui aboutit (rien n'est rejoué tout seul).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/suggestion_model.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suggestions_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suivi_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague3/pointage_vague3.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/screens/serveur_injoignable_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_lot2.dart';
import '../support/donnees_vague1.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';
import '../support/reseau.dart';

final serveur = FauxServeurPrestige();

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

Finder cle(String k) => find.byKey(Key(k));

Future<void> laisser(WidgetTester tester, {int dixiemes = 20}) async {
  for (var i = 0; i < dixiemes; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> saisirIdentifiants(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), DonneesFictives.identifiant);
  await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), DonneesFictives.motDePasse);
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
    listesCommunesVague1(serveur);
  });

  testWidgets('lancement serveur coupé → « injoignable » (pas la licence) → retour du serveur → réessai automatique → connexion',
      (tester) async {
    telephone(tester);
    serveur.coupe = true;
    await lancerApplication(tester);
    await pomper(tester, () => find.byType(ServeurInjoignableScreen).evaluate().isNotEmpty, raison: 'écran injoignable', max: 100);
    expect(find.textContaining('licence n\'est pas en cause'), findsWidgets);
    // Deux réessais automatiques pendant la coupure : l'écran reste, sans s'emballer.
    final avant = serveur.requetes.length;
    await laisser(tester, dixiemes: 210);
    expect(find.byType(ServeurInjoignableScreen), findsOneWidget);
    expect(serveur.requetes.length, avant, reason: 'serveur coupé : aucune requête n\'arrive');
    serveur.coupe = false;
    await laisser(tester, dixiemes: 120); // prochain réessai automatique (toutes les 10 s)
    await pomper(tester, () => find.byType(LoginScreen).evaluate().isNotEmpty, raison: 'connexion au retour du serveur');
    expect(serveur.recues('/licence/find'), hasLength(1), reason: 'une lecture de licence au retour');
    await fermerApplication(tester);
  });

  testWidgets('connexion pendant la coupure (serveur arrêté) → « Serveur injoignable » (3.10.3), saisie gardée → retour → connexion (trois cycles)', (tester) async {
    telephone(tester);
    await lancerApplication(tester);
    await pomper(tester, () => find.byType(LoginScreen).evaluate().isNotEmpty, raison: 'connexion', max: 100);
    await laisser(tester, dixiemes: 5);
    await saisirIdentifiants(tester);
    for (var cycle = 1; cycle <= 3; cycle++) {
      serveur.coupe = true;
      await tester.tap(cle('connexion_se_connecter'));
      await laisser(tester);
      // Serveur arrêté = connexion refusée : cas 1 du pharmacien (3.10.3), « Serveur injoignable… PC serveur allumé ».
      expect(find.text(ApiLoadException.messageReseau), findsOneWidget, reason: 'cycle $cycle : serveur injoignable');
      expect(find.text(DonneesFictives.identifiant), findsOneWidget, reason: 'cycle $cycle : identifiant gardé');
    }
    serveur.coupe = false;
    await tester.tap(cle('connexion_se_connecter'));
    await pomper(tester, () => find.byType(AccueilNouveau).evaluate().isNotEmpty, raison: 'accueil au retour');
    expect(serveur.recues(AppConstants.authEndpoint), hasLength(1), reason: 'les essais coupés ne sont jamais arrivés ; un seul au retour');
    await fermerApplication(tester);
  });

  testWidgets('Suivi Crédit : trois cycles coupure / retour (ouverture, période, Réessayer), jamais « aucun crédit »', (tester) async {
    telephone(tester);
    serveur.coupe = true;
    await ouvrirDepuisAccueil(tester, serveur, const SuiviCreditNouveau());
    await laisser(tester);
    for (var cycle = 1; cycle <= 3; cycle++) {
      expect(cle('erreur_reseau'), findsOneWidget, reason: 'cycle $cycle : cause « Serveur injoignable »');
      expect(find.text('Aucun crédit sur la période'), findsNothing);
      // Encore coupé : « Réessayer » redonne le même message, sans planter ni boucler.
      await tester.tap(cle('bouton_reessayer'));
      await laisser(tester);
      expect(cle('erreur_reseau'), findsOneWidget);
      serveur.coupe = false;
      await tester.tap(cle('bouton_reessayer'));
      await laisser(tester);
      expect(cle('chiffre_montant'), findsOneWidget, reason: 'cycle $cycle : données au retour');
      expect(erreursAffichees(), findsNothing);
      // Nouvelle coupure, puis changement de période : message réseau, pas de liste vide.
      serveur.coupe = true;
      await tester.ensureVisible(cle(cycle.isOdd ? 'periode_hier' : 'periode_aujourdhui'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(cle(cycle.isOdd ? 'periode_hier' : 'periode_aujourdhui'));
      await laisser(tester);
    }
    serveur.coupe = false;
    await tester.tap(cle('bouton_reessayer'));
    await laisser(tester);
    expect(cle('chiffre_montant'), findsOneWidget);
    expect(serveur.recues(AppConstants.suiviCreditEndpoint), hasLength(4), reason: 'une lecture par retour, aucune en rafale');
    await fermerApplication(tester);
  });

  testWidgets('accueil A : chiffres « Indisponible » pendant la coupure, relus par ⟳ au retour (deux cycles)', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.tableauDeBord);
    await lancerApplication(tester);
    await pomper(tester, () => find.byType(LoginScreen).evaluate().isNotEmpty, raison: 'connexion', max: 100);
    await laisser(tester, dixiemes: 5);
    await saisirIdentifiants(tester);
    await tester.tap(cle('connexion_se_connecter'));
    await pomper(tester, () => find.byType(AccueilNouveau).evaluate().isNotEmpty, raison: 'accueil');
    await laisser(tester);
    final actualiser = find.byTooltip('Actualiser les chiffres');
    for (var cycle = 1; cycle <= 2; cycle++) {
      serveur.coupe = true;
      await tester.tap(actualiser);
      await laisser(tester);
      expect(find.text('Indisponible'), findsWidgets, reason: 'cycle $cycle : chiffres indisponibles, pas 0');
      serveur.coupe = false;
      await tester.tap(actualiser);
      await laisser(tester);
      expect(find.text('Indisponible'), findsNothing, reason: 'cycle $cycle : chiffres relus');
    }
    await fermerApplication(tester);
  });

  testWidgets('Suggestions : quantité pendant la coupure → « non enregistrée », valeur gardée ; au retour UN envoi qui aboutit', (tester) async {
    telephone(tester);
    final s = Suggestion(id: DonneesLot2.suggestion1, name: 'SUGG-FICTIVE-01', status: 'pending', grossiste: DonneesLot2.grossisteA);
    await ouvrirDepuisAccueil(tester, serveur, SuggestionDetailNouveau(suggestion: s));
    await pomper(tester, () => cle('qte_${DonneesLot2.article1}').evaluate().isNotEmpty, raison: 'lignes');
    final champ = cle('qte_${DonneesLot2.article1}');
    final bouton = cle('qte_enregistrer_${DonneesLot2.article1}');
    await tester.enterText(champ, '24');
    for (var cycle = 1; cycle <= 2; cycle++) {
      serveur.coupe = true;
      await tester.ensureVisible(bouton);
      await tester.pump();
      await tester.tap(bouton);
      await laisser(tester);
      expect(find.textContaining('non enregistrée'), findsWidgets, reason: 'cycle $cycle');
      expect(tester.widget<TextField>(champ).controller!.text, '24', reason: 'valeur gardée pour un nouvel essai');
      await laisser(tester, dixiemes: 50); // le message disparaît ; rien n'est rejoué tout seul
      expect(serveur.recues(AppConstants.suggestionUpdateQteEndpoint), isEmpty);
    }
    serveur.coupe = false;
    await tester.tap(bouton);
    await laisser(tester);
    expect(find.textContaining('Quantité enregistrée'), findsOneWidget);
    expect(serveur.recues(AppConstants.suggestionUpdateQteEndpoint), hasLength(1));
    await fermerApplication(tester);
  });

  testWidgets('Pointage BL : pointage pendant la coupure → pièce remise « à pointer » ; au retour UN envoi', (tester) async {
    telephone(tester);
    await ouvrirDepuisAccueil(tester, serveur, const PointageBlScreen());
    await laisser(tester, dixiemes: 10);
    await tester.tap(cle('pointage_grossiste'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('GROSSISTE FICTIF').last);
    await pomper(tester, () => cle('pointage_total').evaluate().isNotEmpty, raison: 'pièces');
    final bouton = cle('pointer_BL:BL-TEST-1');
    await tester.ensureVisible(bouton);
    await tester.pump();
    serveur.coupe = true;
    await tester.tap(bouton);
    await laisser(tester);
    expect(find.descendant(of: bouton, matching: find.text('Pointer')), findsOneWidget, reason: 'mise à jour annulée');
    serveur.coupe = false;
    await tester.tap(bouton);
    await laisser(tester);
    expect(find.descendant(of: bouton, matching: find.text('Dépointer')), findsOneWidget);
    expect(serveur.recues('/pointage-bl/pointer/BL/BL-TEST-1'), hasLength(1));
    await fermerApplication(tester);
  });
}
