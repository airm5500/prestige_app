// Bout en bout des modules refaits du LOT 3 (analyses, nouvelle interface) : l'application ENTIÈRE parle en HTTP
// réel au faux serveur Prestige local. Pour chaque module : ouverture depuis l'accueil (recherche de menu,
// présentation B), chiffres clés, période, filtres (feuille du bas) ou recherche locale, graphique (choix de la vue),
// détail, retour à l'accueil. Ces modules n'avaient AUCUN export : pas de menu « Exporter » (vérifié), sauf Stat TVA,
// Marge et CA Crédit qui ont un PDF depuis la 3.8.0 (menu présent ; contenu dans integration/retours_3_8_0_test.dart). Puis : erreur
// du serveur et « Réessayer », droit manquant (sans Réessayer), serveur injoignable, session expirée pendant un
// changement de période (retour à la connexion, mécanisme existant).
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/donnees/analyses_pdf.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/modules/tableau_ratios_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/catalogue_ecrans.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_lot3.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

String jour(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
final aujourdhui = DateTime.now();
final hier = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day - 1);
final ilYa6Jours = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day - 6);

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

Future<void> retourSysteme(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await stabiliser(tester, tours: 4);
}

ModuleLot1 module(String tuile) => modulesLot3.firstWhere((m) => m.tuile == tuile);

/// Ouvre [m] par la recherche de menu de l'accueil B et attend son nouvel écran (sans menu « Exporter » : ces
/// modules n'avaient pas d'export).
Future<void> ouvrir(WidgetTester tester, ModuleLot1 m) async {
  await tester.enterText(find.byKey(const Key('recherche_menu')), m.tuile);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.descendant(of: find.byKey(const Key('defilement_menus')), matching: find.text(m.tuile)).first);
  await attendreWidget(tester, find.byType(m.typeNouveau));
  expect(find.widgetWithText(AppBar, m.titreEcran), findsOneWidget);
  // 3.8.0 (B4) : Stat TVA, Marge et CA Crédit ont un PDF dans « Exporter » ; les autres modules du lot 3 n'en ont pas.
  if (_avecPdf.contains(m.tuile)) {
    expect(find.byKey(const Key('menu_exports')), findsOneWidget, reason: 'PDF (3.8.0)');
  } else {
    expect(find.byKey(const Key('menu_exports')), findsNothing, reason: 'aucun export à l\'origine');
  }
}

/// Modules du lot 3 exportés en PDF depuis la 3.8.0 (tuiles de l'accueil).
final _avecPdf = {
  for (final m in modulesLot3)
    if (const ['Statistiques TVA', 'Marge Produits Vendus', 'Ventes à Crédit'].contains(m.titreEcran)) m.tuile,
};

