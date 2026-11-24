// 3.18.0 — MODE DÉMONSTRATION (lib/demo/), application ENTIÈRE (main.dart), sans aucun serveur :
//  - installation neuve : « Essayer la démonstration » sur le PREMIER écran (configuration), un seul toucher → accueil
//    de la démonstration avec le bandeau « Démonstration — données fictives » ;
//  - AUCUNE requête réseau : le client HTTP « réel » de l'application échoue et relève tout appel, toute création
//    de client dart:io est refusée et relevée ;
//  - chaque rubrique (tous les menus du profil responsable, onglets Analyses / Équipe / Pilotage) s'ouvre avec des
//    données, sans erreur ni « chargement impossible » ;
//  - Analyse Article : « para » et « doli » trouvent des produits FICTIFS ;
//  - écritures (validations, envois, modifications, annulations) et exports refusés proprement : « Indisponible en
//    démonstration », rien d'envoyé, aucun plantage ;
//  - « Quitter la démonstration » : retour au premier écran / à la connexion, préférences, stockage sécurisé, client
//    HTTP intacts ; la vraie connexion fonctionne ensuite contre le vrai serveur (faux serveur Prestige).
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/demo/mode_demo.dart';
import 'package:prestige_app/demo/serveur_demo.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/menus.dart';
import 'package:prestige_app/nouvelle_interface/modules/articles_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/vague4/peremptions_courtes_vague4.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/screens/settings_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';
import 'package:prestige_app/widgets/erreurs_chargement.dart';
import 'package:provider/provider.dart';

import '../support/application.dart';
import '../support/demo.dart';
import '../support/donnees_fictives.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

BuildContext contexteAccueil(WidgetTester tester) => tester.element(find.byType(AccueilNouveau, skipOffstage: false));

Future<void> ouvrir(WidgetTester tester, Widget Function() ecran) async {
  Navigator.of(contexteAccueil(tester)).push(MaterialPageRoute(builder: (_) => ecran()));
  await pomper(tester, fois: 30);
}

Future<void> fermer(WidgetTester tester) async {
  Navigator.of(contexteAccueil(tester)).popUntil((r) => r.isFirst);
  await pomper(tester, fois: 5);
}

/// Erreurs visibles à l'écran (chargement impossible, serveur injoignable…).
List<String> erreursVisibles() => [
      if (find.byType(LoadErrorView).evaluate().isNotEmpty) 'LoadErrorView',
      if (find.byType(EtatErreur).evaluate().isNotEmpty) 'EtatErreur',
      for (final t in ['Chargement impossible', 'Serveur injoignable', ApiLoadException.messageReseau, ApiLoadException.messageReponse])
        if (find.textContaining(t).evaluate().isNotEmpty) t,
    ];

