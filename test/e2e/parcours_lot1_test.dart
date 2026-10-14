// Bout en bout des modules refaits du lot 1 (nouvelle interface) : l'application ENTIÈRE parle en HTTP réel au
// faux serveur Prestige local. Pour chaque module : ouverture depuis l'accueil (recherche de menu, présentation B),
// chiffres affichés, changement de période ou recherche, filtre (feuille du bas), retour à l'accueil ; puis erreur
// du serveur et « Réessayer », serveur injoignable, session expirée (retour à la connexion, mécanisme existant),
// recherche contrôlée (anti-rebond, réponse d'une recherche remplacée ignorée).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/charte.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart';
import 'package:prestige_app/nouvelle_interface/modules/articles_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/catalogue_ecrans.dart';
import '../support/donnees_fictives.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

String jour(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
final aujourdhui = DateTime.now();
final hier = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day - 1);

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

Future<void> retourSysteme(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await stabiliser(tester, tours: 4);
}

/// Ouvre [m] par la recherche de menu de l'accueil B et attend son nouvel écran.
Future<void> ouvrir(WidgetTester tester, ModuleLot1 m) async {
  await tester.enterText(find.byKey(const Key('recherche_menu')), m.tuile);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.descendant(of: find.byKey(const Key('defilement_menus')), matching: find.text(m.tuile)).first);
  await attendreWidget(tester, find.byType(m.typeNouveau));
  expect(find.widgetWithText(AppBar, m.titreEcran), findsOneWidget);
}

/// Retour à l'accueil (et recherche de menu effacée).
Future<void> revenir(WidgetTester tester, ModuleLot1 m) async {
  await retourSysteme(tester);
  await attendreQue(tester, () => find.byType(m.typeNouveau).evaluate().isEmpty, raison: 'retour depuis ${m.tuile}');
  expect(find.byType(AccueilNouveau).hitTestable(), findsOneWidget);
  await tester.enterText(find.byKey(const Key('recherche_menu')), '');
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> choisirPeriode(WidgetTester tester, String nom) async {
  await tester.ensureVisible(find.byKey(Key('periode_$nom')));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byKey(Key('periode_$nom')));
}

String chiffre(WidgetTester tester, String id) => tester.widget<Text>(find.byKey(Key('chiffre_$id'))).data!;

ModuleLot1 module(String tuile) => modulesLot1.firstWhere((m) => m.tuile == tuile);

