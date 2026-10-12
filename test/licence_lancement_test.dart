// Étape 1e : au lancement, serveur injoignable ≠ problème de licence (même règle que prestige_vente_app).
// Serveur injoignable → message + « Réessayer » + réessai automatique toutes les 10 s (la licence n'est pas
// en cause) ; licence réellement absente ou expirée → message dédié et saisie de la clé.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prestige_app/main.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/screens/licence_registration_screen.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/screens/serveur_injoignable_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/services/journal_app.dart';
import 'package:prestige_app/services/pin_securise.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/contexte_api.dart';

/// Réponse de /licence/find : null = serveur injoignable.
http.Response? Function() licence = () => null;
int verifications = 0;

const valide = '{"id":"L1","typeLicence":"ANNUELLE","dateStart":"2026-01-01","dateEnd":"2099-12-31"}';
const expiree = '{"id":"L1","typeLicence":"ANNUELLE","dateStart":"2025-01-01","dateEnd":"2026-01-01"}';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'local_ip': '10.0.0.5', 'remote_ip': 'pharma.example.com', 'is_app_configured': true});
    FlutterSecureStorage.setMockInitialValues({});
    CodeAdmin.instance = CodeAdmin(iterations: 1000);
    JournalApp.actif = false;
    verifications = 0;
    licence = () => null;
    ApiService.client = MockClient((req) async {
      if (req.url.path.endsWith('/licence/find')) {
        verifications++;
        final r = licence();
        if (r == null) throw const SocketException('Connection refused');
        return r;
      }
      return http.Response('[]', 200);
    });
  });

  tearDown(() => ApiService.client = http.Client());

  Future<void> lancer(WidgetTester tester) async {
    await monterAvecProviders(tester, ecran: const AuthWrapper());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('serveur injoignable : pas d\'écran de licence ; message, décompte 10 s et réessai automatique', (tester) async {
    await lancer(tester);
    expect(find.byType(ServeurInjoignableScreen), findsOneWidget);
    expect(find.byType(LicenceRegistrationScreen), findsNothing);
    expect(find.text('Le serveur ne répond pas'), findsOneWidget);
    expect(find.textContaining('La licence n\'est pas en cause'), findsOneWidget);
    expect(find.text('Serveur local · 10.0.0.5:8080'), findsOneWidget);
    expect(find.text('Nouvel essai automatique dans 10 s'), findsOneWidget);
    final avant = verifications;

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Nouvel essai automatique dans 9 s'), findsOneWidget);

    // Toujours injoignable après 10 s : nouvel essai, l'écran reste.
    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
    expect(verifications, avant + 1);
    expect(find.byType(ServeurInjoignableScreen), findsOneWidget);
    expect(find.text('Nouvel essai automatique dans 10 s'), findsOneWidget);

    // Serveur revenu, licence valide : on passe à la connexion sans rien toucher.
    licence = () => http.Response(valide, 200);
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(ServeurInjoignableScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('« Réessayer » : vérification immédiate ; licence réellement absente → écran de licence expliqué', (tester) async {
    await lancer(tester);
    licence = () => http.Response('', 200); // Prestige répond : aucune licence
    await tester.tap(find.byKey(const Key('injoignable_reessayer')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(LicenceRegistrationScreen), findsOneWidget);
    expect(find.text('Licence requise'), findsOneWidget);
    expect(find.textContaining('aucune licence n\'est enregistrée'), findsOneWidget);
  });

  testWidgets('licence expirée : date et explication', (tester) async {
    licence = () => http.Response(expiree, 200);
    await lancer(tester);
    expect(find.byType(LicenceRegistrationScreen), findsOneWidget);
    expect(find.text('Votre licence a expiré le 01/01/2026.'), findsOneWidget);
    expect(find.textContaining('n\'est plus valide'), findsOneWidget);
  });

  testWidgets('licence valide : écran de connexion', (tester) async {
    licence = () => http.Response(valide, 200);
    await lancer(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('application Prestige absente (404) ou erreur serveur : message dédié, pas de licence', (tester) async {
    licence = () => http.Response('Not Found', 404);
    await lancer(tester);
    expect(find.text('Prestige introuvable à cette adresse'), findsOneWidget);
    licence = () => http.Response('<html>500</html>', 500);
    await tester.tap(find.byKey(const Key('injoignable_reessayer')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Le serveur Prestige a répondu par une erreur'), findsOneWidget);
    expect(find.byType(LicenceRegistrationScreen), findsNothing);
  });

  testWidgets('bascule vers le serveur distant et Configuration protégée par le code', (tester) async {
    await lancer(tester);
    await tester.tap(find.byKey(const Key('injoignable_basculer')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Serveur distant · pharma.example.com:8080'), findsOneWidget);

    await tester.tap(find.byKey(const Key('injoignable_configuration')));
    await tester.pumpAndSettle();
    expect(find.text('Code Administrateur requis :'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Configurer les adresses IP du serveur'), findsNothing);
    // Le décompte reprend après la fermeture.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ServeurInjoignableScreen), findsOneWidget);
  });

  test('statut « error » distinct de « notFound »', () {
    expect(LicenceStatus.values, contains(LicenceStatus.error));
    expect(LicenceStatus.error, isNot(LicenceStatus.notFound));
  });
}
