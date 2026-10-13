// Tests de bout en bout : l'application ENTIÈRE (main.dart : providers, thème, parcours de démarrage) est montée
// dans `flutter test` et parle en HTTP réel au faux serveur Prestige local (127.0.0.1), dont l'adresse est
// saisie dans ses préférences comme le ferait la Configuration IP. Aucun émulateur nécessaire (CI Linux).
//
// Parcours : lancement → licence → connexion → accueil → chaque module → retour → déconnexion ;
// session expirée en cours de route → écran de connexion ; serveur coupé → message réseau (jamais « licence »).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/screens/analyse_article_screen.dart';
import 'package:prestige_app/screens/fiche_article_screen.dart';
import 'package:prestige_app/screens/home_screen.dart';
import 'package:prestige_app/screens/licence_registration_screen.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/screens/serveur_injoignable_screen.dart';
import 'package:prestige_app/widgets/erreurs_chargement.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/application.dart';
import '../support/catalogue_ecrans.dart';
import '../support/donnees_fictives.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

/// Téléphone 411 × 891 dp.
void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

Future<void> seConnecter(WidgetTester tester, {String identifiant = DonneesFictives.identifiant, String motDePasse = DonneesFictives.motDePasse}) async {
  await attendreWidget(tester, find.byType(LoginScreen));
  await stabiliser(tester); // nom de l'officine chargé
  await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), identifiant);
  await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), motDePasse);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Connexion'));
}

Future<void> jusquAccueil(WidgetTester tester) async {
  await lancerApplication(tester);
  await seConnecter(tester);
  await attendreWidget(tester, find.byType(HomeScreen));
  await stabiliser(tester);
}

/// Page suivante de l'accueil (glissement), jusqu'à l'arrêt de l'animation.
Future<void> pageSuivante(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(-300, 0));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Ouvre le module [tuile] de l'accueil (en tournant les pages si besoin) et attend sa barre [titre].
Future<void> ouvrirModule(WidgetTester tester, String tuile, String titre) async {
  final f = find.descendant(of: find.byType(HomeScreen), matching: find.text(tuile));
  for (var page = 0; f.evaluate().isEmpty && page < 6; page++) {
    await pageSuivante(tester);
  }
  await tester.tap(f);
  await attendreWidget(tester, find.widgetWithText(AppBar, titre));
}

/// Bouton « retour » du système Android.
Future<void> retourSysteme(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await stabiliser(tester, tours: 4);
}

