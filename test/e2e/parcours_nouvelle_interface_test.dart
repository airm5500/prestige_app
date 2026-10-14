// Tests de bout en bout de la NOUVELLE interface : l'application ENTIÈRE (main.dart) parle en HTTP réel au faux
// serveur Prestige local, comme dans parcours_application_test.dart (qui parcourt l'interface d'origine).
//
//  - la nouvelle interface est celle par défaut (aucun choix mémorisé) ;
//  - chaque module de l'accueil s'ouvre et se referme dans les présentations A, B et C (téléphone) et B (tablette,
//    menu latéral), sans erreur ni « Chargement impossible », avec la session ouverte à la connexion ;
//  - onglets Analyses, Équipe, Réglages ;
//  - alertes de l'accueil A comptées à la demande : appui sur ⟳ → nombre et heure → ouverture du module, qui
//    montre le même nombre avec les mêmes paramètres ; au retour, le nombre mémorisé « il y a X min » ;
//  - retour à l'ancienne interface depuis les Réglages (effet immédiat, mémorisé), puis retour à la nouvelle ;
//  - présentation : code administrateur exigé pour un autre compte, choix direct et mémorisé pour « admin » ;
//  - mêmes règles qu'avant : session expirée → connexion ; serveur coupé → message réseau ; serveur injoignable
//    ≠ licence ; licence absente → écran de licence.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/interface_version.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/alertes_accueil.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart';
import 'package:prestige_app/nouvelle_interface/menus.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/screens/analyse_article_screen.dart';
import 'package:prestige_app/screens/etat_controle_achat_screen.dart';
import 'package:prestige_app/screens/home_screen.dart';
import 'package:prestige_app/screens/licence_registration_screen.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/screens/serveur_injoignable_screen.dart';
import 'package:prestige_app/screens/settings_screen.dart';
import 'package:prestige_app/screens/suivi_peremption_screen.dart';
import 'package:prestige_app/utils/constants.dart';
import 'package:prestige_app/widgets/erreurs_chargement.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/application.dart';
import '../support/catalogue_ecrans.dart';
import '../support/donnees_fictives.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

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

