// Parcours de bout en bout des retours du pharmacien (3.9.0), application ENTIÈRE contre le faux serveur local (vrai
// réseau HTTP) :
//  - onglet Analyses : recherche « contient » → liste → analyse du produit (même détail qu'Analyse Article) → retour ;
//  - « Fiche Article » absent de la nouvelle interface (A, B, recherche de menu, C « Tous les menus ») ; l'ancienne
//    interface le garde ;
//  - Suivi 20/80 ouvert depuis l'accueil : « Tous » → topN absent ;
//  - Pointage BL : explication sans grossiste, dernier grossiste repris à l'ouverture suivante ;
//  - Réglages : « Menus de l'accueil » par pages (compte « admin » sans code ; 3.10.0 : profil pharmacien sans code,
//    compte simple verrouillé avec explication, aucun code demandé) → accueil A en pages (balayage, boutons, indicateur), module ouvert depuis une page, choix
//    mémorisé ; B par pages, recherche à plat ; « Style des icônes » visible du seul compte « admin », P1 appliqué à
//    la barre du bas et mémorisé.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/interface_version.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/apparence_accueil.dart';
import 'package:prestige_app/nouvelle_interface/modules/articles_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:prestige_app/screens/home_screen.dart';
import 'package:prestige_app/screens/personalize_home_screen.dart';
import 'package:prestige_app/services/pin_securise.dart';
import 'package:prestige_app/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_lot3.dart';
import '../support/donnees_vague1.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';
import 'parcours_vague2_test.dart' show telephone, toucher, ouvrirDepuisA, revenirALAccueil, retourSysteme;

final serveur = FauxServeurPrestige();
const _code = '5917';

Finder cle(String k) => find.byKey(Key(k));
Finder dansAccueil(String texte) => find.descendant(of: find.byType(AccueilNouveau), matching: find.text(texte));
Future<SharedPreferences> prefs(WidgetTester tester) async => (await tester.runAsync(SharedPreferences.getInstance))!;

void connexionAdmin() {
  serveur.controlerSession = false;
  serveur.quand('/user/auth', ReponseFausse.json({...DonneesFictives.utilisateur(), 'str_LOGIN': 'admin'},
      entetes: {'set-cookie': 'JSESSIONID=fictif-admin; Path=/prestige; HttpOnly'}), methode: 'POST');
}

