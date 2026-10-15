// Parcours de bout en bout des décisions du pharmacien (3.10.0), application ENTIÈRE contre le faux serveur local
// (vrai réseau HTTP) :
//  - compte « admin » : Réglages › Style des icônes › P4 → accueil A en icônes illustrées (tuiles), barre du bas
//    illustrée, module ouvert depuis une tuile illustrée ; choix mémorisé et repris au lancement ; retour à « Actuel » ;
//  - pharmacien : « Menus de l'accueil » › « 6 tuiles par page » → accueil A : « À surveiller » puis des pages de 6
//    tuiles au plus (boutons, balayage), module ouvert depuis une page ; accueil B : 6 lignes par page, recherche à plat ;
//  - Pointage BL depuis l'accueil, par groupe de grossistes : `groupe=` envoyé, montant du groupe, rien sans choix ;
//  - serveur récent (rôle à la connexion) : rôle affiché dans Réglages › Compte ; serveur ancien : rien.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/interface_version.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/apparence_accueil.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart' show TuileMenu, LigneMenu;
import 'package:prestige_app/nouvelle_interface/icones_illustrees.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_lot3.dart';
import '../support/donnees_vague1.dart';
import '../support/donnees_vague3.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';
import 'parcours_vague2_test.dart' show telephone, toucher, ouvrirDepuisA, revenirALAccueil, retourSysteme;

final serveur = FauxServeurPrestige();

Finder cle(String k) => find.byKey(Key(k));
Finder dansAccueil(String texte) => find.descendant(of: find.byType(AccueilNouveau), matching: find.text(texte));
Future<SharedPreferences> prefs(WidgetTester tester) async => (await tester.runAsync(SharedPreferences.getInstance))!;

void connexion({String login = DonneesFictives.identifiant, Map<String, String>? role}) {
  serveur.controlerSession = false;
  serveur.quand(
      '/user/auth',
      ReponseFausse.json({...DonneesFictives.utilisateur(), 'str_LOGIN': login, if (role != null) 'role': role},
          entetes: {'set-cookie': 'JSESSIONID=fictif-3100; Path=/prestige; HttpOnly'}),
      methode: 'POST');
}

Future<void> reglage(WidgetTester tester, String k) async {
  await tester.scrollUntilVisible(cle(k), 200, scrollable: find.byType(Scrollable).hitTestable().first, maxScrolls: 40);
  await stabiliser(tester, tours: 3);
  await tester.tap(cle(k));
  await stabiliser(tester, tours: 6);
}

String titrePage(WidgetTester tester) => tester.widget<Text>(cle('page_menus_titre')).textSpan!.toPlainText();

/// Tuiles (accueil A) ou lignes (accueil B) de la page de menus visible.
int menusDeLaPage(WidgetTester tester, Type type) =>
    find.descendant(of: cle('pages_menus_defilement'), matching: find.byType(type)).hitTestable().evaluate().length;

