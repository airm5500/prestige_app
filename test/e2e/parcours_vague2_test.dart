// Bout en bout de la vague 2 des nouveaux menus : l'application ENTIÈRE (main.dart) parle en HTTP réel au faux
// serveur Prestige local, dans la nouvelle interface.
//  - administrateur / pharmacien (xtypeuser « dashboard ») : Prévisions, Analyse de garde, CA emplacement / famille
//    s'ouvrent depuis l'accueil A, se filtrent, ouvrent un détail, et l'on revient ; onglet Pilotage dans la barre
//    du bas (Accueil · Analyses · Équipe · Pilotage), axes, « À suivre », contrôle sur confirmation ; tablette ;
//  - calcul long (3 ans) annulable, sans relance automatique ; refus → « Droit manquant » ;
//  - autre profil : barre à trois onglets, menus de la vague 2 absents ;
//  - à la fin de chaque parcours : AUCUNE route interdite reçue par le serveur.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/donnees_vague1.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague2/donnees_vague2.dart';
import 'package:prestige_app/screens/login_screen.dart';

import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_vague1.dart';
import '../support/donnees_vague2.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

/// Menus de la vague 2 (titre du menu, titre de la barre de l'écran).
const menusVague2 = <(String, String)>[
  ('Prévisions', 'Prévisions'),
  ('Analyse de garde', 'Analyse de garde'),
  ('CA emplacement / famille', 'CA emplacement / famille'),
];

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

void tablette(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.5;
  tester.view.physicalSize = const Size(1920, 1200);
  addTearDown(tester.view.reset);
}

Future<void> retourSysteme(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await stabiliser(tester, tours: 4);
}