void main() {
  setUpAll(chargerPolicesReelles);

  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    preparerNouvelle(serveur, p: Presentation.compact);
    donneesAccueil(serveur);
    donneesLot1(serveur);
  });

  tearDown(() async {
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true;
  });

  testWidgets('Rapport d\'Activité : ouverture (aujourd\'hui), période « Hier », retour', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    final m = module('Rapport d\'Activité');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_ttc')));
    expect(chiffre(tester, 'ttc'), formaterMontant(2480650));
    expect(serveur.recues(AppConstants.dashboardRecapEndpoint).last.parametres, {'dtStart': jour(aujourdhui), 'dtEnd': jour(aujourdhui)});
    expect(serveur.recues(AppConstants.dashboardRecapEndpoint).last.sessionEnvoyee, serveur.derniereSession);
    for (final c in [AppConstants.creditsRecapEndpoint, AppConstants.creditTotalsRecapEndpoint, AppConstants.reglementsRecapEndpoint]) {
      expect(serveur.recues(c), hasLength(1), reason: c);
    }
    await choisirPeriode(tester, 'hier');
    await attendreQue(tester, () => serveur.recues(AppConstants.dashboardRecapEndpoint).length == 2, raison: 'rapport d\'hier');
    await attendreWidget(tester, find.byKey(const Key('chiffre_ttc')));
    expect(serveur.recues(AppConstants.dashboardRecapEndpoint).last.parametres, {'dtStart': jour(hier), 'dtEnd': jour(hier)});
    expect(tester.widget<Text>(find.byKey(const Key('periode_resume'))).data, startsWith('Hier · '));
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('Détail CA : ouverture, période « 7 jours », jour par jour, retour', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    final m = module('Détail CA');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_total')));
    expect(chiffre(tester, 'total'), formaterMontant(2152650));
    await choisirPeriode(tester, 'septJours');
    await attendreQue(tester, () => serveur.recues(AppConstants.caComptantEndpoint).length == 2, raison: '7 jours');
    final debut = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day - 6);
    expect(serveur.recues(AppConstants.caComptantEndpoint).last.parametres, {'dtStart': jour(debut), 'dtEnd': jour(aujourdhui)});
    await attendreWidget(tester, find.byKey(const Key('chiffre_total')));
    await tester.scrollUntilVisible(find.text('Jour par jour'.toUpperCase()), 300,
        scrollable: find.descendant(of: find.byKey(const Key('defilement_module')), matching: find.byType(Scrollable)).first);
    expect(find.byType(CarteLigne), findsWidgets, reason: 'une carte par jour (téléphone)');
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('Détail CA : Mobile Money déplié (un appel, mêmes dates) puis replié, chiffres inchangés, retour', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    final m = module('Détail CA');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_total')));
    expect(serveur.recues('/stats-recette-caisse/modes'), isEmpty, reason: 'aucun appel à l\'ouverture');
    final defilement = find.descendant(of: find.byKey(const Key('defilement_module')), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const Key('deplier_mobile')), 300, scrollable: defilement);
    expect(tester.getSemantics(find.byKey(const Key('deplier_mobile'))),
        matchesSemantics(label: 'Détail Mobile Money\nTotal Mobile Money\n${formaterMontant(237750)}', isButton: true, hasExpandedState: true, isExpanded: false, hasTapAction: true,
            hint: 'Déplier le détail par opérateur', isFocusable: true, hasFocusAction: true),
        reason: 'flèche annoncée « Détail Mobile Money », état replié');
    await tester.tap(find.byKey(const Key('deplier_mobile')));
    await attendreWidget(tester, find.byKey(const Key('mobile_ligne_Orange')));
    expect(serveur.recues('/stats-recette-caisse/modes'), hasLength(1));
    expect(serveur.recues('/stats-recette-caisse/modes').single.parametres, serveur.recues(AppConstants.caComptantEndpoint).last.parametres);
    expect(serveur.recues('/stats-recette-caisse/modes').single.sessionEnvoyee, serveur.derniereSession);
    expect(find.byKey(const Key('mobile_ligne_Autres / écart')), findsOneWidget);
    String ligne(String l) => tester.widgetList<LigneDetail>(find.byType(LigneDetail)).firstWhere((w) => w.libelle == l).valeur;
    expect(ligne('TOTAL BRUT PAIEMENTS'), formaterMontant(2152650), reason: 'chiffres de /ca-all inchangés');
    expect(ligne('Total Mobile Money'), formaterMontant(237750));
    await tester.tap(find.byKey(const Key('deplier_mobile')));
    await stabiliser(tester);
    expect(find.byKey(const Key('detail_mobile')), findsNothing);
    expect(serveur.recues('/stats-recette-caisse/modes'), hasLength(1));
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('Suivi Crédit : période « Ce mois », filtre tiers payant et type (feuille du bas), retrait, retour', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    final m = module('Suivi Crédit');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_montant')));
    expect(chiffre(tester, 'montant'), formaterMontant(412500));
    await choisirPeriode(tester, 'ceMois');
    await attendreQue(tester, () => serveur.recues(AppConstants.suiviCreditEndpoint).length == 2, raison: 'ce mois');
    expect(serveur.recues(AppConstants.suiviCreditEndpoint).last.parametres,
        {'dtStart': jour(DateTime(aujourdhui.year, aujourdhui.month, 1)), 'dtEnd': jour(aujourdhui)});
    await attendreWidget(tester, find.byKey(const Key('chiffre_montant')));

    await tester.tap(find.byKey(const Key('bouton_filtres')));
    await stabiliser(tester, tours: 6);
    expect(find.byKey(const Key('feuille_filtres')), findsOneWidget);
    await tester.tap(find.byKey(const Key('filtre_type_ASSURANCE')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('filtres_appliquer')));
    await stabiliser(tester, tours: 6);
    expect(chiffre(tester, 'montant'), formaterMontant(243000 + 98500));
    expect(find.text('SOCIETE FICTIVE SARL'), findsNothing);
    expect(find.byTooltip('Filtres (1 actif)'), findsOneWidget);
    expect(serveur.recues(AppConstants.suiviCreditEndpoint), hasLength(2), reason: 'filtre local, aucune requête');
    await tester.tap(find.byKey(const Key('filtres_retirer')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(chiffre(tester, 'montant'), formaterMontant(412500));
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('Suivi Péremption : chiffres, recherche, filtre « mois » (feuille du bas), menu Exporter, détail, retour', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    final m = module('Suivi Péremption');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_lots')));
    expect(chiffre(tester, 'lots'), '${DonneesFictives.lotsPerimes}');
    expect(chiffre(tester, 'quantite'), '9');
    await tester.enterText(find.byKey(const Key('champ_recherche')), 'sirop');
    await attendreQue(tester, () => serveur.recues(AppConstants.suiviPeremptionEndpoint).length == 2, raison: 'recherche');
    expect(serveur.recues(AppConstants.suiviPeremptionEndpoint).last.parametres['query'], 'sirop');

    await tester.tap(find.byKey(const Key('bouton_filtres')));
    await stabiliser(tester, tours: 6);
    await tester.enterText(find.byKey(const Key('filtre_mois')), '200');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('filtres_appliquer')));
    await stabiliser(tester, tours: 4);
    expect(find.text('Nombre de mois invalide (0 à 120).'), findsOneWidget, reason: '200 mois refusé');
    expect(find.byKey(const Key('feuille_filtres')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('filtre_mois')), '3');
    await tester.tap(find.byKey(const Key('filtres_appliquer')));
    await attendreQue(tester, () => serveur.recues(AppConstants.suiviPeremptionEndpoint).length == 3, raison: 'filtre');
    expect(serveur.recues(AppConstants.suiviPeremptionEndpoint).last.parametres, containsPair('nbreMois', '3'));
    expect(serveur.recues(AppConstants.suiviPeremptionEndpoint).last.parametres, containsPair('query', 'sirop'));
    await stabiliser(tester);
    expect(find.text('3 mois'), findsOneWidget, reason: 'saisie « Autre » rappelée dans les puces de période');

    // Période en mois par les puces : 6 mois → nbreMois=6 ; « Déjà périmés » → nbreMois vide (comme l'origine).
    await tester.tap(find.byKey(const Key('periode_mois_6')));
    await attendreQue(tester, () => serveur.recues(AppConstants.suiviPeremptionEndpoint).length == 4, raison: '6 mois');
    expect(serveur.recues(AppConstants.suiviPeremptionEndpoint).last.parametres, containsPair('nbreMois', '6'));
    expect(tester.widget<Text>(find.byKey(const Key('periode_mois_resume'))).data, startsWith('Lots qui périment du '));
    await stabiliser(tester);
    await tester.tap(find.byKey(const Key('periode_mois_perimes')));
    await attendreQue(tester, () => serveur.recues(AppConstants.suiviPeremptionEndpoint).length == 5, raison: 'déjà périmés');
    expect(serveur.recues(AppConstants.suiviPeremptionEndpoint).last.parametres['nbreMois'] ?? '', '');
    expect(tester.widget<Text>(find.byKey(const Key('periode_mois_resume'))).data, startsWith('Lots déjà périmés'));
    await stabiliser(tester);

    // Icône du menu visible sur la barre bleu nuit (blanche, pas la couleur bleu nuit du thème des menus).
    expect(tester.widget<Icon>(find.descendant(of: find.byKey(const Key('menu_exports')), matching: find.byType(Icon))).color, Charte.blanc);
    await tester.tap(find.byKey(const Key('menu_exports')));
    await stabiliser(tester, tours: 4);
    expect(find.text('PDF de la liste'), findsOneWidget);
    await tester.tapAt(const Offset(10, 600));
    await stabiliser(tester, tours: 4);

    await tester.tap(find.text(DonneesFictives.libelleArticle1).first);
    await stabiliser(tester, tours: 6);
    expect(find.byKey(const Key('detail_lot')), findsOneWidget);
    await retourSysteme(tester);
    await stabiliser(tester, tours: 4);
    await revenir(tester, m);
    await terminer(tester);
  });

  for (final (tuile, route, parametre) in [
    ('Analyse Article', AppConstants.infoEndpoint, 'search'),
    ('Fiche Article', AppConstants.checkProduitEndpoint, 'nompdt'),
  ]) {
    testWidgets('$tuile : recherche (anti-rebond, caractères filtrés), fiche détaillée, retour', (tester) async {
      telephone(tester);
      await jusquAccueilNouveau(tester);
      final m = module(tuile);
      await ouvrir(tester, m);
      serveur.oublierRequetes();
      // Saisie rapide : une seule requête après l'anti-rebond ; caractères de contrôle et symboles retirés.
      for (final t in ['p', 'pa', 'par', 'para<>{}\u0007fictif']) {
        await tester.enterText(find.byKey(const Key('champ_recherche')), t);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await attendreTexte(tester, DonneesFictives.libelleArticle1);
      expect(serveur.recues(route).map((r) => r.parametres), [
        {parametre: 'parafictif'}
      ]);
      await tester.tap(find.text(DonneesFictives.libelleArticle1));
      await attendreWidget(tester, find.byKey(const Key('defilement_detail')));
      expect(find.text('Code CIP'), findsOneWidget);
      await retourSysteme(tester);
      await attendreQue(tester, () => find.byKey(const Key('defilement_detail')).evaluate().isEmpty, raison: 'fiche fermée');
      await revenir(tester, m);
      await terminer(tester);
    });
  }

  testWidgets('recherche : la réponse d\'une recherche remplacée est ignorée (requête précédente annulée)', (tester) async {
    telephone(tester);
    // « parafictif » répond lentement, « sirop » tout de suite.
    serveur.route(AppConstants.infoEndpoint, (r) {
      final q = r.parametres['search'] ?? '';
      final liste = [for (final a in DonneesFictives.articlesAnalyse()) if ('${a['libelle']}'.toLowerCase().contains(q)) a];
      return ReponseFausse.json(liste).apres(q == 'parafictif' ? const Duration(milliseconds: 1500) : Duration.zero);
    }, methode: 'GET');
    await jusquAccueilNouveau(tester);
    await ouvrir(tester, module('Analyse Article'));
    await tester.enterText(find.byKey(const Key('champ_recherche')), 'parafictif');
    await attendreQue(tester, () => serveur.recues(AppConstants.infoEndpoint).isNotEmpty, raison: 'première recherche partie');
    await tester.enterText(find.byKey(const Key('champ_recherche')), 'sirop');
    await attendreTexte(tester, DonneesFictives.libelleArticle2);
    // La réponse lente de « parafictif » arrive ensuite : ignorée.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1800)));
    await stabiliser(tester);
    expect(find.text(DonneesFictives.libelleArticle2), findsOneWidget);
    expect(find.text(DonneesFictives.libelleArticle1), findsNothing);
    expect(serveur.recues(AppConstants.infoEndpoint).map((r) => r.parametres['search']), ['parafictif', 'sirop']);
    await terminer(tester);
  });

  testWidgets('erreur du serveur (500) puis « Réessayer », puis serveur injoignable : causes distinctes, ni licence ni déconnexion',
      (tester) async {
    telephone(tester);
    serveur.quand(AppConstants.caComptantEndpoint, ReponseFausse.erreurServeur(), methode: 'GET');
    await jusquAccueilNouveau(tester);
    await ouvrir(tester, module('Détail CA'));
    await attendreWidget(tester, find.byType(EtatErreur));
    expect(find.byKey(const Key('erreur_serveur')), findsOneWidget);
    expect(find.text('Erreur du serveur'), findsOneWidget);
    expect(find.textContaining('NullPointer'), findsNothing);

    serveur.quand(AppConstants.caComptantEndpoint, ReponseFausse.json(DonneesFictives.caParJour()), methode: 'GET');
    await tester.tap(find.byKey(const Key('bouton_reessayer')));
    await attendreWidget(tester, find.byKey(const Key('chiffre_total')));
    expect(find.byType(EtatErreur), findsNothing);

    await tester.runAsync(serveur.arreter);
    await choisirPeriode(tester, 'hier');
    await attendreWidget(tester, find.byType(EtatErreur));
    expect(find.byKey(const Key('erreur_reseau')), findsOneWidget);
    expect(find.text('Serveur injoignable'), findsOneWidget);
    expect(find.byKey(const Key('bouton_reessayer')), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    await terminer(tester);
  });

  testWidgets('session expirée dans un module du lot → écran de connexion avec message, puis reconnexion', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrir(tester, module('Suivi Crédit'));
    await attendreWidget(tester, find.byKey(const Key('chiffre_montant')));
    serveur.expirerSessions();
    await choisirPeriode(tester, 'hier');
    await attendreWidget(tester, find.byType(LoginScreen));
    await attendreTexte(tester, AuthProvider.messageSessionExpiree);
    await tester.tap(find.text('OK'));
    await stabiliser(tester);
    await seConnecterNouvelle(tester);
    await attendreWidget(tester, find.byType(AccueilNouveau));
    expect(find.byType(AnalyseArticleNouveau), findsNothing);
    await terminer(tester);
  });
}
