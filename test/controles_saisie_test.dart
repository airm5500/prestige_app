// Étape 1g : contrôles de saisie sur les champs (recherches, quantités, montants, dates, connexion,
// configuration, clé de licence) : longueur maximale, caractères autorisés, bornes.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prestige_app/screens/etat_stock_screen.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/screens/settings_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/services/journal_app.dart';
import 'package:prestige_app/utils/saisie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/contexte_api.dart';

String appliquer(List<TextInputFormatter> f, String ancien, String nouveau) {
  var valeur = TextEditingValue(text: nouveau, selection: TextSelection.collapsed(offset: nouveau.length));
  final avant = TextEditingValue(text: ancien, selection: TextSelection.collapsed(offset: ancien.length));
  for (final x in f) {
    valeur = x.formatEditUpdate(avant, valeur);
  }
  return valeur.text;
}

void main() {
  group('Règles', () {
    test('recherche : caractères de contrôle retirés, 60 caractères au plus', () {
      expect(Saisie.recherche('  dolip\u0000rane\n '), 'doliprane');
      expect(Saisie.recherche('x' * 200).length, Saisie.maxRecherche);
      expect(appliquer(Saisie.rechercheFormatters, '', 'a' * 100).length, Saisie.maxRecherche);
    });

    test('entiers bornés', () {
      expect(Saisie.entier('120', min: 0, max: 120), 120);
      expect(Saisie.entier('121', min: 0, max: 120), isNull);
      expect(Saisie.entier('-5', min: -10, max: 10), -5);
      expect(Saisie.entier('abc', min: 0, max: 10), isNull);
      expect(appliquer(Saisie.entierFormatters(3), '', '12a45'), '124');
      expect(appliquer(Saisie.entierSigneFormatters(3), '-1', '-1-'), '-1');
      expect(appliquer(Saisie.entierSigneFormatters(3), '', '-123'), '-123');
    });

    test('montants : virgule acceptée, 2 décimales, bornes', () {
      expect(Saisie.montant('1500,50'), 1500.5);
      expect(Saisie.montant('-3'), isNull);
      expect(Saisie.montant('1e400'), isNull);
      expect(appliquer(Saisie.montantFormatters, '12,5', '12,555'), '12,5');
      expect(appliquer(Saisie.montantFormatters, '12', '12a'), '12');
    });

    test('période : la fin n\'est jamais avant le début', () {
      final a = DateTime(2026, 3, 10), b = DateTime(2026, 3, 1);
      expect(Saisie.periode(a, b, debutModifie: true), (a, a));
      expect(Saisie.periode(a, b, debutModifie: false), (b, b));
      expect(Saisie.periode(b, a, debutModifie: true), (b, a));
    });

    test('configuration : port, délai, nom de l\'application', () {
      expect(Saisie.erreurPort('8080'), isNull);
      expect(Saisie.erreurPort('0'), isNotNull);
      expect(Saisie.erreurPort('70000'), isNotNull);
      expect(Saisie.erreurDelai('0'), isNull);
      expect(Saisie.erreurDelai('1441'), isNotNull);
      expect(Saisie.erreurNomApplication('prestige'), isNull);
      expect(Saisie.erreurNomApplication('pres tige/../x'), isNotNull);
      expect(appliquer(Saisie.nomApplicationFormatters, '', 'pres tige/'), 'prestige');
    });

    test('connexion : identifiant rogné, mot de passe gardé tel quel', () {
      expect(Saisie.erreurIdentifiant('   '), isNotNull);
      expect(Saisie.erreurMotDePasse(' a '), isNull);
      expect(Saisie.erreurMotDePasse(''), isNotNull);
      expect(appliquer(Saisie.motDePasseFormatters, '', 'p' * 300).length, Saisie.maxMotDePasse);
    });

    test('clé de licence : nettoyée', () {
      expect(Saisie.cleLicence('  ABCD-1234\n'), 'ABCD-1234');
    });
  });

  group('Écrans', () {
    late List<http.Request> requetes;

    setUp(() {
      SharedPreferences.setMockInitialValues({'local_ip': '10.0.0.5', 'is_app_configured': true});
      FlutterSecureStorage.setMockInitialValues({});
      JournalApp.actif = false;
      requetes = [];
      ApiService.client = MockClient((req) async {
        requetes.add(req);
        if (req.url.path.endsWith('/user/auth')) return http.Response('{"success":false}', 200);
        return http.Response('{"data":[],"total":0}', 200);
      });
    });

    tearDown(() => ApiService.client = http.Client());

    testWidgets('connexion : le mot de passe est envoyé sans être rogné ; identifiant vide refusé', (tester) async {
      await monterAvecProviders(tester, ecran: const LoginScreen());
      await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), '   ');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), 'x');
      await tester.tap(find.text('Connexion'));
      await tester.pump();
      expect(find.text('Veuillez entrer un identifiant.'), findsOneWidget);
      expect(requetes.where((r) => r.url.path.endsWith('/user/auth')), isEmpty);

      await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), ' admin ');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), 'Test1234 ');
      await tester.tap(find.text('Connexion'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final auth = requetes.lastWhere((r) => r.url.path.endsWith('/user/auth'));
      expect(jsonDecode(auth.body), {'login': 'admin', 'password': 'Test1234 '});
    });

    testWidgets('configuration : port et délai hors bornes refusés', (tester) async {
      await monterAvecProviders(tester, ecran: const SettingsScreen());
      await tester.tap(find.byTooltip('Modifier le port'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextFormField, 'Port du Serveur'), '99999');
      await tester.enterText(find.widgetWithText(TextFormField, 'Délai de déconnexion (minutes)'), '5000');
      await tester.ensureVisible(find.text('Enregistrer et Continuer'));
      await tester.tap(find.text('Enregistrer et Continuer'));
      await tester.pump();
      expect(find.text('Port invalide (1 à 65535).'), findsOneWidget);
      expect(find.text('Valeur invalide (0 à 1440 minutes).'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('port_key'), isNull, reason: 'rien enregistré');
    });

    testWidgets('État de stock : recherche limitée et nettoyée avant l\'envoi', (tester) async {
      await monterAvecProviders(tester, ecran: const EtatStockScreen());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Recherche (Nom, Code, Scan)'), '  ${'d' * 80}  ');
      await tester.tap(find.text('APPLIQUER FILTRES'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final r = requetes.lastWhere((r) => r.url.path.endsWith('/fichearticle/comparaison'));
      expect(r.url.queryParameters['query'], hasLength(lessThanOrEqualTo(Saisie.maxRecherche)));
      expect(r.url.queryParameters['query']!.trim(), r.url.queryParameters['query']);
    });

    testWidgets('clé de licence : encodée dans l\'adresse (route GET inchangée)', (tester) async {
      final ctx = await monterAvecProviders(tester);
      Object? erreur;
      await ApiService().registerLicence(ctx, 'AB/CD 12').catchError((Object e) {
        erreur = e;
        return false;
      });
      expect(erreur, isNull);
      final r = requetes.last;
      expect(r.method, 'GET');
      expect(r.url.path, '/prestige/api/v1/licence/save/AB%2FCD%2012');
    });
  });
}
