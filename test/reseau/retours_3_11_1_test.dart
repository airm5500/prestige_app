// RÉSEAU — retours de la 3.11.1, faux serveur « en mémoire » en temps simulé :
//  - chiffres du tableau de bord sur un serveur ANCIEN (pas de /tableau-bord/tuiles) : aujourd'hui → ancienne route
//    (inchangé) ; hier → « Indisponible sur ce serveur », aucun appel à l'ancienne route ; retour à aujourd'hui : les
//    chiffres reviennent ;
//  - serveur lent : on passe à « Hier » pendant le chargement d'aujourd'hui, puis la réponse d'aujourd'hui arrive en
//    retard : elle n'écrase PAS les chiffres d'hier ;
//  - fréquentation coupée : message et « Réessayer » ; changer la largeur ou la plage ne relance rien.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague4/tableau_bord_vague4.dart';

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

Future<void> toucher(WidgetTester tester, String cle) async {
  await tester.ensureVisible(find.byKey(Key(cle)).first);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.byKey(Key(cle)).first);
  await tester.pump(const Duration(milliseconds: 100));
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

  Finder dansChiffres(Finder f) => find.descendant(of: find.byKey(const Key('carte_tableau_bord_chiffres')), matching: f);

  testWidgets('serveur ancien : hier « Indisponible sur ce serveur » sans appel à l\'ancienne route ; aujourd\'hui revient', (tester) async {
    telephone(tester);
    serveur.quand(ApiTableauBord.routeTuiles, ReponseFausse.introuvable());
    await ouvrirEcran(tester, serveur, const AccueilNouveau(), pret: find.byKey(const Key('chiffre_tb_ca')));
    expect(serveur.recues(ApiTableauBord.routeDaily), hasLength(1));
    await toucher(tester, 'chiffres_hier');
    await pomper(tester, () => dansChiffres(find.byKey(const Key('carte_indisponible'))).evaluate().isNotEmpty, raison: 'hier indisponible');
    expect(serveur.recues(ApiTableauBord.routeDaily), hasLength(1), reason: 'l\'ancienne route ne connaît qu\'aujourd\'hui');
    expect(find.byKey(const Key('chiffre_tb_ca')), findsNothing);
    await toucher(tester, 'chiffres_aujourdhui');
    await pomper(tester, () => find.byKey(const Key('chiffre_tb_ca')).evaluate().isNotEmpty, raison: 'aujourd\'hui');
    expect(serveur.recues(ApiTableauBord.routeDaily), hasLength(2));
    await fermerApplication(tester);
  });

  testWidgets('serveur lent : la réponse d\'aujourd\'hui, arrivée après celle d\'hier, ne l\'écrase pas', (tester) async {
    telephone(tester);
    final hier = DateTime.now().subtract(const Duration(days: 1));
    final jourHier = '${hier.year}-${hier.month.toString().padLeft(2, '0')}-${hier.day.toString().padLeft(2, '0')}';
    serveur.route(ApiTableauBord.routeTuiles, (r) {
      final estHier = r.parametres['date'] == jourHier;
      final j = {...DonneesVague4.tuiles(), 'ca': estHier ? 777000 : 1245300};
      return ReponseFausse.json(j).apres(Duration(seconds: estHier ? 1 : 4));
    }, methode: 'GET');
    await ouvrirEcran(tester, serveur, const AccueilNouveau(), pret: find.byKey(const Key('chiffres_hier')));
    await toucher(tester, 'chiffres_hier'); // aujourd'hui encore en route (4 s)
    await pomper(tester, () => find.text(formaterMontant(777000)).evaluate().isNotEmpty, raison: 'chiffres d\'hier');
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // la réponse d'aujourd'hui arrive
    }
    expect(dansChiffres(find.text(formaterMontant(777000))), findsOneWidget);
    expect(dansChiffres(find.text(formaterMontant(1245300))), findsNothing);
    await fermerApplication(tester);
  });

  testWidgets('fréquentation coupée : message et « Réessayer » ; changer l\'affichage ne relance rien', (tester) async {
    telephone(tester);
    serveur.quand(ApiTableauBord.routeFrequentationPilotage, ReponseFausse.erreurServeur());
    await ouvrirEcran(tester, serveur, const AccueilNouveau(), pret: find.byKey(const Key('frequentation_largeur_2')));
    final carte = find.byKey(const Key('carte_tableau_bord_frequentation'));
    await pomper(tester, () => find.descendant(of: carte, matching: find.text('Réessayer')).evaluate().isNotEmpty, raison: 'erreur affichée');
    final avant = serveur.recues(ApiTableauBord.routeFrequentationPilotage).length;
    await toucher(tester, 'frequentation_largeur_2');
    expect(serveur.recues(ApiTableauBord.routeFrequentationPilotage).length, avant);
    installerRoutesVague4(serveur);
    await tester.tap(find.descendant(of: carte, matching: find.text('Réessayer')));
    await pomper(tester, () => find.byKey(const Key('frequentation_resume')).evaluate().isNotEmpty, raison: 'reprise');
    expect(find.byKey(const Key('frequentation_tranche_8')), findsOneWidget, reason: 'tranches de 2 h gardées : 08-10…');
    await fermerApplication(tester);
  });
}
