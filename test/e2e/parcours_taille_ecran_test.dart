// Bout en bout — Taille de l'écran (3.7.0, docs/TAILLE_ECRAN.md) : l'application ENTIÈRE (main.dart) parle en HTTP
// réel au faux serveur Prestige local, sur un Sunmi V2s (720 × 1440 px, densité 2 → 360 × 720 dp).
//
//  - nouvelle interface, Réglages › Apparence : « Automatique (Compact appliqué sur cet écran) » ; changer la taille
//    exige le code administrateur (Annuler ou code faux : rien n'est enregistré) ; « Plus tard » : choix enregistré,
//    appliqué au prochain lancement seulement ; « Relancer maintenant » : retour à l'accueil, interface reconstruite
//    à la nouvelle taille, SESSION GARDÉE (aucune reconnexion, cookie JSESSIONID renvoyé et accepté par le serveur) ;
//    la déconnexion automatique (délai d'inactivité) fonctionne toujours après la relance ;
//  - prochain lancement : la taille enregistrée est appliquée dès l'écran de connexion ;
//  - ancienne interface, Configuration : même réglage, même code, « Relancer maintenant » garde la session ;
//  - téléphone 1080 × 2400 : Automatique ne change rien (pas de mention « Compact appliqué »).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/reglages_nouveaux.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/screens/home_screen.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/screens/settings_screen.dart';
import 'package:prestige_app/services/pin_securise.dart';
import 'package:prestige_app/ui/taille_ecran.dart';
import 'package:prestige_app/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();
const _code = '5917';

void v2s(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = const Size(720, 1440);
  addTearDown(tester.view.reset);
}

/// Largeur vue par l'interface (MediaQuery sous RacineTailleEcran).
double largeurVue(WidgetTester tester) => MediaQuery.sizeOf(tester.element(find.byType(Navigator).first)).width;

bool connecte(WidgetTester tester) =>
    Provider.of<AuthProvider>(tester.element(find.byType(Navigator).first), listen: false).isLoggedIn;

Future<void> definirCode(WidgetTester tester) async {
  expect(await tester.runAsync(() => CodeAdmin.instance.definir(_code)), isNull);
}

/// Amène le réglage à l'écran (bas des Réglages ou de la Configuration).
Future<void> amenerReglage(WidgetTester tester, String nom) async {
  final cible = find.byKey(ValueKey('taille-ecran-$nom'));
  await tester.scrollUntilVisible(cible, 200, scrollable: find.byType(Scrollable).hitTestable().first, maxScrolls: 40);
  await stabiliser(tester, tours: 3);
}

Future<void> choisir(WidgetTester tester, String nom) async {
  await amenerReglage(tester, nom);
  await tester.tap(find.byKey(ValueKey('taille-ecran-$nom')));
  await stabiliser(tester, tours: 4);
}

Future<void> saisirCode(WidgetTester tester, String code) async {
  expect(find.byKey(const Key('pin_admin_saisie')), findsOneWidget, reason: 'code administrateur demandé');
  expect(find.text('Code Administrateur requis :'), findsOneWidget);
  await tester.enterText(find.byKey(const Key('pin_admin_saisie')), code);
  await tester.tap(find.text('Valider'));
  await stabiliser(tester, tours: 6);
}