Future<void> revenir(WidgetTester tester, ModuleLot1 m) async {
  await retourSysteme(tester);
  await attendreQue(tester, () => find.byType(m.typeNouveau).evaluate().isEmpty, raison: 'retour depuis ${m.tuile}');
  expect(find.byType(AccueilNouveau).hitTestable(), findsOneWidget);
  await tester.enterText(find.byKey(const Key('recherche_menu')), '');
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> toucher(WidgetTester tester, Finder f, {int tours = 6}) async {
  await tester.ensureVisible(f.first);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(f.first);
  await stabiliser(tester, tours: tours);
}

/// 3.11.0 : 7 jours, Ce mois et Mois dernier sont dans le sélecteur « Autres périodes ».
Future<void> choisirPeriode(WidgetTester tester, String nom) =>
    const {'aujourdhui', 'septJours', 'ceMois', 'moisDernier'}.contains(nom) ? choisirAutrePeriode(tester, nom) : toucher(tester, find.byKey(Key('periode_$nom')), tours: 2);

/// Feuille des filtres : [reglages] puis « Appliquer ».
Future<void> filtrer(WidgetTester tester, Future<void> Function() reglages) async {
  await toucher(tester, find.byKey(const Key('bouton_filtres')));
  expect(find.byKey(const Key('feuille_filtres')), findsOneWidget);
  await reglages();
  await toucher(tester, find.byKey(const Key('filtres_appliquer')));
}

Future<void> choisirDansListe(WidgetTester tester, Finder liste, String option) async {
  await toucher(tester, liste, tours: 4);
  await tester.tap(find.text(option).hitTestable().last);
  await stabiliser(tester, tours: 4);
}

String chiffre(WidgetTester tester, String id) => tester.widget<Text>(find.byKey(Key('chiffre_$id'))).data!;

/// Fait défiler la liste du module jusqu'à [f].
Future<void> amener(WidgetTester tester, Finder f, {String defilement = 'defilement_module'}) async {
  final s = find.descendant(of: find.byKey(Key(defilement)), matching: find.byType(Scrollable)).first;
  for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
    await tester.drag(s, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(f, findsWidgets);
}

/// Saisit [texte] dans la recherche contrôlée et attend l'anti-rebond (0,5 s).
Future<void> rechercher(WidgetTester tester, String texte) async {
  await tester.enterText(find.byKey(const Key('champ_recherche')), texte);
  await tester.pump(const Duration(milliseconds: 600));
  await stabiliser(tester, tours: 2);
}

/// Remonte la liste du module jusqu'à [f].
Future<void> remonter(WidgetTester tester, Finder f) async {
  final s = find.descendant(of: find.byKey(const Key('defilement_module')), matching: find.byType(Scrollable)).first;
  for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
    await tester.drag(s, const Offset(0, 400));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(f, findsWidgets);
}

/// Ouvre le détail de [ligne] (feuille du bas) puis le referme.
Future<void> detail(WidgetTester tester, Finder ligne, {List<String> attendus = const []}) async {
  await amener(tester, ligne);
  await toucher(tester, ligne);
  expect(find.byKey(const Key('feuille_detail')), findsOneWidget);
  for (final t in attendus) {
    expect(find.descendant(of: find.byKey(const Key('feuille_detail')), matching: find.text(t)), findsWidgets, reason: t);
  }
  await toucher(tester, find.byKey(const Key('detail_fermer')));
  expect(find.byKey(const Key('feuille_detail')), findsNothing);
}

void main() {
  setUpAll(chargerPolicesReelles);

  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    preparerNouvelle(serveur, p: Presentation.compact);
    donneesAccueil(serveur);
    donneesLot3(serveur);
  });

  tearDown(() async {
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true;
  });

  const routeTableau = AppConstants.tableauBordAchatsVentesEndpoint;

  // 3.8.0 (B1, choix du pharmacien) : ouverture sur « Ce mois » (1er du mois → aujourd'hui) au lieu d'« Aujourd'hui ».
  testWidgets('Tableau : Analyses : « Ce mois », chiffres, « 7 jours », vue Ventes du graphique, détail d\'un jour, retour', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    final m = module('Tableau: Analyses');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_ventes')));
    expect(serveur.recues(routeTableau).single.parametres, {'dtStart': jour(DateTime(aujourdhui.year, aujourdhui.month, 1)), 'dtEnd': jour(aujourdhui)});
    expect(chiffre(tester, 'ventes'), formaterMontant(DonneesLot3.totalVentes));
    expect(chiffre(tester, 'achats'), formaterMontant(DonneesLot3.totalAchats));
    expect(chiffre(tester, 'ratio'), '1,55');
    await choisirPeriode(tester, 'septJours');
    await attendreQue(tester, () => serveur.recues(routeTableau).length == 2, raison: '7 jours');
    expect(serveur.recues(routeTableau).last.parametres, {'dtStart': jour(ilYa6Jours), 'dtEnd': jour(aujourdhui)});
    await stabiliser(tester);
    await amener(tester, find.byKey(const Key('graphique_ventes')));
    await toucher(tester, find.byKey(const Key('graphique_ventes')), tours: 2);
    expect(tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData, hasLength(1), reason: 'ventes seules');
    await detail(tester, find.text('07/10/2026'), attendus: [formaterMontant(150000), formaterMontant(270000), '1,80']);
    expect(serveur.recues(routeTableau), hasLength(2), reason: 'vue et détail : aucune nouvelle requête');
    await revenir(tester, m);
    await terminer(tester);
  });

  // 3.8.0 (B2) : Ratios mensuels sur les 12 derniers mois glissants (au lieu de l'année en cours).
  testWidgets('Tableau : Ratios : jours ≥ norme, calcul normé, Ratios mensuels (12 derniers mois), retour', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    final m = module('Tableau: Ratios');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_ratio')));
    expect(chiffre(tester, 'ratio'), '1,55');
    expect(chiffre(tester, 'jours_norme'), '5 / 9');
    expect(find.text('≥ norme'), findsWidgets);
    await amener(tester, find.byKey(const Key('norme_vente')));
    await tester.enterText(find.byKey(const Key('norme_vente')), '151000');
    await stabiliser(tester, tours: 2);
    expect(tester.widget<Text>(find.byKey(const Key('norme_achat_resultat'))).data, formaterMontant(100000));
    await toucher(tester, find.byKey(const Key('ratios_mensuels_barre')));
    await attendreWidget(tester, find.byKey(const Key('chiffre_mois_norme')));
    expect(find.byType(RatiosMensuelsNouveau), findsOneWidget);
    expect(serveur.recues(routeTableau).last.parametres,
        {'dtStart': jour(DateTime(aujourdhui.year, aujourdhui.month - 11, 1)), 'dtEnd': jour(aujourdhui)});
    expect(chiffre(tester, 'mois_norme'), '2 / 3');
    expect(find.byType(BarChart), findsOneWidget);
    await retourSysteme(tester);
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('Suivi 20/80 : 50 articles, filtre 80 articles, Afficher plus (sans requête), détail, retrait du filtre, retour', (tester) async {
    telephone(tester);
    const route = AppConstants.suivi2080Endpoint;
    await jusquAccueilNouveau(tester);
    final m = module('Suivi 20/80');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_articles')));
    expect(chiffre(tester, 'articles'), '50');
    expect(serveur.recues(route).single.parametres, containsPair('limit', '50'));
    await filtrer(tester, () async {
      await tester.enterText(find.byKey(const Key('filtre_limite')), '80');
      await stabiliser(tester, tours: 2);
    });
    await attendreQue(tester, () => serveur.recues(route).length == 2, raison: '80 articles');
    expect(serveur.recues(route).last.parametres, containsPair('limit', '80'));
    await stabiliser(tester);
    expect(chiffre(tester, 'articles'), '80');
    expect(find.text('80 articles au plus'), findsOneWidget);
    await amener(tester, find.byKey(const Key('bouton_afficher_plus')));
    await toucher(tester, find.byKey(const Key('bouton_afficher_plus')), tours: 2);
    expect(find.byKey(const Key('bouton_afficher_plus')), findsNothing, reason: 'les 80 sont affichés');
    expect(serveur.recues(route), hasLength(2), reason: 'Afficher plus : aucune requête');
    await remonter(tester, find.text('3. PRODUIT FICTIF 20-80 N3'));
    await detail(tester, find.text('3. PRODUIT FICTIF 20-80 N3'), attendus: [formaterMontant(245500)]);
    await remonter(tester, find.byKey(const Key('filtres_retirer')));
    await toucher(tester, find.byKey(const Key('filtres_retirer')));
    await attendreQue(tester, () => serveur.recues(route).length == 3, raison: 'retrait du filtre');
    expect(serveur.recues(route).last.parametres, containsPair('limit', '50'));
    await stabiliser(tester);
    // 3.8.0 (B3) : classement par quantité (vingtType=QTY), puis retour au chiffre d'affaires (requête d'origine).
    expect(serveur.recues(route).last.parametres.containsKey('vingtType'), isFalse);
    final origine = serveur.recues(route).last.parametres;
    await remonter(tester, find.byKey(const Key('classement_quantite')));
    await toucher(tester, find.byKey(const Key('classement_quantite')), tours: 2);
    await attendreQue(tester, () => serveur.recues(route).length == 4, raison: 'par quantité');
    expect(serveur.recues(route).last.parametres, {...origine, 'vingtType': 'QTY'});
    await stabiliser(tester);
    expect(find.text('ARTICLES (PAR QUANTITÉ VENDUE)'), findsOneWidget);
    await toucher(tester, find.byKey(const Key('classement_chiffreAffaires')), tours: 2);
    await attendreQue(tester, () => serveur.recues(route).length == 5, raison: 'par chiffre d\'affaires');
    expect(serveur.recues(route).last.parametres, origine);
    await stabiliser(tester);
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('Stat TVA : API v3, totaux, filtre type de vente, part touchée, détail d\'un taux, retour', (tester) async {
    telephone(tester);
    const route = AppConstants.statTvaEndpoint;
    await jusquAccueilNouveau(tester);
    final m = module('Stat TVA');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_ttc')));
    expect(serveur.recues(route).single.versionApi, 'v3');
    expect(serveur.recues(route).single.parametres, {'dtStart': jour(aujourdhui), 'dtEnd': jour(aujourdhui), 'typeVente': 'TOUT'});
    expect(chiffre(tester, 'ttc'), formaterMontant(1749000));
    expect(chiffre(tester, 'taux'), '3');
    expect(find.text('18 % · 33,7 %'), findsOneWidget);
    await detail(tester, find.text('TVA 18 %'), attendus: [formaterMontant(90000), '33,7 %']);
    await filtrer(tester, () => toucher(tester, find.byKey(const Key('filtre_type_vno')), tours: 2));
    await attendreQue(tester, () => serveur.recues(route).length == 2, raison: 'type de vente');
    expect(serveur.recues(route).last.parametres, containsPair('typeVente', 'VNO'));
    await stabiliser(tester);
    expect(chiffre(tester, 'taux'), '2');
    expect(find.text('Vente Non-Ordonnancée'), findsOneWidget, reason: 'étiquette du filtre');
    await amener(tester, find.byType(PieChart));
    await tester.ensureVisible(find.byType(PieChart));
    await stabiliser(tester, tours: 2);
    await tester.tapAt(tester.getCenter(find.byType(PieChart)) + const Offset(60, 20));
    await stabiliser(tester, tours: 2);
    expect(tester.widget<Text>(find.byKey(const Key('anneau_centre'))).data, endsWith('%'), reason: 'part du taux touché au centre');
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('Marge Produits Vendus : filtre de marge LOCAL, recherche locale, détail, retrait, retour', (tester) async {
    telephone(tester);
    const route = AppConstants.margeProduitsVendusEndpoint;
    await jusquAccueilNouveau(tester);
    final m = module('Marge Produits Vendus');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_produits')));
    expect(chiffre(tester, 'produits'), '${DonneesLot3.produitsMarge}');
    expect(find.byKey(const Key('bouton_afficher_plus')), findsNothing, reason: 'affiché plus bas');
    await filtrer(tester, () async {
      await toucher(tester, find.byKey(const Key('filtre_operateur_superieur')), tours: 2);
      await tester.enterText(find.byKey(const Key('filtre_marge')), '40');
      await stabiliser(tester, tours: 2);
    });
    expect(chiffre(tester, 'produits'), '24');
    expect(find.text('Marge > 40 %'), findsOneWidget);
    await rechercher(tester, 'N50');
    expect(chiffre(tester, 'produits'), '1');
    await detail(tester, find.text('PRODUIT FICTIF MARGE N50'), attendus: ['44 %']);
    expect(serveur.recues(route), hasLength(1), reason: 'filtre et recherche locaux');
    await remonter(tester, find.byKey(const Key('filtres_retirer')));
    await toucher(tester, find.byKey(const Key('filtres_retirer')));
    await rechercher(tester, '');
    expect(chiffre(tester, 'produits'), '${DonneesLot3.produitsMarge}');
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('CA Crédit : recherche et filtre tiers payant LOCAUX, détail, période « Hier », retour', (tester) async {
    telephone(tester);
    const route = AppConstants.caCreditEndpoint;
    await jusquAccueilNouveau(tester);
    final m = module('CA Crédit');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_montant')));
    expect(chiffre(tester, 'montant'), formaterMontant(DonneesLot3.totalCredit));
    expect(chiffre(tester, 'clients'), '3');
    await rechercher(tester, 'beta');
    expect(chiffre(tester, 'ventes'), '2');
    await rechercher(tester, '');
    await filtrer(tester, () => choisirDansListe(tester, find.byKey(const Key('filtre_tiers')), DonneesLot3.assuranceA));
    expect(chiffre(tester, 'ventes'), '3');
    expect(chiffre(tester, 'montant'), formaterMontant(12500 + 8300 + 4700));
    await detail(tester, find.text('CLIENT FICTIF GAMMA'), attendus: ['FAC-T-004', DonneesLot3.assuranceA]);
    expect(serveur.recues(route), hasLength(1), reason: 'recherche et filtre locaux');
    // 3.8.0 (B4) : Exporter → PDF des ventes AFFICHÉES (filtre tiers payant repris), sans requête.
    final sorties = <(ContenuAnalysePdf, String)>[];
    final avant = AnalysesPdf.sortie;
    AnalysesPdf.sortie = (c, nom) async => sorties.add((c, nom));
    addTearDown(() => AnalysesPdf.sortie = avant);
    await toucher(tester, find.byKey(const Key('menu_exports')));
    await toucher(tester, find.text('PDF des ventes à crédit'));
    await attendreQue(tester, () => sorties.isNotEmpty, raison: 'PDF produit');
    final (contenu, nom) = sorties.single;
    expect(nom, 'CA_credit_${jour(aujourdhui)}');
    expect(contenu.filtres, [('Tiers payant', DonneesLot3.assuranceA)]);
    expect(contenu.lignes, hasLength(3));
    expect(contenu.total!.last, formaterMontant(12500 + 8300 + 4700));
    expect(serveur.recues(route), hasLength(1), reason: 'export sans requête');
    await choisirPeriode(tester, 'hier');
    await attendreQue(tester, () => serveur.recues(route).length == 2, raison: 'hier');
    expect(serveur.recues(route).last.parametres, {'dtStart': jour(hier), 'dtEnd': jour(hier)});
    await stabiliser(tester);
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('CA Global : brut, net, modes de paiement, « Ce mois », détail d\'un jour, retour', (tester) async {
    telephone(tester);
    const route = AppConstants.caAllEndpoint;
    await jusquAccueilNouveau(tester);
    final m = module('CA Global');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_brut')));
    expect(chiffre(tester, 'brut'), formaterMontant(DonneesFictives.totalBrutCa));
    expect(chiffre(tester, 'net'), formaterMontant(DonneesFictives.totalBrutCa - (8400 + 6100 + 4300)));
    await choisirPeriode(tester, 'ceMois');
    await attendreQue(tester, () => serveur.recues(route).length == 2, raison: 'ce mois');
    expect(serveur.recues(route).last.parametres, {'dtStart': jour(DateTime(aujourdhui.year, aujourdhui.month, 1)), 'dtEnd': jour(aujourdhui)});
    await stabiliser(tester);
    await detail(tester, find.text('12/10/2026'), attendus: [formaterMontant(433100)]);
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('erreurs : 500 puis « Réessayer », droit manquant (sans Réessayer), serveur injoignable — ni licence ni déconnexion',
      (tester) async {
    telephone(tester);
    serveur.quand(AppConstants.caAllEndpoint, ReponseFausse.erreurServeur(), methode: 'GET');
    serveur.quand(AppConstants.statTvaEndpoint, ReponseFausse.texte('Interdit', statut: 403), methode: 'GET');
    await jusquAccueilNouveau(tester);
    final global = module('CA Global');
    await ouvrir(tester, global);
    await attendreWidget(tester, find.byType(EtatErreur));
    expect(find.byKey(const Key('erreur_serveur')), findsOneWidget);
    expect(find.textContaining('NullPointer'), findsNothing);
    serveur.quand(AppConstants.caAllEndpoint, ReponseFausse.json(DonneesFictives.caParJour()), methode: 'GET');
    await toucher(tester, find.byKey(const Key('bouton_reessayer')));
    await attendreWidget(tester, find.byKey(const Key('chiffre_brut')));
    await revenir(tester, global);

    final tva = module('Stat TVA');
    await ouvrir(tester, tva);
    await attendreWidget(tester, find.byType(EtatErreur));
    expect(find.text('Droit manquant'), findsOneWidget);
    expect(find.byKey(const Key('bouton_reessayer')), findsNothing, reason: 'réessayer ne changerait rien');
    await revenir(tester, tva);

    await tester.runAsync(serveur.arreter);
    final analyses = module('Tableau: Analyses');
    await ouvrir(tester, analyses);
    await attendreWidget(tester, find.byType(EtatErreur));
    expect(find.byKey(const Key('erreur_reseau')), findsOneWidget);
    expect(find.byKey(const Key('bouton_reessayer')), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    await terminer(tester);
  });

  testWidgets('session expirée pendant un changement de période → connexion avec message', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrir(tester, module('Tableau: Ratios'));
    await attendreWidget(tester, find.byKey(const Key('chiffre_ratio')));
    serveur.expirerSessions();
    await choisirPeriode(tester, 'hier');
    await attendreWidget(tester, find.byType(LoginScreen));
    await attendreTexte(tester, AuthProvider.messageSessionExpiree);
    expect(serveur.recues(routeTableau).last.parametres, {'dtStart': jour(hier), 'dtEnd': jour(hier)});
    await tester.tap(find.text('OK'));
    await stabiliser(tester);
    await seConnecterNouvelle(tester);
    await attendreWidget(tester, find.byType(AccueilNouveau));
    await terminer(tester);
  });
}