void main() {
  setUpAll(chargerPolicesReelles);

  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    preparerNouvelle(serveur, p: Presentation.tableauDeBord);
    donneesAccueil(serveur);
    listesCommunesVague1(serveur);
    donneesLot3(serveur);
  });

  tearDown(() async {
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true;
    ProfilAcces.utilisateur.value = null;
  });

  testWidgets('compte « admin » : style P4 → icônes illustrées (tuiles, barre du bas), module ouvert, choix repris ; retour à « Actuel »',
      (tester) async {
    telephone(tester);
    connexion(login: 'admin');
    await jusquAccueilNouveau(tester);
    expect(find.byType(IconeIllustree), findsNothing, reason: 'défaut : « Actuel »');
    await toucherReglages(tester);
    await reglage(tester, 'style_icones_p4');
    expect((await prefs(tester)).getString(ApparenceAccueilPrefs.cleStyle), 'p4');
    await retourSysteme(tester);

    expect(find.byType(IconeIllustree), findsWidgets);
    expect(cle('onglet_illustre_accueil_actif'), findsOneWidget);
    expect(cle('onglet_illustre_analyses'), findsOneWidget);
    expect(tester.widget<NavigationBar>(cle('barre_accueil')).indicatorColor, isNotNull);
    await ouvrirDepuisA(tester, 'Visualisation BL');
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Visualisation BL'));
    await revenirALAccueil(tester);
    // Onglet Analyses : lignes illustrées.
    await ouvrirOnglet(tester, 'Analyses');
    await stabiliser(tester, tours: 4);
    expect(cle('onglet_illustre_analyses_actif'), findsOneWidget);
    expect(find.descendant(of: cle('defilement_menus'), matching: find.byType(IconeIllustree)), findsWidgets);
    await retourSysteme(tester);
    await terminer(tester);

    // Relance : P4 repris ; puis retour à « Actuel ».
    ApparenceAccueilPrefs.reinitialiser();
    await tester.runAsync(InterfaceVersion.load);
    expect(ApparenceAccueilPrefs.style.value, StyleIcones.p4);
    utiliserReseauReel();
    await jusquAccueilNouveau(tester);
    expect(find.byType(IconeIllustree), findsWidgets);
    await toucherReglages(tester);
    await reglage(tester, 'style_icones_actuel');
    await retourSysteme(tester);
    expect(find.byType(IconeIllustree), findsNothing);
    await terminer(tester);
  });

  testWidgets('pharmacien : « 6 tuiles par page » → A : « À surveiller » puis pages de 6 tuiles au plus, module ouvert', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await toucherReglages(tester);
    await reglage(tester, 'affichage_menus_parSix');
    expect((await prefs(tester)).getInt(ApparenceAccueilPrefs.cleAffichage), 2);
    await retourSysteme(tester);

    expect(cle('pages_menus'), findsOneWidget);
    expect(titrePage(tester), startsWith('À SURVEILLER'));
    final vus = <String>{};
    var pages = 0;
    while (true) {
      await tester.tap(cle('page_menus_suivante'));
      await stabiliser(tester, tours: 8);
      pages++;
      final n = menusDeLaPage(tester, TuileMenu);
      expect(n, inInclusiveRange(1, menusParPage), reason: 'page $pages : ${titrePage(tester)}');
      for (final t in find.descendant(of: cle('pages_menus_defilement'), matching: find.byType(TuileMenu)).hitTestable().evaluate()) {
        vus.add((t.widget as TuileMenu).titre);
      }
      if (tester.widget<IconButton>(cle('page_menus_suivante')).onPressed == null) break;
    }
    expect(pages, greaterThanOrEqualTo(5), reason: '35 menus du pharmacien, 6 par page');
    expect(vus, contains('Pointage BL'));
    // Retour d'une page (bouton ‹) puis balayage vers la droite : page précédente encore ; ouverture d'un module.
    final derniere = titrePage(tester);
    await tester.tap(cle('page_menus_precedente'));
    await stabiliser(tester, tours: 8);
    expect(titrePage(tester), isNot(derniere));
    await tester.drag(cle('pages_menus_defilement'), const Offset(300, 0));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300)); // fin du « coup de pouce » de la page
    }
    expect(menusDeLaPage(tester, TuileMenu), greaterThan(0), reason: titrePage(tester));
    final premiere = find.descendant(of: cle('pages_menus_defilement'), matching: find.byType(TuileMenu)).hitTestable().first;
    final titre = tester.widget<TuileMenu>(premiere).titre;
    await tester.tap(premiere);
    await stabiliser(tester, tours: 10);
    expect(find.byType(AccueilNouveau).hitTestable(), findsNothing, reason: 'module « $titre » ouvert');
    await revenirALAccueil(tester);
    await terminer(tester);
  });

  testWidgets('accueil B en « 6 tuiles par page » : 6 lignes au plus par page ; la recherche revient à plat', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.compact, affichage: AffichageMenus.parSix);
    utiliserReseauReel();
    await jusquAccueilNouveau(tester);
    expect(cle('pages_menus'), findsOneWidget);
    expect(cle('page_menus_paquet_0'), findsOneWidget);
    expect(menusDeLaPage(tester, LigneMenu), menusParPage);
    await tester.tap(cle('page_menus_suivante'));
    await stabiliser(tester, tours: 8);
    expect(menusDeLaPage(tester, LigneMenu), inInclusiveRange(1, menusParPage));
    await tester.enterText(cle('recherche_menu'), 'stock');
    await stabiliser(tester, tours: 4);
    expect(cle('pages_menus'), findsNothing);
    expect(dansAccueil('Etat de Stock'), findsOneWidget);
    await terminer(tester);
  });

  testWidgets('Pointage BL par groupe de grossistes depuis l\'accueil : groupe envoyé, montant du groupe', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrirDepuisA(tester, 'Pointage BL');
    await attendreWidget(tester, cle('pointage_pourquoi'));
    await toucher(tester, cle('pointage_mode_groupe'), defilement: cle('defilement_pointage'));
    expect(serveur.recues(ApiPointage.route), isEmpty);
    await toucher(tester, cle('pointage_groupe'), defilement: cle('defilement_pointage'));
    await toucher(tester, find.text('GROUPE FICTIF').last);
    await attendreWidget(tester, cle('pointage_montant'));
    final p = serveur.recues(ApiPointage.route).single.parametres;
    expect([p['grossiste'], p['groupe']], ['', DonneesVague3.groupe]);
    expect(find.text('Montant du groupe'), findsOneWidget);
    await revenirALAccueil(tester);
    await terminer(tester);
  });

  testWidgets('serveur récent : rôle affiché dans Réglages › Compte ; serveur ancien : aucune ligne', (tester) async {
    telephone(tester);
    connexion(role: {'code': 'PHARMACIEN', 'libelle': 'Pharmacien'});
    await jusquAccueilNouveau(tester);
    expect(ProfilAcces.serveurRecent, isTrue);
    await toucherReglages(tester);
    await tester.scrollUntilVisible(cle('reglages_role'), 200, scrollable: find.byType(Scrollable).hitTestable().first, maxScrolls: 40);
    expect(find.text('Rôle : Pharmacien'), findsOneWidget);
    await terminer(tester);

    connexion();
    utiliserReseauReel();
    await jusquAccueilNouveau(tester);
    expect(ProfilAcces.serveurRecent, isFalse);
    await toucherReglages(tester);
    await tester.scrollUntilVisible(cle('reglages_version'), 200, scrollable: find.byType(Scrollable).hitTestable().first, maxScrolls: 40);
    expect(cle('reglages_role'), findsNothing);
    await terminer(tester);
  });
}
