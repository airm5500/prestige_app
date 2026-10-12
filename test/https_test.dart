// Étape 1h : adresses https:// acceptées dans la configuration du serveur (tests, accès distant) ;
// HTTP garanti pour le réseau local (comportement d'origine) ; HTTPS jamais imposé.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prestige_app/providers/ip_config_provider.dart';
import 'package:prestige_app/screens/settings_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/services/journal_app.dart';
import 'package:prestige_app/utils/adresse_serveur.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/contexte_api.dart';

void main() {
  group('AdresseServeur', () {
    test('sans protocole : HTTP (réseau local, inchangé)', () {
      expect(AdresseServeur.racine('192.168.1.100', '8080', 'prestige'), 'http://192.168.1.100:8080/prestige');
      expect(AdresseServeur.racine('serveur', '8080', 'prestige'), 'http://serveur:8080/prestige');
    });

    test('https:// et http:// acceptés (casse indifférente, barre finale tolérée)', () {
      expect(AdresseServeur.racine('https://pharma.example.com', '8181', 'prestige'), 'https://pharma.example.com:8181/prestige');
      expect(AdresseServeur.racine('HTTPS://pharma.example.com/', '443', 'prestige'), 'https://pharma.example.com:443/prestige');
      expect(AdresseServeur.racine('http://10.0.0.5', '8080', 'prestige'), 'http://10.0.0.5:8080/prestige');
      expect(AdresseServeur.estHttps('https://pharma.example.com'), isTrue);
      expect(AdresseServeur.estHttps('192.168.1.100'), isFalse);
    });

    test('contrôle de la saisie', () {
      expect(AdresseServeur.erreur('192.168.1.100', requis: true), isNull);
      expect(AdresseServeur.erreur('https://pharma.example.com', requis: true), isNull);
      expect(AdresseServeur.erreur('', requis: false), isNull);
      expect(AdresseServeur.erreur('', requis: true), 'Ce champ est requis.');
      expect(AdresseServeur.erreur('ftp://pharma.example.com', requis: true), contains('https://'));
      expect(AdresseServeur.erreur('pharma.example.com:8080', requis: true), contains('port'));
      expect(AdresseServeur.erreur('pharma.example.com/prestige', requis: true), contains('chemin'));
      expect(AdresseServeur.erreur('192.168.1', requis: true), isNotNull);
      expect(AdresseServeur.erreur('300.1.1.1', requis: true), isNotNull);
      expect(AdresseServeur.erreur('pharma example', requis: true), isNotNull);
    });
  });

  group('Application', () {
    late List<http.Request> requetes;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      JournalApp.actif = false;
      requetes = [];
      ApiService.client = MockClient((req) async {
        requetes.add(req);
        return http.Response('[]', 200);
      });
    });

    tearDown(() => ApiService.client = http.Client());

    testWidgets('mode distant en https : toutes les requêtes (v1 et v3) partent en HTTPS ; local reste en HTTP', (tester) async {
      SharedPreferences.setMockInitialValues({
        'local_ip': '192.168.1.100',
        'remote_ip': 'https://pharma.example.com',
        'port_key': '8181',
        'is_app_configured': true,
      });
      final ip = IpConfigProvider();
      final ctx = await monterAvecProviders(tester, ip: ip);
      expect(ip.activeBaseUrl, 'http://192.168.1.100:8181/prestige/api/v1');

      ip.setUseLocalIp(false);
      await tester.pump();
      expect(ip.activeBaseUrl, 'https://pharma.example.com:8181/prestige/api/v1');
      await ApiService().get(ctx, '/officine');
      await ApiService().getV3(ctx, '/tvas');
      expect(requetes.map((r) => r.url.toString()), [
        'https://pharma.example.com:8181/prestige/api/v1/officine',
        'https://pharma.example.com:8181/prestige/api/v3/tvas',
      ]);
    });

    testWidgets('certificat refusé : message clair', (tester) async {
      SharedPreferences.setMockInitialValues({'local_ip': 'https://pharma.example.com', 'is_app_configured': true});
      ApiService.client = MockClient((_) async => throw const HandshakeException('CERTIFICATE_VERIFY_FAILED'));
      final ctx = await monterAvecProviders(tester);
      Object? e;
      await ApiService().get(ctx, '/officine').catchError((Object x) => e = x);
      expect('$e', ApiLoadException.messageCertificat);
    });

    testWidgets('Configuration : une adresse https:// est acceptée et enregistrée telle quelle (mêmes clés)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await monterAvecProviders(tester, ecran: const SettingsScreen());
      await tester.enterText(find.widgetWithText(TextFormField, 'Adresse IP Locale'), '192.168.1.100');
      await tester.enterText(find.widgetWithText(TextFormField, 'Adresse IP Distante'), 'https://pharma.example.com');
      await tester.ensureVisible(find.text('Enregistrer et Continuer'));
      await tester.tap(find.text('Enregistrer et Continuer'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('remote_ip'), 'https://pharma.example.com');
      expect(prefs.getString('local_ip'), '192.168.1.100');
      // Le test de connexion a interrogé l'adresse https.
      expect(requetes.any((r) => r.url.scheme == 'https' && r.url.host == 'pharma.example.com'), isTrue);
    });

    testWidgets('Configuration : protocole inconnu refusé', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await monterAvecProviders(tester, ecran: const SettingsScreen());
      await tester.enterText(find.widgetWithText(TextFormField, 'Adresse IP Locale'), 'ftp://192.168.1.100');
      await tester.ensureVisible(find.text('Enregistrer et Continuer'));
      await tester.tap(find.text('Enregistrer et Continuer'));
      await tester.pump();
      expect(find.text('Seuls http:// et https:// sont acceptés.'), findsOneWidget);
    });
  });

  test('trafic en clair : toujours autorisé (mode local) et documenté', () {
    final xml = File('android/app/src/main/res/xml/network_security_config.xml').readAsStringSync();
    expect(xml, contains('cleartextTrafficPermitted="true"'));
    expect(File('docs/HTTPS_ET_TRAFIC_EN_CLAIR.md').existsSync(), isTrue);
  });
}
