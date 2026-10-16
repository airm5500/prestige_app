// Bout en bout de la 3.11.0 : l'application ENTIÈRE (main.dart) parle en HTTP réel au faux serveur Prestige local.
//  - migration : un téléphone qui avait choisi A ouvre le TABLEAU DE BORD (une seule fois) ; un choix fait ensuite
//    est gardé ; cartes du tableau de bord (chargement, « Cartes » : masquer et ordre mémorisés), « Tous les menus » ;
//  - Balance vente / caisse : quatre onglets, analyse chargée à la première ouverture, « Surveiller et alertes » ;
//  - Sur-stocks : liste, « Afficher plus » (start=50), jamais de création d'inventaire ;
//  - menus réunis (Achats Fourn. et CA Crédit : Détail | Synthèse) ; « Evolution Stock » dans la Valorisation ;
//  - cloche : avoirs et saisies en périmés dans « À surveiller » ;
//  - écran de chargement « Prestige Pharmacien » (étapes).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/interface_version.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/menus.dart';
import 'package:prestige_app/nouvelle_interface/modules/achats_fournisseurs_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/ca_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/controle_achat_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suivi_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/donnees_vague1.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague4/balance_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/donnees_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/perimes_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/surstock_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/tableau_bord_vague4.dart';
import 'package:prestige_app/screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_vague1.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

Future<void> retourSysteme(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await stabiliser(tester, tours: 4);
}

Future<void> toucher(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible.first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(cible.hitTestable().first);
  await stabiliser(tester, tours: 6);
}

/// Ouvre un menu : depuis le tableau de bord par « Tous les menus », sinon par la recherche de l'accueil B.
Future<void> ouvrirMenu(WidgetTester tester, String titre) async {
  if (find.byKey(const Key('recherche_menu')).evaluate().isNotEmpty) {
    await tester.enterText(find.byKey(const Key('recherche_menu')), titre);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.descendant(of: find.byKey(const Key('defilement_menus')), matching: find.text(titre)).first);
    await stabiliser(tester, tours: 6);
    return;
  }
  await toucher(tester, find.text('Tous les menus'));
  final cible = find.descendant(of: find.byKey(const Key('defilement_menus')), matching: find.text(titre));
  final scrollable = find.descendant(of: find.byKey(const Key('defilement_menus')), matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(cible.first, 200, scrollable: scrollable, maxScrolls: 60);
  await toucher(tester, cible);
}