Future<void> amenerEnVue(WidgetTester tester, Finder cible, Finder defilement) async {
  final scrollable = find.descendant(of: defilement, matching: find.byType(Scrollable)).first;
  if (cible.evaluate().isEmpty) {
    for (var i = 0; i < 4; i++) {
      await tester.drag(scrollable, const Offset(0, 3000));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.scrollUntilVisible(cible, 250, scrollable: scrollable, maxScrolls: 80);
  }
  if (cible.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(cible.first);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> toucher(WidgetTester tester, Finder cible, {Finder? defilement}) async {
  if (defilement != null) await amenerEnVue(tester, cible, defilement);
  await tester.tap(cible.hitTestable().first);
  await stabiliser(tester, tours: 6);
}

Future<void> ouvrirDepuisA(WidgetTester tester, String titre) =>
    toucher(tester, find.descendant(of: find.byType(AccueilNouveau), matching: find.text(titre)), defilement: find.byKey(const Key('defilement_accueil')));

Future<void> revenirALAccueil(WidgetTester tester) async {
  for (var i = 0; i < 5 && find.byType(AccueilNouveau).hitTestable().evaluate().isEmpty; i++) {
    await retourSysteme(tester);
  }
  expect(find.byType(AccueilNouveau).hitTestable(), findsOneWidget, reason: 'retour à l\'accueil');
}

/// Onglet interne (TabBar) d'un écran.
Future<void> onglet(WidgetTester tester, String nom) async {
  final cible = find.descendant(of: find.byType(TabBar), matching: find.text(nom)).first;
  await tester.ensureVisible(cible);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(cible);
  await stabiliser(tester, tours: 8);
}

void aucuneRouteInterdite() => expect(requetesInterdites(serveur), isEmpty, reason: 'routes interdites reçues');

void main() {
  setUpAll(chargerPolicesReelles);

  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    preparerNouvelle(serveur, p: Presentation.tableauDeBord);
    donneesAccueil(serveur);
    listesCommunesVague1(serveur);
  });

  tearDown(() async {
    aucuneRouteInterdite();
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..parDefaut = ((_) => ReponseFausse.json(DonneesFictives.listeVide()));
    ProfilAcces.utilisateur.value = null;
    ReglagesAlertes.oublier();
  });

  testWidgets('Prévisions : synthèse et liste, filtres, recherche, détail et équivalents, analyse d\'une commande, demande sur « Calculer »',
      (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    expect(ProfilAcces.responsable, isTrue);
    await ouvrirDepuisA(tester, 'Prévisions');
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Prévisions'));
    await attendreWidget(tester, find.byKey(const Key('previsions_total')));
    expect(find.byKey(const Key('chiffre_a_commander')), findsOneWidget);
    expect(serveur.recues(ApiPrevisions.routeTableau), hasLength(1));
    expect(serveur.recues(ApiPrevisions.routePrevisions).single.parametres['limit'], '25');
    expect(serveur.recues('/analyse-commande/a-analyser'), isEmpty, reason: 'onglet pas encore ouvert');
    expect(serveur.recues(ApiPrevisions.routeDemande), isEmpty);

    // Filtre « À commander » (puce), méthode (feuille), recherche (anti-rebond).
    await toucher(tester, find.byKey(const Key('filtre_prevision_aCommander')), defilement: find.byKey(const Key('defilement_previsions')));
    await attendreQue(tester, () => serveur.recues(ApiPrevisions.routePrevisions).last.parametres['filtre'] == 'ACOMMANDER', raison: 'filtre');
    await tester.tap(find.byKey(const Key('bouton_filtres')));
    await stabiliser(tester, tours: 8);
    await toucher(tester, find.byKey(const Key('filtre_methode_saison')));
    await toucher(tester, find.byKey(const Key('filtres_appliquer')));
    await attendreQue(tester, () => serveur.recues(ApiPrevisions.routePrevisions).last.parametres['methode'] == 'SAISON', raison: 'méthode');
    expect(find.text('Méthode : Saisonnière'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('champ_recherche')), 'fictif 2');
    await tester.pump(const Duration(milliseconds: 600));
    await attendreQue(tester, () => serveur.recues(ApiPrevisions.routePrevisions).last.parametres['query'] == 'fictif 2', raison: 'recherche');
    await attendreWidget(tester, find.byKey(const Key('prevision_PRD-PREV-2')));

    // Détail du produit, équivalents à la demande.
    await toucher(tester, find.byKey(const Key('prevision_PRD-PREV-2')), defilement: find.byKey(const Key('defilement_previsions')));
    await attendreWidget(tester, find.byKey(const Key('historique_mensuel')));
    expect(serveur.recues('/analyse-commande/produit/PRD-PREV-2'), hasLength(1));
    expect(serveur.recues('/analyse-commande/equivalents/PRD-PREV-2'), isEmpty);
    await toucher(tester, find.byKey(const Key('bouton_equivalents')), defilement: find.byKey(const Key('defilement_detail_prevision')));
    await attendreWidget(tester, find.byKey(const Key('liste_equivalents')));
    expect(find.text('EQUIVALENT FICTIF 500MG'), findsOneWidget);
    await retourSysteme(tester);

    // Analyse d'une commande.
    await onglet(tester, 'Analyse suggestion / commande');
    await attendreWidget(tester, find.byKey(const Key('a_analyser_CMD-TEST-1')));
    await toucher(tester, find.byKey(const Key('a_analyser_CMD-TEST-1')));
    await attendreWidget(tester, find.byKey(const Key('analyse_titre')));
    expect(serveur.recues(ApiPrevisions.routeAnalyse).single.parametres, {'type': 'COMMANDE', 'id': 'CMD-TEST-1'});
    expect(find.text('Quantité bien supérieure au besoin'), findsOneWidget);
    await toucher(tester, find.byKey(const Key('analyse_alertes_true')));
    expect(find.text('PRODUIT PREVU FICTIF 3'), findsNothing, reason: 'lignes sans alerte masquées');
    await retourSysteme(tester);

    // Demande : rien avant « Calculer » ; 24 mois.
    await onglet(tester, 'Analyse de la demande');
    await stabiliser(tester, tours: 10);
    await amenerEnVue(tester, find.byKey(const Key('demande_invite')), find.byKey(const Key('defilement_demande')));
    expect(find.byKey(const Key('demande_invite')), findsOneWidget);
    expect(serveur.recues(ApiPrevisions.routeDemande), isEmpty, reason: 'pas de calcul à l\'ouverture');
    await toucher(tester, find.byKey(const Key('demande_mois_24')));
    await toucher(tester, find.byKey(const Key('demande_calculer')), defilement: find.byKey(const Key('defilement_demande')));
    await attendreWidget(tester, find.byKey(const Key('demande_resultat')));
    expect(serveur.recues(ApiPrevisions.routeDemande).single.parametres['mois'], '24');
    expect(find.byKey(const Key('chiffre_demande_pic')), findsOneWidget);
    await toucher(tester, find.byKey(const Key('demande_mois_36')), defilement: find.byKey(const Key('defilement_demande')));
    expect(find.byKey(const Key('demande_perimee')), findsOneWidget, reason: 'choix changé : résultat signalé à recalculer');
    expect(serveur.recues(ApiPrevisions.routeDemande), hasLength(1), reason: 'pas de relance automatique');
    await revenirALAccueil(tester);
    await terminer(tester);
  });

  testWidgets('Pilotage : onglet de la barre du bas (4 onglets), synthèse, axe, À suivre, contrôle confirmé', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    final barre = tester.widget<NavigationBar>(find.byKey(const Key('barre_accueil')));
    expect([for (final d in barre.destinations) (d as NavigationDestination).label], ['Accueil', 'Analyses', 'Équipe', 'Pilotage']);
    expect(serveur.requetes.where((r) => r.chemin.startsWith('/pilotage')), isEmpty, reason: 'rien avant l\'ouverture de l\'onglet');
    await ouvrirOnglet(tester, 'Pilotage');
    await attendreWidget(tester, find.byKey(const Key('tuile_caTTC')));
    expect(serveur.recues('/pilotage/onglet/synthese').single.parametres, {'axe': 'MOIS'});
    expect(serveur.recues(ApiPilotage.routeControler), isEmpty);

    await toucher(tester, find.byKey(const Key('axe_VS_M1')));
    await attendreWidget(tester, find.byKey(const Key('variation_caTTC')));
    expect(serveur.recues('/pilotage/onglet/synthese').last.parametres, {'axe': 'VS_M1'});
    expect(find.byKey(const Key('pilotage_reference')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('variation_caTTC')), matching: find.byIcon(Icons.arrow_upward)), findsOneWidget,
        reason: 'hausse : flèche + texte, pas la couleur seule');

    await onglet(tester, 'À suivre');
    await attendreWidget(tester, find.byKey(const Key('pilotage_a_suivre')));
    expect(serveur.recues('/pilotage/onglet/asuivre').single.parametres, {'axe': 'VS_M1'});
    expect(find.text('PRODUIT A PERTE FICTIF'), findsOneWidget);

    await toucher(tester, find.byKey(const Key('pilotage_controler')), defilement: find.byKey(const Key('defilement_pilotage')));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(serveur.recues(ApiPilotage.routeControler), isEmpty, reason: 'rien avant confirmation');
    await toucher(tester, find.byKey(const Key('controle_confirmer')));
    await attendreWidget(tester, find.byKey(const Key('controle_resultat')));
    expect(serveur.recues(ApiPilotage.routeControler).single.parametres, {'axe': 'VS_M1'});

    await ouvrirOnglet(tester, 'Accueil');
    expect(find.byType(AccueilNouveau), findsOneWidget);
    await terminer(tester);
  });

  testWidgets('Analyse de garde : années, gardes, synthèse, tranches, produits (tri, classe, page suivante), vendeurs, retour',
      (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrirDepuisA(tester, 'Analyse de garde');
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Analyse de garde'));
    await attendreWidget(tester, find.byKey(const Key('gardes_total')));
    expect(serveur.recues(ApiGardes.routeGardes).single.parametres, {'annee': '2026'});
    await toucher(tester, find.byKey(const Key('annee_2025')));
    await attendreWidget(tester, find.byKey(const Key('garde_GARDE-TEST-0')));
    await toucher(tester, find.byKey(const Key('annee_2026')));
    await attendreWidget(tester, find.byKey(const Key('garde_GARDE-TEST-1')));

    await toucher(tester, find.byKey(const Key('garde_GARDE-TEST-1')));
    await attendreWidget(tester, find.byKey(const Key('chiffre_garde_montant')));
    expect(find.byKey(const Key('garde_tranches')), findsOneWidget);
    await toucher(tester, find.byKey(const Key('heures_4')), defilement: find.byKey(const Key('defilement_garde_synthese')));
    await attendreQue(tester, () => serveur.recues('/gardes/GARDE-TEST-1/rapport').last.parametres['heures'] == '4', raison: 'tranches de 4 h');

    await onglet(tester, 'Produits');
    await attendreWidget(tester, find.byKey(const Key('garde_produits_total')));
    await toucher(tester, find.byKey(const Key('bouton_afficher_plus')), defilement: find.byKey(const Key('defilement_garde_produits')));
    await attendreQue(tester, () => serveur.recues('/gardes/GARDE-TEST-1/rapport').last.parametres['start'] == '25', raison: 'page suivante');
    await toucher(tester, find.byKey(const Key('tri_quantite')), defilement: find.byKey(const Key('defilement_garde_produits')));
    await attendreQue(tester, () => serveur.recues('/gardes/GARDE-TEST-1/rapport').last.parametres['tri'] == 'quantite', raison: 'tri');
    await toucher(tester, find.byKey(const Key('classe_A')), defilement: find.byKey(const Key('defilement_garde_produits')));
    await attendreQue(tester, () => serveur.recues('/gardes/GARDE-TEST-1/rapport').last.parametres['classe'] == 'A', raison: 'classe');
    await attendreTexte(tester, '5 produits en classe A sur 30');

    expect(serveur.recues('/gardes/GARDE-TEST-1/vendeurs'), isEmpty);
    await onglet(tester, 'Vendeurs');
    await attendreWidget(tester, find.byKey(const Key('vendeur_0')));
    expect(find.text('CAISSIERE Fictive Une'), findsOneWidget);
    await revenirALAccueil(tester);
    await terminer(tester);
  });

  testWidgets('CA emplacement / famille : 3 semaines à l\'ouverture, cartes et tranches, regroupement, 3 ans, détail d\'une ligne', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrirDepuisA(tester, 'CA emplacement / famille');
    await attendreWidget(tester, find.widgetWithText(AppBar, 'CA emplacement / famille'));
    await attendreWidget(tester, find.byKey(const Key('ligne_ca_0')));
    expect(serveur.recues(ApiCaZone.route).single.parametres['typePeriode'], 'TROIS_SEMAINES');
    expect(find.byKey(const Key('chiffre_ca_total')), findsOneWidget);
    expect(find.textContaining('S42 (12/10-14/10) (en cours)'), findsWidgets, reason: 'tranche en cours signalée');

    // Regroupement par famille (feuille des filtres).
    await tester.tap(find.byKey(const Key('bouton_filtres')));
    await stabiliser(tester, tours: 10);
    await toucher(tester, find.byKey(const Key('regroupement_FAMILLE')));
    await toucher(tester, find.byKey(const Key('filtres_appliquer')));
    await attendreQue(tester, () => serveur.recues(ApiCaZone.route).last.parametres['regroupement'] == 'FAMILLE', raison: 'regroupement');
    await attendreTexte(tester, 'ANTALGIQUES FICTIFS');
    expect(serveur.recues('/common/famillearticles'), hasLength(1), reason: 'listes lues à l\'ouverture de la feuille');

    // 3 ans : choix normal, aucune fenêtre bloquante.
    await toucher(tester, find.byKey(const Key('periode_ca_TROIS_ANS')), defilement: find.byKey(const Key('defilement_ca')));
    expect(find.byType(AlertDialog), findsNothing);
    await attendreQue(tester, () => serveur.recues(ApiCaZone.route).last.parametres['typePeriode'] == 'TROIS_ANS', raison: '3 ans');
    await attendreWidget(tester, find.byKey(const Key('ligne_ca_0')));
    expect(find.text('2023'), findsWidgets);

    await toucher(tester, find.byKey(const Key('ligne_ca_0')), defilement: find.byKey(const Key('defilement_ca')));
    await attendreWidget(tester, find.byKey(const Key('detail_ca_total')));
    final d = serveur.recues(ApiCaZone.routeDetail).single.parametres;
    expect(d['ligneFamilleId'], 'FAM-TEST-1');
    expect(d['typePeriode'], 'TROIS_ANS');
    expect(find.text('PRODUIT CA FICTIF 1'), findsOneWidget);
    await revenirALAccueil(tester);
    await terminer(tester);
  });

  testWidgets('calcul long annulable : 3 ans lent → indication discrète, « Annuler », pas de relance automatique', (tester) async {
    telephone(tester);
    serveur.route(ApiCaZone.route, (r) {
      final rep = ReponseFausse.json(DonneesVague2.caZone(r.parametres));
      return r.parametres['typePeriode'] == 'TROIS_ANS' ? rep.apres(const Duration(seconds: 20)) : rep;
    }, methode: 'GET');
    await jusquAccueilNouveau(tester);
    await ouvrirDepuisA(tester, 'CA emplacement / famille');
    await attendreWidget(tester, find.byKey(const Key('ligne_ca_0')));
    await toucher(tester, find.byKey(const Key('periode_ca_TROIS_ANS')), defilement: find.byKey(const Key('defilement_ca')));
    await attendreWidget(tester, find.byKey(const Key('indication_calcul_long')));
    expect(find.text('Calcul sur 3 ans, peut prendre un moment.'), findsOneWidget);
    await toucher(tester, find.byKey(const Key('bouton_annuler_calcul')));
    expect(find.byKey(const Key('ca_annule')), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await stabiliser(tester);
    expect(serveur.recues(ApiCaZone.route).where((r) => r.parametres['typePeriode'] == 'TROIS_ANS'), hasLength(1), reason: 'aucune relance');
    expect(find.byKey(const Key('ligne_ca_0')), findsNothing, reason: 'la réponse annulée ne s\'affiche pas');
    await revenirALAccueil(tester);
    await terminer(tester);
  });

  testWidgets('refus du serveur : Prévisions « Droit manquant » sans « Réessayer » ni déconnexion ; Pilotage aussi', (tester) async {
    telephone(tester);
    const refus = {'success': false, 'msg': 'Vous n\'avez pas accès à l\'analyse des commandes.'};
    serveur.quand(ApiPrevisions.routeTableau, ReponseFausse.json(refus));
    serveur.quand(ApiPrevisions.routePrevisions, ReponseFausse.json(refus));
    serveur.quand('/pilotage/onglet/synthese', ReponseFausse.json({'success': false, 'message': 'Votre profil ne donne pas accès au pilotage de l\'officine.'}));
    await jusquAccueilNouveau(tester);
    await ouvrirDepuisA(tester, 'Prévisions');
    await attendreWidget(tester, find.byKey(const Key('erreur_droit')));
    expect(find.byKey(const Key('bouton_reessayer')), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    await revenirALAccueil(tester);
    await ouvrirOnglet(tester, 'Pilotage');
    await attendreWidget(tester, find.byKey(const Key('erreur_droit')));
    expect(find.textContaining('Droit manquant : consulter le pilotage.'), findsOneWidget);
    expect(serveur.recues(ApiPilotage.routeControler), isEmpty);
    await ouvrirOnglet(tester, 'Accueil');
    await terminer(tester);
  });

  testWidgets('tablette (B, menu latéral) : chaque menu de la vague 2 s\'ouvre en tableau dense ; Pilotage dans le menu latéral', (tester) async {
    tablette(tester);
    preparerNouvelle(serveur);
    await jusquAccueilNouveau(tester);
    for (final (titre, barre) in menusVague2) {
      final erreurs = await releverErreurs(() async {
        await toucher(tester, find.descendant(of: find.byType(AccueilNouveau), matching: find.text(titre)),
            defilement: find.byKey(const Key('defilement_menus')));
        await stabiliser(tester, tours: 20);
      });
      expect(erreurs, isEmpty, reason: '$titre : ${erreurs.join('\n')}');
      expect(find.widgetWithText(AppBar, barre), findsWidgets);
      await attendreWidget(tester, find.byKey(const Key('tableau_dense')));
      await revenirALAccueil(tester);
    }
    await tester.tap(find.descendant(of: find.byType(AccueilNouveau), matching: find.text('Pilotage')).last);
    await stabiliser(tester, tours: 10);
    await attendreWidget(tester, find.byKey(const Key('tuile_caTTC')));
    await terminer(tester);
  });

  testWidgets('autre profil (mainmenumanager) : barre à 3 onglets (pas de Pilotage), menus de la vague 2 absents', (tester) async {
    telephone(tester);
    serveur.controlerSession = false;
    serveur.quand(
        '/user/auth',
        ReponseFausse.json({...DonneesFictives.utilisateur(), 'xtypeuser': 'mainmenumanager'},
            entetes: {'set-cookie': 'JSESSIONID=fictif-autre; Path=/prestige; HttpOnly'}),
        methode: 'POST');
    await jusquAccueilNouveau(tester);
    expect(ProfilAcces.responsable, isFalse);
    final barre = tester.widget<NavigationBar>(find.byKey(const Key('barre_accueil')));
    expect([for (final d in barre.destinations) (d as NavigationDestination).label], ['Accueil', 'Analyses', 'Équipe']);
    final defilement = find.byKey(const Key('defilement_accueil'));
    await tester.scrollUntilVisible(find.text('Présences').last, 300, scrollable: find.descendant(of: defilement, matching: find.byType(Scrollable)).first);
    for (final (t, _) in menusVague2) {
      expect(find.descendant(of: find.byType(AccueilNouveau), matching: find.text(t)), findsNothing, reason: t);
    }
    expect(serveur.requetes.where((r) => r.chemin.startsWith('/pilotage') || r.chemin.startsWith('/analyse-commande')), isEmpty);
    await terminer(tester);
  });
}
