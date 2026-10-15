// RÉSEAU — Prestige momentanément INDISPONIBLE à la connexion (3.10.2, demande du pharmacien : « erreur 404 » quand
// il se connecte pendant un redéploiement de Prestige), deux interfaces :
//  - 404 de POST /user/auth (application en cours de redéploiement), 502 / 503 / 504, connexion refusée (port fermé,
//    vrai socket) → « Serveur indisponible, veuillez réessayer. », jamais « code 404 » ; puis, serveur revenu,
//    connexion réussie au réessai ;
//  - NON confondu avec : mot de passe faux (message du serveur), erreur 500 (« Erreur du serveur »), Wi-Fi coupé
//    (« Serveur injoignable… Vérifiez le Wi-Fi »), 404 MÉTIER d'un module (inchangé) ;
//  - /officine en 404 sur l'écran de connexion : aucune erreur affichée, le dernier nom connu reste.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/screens/home_screen.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import '../outils/contexte_api.dart';
import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();
const indisponible = ApiLoadException.messageServeurIndisponible;

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

Future<void> laisser(WidgetTester tester, {int dixiemes = 20}) async {
  for (var i = 0; i < dixiemes; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lancement → écran de connexion (licence lue), interface [nouvelle] ou d'origine.
Future<void> jusquConnexion(WidgetTester tester, {required bool nouvelle}) async {
  if (nouvelle) {
    preparerNouvelle(serveur, p: Presentation.compact);
  } else {
    preparerTelephone(serveur);
  }
  ApiService.client = serveur.clientMemoire();
  await lancerApplication(tester);
  for (var i = 0; i < 100 && find.byType(LoginScreen).evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.byType(LoginScreen), findsOneWidget);
  await laisser(tester, dixiemes: 10);
}

Future<void> tenterConnexion(WidgetTester tester, {String motDePasse = DonneesFictives.motDePasse}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), DonneesFictives.identifiant);
  await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), motDePasse);
  final bouton = find.byKey(const Key('connexion_se_connecter'));
  await tester.tap(bouton.evaluate().isNotEmpty ? bouton : find.widgetWithText(ElevatedButton, 'Connexion'));
  await laisser(tester);
}

Future<void> fermer(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 2));
}

/// Aucun code HTTP brut à l'écran.
void aucunCodeBrut() {
  expect(find.textContaining('404'), findsNothing);
  expect(find.textContaining('code 50'), findsNothing);
}

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() {
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..coupe = false
      ..oublierRequetes();
    donneesAccueil(serveur);
  });

  for (final nouvelle in [true, false]) {
    final nom = nouvelle ? 'nouvelle interface' : 'interface d\'origine';
    final accueil = nouvelle ? find.byType(AccueilNouveau) : find.byType(HomeScreen);

    for (final (cas, reponse) in [
      ('404 (redéploiement)', ReponseFausse.introuvable()),
      ('502', ReponseFausse.erreurServeur(statut: 502)),
      ('503', ReponseFausse.erreurServeur(statut: 503)),
      ('504', ReponseFausse.erreurServeur(statut: 504)),
    ]) {
      testWidgets('$nom : connexion en $cas → « Serveur indisponible » ; serveur revenu → connexion réussie', (tester) async {
        telephone(tester);
        await jusquConnexion(tester, nouvelle: nouvelle);
        serveur.quand(AppConstants.authEndpoint, reponse, methode: 'POST');
        await tenterConnexion(tester);
        expect(find.text(indisponible), findsOneWidget);
        aucunCodeBrut();
        expect(find.byType(LoginScreen), findsOneWidget);
        // Prestige redéployé : réessai.
        serveur.installerRoutesParDefaut();
        donneesAccueil(serveur);
        await tenterConnexion(tester);
        await laisser(tester, dixiemes: 30);
        expect(accueil, findsOneWidget);
        await fermer(tester);
      });
    }

    testWidgets('$nom : connexion refusée (Prestige arrêté) → « Serveur indisponible »', (tester) async {
      telephone(tester);
      await jusquConnexion(tester, nouvelle: nouvelle);
      serveur.coupe = true; // le client en mémoire lève SocketException('Connection refused')
      await tenterConnexion(tester);
      expect(find.text(indisponible), findsOneWidget);
      serveur.coupe = false;
      await fermer(tester);
    });

    testWidgets('$nom : NON confondu — mot de passe faux, erreur 500, Wi-Fi coupé', (tester) async {
      telephone(tester);
      await jusquConnexion(tester, nouvelle: nouvelle);
      await tenterConnexion(tester, motDePasse: 'Mauvais-Mot-De-Passe-1');
      expect(find.text(DonneesFictives.messageIdentifiantsIncorrects), findsOneWidget);
      expect(find.text(indisponible), findsNothing);

      serveur.quand(AppConstants.authEndpoint, ReponseFausse.erreurServeur(), methode: 'POST');
      await tenterConnexion(tester);
      expect(find.textContaining('Erreur du serveur (code 500)'), findsOneWidget);
      expect(find.text(indisponible), findsNothing);

      // Wi-Fi coupé : le réseau est inaccessible (≠ connexion refusée par le serveur).
      ApiService.client = MockClient((_) async => throw const SocketException('Network is unreachable', osError: OSError('Network is unreachable', 101)));
      await tenterConnexion(tester);
      expect(find.textContaining('Serveur injoignable'), findsOneWidget);
      expect(find.text(indisponible), findsNothing);
      await fermer(tester);
    });
  }

  testWidgets('/officine en 404 sur l\'écran de connexion : aucune erreur affichée, connexion normale', (tester) async {
    telephone(tester);
    serveur.quand(AppConstants.officineEndpoint, ReponseFausse.introuvable(), methode: 'GET');
    await jusquConnexion(tester, nouvelle: true);
    expect(find.text(indisponible), findsNothing);
    aucunCodeBrut();
    await tenterConnexion(tester);
    await laisser(tester, dixiemes: 30);
    expect(find.byType(AccueilNouveau), findsOneWidget);
    await fermer(tester);
  });

  group('vrai réseau (127.0.0.1)', () {
    test('port fermé : connexion refusée reconnue (ni 404, ni Wi-Fi)', () async {
      final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = s.port;
      await s.close(force: true);
      final avant = HttpOverrides.current;
      HttpOverrides.global = null; // flutter_test simule HttpClient : vrai socket pour ce test
      addTearDown(() => HttpOverrides.global = avant);
      try {
        await http.Client().post(Uri.parse('http://127.0.0.1:$port/prestige/api/v1/user/auth'), body: '{}');
        fail('connexion attendue refusée');
      } catch (e) {
        expect(ApiService.connexionRefusee(e), isTrue, reason: '$e');
      }
    });

    testWidgets('POST /user/auth en 404 : exception « serveur indisponible » (code 404 gardé pour le diagnostic)', (tester) async {
      preparerTelephone(serveur);
      ApiService.client = serveur.clientMemoire();
      serveur.quand(AppConstants.authEndpoint, ReponseFausse.introuvable(), methode: 'POST');
      final ctx = await monterAvecProviders(tester);
      Object? erreur;
      try {
        await ApiService().post(ctx, AppConstants.authEndpoint, {'login': 'x', 'password': 'y'});
      } catch (e) {
        erreur = e;
      }
      expect(erreur, isA<ApiLoadException>());
      expect((erreur as ApiLoadException).code, 404);
      expect(erreur.serveurIndisponible, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    });
  });
}