Future<SharedPreferences> prefs(WidgetTester tester) async => (await tester.runAsync(SharedPreferences.getInstance))!;

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
      ..controlerSession = true;
    TailleEcranReglage.reinitialiser();
  });

  testWidgets(
      'nouvelle interface, Sunmi V2s : réglage protégé par le code, « Plus tard » = prochain lancement, '
      '« Relancer maintenant » garde la session ; déconnexion automatique toujours active', (tester) async {
    v2s(tester);
    await jusquAccueilNouveau(tester);
    await definirCode(tester);
    expect(largeurVue(tester), closeTo(400, 0.01), reason: 'Automatique : Compact appliqué d\'office sur le V2s');

    await toucherReglages(tester);
    await amenerReglage(tester, 'tresCompact');
    expect(find.text('Automatique (Compact appliqué sur cet écran)'), findsOneWidget);

    // Annuler : rien n'est enregistré.
    await choisir(tester, 'tresCompact');
    await tester.tap(find.text('Annuler'));
    await stabiliser(tester, tours: 4);
    expect(TailleEcranReglage.enregistree, TailleEcran.automatique);
    expect((await prefs(tester)).getString(TailleEcranReglage.cle), isNull);

    // Code faux : refusé, la fenêtre reste ouverte ; Annuler ensuite : toujours rien.
    await choisir(tester, 'tresCompact');
    await saisirCode(tester, '0000');
    expect(find.byKey(const Key('pin_admin_saisie')), findsOneWidget, reason: 'code faux : accès refusé');
    expect(find.byKey(const ValueKey('taille-ecran-relancer')), findsNothing);
    await tester.tap(find.text('Annuler'));
    await stabiliser(tester, tours: 4);
    expect(TailleEcranReglage.enregistree, TailleEcran.automatique);

    // Bon code → « Plus tard » : enregistré pour le prochain lancement, rien ne change maintenant.
    await choisir(tester, 'compact');
    await saisirCode(tester, _code);
    expect(find.byKey(const ValueKey('taille-ecran-relancer')), findsOneWidget);
    expect(find.text('Taille de l\'écran : Compact'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('taille-ecran-plus-tard')));
    await stabiliser(tester, tours: 4);
    expect((await prefs(tester)).getString(TailleEcranReglage.cle), 'compact');
    expect(TailleEcranReglage.active.value, TailleEcran.automatique, reason: 'appliqué au prochain lancement');
    expect(find.text('Choix enregistré : appliqué au prochain lancement.'), findsOneWidget);
    expect(find.byType(ReglagesScreen), findsOneWidget);

    // Bon code → « Relancer maintenant » : retour à l'accueil, interface à 450 dp, session gardée.
    serveur.oublierRequetes();
    await choisir(tester, 'tresCompact');
    await saisirCode(tester, _code);
    await tester.tap(find.byKey(const ValueKey('taille-ecran-relancer-maintenant')));
    await attendreWidget(tester, find.byType(AccueilNouveau));
    await stabiliser(tester);
    expect(TailleEcranReglage.active.value, TailleEcran.tresCompact);
    expect((await prefs(tester)).getString(TailleEcranReglage.cle), 'tresCompact');
    expect(largeurVue(tester), closeTo(450, 0.01));
    expect(find.byType(LoginScreen), findsNothing, reason: 'aucune reconnexion');
    expect(find.byKey(const ValueKey('taille-ecran-relancer')), findsNothing);
    expect(connecte(tester), isTrue);
    // L'accueil A reconstruit redemande les chiffres du jour : même cookie de session, accepté par le serveur.
    await attendreQue(tester, () => serveur.recues('/recap/dashboard').isNotEmpty, raison: 'chiffres du jour redemandés');
    await stabiliser(tester);
    final apres = serveur.recues('/recap/dashboard');
    expect(apres.every((r) => (r.cookie ?? '').contains('JSESSIONID=')), isTrue, reason: 'cookie de session renvoyé');
    expect(find.byType(LoginScreen), findsNothing, reason: 'session acceptée par le serveur');
    expect(connecte(tester), isTrue);

    // Déconnexion automatique après inactivité : toujours en place après la relance.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await stabiliser(tester, tours: 4);
    await tester.runAsync(() async {
      final p = await SharedPreferences.getInstance();
      await p.setInt(AppConstants.lastPausedTimeKey, DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch);
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await attendreTexte(tester, 'Session Expirée');
    await tester.tap(find.text('OK'));
    await attendreWidget(tester, find.byType(LoginScreen));
    expect(largeurVue(tester), closeTo(450, 0.01), reason: 'taille gardée après la déconnexion');
    await terminer(tester);
  });

  testWidgets('prochain lancement : la taille enregistrée (« Plus tard ») est appliquée dès la connexion', (tester) async {
    v2s(tester);
    await jusquAccueilNouveau(tester);
    await definirCode(tester);
    await toucherReglages(tester);
    await choisir(tester, 'tresCompact');
    await saisirCode(tester, _code);
    await tester.tap(find.byKey(const ValueKey('taille-ecran-plus-tard')));
    await stabiliser(tester, tours: 4);
    expect(largeurVue(tester), closeTo(400, 0.01), reason: 'rien ne change avant le prochain lancement');

    // Nouveau lancement : main() lit le réglage avant runApp.
    await tester.pumpWidget(const SizedBox());
    await stabiliser(tester);
    await tester.runAsync(TailleEcranReglage.charger);
    expect(TailleEcranReglage.active.value, TailleEcran.tresCompact);
    await lancerApplication(tester);
    await attendreWidget(tester, find.byType(LoginScreen));
    expect(largeurVue(tester), closeTo(450, 0.01));
    await terminer(tester);
  });

  testWidgets('ancienne interface, Configuration : même réglage, même code, « Relancer maintenant » garde la session',
      (tester) async {
    v2s(tester);
    preparerTelephone(serveur); // interface d'origine
    await lancerApplication(tester);
    await attendreWidget(tester, find.byType(LoginScreen));
    await stabiliser(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), DonneesFictives.identifiant);
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), DonneesFictives.motDePasse);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Connexion'));
    await attendreWidget(tester, find.byType(HomeScreen));
    await stabiliser(tester);
    await definirCode(tester);
    expect(largeurVue(tester), closeTo(400, 0.01));

    await tester.tap(find.byTooltip('Configuration IP'));
    await attendreWidget(tester, find.byType(SettingsScreen));
    await stabiliser(tester, tours: 4);
    await amenerReglage(tester, 'compact');
    expect(find.text('Automatique (Compact appliqué sur cet écran)'), findsOneWidget);
    await choisir(tester, 'tresCompact');
    await tester.tap(find.text('Annuler'));
    await stabiliser(tester, tours: 4);
    expect(TailleEcranReglage.enregistree, TailleEcran.automatique, reason: 'sans le code : rien');

    await choisir(tester, 'tresCompact');
    await saisirCode(tester, _code);
    await tester.tap(find.byKey(const ValueKey('taille-ecran-relancer-maintenant')));
    await attendreWidget(tester, find.byType(HomeScreen));
    await stabiliser(tester);
    expect(find.byType(SettingsScreen), findsNothing, reason: 'retour à l\'accueil');
    expect(largeurVue(tester), closeTo(450, 0.01));
    expect(find.byType(LoginScreen), findsNothing);
    expect(connecte(tester), isTrue);
    await terminer(tester);
  });

  // 3.8.0 (D1, réponse du pharmacien) : comme la présentation A / B / C, le compte « admin » change la taille SANS
  // code dans la nouvelle interface ; les autres comptes saisissent le code (tests ci-dessus, inchangés).
  void connexionAdmin() {
    serveur.controlerSession = false;
    serveur.quand('/user/auth', ReponseFausse.json({...DonneesFictives.utilisateur(), 'str_LOGIN': 'admin'},
        entetes: {'set-cookie': 'JSESSIONID=fictif-admin; Path=/prestige; HttpOnly'}), methode: 'POST');
  }

  testWidgets('nouvelle interface, compte « admin » : taille changée SANS code (comme la présentation)', (tester) async {
    v2s(tester);
    connexionAdmin();
    await jusquAccueilNouveau(tester);
    await definirCode(tester);
    await toucherReglages(tester);
    await amenerReglage(tester, 'compact');
    expect(find.text('Code administrateur demandé'), findsNothing);
    expect(find.text('Pour tous les comptes de ce téléphone'), findsOneWidget);
    await choisir(tester, 'tresCompact');
    expect(find.byKey(const Key('pin_admin_saisie')), findsNothing, reason: 'administrateur : aucun code');
    expect(find.byKey(const ValueKey('taille-ecran-relancer')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('taille-ecran-plus-tard')));
    await stabiliser(tester, tours: 4);
    expect((await prefs(tester)).getString(TailleEcranReglage.cle), 'tresCompact');
    await terminer(tester);
  });

  testWidgets('ancienne interface, compte « admin » : Configuration inchangée, le code reste demandé', (tester) async {
    v2s(tester);
    connexionAdmin();
    preparerTelephone(serveur); // interface d'origine
    await lancerApplication(tester);
    await attendreWidget(tester, find.byType(LoginScreen));
    await stabiliser(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), DonneesFictives.identifiant);
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), DonneesFictives.motDePasse);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Connexion'));
    await attendreWidget(tester, find.byType(HomeScreen));
    await stabiliser(tester);
    await definirCode(tester);
    await tester.tap(find.byTooltip('Configuration IP'));
    await attendreWidget(tester, find.byType(SettingsScreen));
    await stabiliser(tester, tours: 4);
    await choisir(tester, 'compact');
    expect(find.byKey(const Key('pin_admin_saisie')), findsOneWidget, reason: 'ancienne interface : code toujours demandé');
    await tester.tap(find.text('Annuler'));
    await stabiliser(tester, tours: 4);
    expect(TailleEcranReglage.enregistree, TailleEcran.automatique);
    await terminer(tester);
  });

  testWidgets('téléphone 1080 × 2400 : Automatique ne change rien, pas de mention « Compact appliqué »', (tester) async {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    await jusquAccueilNouveau(tester);
    expect(largeurVue(tester), closeTo(1080 / 2.625, 0.01));
    await toucherReglages(tester);
    await amenerReglage(tester, 'tresCompact');
    expect(find.byKey(const ValueKey('taille-ecran-auto-compact')), findsNothing);
    expect(find.text('Taille de l\'écran'), findsOneWidget);
    await terminer(tester);
  });
}