void main() {
  setUpAll(chargerPolicesReelles);

  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    donneesAccueil(serveur);
    listesCommunesVague1(serveur);
    ComptageSaisiesPerimes.oublier();
    CartesTableauBordPrefs.cartes.value = CartesTableauBordPrefs.defaut;
  });

  tearDown(() async {
    expect(serveur.recues(ApiSurstock.routeInterdite), isEmpty, reason: 'création d\'inventaire : jamais');
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..parDefaut = ((_) => ReponseFausse.json(DonneesFictives.listeVide()));
    ProfilAcces.utilisateur.value = null;
    ReglagesAlertes.oublier();
  });

  testWidgets('migration : l\'accueil A choisi avant la 3.11.0 devient le tableau de bord, une seule fois ; cartes, « Cartes », « Tous les menus »',
      (tester) async {
    telephone(tester);
    // Téléphone d'avant la 3.11.0 : présentation A enregistrée, migration jamais faite.
    preparerNouvelle(serveur, p: Presentation.tableauDeBord, prefs: {PresentationPrefs.cleMigration: false});
    await tester.runAsync(InterfaceVersion.load); // lecture des réglages au lancement (main.dart)
    await jusquAccueilNouveau(tester);
    await attendreWidget(tester, find.byType(AccueilTableauPrestige));
    expect(PresentationPrefs.choix.value, Presentation.tableauPrestige);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PresentationPrefs.cleMigration), isTrue);
    expect(prefs.getString(PresentationPrefs.cle), 'tableauPrestige');

    // Cartes : chiffres du jour (route du tableau de bord), évolution du mois.
    await attendreWidget(tester, find.byKey(const Key('chiffre_tb_ca')));
    expect(serveur.recues('/tableau-bord/tuiles'), hasLength(1));
    expect(find.byKey(const Key('carte_tableau_bord_evolution')), findsOneWidget);
    // Boutons de l'en-tête : Actualiser, Réglages, puis Déconnexion (en dernier, rouge).
    final x = [for (final k in ['tableau_bord_actualiser', 'bouton_reglages', 'bouton_deconnexion']) tester.getCenter(find.byKey(Key(k)).first).dx];
    expect(x[0] < x[1] && x[1] < x[2], isTrue, reason: 'déconnexion après les Réglages');

    // « Cartes » : masquer « Chiffres du jour », mémorisé.
    await toucher(tester, find.text('Cartes'));
    await toucher(tester, find.byKey(const Key('carte_visible_chiffres')));
    await toucher(tester, find.byKey(const Key('filtres_appliquer')));
    expect(find.byKey(const Key('carte_tableau_bord_chiffres')), findsNothing);
    expect(prefs.getString(CartesTableauBordPrefs.cle), startsWith('chiffres:0'));

    // ⟳ : recharge les cartes affichées.
    final avant = serveur.recues('/ws/ca-achats-ventes').length;
    await toucher(tester, find.byKey(const Key('tableau_bord_actualiser')));
    await attendreQue(tester, () => serveur.recues('/ws/ca-achats-ventes').length > avant, raison: 'actualisation');

    // Les menus restent accessibles.
    await toucher(tester, find.text('Tous les menus'));
    expect(find.byType(TousLesMenusScreen), findsOneWidget);
    await retourSysteme(tester);

    // Choix fait ensuite (A) : gardé, plus de migration.
    await PresentationPrefs.enregistrer(Presentation.tableauDeBord);
    expect(await PresentationPrefs.charger(), Presentation.tableauDeBord);
    await terminer(tester);
  });

  testWidgets('appareil neuf : tableau de bord ; fréquentation Aujourd\'hui → Hier ; top 10 par famille', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.automatique, prefs: {PresentationPrefs.cleMigration: false});
    await tester.runAsync(InterfaceVersion.load);
    await jusquAccueilNouveau(tester);
    await attendreWidget(tester, find.byType(AccueilTableauPrestige));
    final defilement = find.descendant(of: find.byKey(const Key('defilement_tableau_bord')), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const Key('frequentation_hier')), 300, scrollable: defilement, maxScrolls: 30);
    await attendreWidget(tester, find.byKey(const Key('frequentation_resume')));
    await toucher(tester, find.byKey(const Key('frequentation_hier')));
    final hier = DateTime.now().subtract(const Duration(days: 1));
    String j(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    await attendreQue(tester, () => serveur.recues('/pilotage/suivi/frequentation').last.parametres['dtStart'] == j(hier), raison: 'hier');
    await tester.scrollUntilVisible(find.byKey(const Key('top_familles')), 300, scrollable: defilement, maxScrolls: 30);
    await toucher(tester, find.byKey(const Key('top_familles')));
    await attendreQue(tester, () => serveur.recues('/tableau-bord/emplacements').last.parametres['axe'] == 'famille', raison: 'familles');
    await attendreTexte(tester, '1. FAMILLE FICTIVE 0');
    await terminer(tester);
  });

  testWidgets('Balance vente / caisse : Balance, Analyse (chargée à la première ouverture), Évolution par mode (même appel), Surveiller et alertes',
      (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.compact);
    await jusquAccueilNouveau(tester);
    await ouvrirMenu(tester, 'Balance vente / caisse');
    await attendreWidget(tester, find.byType(BalanceCaisseScreen));
    await attendreWidget(tester, find.byKey(const Key('chiffre_balance_net')));
    expect(serveur.recues(ApiBalance.routeAnalyse), isEmpty, reason: 'onglet pas encore ouvert');
    expect(find.text('COMPTANT · 52 ventes'), findsOneWidget);

    await toucher(tester, find.byKey(const Key('balance_onglet_analyse')));
    await attendreWidget(tester, find.byKey(const Key('analyse_periode_1')));
    expect(serveur.recues(ApiBalance.routeAnalyse).single.parametres, {'typePeriode': 'TROIS_SEMAINES'});
    await toucher(tester, find.byKey(const Key('balance_onglet_modes')));
    await attendreWidget(tester, find.byKey(const Key('modes_periode_0')));
    expect(serveur.recues(ApiBalance.routeAnalyse), hasLength(1), reason: 'les deux onglets partagent le même appel');
    await toucher(tester, find.byKey(const Key('modes_periode_TROIS_MOIS')));
    await attendreQue(tester, () => serveur.recues(ApiBalance.routeAnalyse).last.parametres['typePeriode'] == 'TROIS_MOIS', raison: '3 mois');

    await toucher(tester, find.byKey(const Key('balance_onglet_surveiller')));
    await attendreWidget(tester, find.byKey(const Key('alerte_saisies_perimes')));
    expect(find.byKey(const Key('alerte_avoirs')), findsOneWidget);
    expect(find.byKey(const Key('alerte_peremption')), findsOneWidget);
    await toucher(tester, find.byKey(const Key('alerte_saisies_perimes_actualiser')));
    await attendreWidget(tester, find.byKey(const Key('alerte_saisies_perimes_nombre')));
    expect(find.textContaining('3 saisies', findRichText: true), findsOneWidget);
    await terminer(tester);
  });

  testWidgets('Sur-stocks : liste, « Afficher plus » (start=50), critères ; jamais de création d\'inventaire', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.compact);
    await jusquAccueilNouveau(tester);
    await ouvrirMenu(tester, 'Sur-stocks');
    await attendreWidget(tester, find.byType(SurstocksScreen));
    await attendreWidget(tester, find.byKey(const Key('chiffre_surstock_total')));
    expect(serveur.recues(ApiSurstock.route).single.parametres['start'], '0');
    final liste = find.descendant(of: find.byKey(const Key('defilement_surstock')), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const Key('bouton_afficher_plus')), 600, scrollable: liste, maxScrolls: 80);
    await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
    await attendreQue(tester, () => serveur.recues(ApiSurstock.route).length == 2, raison: 'page 2');
    expect(serveur.recues(ApiSurstock.route).last.parametres['start'], '50');
    await terminer(tester);
  });

  testWidgets('menus réunis : Achats Fourn. et CA Crédit (Détail | Synthèse) ; anciens menus séparés absents ; Évolution dans la Valorisation',
      (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.compact);
    await jusquAccueilNouveau(tester);
    final titres = menusAutorises().map((m) => m.titre).toSet();
    expect(titres.containsAll(['Achats Fourn.', 'CA Crédit', 'Valorisation', 'Balance vente / caisse', 'Sur-stocks']), isTrue);
    expect(titres.intersection({'Etat Contrôle Achat', 'Suivi Crédit', 'Evolution Stock'}), isEmpty);

    await ouvrirMenu(tester, 'Achats Fourn.');
    await attendreWidget(tester, find.byType(AchatsFournisseursNouveau));
    expect(find.byType(ControleAchatNouveau), findsNothing, reason: 'Synthèse construite au premier passage seulement');
    await toucher(tester, find.byKey(const Key('onglet_menu_1')));
    await attendreWidget(tester, find.byType(ControleAchatNouveau));
    await retourSysteme(tester);
    await attendreQue(tester, () => find.byType(ControleAchatNouveau).evaluate().isEmpty, raison: 'retour');

    await tester.enterText(find.byKey(const Key('recherche_menu')), '');
    await stabiliser(tester);
    await ouvrirMenu(tester, 'CA Crédit');
    await attendreWidget(tester, find.byType(CaCreditNouveau));
    await toucher(tester, find.byKey(const Key('onglet_menu_1')));
    await attendreWidget(tester, find.byType(SuiviCreditNouveau));
    await terminer(tester);
  });

  testWidgets('écran de chargement « Prestige Pharmacien » : anneau, une ligne d\'étape, étape sur 4 et adresse du serveur, version',
      (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.compact);
    // Licence lente : l'écran de chargement reste affiché à l'étape « licence ».
    serveur.quand('/licence/find', ReponseFausse.json(DonneesFictives.licenceValide()).apres(const Duration(seconds: 2)), methode: 'GET');
    await lancerApplication(tester);
    await attendreWidget(tester, find.byKey(const Key('ecran_chargement')));
    expect(find.text('Prestige Pharmacien'), findsOneWidget);
    expect(find.byKey(const Key('chargement_anneau')), findsOneWidget);
    // Une seule ligne d'étape, parmi les étapes connues ; « Étape n sur 4 · adresse du serveur ».
    final etape = tester.widget<Text>(find.byKey(const Key('chargement_etape'))).data;
    expect(EtapeChargement.values.map((e) => e.texte), contains(etape));
    expect(tester.widget<Text>(find.byKey(const Key('chargement_detail'))).data, matches(RegExp(r'^Étape [1-4] sur 4 · .+:\d+$')));
    await attendreWidget(tester, find.byKey(const Key('connexion_se_connecter')));
    await terminer(tester);
  });
}