void main() {
  late HttpOverrides? precedent;
  late ReseauInterdit reseau;

  setUp(() {
    precedent = HttpOverrides.current;
    reseau = ReseauInterdit();
    HttpOverrides.global = reseau;
  });
  tearDown(() async {
    HttpOverrides.global = precedent;
    if (ModeDemo.estActif) await ModeDemo.quitter(); // test échoué en pleine démonstration
    ModeDemo.horloge = DateTime.now;
  });

  testWidgets('installation neuve : démonstration en 1 toucher, chaque rubrique, aucune requête, sortie intacte', (tester) async {
    telephone(tester);
    final client = await preparerInstallation();
    await lancerApplication(tester);
    await pomper(tester, fois: 10);
    // Premier écran d'une installation neuve : la configuration du serveur, avec le bouton.
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text(ModeDemo.libelleBouton), findsOneWidget);
    final prefsAvant = await instantanePreferences();
    final coffreAvant = await instantaneCoffre();

    await toucherDemo(tester); // UN toucher
    expect(ModeDemo.estActif, isTrue);
    expect(find.byType(AccueilNouveau), findsOneWidget);
    expect(find.text(ModeDemo.libelleBandeau), findsOneWidget);
    expect(find.text(ModeDemo.libelleQuitter), findsOneWidget);
    expect(find.textContaining('DÉMONSTRATION'), findsWidgets);
    expect(find.textContaining(RegExp(r'1\s245\s300')), findsWidgets, reason: 'chiffres du jour fictifs');
    expect(find.text('24/11/2026'), findsWidgets, reason: 'date du jour (horloge de la démonstration)');

    // Chaque rubrique : tous les menus du profil responsable.
    final problemes = <String>[];
    final menus = menusAutorises();
    expect(menus.length, greaterThanOrEqualTo(30));
    for (final m in menus) {
      final erreurs = await releverErreurs(() async {
        await ouvrir(tester, m.ecran);
        final visibles = erreursVisibles();
        if (visibles.isNotEmpty) problemes.add('${m.titre} : $visibles');
        await fermer(tester);
      });
      for (final e in erreurs) {
        problemes.add('${m.titre} : $e');
      }
    }
    // Onglets de l'accueil.
    for (final onglet in ['Analyses', 'Équipe', 'Pilotage', 'Accueil']) {
      final erreurs = await releverErreurs(() async {
        await ouvrirOnglet(tester, onglet);
        await pomper(tester, fois: 30);
        final visibles = erreursVisibles();
        if (visibles.isNotEmpty) problemes.add('onglet $onglet : $visibles');
      });
      problemes.addAll(erreurs.map((e) => 'onglet $onglet : $e'));
    }
    expect(problemes, isEmpty, reason: problemes.join('\n'));

    // Analyse Article : produits fictifs.
    await ouvrir(tester, () => const AnalyseArticleNouveau());
    await tester.enterText(find.byType(TextField).first, 'para');
    await pomper(tester, fois: 30);
    expect(find.textContaining('PARACÉTAMOL FICTIF 500MG'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'doli');
    await pomper(tester, fois: 30);
    expect(find.textContaining('DOLIFICTIF'), findsWidgets);
    await fermer(tester);

    // Aucune requête réseau pendant toute la démonstration.
    expect(client.appels, isEmpty, reason: 'client HTTP réel appelé : ${client.appels}');
    expect(reseau.tentatives, isEmpty, reason: 'client dart:io créé');

    // Sortie : retour au premier écran, tout est comme avant.
    await quitterDemo(tester);
    expect(ModeDemo.estActif, isFalse);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text(ModeDemo.libelleBandeau), findsNothing);
    expect(await instantanePreferences(), prefsAvant, reason: 'préférences réelles inchangées');
    expect(await instantaneCoffre(), coffreAvant, reason: 'stockage sécurisé réel inchangé');
    expect(identical(ApiService.client, client), isTrue, reason: 'client HTTP réel remis');
    expect(find.byType(TextFormField).evaluate().isNotEmpty, isTrue);
    expect(find.widgetWithText(TextFormField, ModeDemo.adresse), findsNothing);
    await finDemo(tester);
  });

  testWidgets('écritures et exports refusés : « Indisponible en démonstration », rien d\'envoyé, aucun plantage', (tester) async {
    telephone(tester);
    final client = await preparerInstallation();
    await lancerApplication(tester);
    await pomper(tester, fois: 10);
    await toucherDemo(tester);

    // Depuis l'écran : changement du statut d'un lot à péremption courte (PUT).
    await ouvrir(tester, () => const PeremptionsCourtesScreen());
    await tester.tap(find.byKey(const Key('pc_statut_ligne_0')));
    await pomper(tester, fois: 5);
    await tester.tap(find.byKey(const Key('pc_choix_RECLAME')).last);
    await pomper(tester, fois: 5);
    expect(find.textContaining(ModeDemo.messageIndisponible), findsWidgets);
    expect(tester.takeException(), isNull);
    await fermer(tester);

    // Toutes les familles d'écriture (POST, PUT, DELETE, GET d'action, export) : refusées avant tout envoi.
    final ctx = contexteAccueil(tester);
    final api = ApiService();
    final appels = <String, Future<Object?> Function()>{
      'POST quantité suggestion': () => api.post(ctx, AppConstants.suggestionUpdateQteEndpoint, {'id': 'X', 'qte': 2}),
      'POST terminal retiré': () => api.post(ctx, '/rh/mobile/terminaux/TERM-TEST-1/retirer', {}),
      'POST rappels marqués': () => api.postAvecParametres(ctx, '/rappels-habitude/marquer', {'ids': ['R1']}),
      'PUT pointage BL': () => api.put(ctx, '/pointage-bl/pointer/BL/1'),
      'DELETE suggestion': () => api.delete(ctx, '${AppConstants.suggestionDeleteEndpoint}/S1'),
      'GET annulation de vente': () => api.get(ctx, '${AppConstants.venteAnnulationEndpoint}/V1'),
      'GET suggestion en attente': () => api.get(ctx, '${AppConstants.suggestionSetPendingEndpoint}/S1'),
      'export PDF': () => api.getBytes(ctx, '/balance/balancesalecash/pdf'),
    };
    for (final e in appels.entries) {
      Object? erreur;
      try {
        await e.value();
      } catch (x) {
        erreur = x;
      }
      expect(erreur, isA<ApiLoadException>().having((x) => x.message, 'message', ModeDemo.messageIndisponible), reason: e.key);
    }
    // Lectures en POST toujours permises (ticket Z) ; lecture GET ordinaire servie.
    expect(await api.get(ctx, '/officine'), isA<List<Object?>>());
    await pomper(tester, fois: 5);
    expect(client.appels, isEmpty);
    expect(reseau.tentatives, isEmpty);
    await finDemo(tester);
  });

  for (final (nom, taille, densite) in [('iPhone SE', const Size(750, 1334), 2.0), ('iPad', const Size(2048, 1536), 2.0)]) {
    testWidgets('iOS · $nom : même démonstration (1 toucher, rubriques, aucune requête, sortie)', (tester) async {
      tester.view.devicePixelRatio = densite;
      tester.view.physicalSize = taille;
      addTearDown(tester.view.reset);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final client = await preparerInstallation();
        await lancerApplication(tester);
        await pomper(tester, fois: 10);
        final prefsAvant = await instantanePreferences();
        await toucherDemo(tester);
        expect(find.text(ModeDemo.libelleBandeau), findsOneWidget);
        for (final titre in ['Détail CA', 'CA Crédit', 'Analyse Article', 'Etat de Stock', 'Présences']) {
          final erreurs = await releverErreurs(() async {
            await ouvrir(tester, menusModules.firstWhere((m) => m.titre == titre).ecran);
            expect(erreursVisibles(), isEmpty, reason: titre);
            await fermer(tester);
          });
          expect(erreurs, isEmpty, reason: '$titre : $erreurs');
        }
        await quitterDemo(tester);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(await instantanePreferences(), prefsAvant);
        expect(client.appels, isEmpty);
        expect(reseau.tentatives, isEmpty);
        await finDemo(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  group('téléphone configuré (serveur réel)', () {
    final serveur = FauxServeurPrestige();
    setUp(() async {
      await serveur.demarrer();
      serveur.installerRoutesParDefaut();
    });
    tearDown(serveur.arreter);

    testWidgets('connexion → démonstration → sortie : config, identifiants mémorisés et serveur réel intacts', (tester) async {
      telephone(tester);
      preparerTelephone(serveur, nouvelle: true, autres: {
        AppConstants.rememberMeKey: true,
        AppConstants.savedUsernameKey: DonneesFictives.identifiant,
        'officine_name': DonneesFictives.nomOfficine,
      });
      ModeDemo.horloge = () => horlogeDemo;
      final reel = serveur.clientMemoire();
      ApiService.client = reel;
      await lancerApplication(tester);
      await pomperJusqua(tester, () => find.byType(LoginScreen).evaluate().isNotEmpty, raison: 'écran de connexion');
      await pomper(tester, fois: 10);
      final prefsAvant = await instantanePreferences();
      final coffreAvant = await instantaneCoffre();
      final requetesAvant = serveur.requetes.length;

      await tester.ensureVisible(find.byKey(const Key('essayer_demonstration')));
      await pomper(tester, fois: 3);
      await toucherDemo(tester);
      expect(find.text(ServeurDemo.officine), findsWidgets);
      expect(find.text(DonneesFictives.nomOfficine), findsNothing, reason: 'aucune donnée réelle dans la démonstration');
      await ouvrir(tester, menusModules.firstWhere((m) => m.titre == 'CA Crédit').ecran);
      await fermer(tester);
      // Déconnexion depuis l'accueil (bouton) = sortie de la démonstration.
      expect(serveur.requetes.length, requetesAvant, reason: 'aucune requête au serveur réel pendant la démonstration');
      Provider.of<AuthProvider>(contexteAccueil(tester), listen: false).forceLogout();
      await pomper(tester, fois: 20);
      expect(ModeDemo.estActif, isFalse);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(await instantanePreferences(), prefsAvant);
      expect(await instantaneCoffre(), coffreAvant);
      expect(identical(ApiService.client, reel), isTrue);

      // La vraie connexion fonctionne toujours, contre le vrai serveur.
      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), DonneesFictives.motDePasse);
      await tester.tap(find.byKey(const Key('connexion_se_connecter')));
      await pomperJusqua(tester, () => find.byType(AccueilNouveau).evaluate().isNotEmpty, raison: 'accueil réel');
      await pomper(tester, fois: 10);
      expect(serveur.recues('/user/auth', methode: 'POST'), isNotEmpty);
      expect(find.text(ModeDemo.libelleBandeau), findsNothing);
      expect(find.text(ServeurDemo.officine), findsNothing);
      await finDemo(tester);
    });
  });
}