/// Amène un réglage des Réglages à l'écran et le touche.
Future<void> reglage(WidgetTester tester, String k) async {
  await tester.scrollUntilVisible(cle(k), 200, scrollable: find.byType(Scrollable).hitTestable().first, maxScrolls: 40);
  await stabiliser(tester, tours: 3);
  await tester.tap(cle(k));
  await stabiliser(tester, tours: 6);
}

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

  testWidgets('Analyses : recherche « contient » → analyse du produit → retour ; aucun /info avant le toucher', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrirOnglet(tester, 'Analyses');
    await stabiliser(tester, tours: 4);
    expect(cle('recherche_produit_analyses'), findsOneWidget);
    expect(find.text('Analyse Article'), findsWidgets, reason: 'menus de l\'onglet affichés sans recherche');
    await tester.enterText(cle('champ_recherche'), '500mg');
    await attendreWidget(tester, cle('produit_9990001'));
    expect(serveur.recues(AppConstants.rechercheProduitEndpoint).single.parametres, {'q': '500mg'});
    expect(serveur.recues(AppConstants.infoEndpoint), isEmpty);
    await toucher(tester, cle('produit_9990001'));
    await attendreWidget(tester, find.byType(DetailAnalyseArticle));
    expect(serveur.recues(AppConstants.infoEndpoint).single.parametres, {'search': '9990001'});
    expect(find.text('Détails de l\'article'), findsOneWidget);
    await retourSysteme(tester);
    expect(cle('produit_9990001'), findsOneWidget, reason: 'résultats gardés au retour');
    await tester.tap(find.byTooltip('Effacer la recherche'));
    await stabiliser(tester, tours: 6);
    expect(find.text('Analyse Article'), findsWidgets);
    await retourSysteme(tester); // retour système : revient à l'onglet Accueil
    expect(find.byType(AccueilNouveau), findsOneWidget);
    await terminer(tester);
  });

  testWidgets('« Fiche Article » absent de la nouvelle interface (A, B et sa recherche, C) ; présent dans l\'ancienne', (tester) async {
    telephone(tester);
    tester.view.physicalSize = const Size(411 * 2.625, 5000 * 2.625);
    await jusquAccueilNouveau(tester);
    expect(dansAccueil('Analyse Article'), findsOneWidget);
    expect(dansAccueil('Fiche Article'), findsNothing);
    await terminer(tester);

    preparerNouvelle(serveur, p: Presentation.compact);
    utiliserReseauReel();
    await jusquAccueilNouveau(tester);
    expect(dansAccueil('Fiche Article'), findsNothing);
    await tester.enterText(cle('recherche_menu'), 'fiche');
    await stabiliser(tester, tours: 4);
    expect(find.text('Aucun menu ne correspond.'), findsOneWidget);
    await terminer(tester);

    preparerNouvelle(serveur, p: Presentation.guide);
    utiliserReseauReel();
    await jusquAccueilNouveau(tester);
    await toucher(tester, find.text('Voir tous les menus'));
    expect(find.text('Analyse Article'), findsOneWidget);
    expect(find.text('Fiche Article'), findsNothing);
    await terminer(tester);

    // Ancienne interface : son accueil et sa personnalisation proposent toujours « Fiche Article ».
    preparerTelephone(serveur);
    utiliserReseauReel();
    await ecranConnecte(() => const HomeScreen())(tester, serveur);
    await tester.tap(find.byTooltip('Personnaliser l\'accueil'));
    await stabiliser(tester, tours: 6);
    final titres = [for (final i in tester.widget<PersonalizeHomeScreen>(find.byType(PersonalizeHomeScreen)).allItems) i['title']];
    expect(titres, contains('Fiche Article'));
    await terminer(tester);
  });

  testWidgets('Suivi 20/80 depuis l\'accueil : « Tous » → topN absent, tous les articles', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrirDepuisA(tester, 'Suivi 20/80');
    await attendreWidget(tester, cle('chiffre_articles'));
    expect(serveur.recues(AppConstants.suivi2080Endpoint).single.parametres['topN'], '50');
    await toucher(tester, cle('bouton_filtres'));
    await toucher(tester, cle('filtre_tous'));
    await toucher(tester, cle('filtres_appliquer'));
    await attendreQue(tester, () => serveur.recues(AppConstants.suivi2080Endpoint).length == 2, raison: 'requête « Tous »');
    await stabiliser(tester);
    expect(serveur.recues(AppConstants.suivi2080Endpoint).last.parametres.containsKey('topN'), isFalse);
    expect(tester.widget<Text>(cle('chiffre_articles')).data, '${DonneesLot3.articles2080}');
    await revenirALAccueil(tester);
    await terminer(tester);
  });

  testWidgets('Pointage BL : explication sans grossiste, puis dernier grossiste repris à l\'ouverture suivante', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrirDepuisA(tester, 'Pointage BL');
    await attendreWidget(tester, cle('pointage_pourquoi'));
    expect(serveur.recues(ApiPointage.route), isEmpty);
    await toucher(tester, cle('pointage_grossiste'), defilement: cle('defilement_pointage'));
    await toucher(tester, find.text('GROSSISTE FICTIF').last);
    await attendreWidget(tester, cle('pointage_total'));
    await revenirALAccueil(tester);
    serveur.oublierRequetes();
    await ouvrirDepuisA(tester, 'Pointage BL');
    await attendreWidget(tester, cle('pointage_total'));
    expect(serveur.recues(ApiPointage.route).single.parametres['grossiste'], 'GRO-TEST-1');
    expect(cle('pointage_dernier_choix'), findsOneWidget);
    await revenirALAccueil(tester);
    await terminer(tester);
  });

  testWidgets('compte « admin » : menus par pages (sans code) → accueil A en pages, module ouvert, choix mémorisé ; style P1',
      (tester) async {
    telephone(tester);
    connexionAdmin();
    await jusquAccueilNouveau(tester);
    expect(cle('pages_menus'), findsNothing, reason: 'défaut : sur une page');
    await toucherReglages(tester);
    await reglage(tester, 'affichage_menus_parRubrique');
    expect(find.byKey(const Key('pin_admin_saisie')), findsNothing, reason: 'administrateur : aucun code');
    expect((await prefs(tester)).getInt(ApparenceAccueilPrefs.cleAffichage), 1);
    // Style des icônes : réglage caché, visible ici (compte « admin »).
    await reglage(tester, 'style_icones_p1');
    expect((await prefs(tester)).getString(ApparenceAccueilPrefs.cleStyle), 'p1');
    await retourSysteme(tester);

    // Accueil A par pages : « À surveiller » puis une famille par page.
    expect(cle('pages_menus'), findsOneWidget);
    expect(cle('indicateur_pages'), findsOneWidget);
    String titre() => tester.widget<Text>(cle('page_menus_titre')).textSpan!.toPlainText();
    expect(titre(), startsWith('À SURVEILLER'));
    await tester.fling(cle('pages_menus_defilement'), const Offset(-400, 0), 1500);
    await stabiliser(tester, tours: 10);
    expect(titre(), startsWith('VENTES & CAISSE'), reason: 'balayage vers la gauche : page suivante');
    await tester.tap(cle('page_menus_suivante'));
    await stabiliser(tester, tours: 10);
    expect(titre(), startsWith('CRÉDITS & CLIENTS'));
    await tester.tap(cle('page_menus_precedente'));
    await stabiliser(tester, tours: 10);
    expect(titre(), startsWith('VENTES & CAISSE'));
    await toucher(tester, dansAccueil('Détail CA'));
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Détail CA'));
    await revenirALAccueil(tester);
    // Barre du bas en P1 : indicateur coloré de l'onglet actif.
    final barre = tester.widget<NavigationBar>(cle('barre_accueil'));
    expect(barre.indicatorColor, teinteOnglet(OngletAccueil.accueil).pastille);
    await terminer(tester);

    // Relance (lecture des préférences comme main()) : les deux choix sont repris.
    ApparenceAccueilPrefs.reinitialiser();
    await tester.runAsync(InterfaceVersion.load);
    expect(ApparenceAccueilPrefs.affichage.value, AffichageMenus.parRubrique);
    utiliserReseauReel();
    await jusquAccueilNouveau(tester);
    expect(cle('pages_menus'), findsOneWidget);
    expect(ApparenceAccueilPrefs.style.value, StyleIcones.p1);
    await terminer(tester);
  });

  testWidgets('3.10.0 · profil pharmacien (pas « admin ») : « Menus de l\'accueil » changé sans code ; style des icônes caché',
      (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    expect(ProfilAcces.responsable, isTrue, reason: 'compte fictif : profil « dashboard » (pharmacien)');
    await toucherReglages(tester);
    expect(cle('style_icones_p1'), findsNothing, reason: 'réglage caché aux autres comptes que « admin »');
    expect(cle('affichage_menus_verrouille'), findsNothing);
    await reglage(tester, 'affichage_menus_parRubrique');
    expect(cle('pin_admin_saisie'), findsNothing, reason: 'pharmacien : aucun code');
    expect(ApparenceAccueilPrefs.affichage.value, AffichageMenus.parRubrique);
    expect((await prefs(tester)).getInt(ApparenceAccueilPrefs.cleAffichage), 1);
    await reglage(tester, 'affichage_menus_parSix');
    expect((await prefs(tester)).getInt(ApparenceAccueilPrefs.cleAffichage), 2);
    await terminer(tester);
  });

  testWidgets('3.10.0 · compte simple (ni administrateur ni pharmacien) : « Menus de l\'accueil » verrouillé, explication, aucun code',
      (tester) async {
    telephone(tester);
    serveur.quand('/user/auth', ReponseFausse.json({...DonneesFictives.utilisateur(), 'xtypeuser': 'mainmenumanager'},
        entetes: {'set-cookie': 'JSESSIONID=fictif-caisse; Path=/prestige; HttpOnly'}), methode: 'POST');
    serveur.controlerSession = false;
    expect(await tester.runAsync(() => CodeAdmin.instance.definir(_code)), isNull);
    await jusquAccueilNouveau(tester);
    expect(ProfilAcces.responsable, isFalse);
    await toucherReglages(tester);
    expect(cle('affichage_menus_verrouille'), findsOneWidget);
    expect(find.text(ApparenceAccueilPrefs.explicationAffichageVerrouille), findsWidgets);
    await reglage(tester, 'affichage_menus_parRubrique');
    expect(cle('pin_admin_saisie'), findsNothing, reason: 'plus de code administrateur pour ce réglage');
    expect(cle('affichage_menus_refus'), findsOneWidget, reason: 'explication au toucher');
    expect(ApparenceAccueilPrefs.affichage.value, AffichageMenus.unePage);
    expect((await prefs(tester)).getInt(ApparenceAccueilPrefs.cleAffichage), isNull);
    await terminer(tester);
  });

  testWidgets('présentation B par pages : une famille par page, la recherche de menu revient à plat', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.compact, affichage: AffichageMenus.parRubrique);
    utiliserReseauReel();
    await jusquAccueilNouveau(tester);
    expect(cle('pages_menus'), findsOneWidget);
    expect(cle('page_menus_ventes'), findsOneWidget);
    await tester.enterText(cle('recherche_menu'), 'stock');
    await stabiliser(tester, tours: 4);
    expect(cle('pages_menus'), findsNothing);
    expect(cle('defilement_menus'), findsOneWidget);
    expect(dansAccueil('Etat de Stock'), findsOneWidget);
    await toucher(tester, dansAccueil('Etat de Stock'));
    await attendreWidget(tester, find.widgetWithText(AppBar, 'État de Stock'));
    await revenirALAccueil(tester);
    await terminer(tester);
  });
}