/// Fait défiler [defilement] jusqu'à rendre [cible] touchable (au-dessus de la barre du bas).
Future<void> amenerEnVue(WidgetTester tester, Finder cible, Finder defilement) async {
  final scrollable = find.descendant(of: defilement, matching: find.byType(Scrollable)).first;
  if (cible.evaluate().isEmpty) {
    // Retour en haut de la liste, puis descente jusqu'à la cible.
    for (var i = 0; i < 4; i++) {
      await tester.drag(scrollable, const Offset(0, 2000));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.scrollUntilVisible(cible, 250, scrollable: scrollable, maxScrolls: 60);
  }
  for (var i = 0; i < 6 && cible.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(scrollable, const Offset(0, -150));
    await tester.pump(const Duration(milliseconds: 300));
  }
  // Tout en bas de la liste : remonter un peu si la cible est sous la barre.
  for (var i = 0; i < 6 && cible.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(scrollable, const Offset(0, 100));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Ouvre chaque module depuis l'accueil de la présentation [p] et revient ; renvoie les problèmes relevés.
Future<List<String>> parcourirModules(WidgetTester tester, Presentation p) async {
  final problemes = <String>[];
  for (final module in modulesAccueil) {
    final menu = menusModules.firstWhere((m) => m.titre == module.tuile);
    final erreurs = await releverErreurs(() async {
      if (p == Presentation.guide) {
        final question = find.descendant(of: find.byType(AccueilNouveau), matching: find.text(menu.question.titre));
        await amenerEnVue(tester, question, find.byKey(const Key('defilement_accueil')));
        await tester.tap(question);
        await attendreWidget(tester, find.widgetWithText(AppBar, menu.question.titre));
        await stabiliser(tester, tours: 4);
        final carte = find.descendant(of: find.byType(QuestionScreen), matching: find.text(module.tuile));
        await amenerEnVue(tester, carte, find.byKey(const Key('defilement_question')));
        await tester.tap(carte);
      } else {
        final cible = find.descendant(of: find.byType(AccueilNouveau), matching: find.text(module.tuile));
        final defilement = find.byKey(Key(p == Presentation.compact ? 'defilement_menus' : 'defilement_accueil'));
        await amenerEnVue(tester, cible, defilement);
        if (cible.hitTestable().evaluate().isEmpty) {
          problemes.add('${module.tuile} : menu introuvable ou non touchable (présentation ${p.lettre})');
          return;
        }
        await tester.tap(cible.hitTestable().first);
      }
      await stabiliser(tester, tours: 20);
    });
    for (final e in erreurs.toSet()) {
      problemes.add('${module.tuile} : $e');
    }
    if (find.widgetWithText(AppBar, module.titreEcran).evaluate().isEmpty) {
      problemes.add('${module.tuile} : barre « ${module.titreEcran} » absente');
    }
    if (find.byType(LoadErrorView).evaluate().isNotEmpty || find.byType(LoadErrorBanner).evaluate().isNotEmpty) {
      problemes.add('${module.tuile} : « Chargement impossible » alors que le serveur répond normalement');
    }
    if (find.byType(LoginScreen).evaluate().isNotEmpty) problemes.add('${module.tuile} : retour inattendu à la connexion');

    await releverErreurs(() => retourSysteme(tester));
    if (p == Presentation.guide) {
      // Module → question → accueil.
      if (find.byType(QuestionScreen).hitTestable().evaluate().isEmpty) problemes.add('${module.tuile} : le retour ne ramène pas à la question');
      await releverErreurs(() => retourSysteme(tester));
    }
    var essais = 0;
    while (find.byType(AccueilNouveau).hitTestable().evaluate().isEmpty && essais++ < 3) {
      if (essais == 1) problemes.add('${module.tuile} : le retour ne ramène pas à l\'accueil');
      await releverErreurs(() => retourSysteme(tester));
    }
  }
  return problemes;
}

void main() {
  setUpAll(chargerPolicesReelles);

  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    preparerNouvelle(serveur);
    donneesAccueil(serveur);
  });

  tearDown(() async {
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..parDefaut = ((_) => ReponseFausse.json(DonneesFictives.listeVide()));
  });

  testWidgets('nouvelle interface PAR DÉFAUT (aucun choix mémorisé) : connexion, accueil A, chiffres du jour, déconnexion',
      (tester) async {
    telephone(tester);
    // Téléphone qui n'a jamais choisi : aucune clé d'interface ni de présentation.
    SharedPreferences.setMockInitialValues(serveur.preferencesApp());
    InterfaceVersion.useNew.value = false;
    PresentationPrefs.choix.value = Presentation.compact;
    await tester.runAsync(InterfaceVersion.load);
    expect(InterfaceVersion.useNew.value, isTrue, reason: 'nouvelle interface par défaut');
    expect(PresentationPrefs.choix.value, Presentation.automatique, reason: 'présentation automatique (A sur téléphone)');

    await lancerApplication(tester);
    await attendreWidget(tester, find.byKey(const Key('connexion_se_connecter')));
    await attendreTexte(tester, DonneesFictives.nomOfficine);
    expect(find.text('Se connecter'), findsOneWidget);

    // Mauvais mot de passe : message du serveur, on reste sur la connexion (mêmes contrôles qu'avant).
    await seConnecterNouvelle(tester, motDePasse: 'mauvais');
    await attendreTexte(tester, DonneesFictives.messageIdentifiantsIncorrects);
    expect(find.byType(AccueilNouveau), findsNothing);

    await seConnecterNouvelle(tester);
    await attendreWidget(tester, find.byType(AccueilNouveau));
    expect(find.byType(HomeScreen), findsNothing);
    // Accueil A : chiffres du jour lus sur les routes existantes, avec la session de la connexion.
    await attendreTexte(tester, '1 245 300 F');
    await attendreTexte(tester, '3 / 4');
    expect(serveur.recues('/recap/dashboard').last.sessionEnvoyee, serveur.derniereSession);
    expect(serveur.recues('/rh/presence').last.sessionEnvoyee, serveur.derniereSession);
    expect(find.text(DonneesFictives.nomOfficine), findsOneWidget);

    await tester.tap(find.byTooltip('Déconnexion').first);
    await attendreWidget(tester, find.byType(LoginScreen));
    expect(serveur.recues('/user/logout', methode: 'POST'), hasLength(1));
    await terminer(tester);
  });

  for (final (lettre, p) in presentationsTestees) {
    testWidgets('présentation $lettre (téléphone) : chaque module s\'ouvre sans erreur et se referme', (tester) async {
      telephone(tester);
      preparerNouvelle(serveur, p: p);
      await jusquAccueilNouveau(tester);
      final problemes = await parcourirModules(tester, p);
      expect(problemes, isEmpty, reason: problemes.join('\n'));
      expect(serveur.requetes.where((r) => !r.chemin.startsWith('/licence') && r.chemin != '/user/auth' && r.chemin != '/officine')
          .map((r) => r.sessionEnvoyee).toSet(), {serveur.derniereSession});
      await terminer(tester);
    });
  }

  testWidgets('tablette : présentation B automatique (menu latéral, deux colonnes), chaque module s\'ouvre et se referme',
      (tester) async {
    tablette(tester);
    await jusquAccueilNouveau(tester);
    expect(find.byKey(const Key('barre_accueil')), findsNothing, reason: 'menu latéral à la place de la barre du bas');
    expect(find.text('Pilotage'.toUpperCase()), findsOneWidget);
    expect(find.text('Rechercher un menu'), findsOneWidget);
    final problemes = await parcourirModules(tester, Presentation.compact);
    expect(problemes, isEmpty, reason: problemes.join('\n'));
    await terminer(tester);
  });

  testWidgets('présentation B : la recherche de menu filtre la liste', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.compact);
    await jusquAccueilNouveau(tester);
    await tester.enterText(find.byKey(const Key('recherche_menu')), 'peremption');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Suivi Péremption'), findsOneWidget);
    expect(find.text('Détail CA'), findsNothing);
    await terminer(tester);
  });

  testWidgets('onglets Analyses, Équipe (présences : jour, période, pointage) et Réglages', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);

    await ouvrirOnglet(tester, 'Analyses');
    expect(find.text('Analyse Article'), findsOneWidget);
    await tester.tap(find.text('Analyse Article'));
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Analyse Article'));
    await tester.enterText(find.byType(TextField), 'parafictif');
    await attendreTexte(tester, DonneesFictives.libelleArticle1);
    await retourSysteme(tester);
    await attendreQue(tester, () => find.byType(AnalyseArticleScreen).evaluate().isEmpty, raison: 'retour aux analyses');

    await ouvrirOnglet(tester, 'Équipe');
    for (final (entree, titre, route) in [
      ('Présence du jour', 'Présence du jour', '/rh/presence'),
      ('Tableau des présences', 'Tableau des présences', '/rh/tableau'),
      ('Pointage & téléphones', 'Pointage & téléphones', '/rh/mobile/code'),
    ]) {
      serveur.oublierRequetes();
      await tester.tap(find.descendant(of: find.byType(AccueilNouveau), matching: find.text(entree)));
      await attendreWidget(tester, find.widgetWithText(AppBar, titre));
      await attendreQue(tester, () => serveur.recues(route).isNotEmpty, raison: '$route demandé');
      expect(find.byType(LoadErrorView), findsNothing);
      await retourSysteme(tester);
      await attendreQue(tester, () => find.byType(AccueilNouveau).hitTestable().evaluate().isNotEmpty, raison: 'retour à l\'équipe');
    }

    await ouvrirOnglet(tester, 'Réglages');
    expect(find.byKey(const Key('interrupteur_nouvelle_interface')), findsOneWidget);
    expect(find.text('B · Compact'), findsOneWidget);
    // Retour système sur un onglet : revient à l'onglet Accueil (et ne quitte pas l'application).
    await retourSysteme(tester);
    expect(find.text('Chiffre d\'affaires'), findsOneWidget);
    await terminer(tester);
  });

  testWidgets('retour à l\'ancienne interface depuis les Réglages : immédiat, mémorisé, puis retour à la nouvelle', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrirOnglet(tester, 'Réglages');
    await tester.tap(find.byKey(const Key('interrupteur_nouvelle_interface')));
    await stabiliser(tester);

    // Effet immédiat : ancien accueil, ancien thème, toujours connecté (aucune nouvelle connexion).
    await attendreWidget(tester, find.byType(HomeScreen));
    expect(find.text('Fonctionnalités'), findsOneWidget);
    expect(find.byType(AccueilNouveau), findsNothing);
    expect(serveur.recues('/user/auth'), hasLength(1));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(InterfaceVersion.cle), isFalse, reason: 'choix mémorisé');

    // Au prochain lancement, l'ancienne interface est toujours là.
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(InterfaceVersion.load);
    expect(InterfaceVersion.useNew.value, isFalse);
    await lancerApplication(tester);
    await attendreWidget(tester, find.byType(LoginScreen));
    await stabiliser(tester);
    expect(find.widgetWithText(ElevatedButton, 'Connexion'), findsOneWidget, reason: 'écran de connexion d\'origine');
    expect(find.byKey(const Key('connexion_se_connecter')), findsNothing);
    await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), DonneesFictives.identifiant);
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), DonneesFictives.motDePasse);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Connexion'));
    await attendreWidget(tester, find.byType(HomeScreen));
    await stabiliser(tester);

    // Ancienne interface → Configuration IP → « Nouvelle interface » : retour à la nouvelle.
    await tester.tap(find.byTooltip('Configuration IP'));
    await attendreWidget(tester, find.byType(SettingsScreen));
    await amenerEnVue(tester, find.byKey(const Key('interrupteur_nouvelle_interface')), find.byType(SettingsScreen));
    await tester.tap(find.byKey(const Key('interrupteur_nouvelle_interface')));
    await stabiliser(tester);
    expect(prefs.getBool(InterfaceVersion.cle), isTrue);
    // Effet immédiat : nouvel accueil, toujours connecté.
    await attendreWidget(tester, find.byType(AccueilNouveau));
    expect(find.byType(SettingsScreen), findsNothing);
    await terminer(tester);
  });

  testWidgets('présentation A/B/C : autre compte → code administrateur exigé ; compte « admin » → choix direct et mémorisé',
      (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrirOnglet(tester, 'Réglages');
    await tester.tap(find.byKey(const Key('presentation_guide')));
    await stabiliser(tester, tours: 4);
    expect(find.text('Code Administrateur requis :'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await stabiliser(tester, tours: 4);
    expect(PresentationPrefs.choix.value, Presentation.automatique, reason: 'refusé sans le code administrateur');
    await ouvrirOnglet(tester, 'Accueil');
    await tester.tap(find.byTooltip('Déconnexion').first);
    await attendreWidget(tester, find.byType(LoginScreen));

    // Connexion du compte administrateur.
    serveur.controlerSession = false;
    serveur.quand('/user/auth', ReponseFausse.json({...DonneesFictives.utilisateur(), 'str_LOGIN': 'admin'},
        entetes: {'set-cookie': 'JSESSIONID=fictif-admin; Path=/prestige; HttpOnly'}), methode: 'POST');
    await seConnecterNouvelle(tester);
    await attendreWidget(tester, find.byType(AccueilNouveau));
    await stabiliser(tester);
    await ouvrirOnglet(tester, 'Réglages');
    expect(find.text('Présentation (pour tous les comptes de ce téléphone)'), findsOneWidget, reason: 'compte administrateur reconnu');
    await tester.tap(find.byKey(const Key('presentation_guide')));
    await stabiliser(tester, tours: 4);
    expect(find.text('Code Administrateur requis :'), findsNothing);
    expect(PresentationPrefs.choix.value, Presentation.guide);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PresentationPrefs.cle), 'guide');
    await ouvrirOnglet(tester, 'Accueil');
    expect(find.text('Que voulez-vous savoir ?'), findsOneWidget);
    await terminer(tester);
  });

  testWidgets('accueil A : ⟳ → nombre et heure → le module ouvert montre le même nombre ; au retour « il y a X min »',
      (tester) async {
    telephone(tester);
    donneesAlertes(serveur);
    await jusquAccueilNouveau(tester);
    await attendreTexte(tester, '3 / 4');
    final defilement = find.byKey(const Key('defilement_accueil'));
    String texte(String cle) => tester.widget<Text>(find.byKey(Key(cle))).textSpan!.toPlainText();

    // Avant tout appui : invitation, aucun appel.
    expect(find.byKey(const Key('alerte_peremption_invite')), findsOneWidget);
    expect(find.byKey(const Key('alerte_controle_invite')), findsOneWidget);
    expect(serveur.recues(AppConstants.suiviPeremptionEndpoint), isEmpty);
    expect(serveur.recues(AppConstants.etatControleAchatEndpoint), isEmpty);

    // Appuis : nombre + heure du comptage.
    final heure = RegExp(r'à \d\d:\d\d$');
    for (final (cle, attendu) in [('peremption', '3 lots'), ('controle', '7 bons')]) {
      final bouton = find.byKey(Key('alerte_${cle}_actualiser'));
      await amenerEnVue(tester, bouton, defilement);
      await tester.tap(bouton);
      await attendreWidget(tester, find.byKey(Key('alerte_${cle}_nombre')));
      expect(texte('alerte_${cle}_nombre'), startsWith('$attendu · '));
      expect(texte('alerte_${cle}_nombre'), matches(heure));
      expect(find.byKey(Key('alerte_${cle}_invite')), findsNothing);
    }
    final comptagePeremption = serveur.recues(AppConstants.suiviPeremptionEndpoint).single;
    final comptageControle = serveur.recues(AppConstants.etatControleAchatEndpoint).single;

    // Suivi Péremption ouvert depuis l'alerte : même requête, autant de lots listés que le nombre affiché.
    await tester.tap(find.text('Produits proches de la péremption'));
    await attendreWidget(tester, find.byType(SuiviPeremptionScreen));
    await attendreQue(tester, () => serveur.recues(AppConstants.suiviPeremptionEndpoint).length == 2, raison: 'liste du module');
    await stabiliser(tester);
    expect(serveur.recues(AppConstants.suiviPeremptionEndpoint).last.parametres, comptagePeremption.parametres);
    expect(find.descendant(of: find.byType(SuiviPeremptionScreen), matching: find.byType(ListTile)), findsNWidgets(DonneesFictives.lotsPerimes));
    await retourSysteme(tester);
    await attendreQue(tester, () => find.byType(AccueilNouveau).hitTestable().evaluate().isNotEmpty, raison: 'retour à l\'accueil');

    // Au retour : nombres mémorisés (aucun nouvel appel), marqués « il y a X min ».
    AlertesAccueil.maintenant = () => DateTime.now().add(const Duration(minutes: 5, seconds: 30));
    await tester.pump(const Duration(seconds: 31));
    expect(texte('alerte_peremption_nombre'), '3 lots · il y a 5 min');
    expect(texte('alerte_controle_nombre'), '7 bons · il y a 5 min');
    expect(serveur.recues(AppConstants.suiviPeremptionEndpoint), hasLength(2));
    expect(serveur.recues(AppConstants.etatControleAchatEndpoint), hasLength(1));

    // Etat Contrôle Achat ouvert depuis l'alerte : « Rechercher » avec ses filtres par défaut → même requête,
    // « Total Bons » = nombre affiché sur l'accueil.
    final carteControle = find.text('Contrôle des bons de livraison');
    await amenerEnVue(tester, carteControle, defilement);
    await tester.tap(carteControle);
    await attendreWidget(tester, find.byType(EtatControleAchatScreen));
    await stabiliser(tester);
    await tester.tap(find.descendant(of: find.byType(EtatControleAchatScreen), matching: find.text('Rechercher')));
    await attendreTexte(tester, 'Total Bons:');
    expect(serveur.recues(AppConstants.etatControleAchatEndpoint).last.parametres, comptageControle.parametres);
    final ligneTotal = find.ancestor(of: find.text('Total Bons:'), matching: find.byType(Row)).first;
    expect(find.descendant(of: ligneTotal, matching: find.text('${DonneesFictives.bonsControles}')), findsOneWidget);
    await retourSysteme(tester);
    await attendreQue(tester, () => find.byType(AccueilNouveau).hitTestable().evaluate().isNotEmpty, raison: 'retour à l\'accueil');
    expect(texte('alerte_controle_nombre'), startsWith('7 bons · '));
    await terminer(tester);
  });

  testWidgets('accueil A : échec du comptage (500 puis serveur coupé) affiché sur l\'alerte, l\'accueil reste utilisable',
      (tester) async {
    telephone(tester);
    serveur.quand(AppConstants.suiviPeremptionEndpoint, ReponseFausse.erreurServeur());
    await jusquAccueilNouveau(tester);
    await attendreTexte(tester, '3 / 4');
    final bouton = find.byKey(const Key('alerte_peremption_actualiser'));
    await amenerEnVue(tester, bouton, find.byKey(const Key('defilement_accueil')));
    await tester.tap(bouton);
    await attendreTexte(tester, 'Erreur du serveur (code 500).');
    expect(find.textContaining('NullPointer'), findsNothing);
    expect(find.byKey(const Key('alerte_controle_invite')), findsOneWidget, reason: 'l\'autre alerte n\'est pas touchée');
    // Le reste de l'accueil est intact : chiffres du jour toujours affichés.
    await tester.scrollUntilVisible(find.text(formaterMontant(DonneesFictives.caDuJour)), -150,
        scrollable: find.descendant(of: find.byKey(const Key('defilement_accueil')), matching: find.byType(Scrollable)).first);
    expect(find.text(formaterMontant(DonneesFictives.caDuJour)), findsOneWidget, reason: 'chiffres du jour intacts');
    await amenerEnVue(tester, find.byKey(const Key('alerte_controle_actualiser')), find.byKey(const Key('defilement_accueil')));
    await tester.runAsync(serveur.arreter);
    await tester.tap(find.byKey(const Key('alerte_controle_actualiser')));
    await attendreTexte(tester, 'Serveur injoignable. Vérifiez le réseau.');
    expect(find.text('Erreur du serveur (code 500).'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    await terminer(tester);
  });

  testWidgets('session expirée en cours de route → écran de connexion avec message (nouvelle interface)', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrirOnglet(tester, 'Analyses');
    await tester.tap(find.text('Analyse Article'));
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Analyse Article'));
    serveur.expirerSessions();
    await tester.enterText(find.byType(TextField), 'parafictif');
    await attendreWidget(tester, find.byType(LoginScreen));
    await attendreTexte(tester, AuthProvider.messageSessionExpiree);
    await attendreQue(tester, () => find.byType(AnalyseArticleScreen).evaluate().isEmpty, raison: 'Analyse Article fermée');
    await tester.tap(find.text('OK'));
    await stabiliser(tester);
    await seConnecterNouvelle(tester);
    await attendreWidget(tester, find.byType(AccueilNouveau));
    await terminer(tester);
  });

  testWidgets('serveur coupé en cours de route → message réseau, ni licence ni déconnexion (nouvelle interface)', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrirOnglet(tester, 'Analyses');
    await tester.tap(find.text('Analyse Article'));
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Analyse Article'));
    await tester.runAsync(serveur.arreter);
    await tester.enterText(find.byType(TextField), 'parafictif');
    await attendreWidget(tester, find.byType(LoadErrorView));
    expect(find.textContaining('Serveur injoignable'), findsOneWidget);
    expect(find.byType(LicenceRegistrationScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    await terminer(tester);
  });

  testWidgets('serveur injoignable dès le lancement → assistant « Le serveur ne répond pas » (pas licence)', (tester) async {
    telephone(tester);
    final ferme = await tester.runAsync(FauxServeurPrestige.portFerme);
    SharedPreferences.setMockInitialValues({...serveur.preferencesApp(), 'port_key': '$ferme'});
    await lancerApplication(tester);
    await attendreWidget(tester, find.byType(ServeurInjoignableScreen));
    expect(find.text('Le serveur ne répond pas'), findsOneWidget);
    expect(find.textContaining('La licence n\'est pas en cause'), findsOneWidget);
    expect(find.text('Hors ligne'), findsOneWidget);
    expect(find.byKey(const Key('injoignable_reessayer')), findsOneWidget);
    expect(find.byType(LicenceRegistrationScreen), findsNothing);
    await terminer(tester);
  });

  testWidgets('licence absente → écran de licence (nouvelle interface)', (tester) async {
    telephone(tester);
    serveur.quand('/licence/find', ReponseFausse.vide(), methode: 'GET');
    await lancerApplication(tester);
    await attendreWidget(tester, find.byType(LicenceRegistrationScreen));
    expect(find.text('Licence requise'), findsOneWidget);
    expect(find.text('Valider la licence'), findsOneWidget);
    expect(find.byType(ServeurInjoignableScreen), findsNothing);
    await terminer(tester);
  });
}