void main() {
  setUpAll(chargerPolicesReelles);

  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    preparerTelephone(serveur);
  });

  tearDown(() async {
    restaurerClient();
    await serveur.arreter();
    // Routes par défaut pour le test suivant (un test a pu en remplacer).
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..parDefaut = ((_) => ReponseFausse.json(DonneesFictives.listeVide()));
  });

  testWidgets('lancement → licence vérifiée → connexion → accueil → déconnexion', (tester) async {
    telephone(tester);
    await lancerApplication(tester);
    await attendreWidget(tester, find.byType(LoginScreen));
    expect(serveur.recues('/licence/find'), isNotEmpty, reason: 'la licence est vérifiée au lancement');
    await attendreTexte(tester, DonneesFictives.nomOfficine); // nom de l'officine sur l'écran de connexion

    // Mauvais mot de passe : message du serveur, on reste sur la connexion.
    await seConnecter(tester, motDePasse: 'mauvais');
    await attendreTexte(tester, DonneesFictives.messageIdentifiantsIncorrects);
    expect(find.byType(HomeScreen), findsNothing);

    await seConnecter(tester);
    await attendreWidget(tester, find.byType(HomeScreen));
    await attendreTexte(tester, DonneesFictives.nomOfficine);
    expect(find.text('Bienvenue ${DonneesFictives.nomComplet}'), findsOneWidget);
    expect(find.text('Fonctionnalités'), findsOneWidget);

    // Le cookie de la réponse de connexion est renvoyé ensuite (pas un ancien).
    final derniereConnexion = serveur.requetes.lastIndexWhere((r) => r.chemin == '/user/auth');
    final apres = serveur.requetes.sublist(derniereConnexion + 1);
    expect(serveur.recues('/user/auth').last.sessionEnvoyee, isNull);
    expect(apres, isNotEmpty);
    expect(apres.map((r) => r.sessionEnvoyee).toSet(), {serveur.derniereSession});

    await tester.tap(find.byTooltip('Déconnexion'));
    await attendreWidget(tester, find.byType(LoginScreen));
    expect(serveur.recues('/user/logout', methode: 'POST'), hasLength(1));
    await terminer(tester);
  });

  testWidgets('chaque module de l\'accueil s\'ouvre (sans erreur ni « Chargement impossible ») et se referme', (tester) async {
    telephone(tester);
    await jusquAccueil(tester);

    final problemes = <String>[];
    final vus = <String>{};
    const parPage = 6;
    for (var i = 0; i < modulesAccueil.length; i++) {
      final module = modulesAccueil[i];
      if (i > 0 && i % parPage == 0) await pageSuivante(tester);
      final tuile = find.descendant(of: find.byType(HomeScreen), matching: find.text(module.tuile));
      expect(tuile, findsOneWidget, reason: 'tuile « ${module.tuile} » absente de l\'accueil (page ${i ~/ parPage + 1})');

      final erreurs = await releverErreurs(() async {
        await tester.tap(tuile);
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
      vus.add(module.tuile);

      await releverErreurs(() => retourSysteme(tester));
      var essais = 0;
      while (find.text('Fonctionnalités').hitTestable().evaluate().isEmpty && essais++ < 3) {
        if (essais == 1) problemes.add('${module.tuile} : le retour ne ramène pas à l\'accueil');
        await releverErreurs(() => retourSysteme(tester));
      }
    }
    expect(vus, hasLength(modulesAccueil.length));
    // Aucun module de l'accueil absent du catalogue (test/support/catalogue_ecrans.dart) : dernière page complète.
    final pages = (tester.widget<PageView>(find.byType(PageView)).childrenDelegate as SliverChildBuilderDelegate).childCount;
    expect(pages, (modulesAccueil.length / parPage).ceil(), reason: 'nouveau module à l\'accueil : l\'ajouter au catalogue');
    expect(find.descendant(of: find.byType(GridView), matching: find.byType(InkWell)),
        findsNWidgets(modulesAccueil.length - (pages! - 1) * parPage));
    expect(problemes, isEmpty, reason: problemes.join('\n'));
    // Toutes les requêtes des modules portent la session ouverte à la connexion.
    expect(serveur.requetes.where((r) => !r.chemin.startsWith('/licence') && r.chemin != '/user/auth' && r.chemin != '/officine')
        .map((r) => r.sessionEnvoyee).toSet(), {serveur.derniereSession});
    await terminer(tester);
  });

  testWidgets('Analyse Article puis Fiche Article : recherche, résultat du serveur, détail', (tester) async {
    telephone(tester);
    await jusquAccueil(tester);

    await ouvrirModule(tester, 'Analyse Article', 'Analyse Article');
    await tester.enterText(find.byType(TextField), 'parafictif');
    await attendreTexte(tester, DonneesFictives.libelleArticle1);
    expect(serveur.recues('/info').last.parametres['search'], 'parafictif');
    expect(find.text(DonneesFictives.libelleArticle2), findsNothing);
    await tester.tap(find.text(DonneesFictives.libelleArticle1));
    await attendreTexte(tester, 'Détails de l\'Article');
    expect(find.text('Stock réserve'), findsWidgets);
    await retourSysteme(tester); // ferme le détail
    await attendreQue(tester, () => find.text('Détails de l\'Article').evaluate().isEmpty, raison: 'détail fermé');
    await retourSysteme(tester); // revient à l'accueil
    await attendreQue(tester, () => find.byType(AnalyseArticleScreen).evaluate().isEmpty, raison: 'retour à l\'accueil');

    await ouvrirModule(tester, 'Fiche Article', 'Fiche Article');
    await tester.enterText(find.descendant(of: find.byType(FicheArticleScreen), matching: find.byType(TextField)), 'sirop');
    await attendreTexte(tester, DonneesFictives.libelleArticle2);
    expect(serveur.recues('/checkproduit').last.parametres['nompdt'], 'sirop');
    await terminer(tester);
  });

  testWidgets('module Présences : jour, période et pointage avec les données du serveur', (tester) async {
    telephone(tester);
    await jusquAccueil(tester);
    await ouvrirModule(tester, 'Présences', 'Présence du jour');
    await attendreTexte(tester, DonneesFictives.employe);
    expect(serveur.recues('/rh/presence'), isNotEmpty);

    await tester.tap(find.text('Période'));
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Tableau des présences'));
    await attendreTexte(tester, DonneesFictives.employe);
    expect(serveur.recues('/rh/tableau'), isNotEmpty);

    await tester.tap(find.text('Pointage'));
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Pointage & téléphones'));
    await attendreQue(tester, () => serveur.recues('/rh/mobile/code').isNotEmpty, raison: 'code de pointage demandé');
    await attendreQue(tester, () => serveur.recues('/rh/mobile/terminaux').isNotEmpty, raison: 'téléphones demandés');
    expect(find.byType(LoadErrorView), findsNothing);

    await retourSysteme(tester);
    await attendreQue(tester, () => find.text('Fonctionnalités').hitTestable().evaluate().isNotEmpty, raison: 'retour à l\'accueil');
    await terminer(tester);
  });

  testWidgets('session expirée en cours de route → écran de connexion avec message, puis reconnexion', (tester) async {
    telephone(tester);
    await jusquAccueil(tester);
    await ouvrirModule(tester, 'Analyse Article', 'Analyse Article');

    serveur.expirerSessions(); // le serveur a oublié la session (redémarrage, délai d'inactivité serveur…)
    await tester.enterText(find.byType(TextField), 'parafictif');
    await attendreWidget(tester, find.byType(LoginScreen));
    await attendreTexte(tester, 'Session Expirée');
    expect(find.text(AuthProvider.messageSessionExpiree), findsOneWidget);
    // Les écrans ouverts sont fermés (fin de l'animation de sortie).
    await attendreQue(tester, () => find.byType(AnalyseArticleScreen).evaluate().isEmpty, raison: 'Analyse Article fermée');
    await tester.tap(find.text('OK'));
    await stabiliser(tester);

    // Reconnexion : nouvelle session, l'application repart.
    final ancienne = serveur.derniereSession;
    await seConnecter(tester);
    await attendreWidget(tester, find.byType(HomeScreen));
    expect(serveur.derniereSession, isNot(ancienne));
    await terminer(tester);
  });

  testWidgets('session expirée signalée en 200 {success:false} → écran de connexion', (tester) async {
    telephone(tester);
    await jusquAccueil(tester);
    serveur.reponseSansSession = (_) => ReponseFausse.sessionExpireeEn200();
    addTearDown(() => serveur.reponseSansSession = (_) => ReponseFausse.sessionExpiree());
    await ouvrirModule(tester, 'Analyse Article', 'Analyse Article');
    serveur.expirerSessions();
    await tester.enterText(find.byType(TextField), 'parafictif');
    await attendreWidget(tester, find.byType(LoginScreen));
    await attendreTexte(tester, AuthProvider.messageSessionExpiree);
    await terminer(tester);
  });

  testWidgets('serveur coupé en cours de route → message réseau, ni licence ni déconnexion', (tester) async {
    telephone(tester);
    await jusquAccueil(tester);
    await ouvrirModule(tester, 'Analyse Article', 'Analyse Article');

    await tester.runAsync(serveur.arreter);
    await tester.enterText(find.byType(TextField), 'parafictif');
    await attendreWidget(tester, find.byType(LoadErrorView));
    expect(find.text('Chargement impossible'), findsOneWidget);
    expect(find.textContaining('Serveur injoignable'), findsOneWidget);
    expect(find.byType(LicenceRegistrationScreen), findsNothing);
    expect(find.textContaining('icence'), findsNothing);
    expect(find.byType(LoginScreen), findsNothing, reason: 'une panne réseau ne déconnecte pas');
    await terminer(tester);
  });

  testWidgets('serveur injoignable dès le lancement → « Le serveur ne répond pas » (pas licence)', (tester) async {
    telephone(tester);
    final ferme = await tester.runAsync(FauxServeurPrestige.portFerme);
    SharedPreferences.setMockInitialValues({...serveur.preferencesApp(), 'port_key': '$ferme'});
    await lancerApplication(tester);
    await attendreWidget(tester, find.byType(ServeurInjoignableScreen));
    expect(find.text('Le serveur ne répond pas'), findsOneWidget);
    expect(find.textContaining('La licence n\'est pas en cause'), findsOneWidget);
    expect(find.byType(LicenceRegistrationScreen), findsNothing);
    await terminer(tester);
  });

  testWidgets('licence absente (réponse vide du serveur) → écran de licence', (tester) async {
    telephone(tester);
    serveur.quand('/licence/find', ReponseFausse.vide(), methode: 'GET');
    await lancerApplication(tester);
    await attendreWidget(tester, find.byType(LicenceRegistrationScreen));
    expect(find.text('Licence requise'), findsOneWidget);
    expect(find.byType(ServeurInjoignableScreen), findsNothing);
    await terminer(tester);
  });

  testWidgets('licence expirée → écran de licence avec la date d\'expiration', (tester) async {
    telephone(tester);
    serveur.quand('/licence/find', ReponseFausse.json(DonneesFictives.licenceExpiree()), methode: 'GET');
    await lancerApplication(tester);
    await attendreWidget(tester, find.byType(LicenceRegistrationScreen));
    expect(find.text('Votre licence a expiré le 01/01/2026.'), findsOneWidget);
    await terminer(tester);
  });

  testWidgets('erreur 500 du serveur au lancement → message serveur, pas licence', (tester) async {
    telephone(tester);
    serveur.quand('/licence/find', ReponseFausse.erreurServeur(), methode: 'GET');
    await lancerApplication(tester);
    await attendreWidget(tester, find.byType(ServeurInjoignableScreen));
    expect(find.text('Le serveur Prestige a répondu par une erreur'), findsOneWidget);
    expect(find.textContaining('NullPointer'), findsNothing);
    await terminer(tester);
  });
}
