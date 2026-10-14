// Bout en bout des modules refaits du LOT 2 (achats et stock, nouvelle interface) : l'application ENTIÈRE parle en
// HTTP réel au faux serveur Prestige local. Pour chaque module : ouverture depuis l'accueil (recherche de menu,
// présentation B), chiffres, période, filtres (feuille du bas), détail, menu Exporter, retour à l'accueil. Puis :
// double appui sur l'enregistrement d'une quantité = UN SEUL envoi, suppression confirmée ou annulée, erreur du
// serveur et « Réessayer », droit manquant (sans Réessayer), serveur injoignable, session expirée pendant une
// écriture (retour à la connexion, mécanisme existant).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/modules/suggestions_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/catalogue_ecrans.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_lot2.dart';
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

ModuleLot1 module(String tuile) => modulesLot2.firstWhere((m) => m.tuile == tuile);

/// Ouvre [m] par la recherche de menu de l'accueil B et attend son nouvel écran.
Future<void> ouvrir(WidgetTester tester, ModuleLot1 m) async {
  await tester.enterText(find.byKey(const Key('recherche_menu')), m.tuile);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.descendant(of: find.byKey(const Key('defilement_menus')), matching: find.text(m.tuile)).first);
  await attendreWidget(tester, find.byType(m.typeNouveau));
  expect(find.widgetWithText(AppBar, m.titreEcran), findsOneWidget);
}

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

Future<void> choisirPeriode(WidgetTester tester, String nom) => toucher(tester, find.byKey(Key('periode_$nom')), tours: 2);

/// Feuille des filtres : [reglages] puis « Appliquer » (ou « Rechercher »).
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
  for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
    await tester.drag(s, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(f, findsWidgets);
}

Iterable<RequeteRecue> postsQuantite() => serveur.recues(AppConstants.suggestionUpdateQteEndpoint, methode: 'POST');

void main() {
  setUpAll(chargerPolicesReelles);

  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    preparerNouvelle(serveur, p: Presentation.compact);
    donneesAccueil(serveur);
    donneesLot2(serveur);
  });

  tearDown(() async {
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true;
  });

  testWidgets('Suggestions : ouverture, double appui sur ✓ = UN envoi, message clair, suppression annulée puis confirmée, Exporter, retour',
      (tester) async {
    telephone(tester);
    // Enregistrement lent : le second appui arrive pendant l'envoi.
    serveur.quand(AppConstants.suggestionUpdateQteEndpoint, ReponseFausse.json({'success': true}).apres(const Duration(milliseconds: 700)), methode: 'POST');
    await jusquAccueilNouveau(tester);
    final m = module('Suggestions');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_suggestions')));
    expect(chiffre(tester, 'suggestions'), '2');
    expect(serveur.recues(AppConstants.suggestionListEndpoint).single.parametres, {'limit': '50'});

    await toucher(tester, find.text(DonneesLot2.grossisteA));
    await attendreWidget(tester, find.byKey(const Key('chiffre_montant_achat')));
    expect(serveur.recues('${AppConstants.suggestionSetPendingEndpoint}/${DonneesLot2.suggestion1}'), hasLength(1));
    expect(chiffre(tester, 'montant_achat'), formaterMontant(23600));
    expect(find.byType(SuggestionDetailNouveau), findsOneWidget);

    // Double appui pendant l'envoi : une seule requête.
    final champ = find.byKey(const Key('qte_${DonneesLot2.article1}'));
    final bouton = find.byKey(const Key('qte_enregistrer_${DonneesLot2.article1}'));
    await tester.enterText(champ, '24');
    await tester.ensureVisible(bouton);
    await tester.pump();
    await tester.tap(bouton);
    await tester.tap(bouton, warnIfMissed: false); // second appui, avant même que l'écran ne se redessine
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('qte_enregistrer_${DonneesLot2.article1}')), findsNothing, reason: 'envoi en cours : bouton remplacé par l\'indicateur');
    await attendreTexte(tester, 'Quantité enregistrée : 24 · ${DonneesFictives.libelleArticle1}');
    await attendreQue(tester, () => find.byKey(const Key('qte_enregistrer_${DonneesLot2.article1}')).evaluate().isNotEmpty, raison: 'fin de l\'envoi');
    await stabiliser(tester);
    expect(postsQuantite(), hasLength(1), reason: 'double appui : un seul envoi');
    expect(postsQuantite().single.json, {'itemId': DonneesLot2.article1, 'qte': 24});
    expect(postsQuantite().single.sessionEnvoyee, serveur.derniereSession);
    expect(find.text('Enregistrée'), findsOneWidget);

    // Un nouvel appui après la fin de l'envoi est un nouvel enregistrement (légitime).
    await toucher(tester, bouton);
    await attendreQue(tester, () => postsQuantite().length == 2, raison: 'second enregistrement');
    await attendreQue(tester, () => find.byKey(const Key('qte_enregistrer_${DonneesLot2.article1}')).evaluate().isNotEmpty, raison: 'fin de l\'envoi'); // envoi terminé : le bouton revient

    // Quantité refusée : message, rien n'est envoyé.
    await tester.enterText(champ, '');
    await toucher(tester, bouton);
    expect(find.text('Quantité invalide (0 à 99999) : non enregistrée.'), findsOneWidget);
    await stabiliser(tester, tours: 6);
    expect(postsQuantite(), hasLength(2));

    // Suppression d'une ligne : annulée (rien), puis confirmée (DELETE + relecture).
    final supprimer = find.byKey(const Key('ligne_supprimer_${DonneesLot2.article2}'));
    await toucher(tester, supprimer);
    expect(find.byType(AlertDialog), findsOneWidget);
    await toucher(tester, find.byKey(const Key('confirmer_non')));
    expect(serveur.recues('${AppConstants.suggestionDeleteItemEndpoint}/${DonneesLot2.article2}', methode: 'DELETE'), isEmpty);
    await toucher(tester, supprimer);
    await toucher(tester, find.byKey(const Key('confirmer_oui')));
    await attendreQue(tester, () => serveur.recues('${AppConstants.suggestionDeleteItemEndpoint}/${DonneesLot2.article2}', methode: 'DELETE').length == 1,
        raison: 'suppression de la ligne');
    await attendreTexte(tester, 'Article retiré de la suggestion : ${DonneesFictives.libelleArticle2}');

    // Exporter : CSV de la suggestion.
    await toucher(tester, find.byKey(const Key('menu_exports')));
    expect(find.text('CSV de la suggestion (cip;qte)'), findsOneWidget);
    await tester.tapAt(const Offset(10, 600));
    await stabiliser(tester, tours: 4);

    await retourSysteme(tester);
    await attendreQue(tester, () => find.byType(SuggestionDetailNouveau).evaluate().isEmpty, raison: 'retour à la liste');
    expect(serveur.recues(AppConstants.suggestionListEndpoint), hasLength(2), reason: 'liste relue au retour (comme l\'origine)');
    await stabiliser(tester);
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('Suggestions : suppression d\'une suggestion par son menu (confirmation), message de résultat', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    final m = module('Suggestions');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_suggestions')));
    await toucher(tester, find.byKey(const Key('suggestion_menu_${DonneesLot2.suggestion2}')));
    expect(find.byKey(const Key('suggestion_actions')), findsOneWidget);
    await toucher(tester, find.byKey(const Key('suggestion_supprimer')));
    expect(find.byType(AlertDialog), findsOneWidget);
    await toucher(tester, find.byKey(const Key('confirmer_oui')));
    await attendreQue(tester, () => serveur.recues('${AppConstants.suggestionDeleteEndpoint}/${DonneesLot2.suggestion2}', methode: 'DELETE').length == 1,
        raison: 'suppression');
    await attendreTexte(tester, 'Suggestion supprimée : ${DonneesLot2.grossisteB} · SUGG-FICTIVE-02');
    expect(serveur.recues('${AppConstants.suggestionSetPendingEndpoint}/${DonneesLot2.suggestion2}'), isEmpty,
        reason: 'aucune écriture « en cours » sans ouverture');
    await stabiliser(tester);
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('État de Stock : recherche, filtres (emplacement, stock < quantité), détail, Afficher plus, retour', (tester) async {
    telephone(tester);
    const route = '/fichearticle/comparaison';
    await jusquAccueilNouveau(tester);
    final m = module('Etat de Stock');
    await ouvrir(tester, m);
    await stabiliser(tester);
    expect(serveur.recues(route), isEmpty);
    await tester.enterText(find.byKey(const Key('champ_recherche')), 'fictif');
    await attendreWidget(tester, find.byKey(const Key('chiffre_articles')));
    expect(chiffre(tester, 'articles'), '19');
    await amener(tester, find.byKey(const Key('bouton_afficher_plus')));
    await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
    await attendreQue(tester, () => serveur.recues(route).length == 2, raison: 'page 2');
    expect(serveur.recues(route).last.parametres, containsPair('start', '15'));

    await filtrer(tester, () async {
      await choisirDansListe(tester, find.byKey(const Key('filtre_emplacement')), 'RAYON A');
      await toucher(tester, find.byKey(const Key('filtre_stock_LESS')), tours: 2);
      await tester.enterText(find.byKey(const Key('filtre_quantite')), '30');
      await tester.pump();
    });
    await attendreQue(tester, () => serveur.recues(route).length == 3, raison: 'filtres');
    expect(serveur.recues(route).last.parametres, containsPair('codeRayon', 'RAY-A'));
    expect(serveur.recues(route).last.parametres, containsPair('filtreStock', 'LESS'));
    expect(serveur.recues(route).last.parametres, containsPair('stock', '30'));
    expect(find.byTooltip('Filtres (2 actifs)'), findsOneWidget);
    await stabiliser(tester);
    await toucher(tester, find.text('ARTICLE FICTIF 4'));
    expect(find.byKey(const Key('detail_article')), findsOneWidget);
    expect(find.text(DonneesLot2.grossisteA), findsOneWidget, reason: 'nom du grossiste (liste chargée à l\'ouverture)');
    await retourSysteme(tester);
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('Visualisation BL : jour, période « Hier », filtre statut, détail du bon, retour', (tester) async {
    telephone(tester);
    const route = '/etat-control-bon/list';
    await jusquAccueilNouveau(tester);
    final m = module('Visualisation BL');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_total_bl')));
    expect(chiffre(tester, 'total_bl'), '${DonneesLot2.bonsLivraison}');
    expect(serveur.recues(route).single.parametres, containsPair('dtStart', jour(aujourdhui)));
    await choisirPeriode(tester, 'hier');
    await attendreQue(tester, () => serveur.recues(route).length == 2, raison: 'hier');
    expect(serveur.recues(route).last.parametres, containsPair('dtStart', jour(hier)));
    expect(serveur.recues(route).last.parametres, containsPair('dtEnd', jour(hier)));
    await stabiliser(tester);
    // 3.8.0 (A1) : le statut part dans « statutControle », le paramètre que le serveur lit (« checked » reste vide) ;
    // le faux serveur filtre comme le vrai : 23 bons dont 7 contrôlés (TERMINE) → 16 non contrôlés.
    expect(find.byKey(const Key('filtre_utilisateur')), findsNothing);
    await filtrer(tester, () async {
      expect(find.byKey(const Key('filtre_utilisateur')), findsNothing, reason: 'filtre utilisateur ignoré par le serveur : plus proposé');
      expect(find.byKey(const Key('filtre_utilisateur_a_venir')), findsOneWidget);
      await toucher(tester, find.byKey(const Key('filtre_statut_NON_CONTROLE')), tours: 2);
    });
    await attendreQue(tester, () => serveur.recues(route).length == 3, raison: 'statut');
    expect(serveur.recues(route).last.parametres, containsPair('statutControle', 'NON_CONTROLE'));
    expect(serveur.recues(route).last.parametres, containsPair('checked', ''));
    expect(serveur.recues(route).last.parametres, containsPair('userId', ''));
    await stabiliser(tester);
    expect(chiffre(tester, 'total_bl'), '16', reason: 'total du serveur après son filtre');
    expect(find.text('Contrôle : Non contrôlés'), findsOneWidget);
    await toucher(tester, find.text(DonneesLot2.grossisteB));
    await attendreWidget(tester, find.byKey(const Key('defilement_detail')));
    expect(find.text('Écart 1'), findsOneWidget, reason: 'écart du premier bon : stock théorique 14 − contrôlé 13');
    await retourSysteme(tester);
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('État Contrôle Achat : jour, période « 7 jours », filtre groupe, retour', (tester) async {
    telephone(tester);
    const route = AppConstants.etatControleAchatEndpoint;
    await jusquAccueilNouveau(tester);
    final m = module('Etat Contrôle Achat');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_achats_ttc')));
    expect(chiffre(tester, 'achats_ttc'), formaterMontant(767000));
    await choisirPeriode(tester, 'septJours');
    await attendreQue(tester, () => serveur.recues(route).length == 2, raison: '7 jours');
    expect(serveur.recues(route).last.parametres['dtStart'], jour(DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day - 6)));
    await stabiliser(tester);
    await filtrer(tester, () => choisirDansListe(tester, find.byKey(const Key('filtre_groupe')), 'GROUPE FICTIF B'));
    await attendreQue(tester, () => serveur.recues(route).length == 3, raison: 'groupe');
    expect(serveur.recues(route).last.parametres, containsPair('groupeId', '2'));
    await stabiliser(tester);
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('Retours fournisseurs (lecture seule) : jour, filtre réponse, détail, produits retournés, retour', (tester) async {
    telephone(tester);
    const route = AppConstants.retoursFournisseursEndpoint;
    await jusquAccueilNouveau(tester);
    final m = module('Retours Fournisseurs');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_montant')));
    expect(chiffre(tester, 'montant'), formaterMontant(60500));
    await filtrer(tester, () => toucher(tester, find.byKey(const Key('filtre_reponse_avec')), tours: 2));
    await attendreQue(tester, () => serveur.recues(route).length == 2, raison: 'filtre');
    expect(serveur.recues(route).last.parametres, containsPair('filtre', 'WITH'));
    await stabiliser(tester);
    await toucher(tester, find.text(DonneesLot2.grossisteA));
    await attendreWidget(tester, find.byKey(const Key('chiffre_retour_qte')));
    expect(chiffre(tester, 'retour_qte'), '7');
    await retourSysteme(tester);
    await toucher(tester, find.byKey(const Key('retours_produits')));
    await attendreWidget(tester, find.byKey(const Key('chiffre_avoirs_produits')));
    expect(serveur.recues(AppConstants.avoirsFournisseursEndpoint).single.parametres, {'dtStart': jour(aujourdhui), 'dtEnd': jour(aujourdhui)});
    await retourSysteme(tester);
    expect(serveur.requetes.where((r) => r.methode != 'GET' && r.chemin != '/user/auth'), isEmpty, reason: 'aucune écriture');
    await revenir(tester, m);
    await terminer(tester);
  });

  // 3.8.0 (A4, choix du pharmacien) : ouverture sur « Ce mois » (1er du mois → aujourd'hui) au lieu de « 7 jours ».
  testWidgets('Évolution stock : « Ce mois » à l\'ouverture, chiffres, menu Exporter (PDF), retour', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    final m = module('Evolution Stock');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_fin')));
    expect(serveur.recues(AppConstants.valorisationAllEndpoint).single.parametres,
        {'dtStart': jour(DateTime(aujourdhui.year, aujourdhui.month, 1)), 'dtEnd': jour(aujourdhui)});
    final jours = aujourdhui.day - 1;
    expect(chiffre(tester, 'fin'), formaterMontant(DonneesLot2.valeurInitiale + jours * DonneesLot2.pasJournalier));
    if (jours > 0) expect(chiffre(tester, 'variation'), '+${formaterMontant(jours * DonneesLot2.pasJournalier)}');
    await toucher(tester, find.byKey(const Key('menu_exports')));
    expect(find.text('PDF du graphique'), findsOneWidget);
    await tester.tapAt(const Offset(10, 600));
    await stabiliser(tester, tours: 4);
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('Analyse Saisies BL : chiffres, filtre « Pas bon » sans nouvelle requête, retrait, retour', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    final m = module('Analyse Saisies BL');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_affiches')));
    final bons = int.parse(chiffre(tester, 'bons')), pasBons = int.parse(chiffre(tester, 'pas_bons'));
    expect(bons + pasBons, DonneesLot2.bonsLivraison);
    await filtrer(tester, () => toucher(tester, find.byKey(const Key('filtre_statut_Pas_bon')), tours: 2));
    expect(chiffre(tester, 'affiches'), '$pasBons');
    expect(serveur.recues(AppConstants.analyseSaisieBlEndpoint), hasLength(1));
    await toucher(tester, find.byKey(const Key('filtres_retirer')));
    expect(chiffre(tester, 'affiches'), '${DonneesLot2.bonsLivraison}');
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('Suivi Ajustements : jour, filtre motif, détail avec analyse, retour', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    final m = module('Suivi Ajustements');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_ajustements')));
    expect(chiffre(tester, 'ajustements'), '2');
    await filtrer(tester, () => choisirDansListe(tester, find.byKey(const Key('filtre_motif')), 'INVENTAIRE'));
    await attendreQue(tester, () => serveur.recues(AppConstants.ajustementEndpoint).length == 2, raison: 'motif');
    expect(serveur.recues(AppConstants.ajustementEndpoint).last.parametres, containsPair('typeFiltre', 'TYP-INVENT'));
    await stabiliser(tester);
    await toucher(tester, find.text('AJUSTEMENT FICTIF CASSE'));
    await attendreWidget(tester, find.byKey(const Key('chiffre_positif')));
    expect(chiffre(tester, 'positif'), formaterMontant(5400));
    expect(chiffre(tester, 'negatif'), formaterMontant(-1700));
    await retourSysteme(tester);
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('erreurs : 500 puis « Réessayer », droit manquant (sans Réessayer), serveur injoignable — ni licence ni déconnexion',
      (tester) async {
    telephone(tester);
    serveur.quand(AppConstants.etatControleAchatEndpoint, ReponseFausse.erreurServeur(), methode: 'GET');
    serveur.quand(AppConstants.suggestionListEndpoint, ReponseFausse.texte('Interdit', statut: 403), methode: 'GET');
    await jusquAccueilNouveau(tester);
    final achat = module('Etat Contrôle Achat');
    await ouvrir(tester, achat);
    await attendreWidget(tester, find.byType(EtatErreur));
    expect(find.byKey(const Key('erreur_serveur')), findsOneWidget);
    expect(find.textContaining('NullPointer'), findsNothing);
    serveur.quand(AppConstants.etatControleAchatEndpoint, ReponseFausse.json(DonneesFictives.etatControleAchat()), methode: 'GET');
    await toucher(tester, find.byKey(const Key('bouton_reessayer')));
    await attendreWidget(tester, find.byKey(const Key('chiffre_achats_ttc')));
    await revenir(tester, achat);

    final sugg = module('Suggestions');
    await ouvrir(tester, sugg);
    await attendreWidget(tester, find.byType(EtatErreur));
    expect(find.text('Droit manquant'), findsOneWidget);
    expect(find.byKey(const Key('bouton_reessayer')), findsNothing, reason: 'réessayer ne changerait rien');
    await revenir(tester, sugg);

    await tester.runAsync(serveur.arreter);
    final evolution = module('Evolution Stock');
    await ouvrir(tester, evolution);
    await attendreWidget(tester, find.byType(EtatErreur));
    expect(find.byKey(const Key('erreur_reseau')), findsOneWidget);
    expect(find.byKey(const Key('bouton_reessayer')), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    await terminer(tester);
  });

  testWidgets('session expirée pendant l\'enregistrement d\'une quantité → connexion avec message, rien d\'enregistré', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrir(tester, module('Suggestions'));
    await attendreWidget(tester, find.byKey(const Key('chiffre_suggestions')));
    await toucher(tester, find.text(DonneesLot2.grossisteA));
    await attendreWidget(tester, find.byKey(const Key('chiffre_montant_achat')));
    serveur.expirerSessions();
    await tester.enterText(find.byKey(const Key('qte_${DonneesLot2.article1}')), '7');
    await toucher(tester, find.byKey(const Key('qte_enregistrer_${DonneesLot2.article1}')));
    await attendreWidget(tester, find.byType(LoginScreen));
    await attendreTexte(tester, AuthProvider.messageSessionExpiree);
    expect(postsQuantite(), hasLength(1), reason: 'une seule tentative, refusée par le serveur');
    await tester.tap(find.text('OK'));
    await stabiliser(tester);
    await seConnecterNouvelle(tester);
    await attendreWidget(tester, find.byType(AccueilNouveau));
    await terminer(tester);
  });
}
