// Étape 1a : mot de passe mémorisé et cookie de session plus jamais en clair.
// Stockage sécurisé (flutter_secure_storage), migration transparente des anciennes clés en clair
// (`saved_password`, `session_cookie`) puis suppression, repli sans perte si le stockage sûr échoue,
// exclusion des sauvegardes Android, rien dans le journal.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/providers/ip_config_provider.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/services/journal_app.dart';
import 'package:prestige_app/services/stockage_securise.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const mdp = 'Secret!42';
const cookie = 'JSESSIONID=abc123secret';

/// Stockage sûr en panne (Keystore indisponible) ; [relectureFausse] : relecture différente de l'écriture.
class CoffreEnPanne implements CoffreIdentifiants {
  final bool relectureFausse;
  final Map<String, String> donnees = {};
  CoffreEnPanne({this.relectureFausse = false});

  @override
  Future<String?> lire(String cle) async {
    if (relectureFausse) return 'autre';
    throw PlatformException(code: 'KeyStoreException', message: 'Keystore indisponible ($mdp)');
  }

  @override
  Future<void> ecrire(String cle, String valeur) async {
    if (relectureFausse) {
      donnees[cle] = valeur;
      return;
    }
    throw Exception('écriture impossible : $valeur');
  }

  @override
  Future<void> effacer(String cle) async => throw PlatformException(code: 'KeyStoreException');
}

const _sur = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

Future<void> aucuneTraceEnClair(List<String> secrets) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  expect(prefs.containsKey('saved_password'), isFalse);
  expect(prefs.containsKey('session_cookie'), isFalse);
  for (final k in prefs.getKeys()) {
    for (final s in secrets) {
      expect('${prefs.get(k)}', isNot(contains(s)), reason: 'clé $k');
    }
  }
}

/// Serveur simulé : /user/auth accepte [mdp] et pose un cookie ; /officine répond.
MockClient serveur({List<http.Request>? requetes}) => MockClient((req) async {
      requetes?.add(req);
      if (req.url.path.endsWith('/user/auth')) {
        final body = jsonDecode(req.body) as Map;
        if (body['password'] == mdp) {
          return http.Response(
              jsonEncode({'success': true, 'str_USER_ID': 'u1', 'str_FIRST_NAME': 'Awa', 'str_LAST_NAME': 'Kouassi', 'str_LOGIN': body['login'], 'OFFICINE': 'PHCIE TEST'}),
              200,
              headers: {'set-cookie': '$cookie; Path=/prestige; HttpOnly', 'content-type': 'application/json'});
        }
        return http.Response('{"success":false}', 200);
      }
      if (req.url.path.endsWith('/officine')) return http.Response('[{"nomComplet":"PHCIE TEST"}]', 200);
      return http.Response('', 404);
    });

void main() {
  late List<String> journal;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    IdentifiantsSecurises.instance = IdentifiantsSecurises.creer();
    CookieSecurise.instance = CookieSecurise.creer();
    journal = [];
    JournalApp.actif = true;
    JournalApp.sortie = journal.add;
  });

  tearDown(() {
    ApiService.client = http.Client();
  });

  void pasDeSecretDansLeJournal() {
    for (final l in journal) {
      expect(l, isNot(contains(mdp.trim())));
      expect(l, isNot(contains('abc123secret')));
    }
  }

  group('Migration transparente', () {
    test('mot de passe et cookie en clair → stockage sûr, puis clés en clair supprimées', () async {
      SharedPreferences.setMockInitialValues({'saved_password': mdp, 'session_cookie': cookie, 'remember_me': true, 'saved_username': 'admin'});
      expect(await IdentifiantsSecurises.instance.migrer(), isTrue);
      await ApiService().loadSessionCookie();

      expect(await _sur.read(key: IdentifiantsSecurises.cleSure), mdp);
      expect(await _sur.read(key: CookieSecurise.cleSure), cookie);
      await aucuneTraceEnClair([mdp, cookie]);
      // Les autres réglages ne bougent pas (mêmes clés).
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('saved_username'), 'admin');
      expect(prefs.getBool('remember_me'), isTrue);
      expect(await IdentifiantsSecurises.instance.lire(), mdp);
      pasDeSecretDansLeJournal();
    });

    test('au démarrage, AuthProvider migre les deux secrets', () async {
      SharedPreferences.setMockInitialValues({'saved_password': mdp, 'session_cookie': cookie});
      final auth = AuthProvider();
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(auth.isLoading, isFalse);
      await aucuneTraceEnClair([mdp, cookie]);
      expect(await _sur.read(key: IdentifiantsSecurises.cleSure), mdp);
    });

    test('rien à migrer : aucune écriture', () async {
      expect(await IdentifiantsSecurises.instance.migrer(), isTrue);
      expect(await _sur.readAll(), isEmpty);
    });
  });

  group('Stockage sûr en panne : repli sans perte', () {
    test('migration impossible : la clé en clair est gardée et relue, nouvel essai au lancement suivant', () async {
      SharedPreferences.setMockInitialValues({'saved_password': mdp});
      IdentifiantsSecurises.instance = IdentifiantsSecurises.creer(coffre: CoffreEnPanne());
      expect(await IdentifiantsSecurises.instance.migrer(), isFalse);
      expect(await IdentifiantsSecurises.instance.lire(), mdp);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('saved_password'), mdp);
      // Lancement suivant, Keystore revenu : migration faite.
      IdentifiantsSecurises.instance = IdentifiantsSecurises.creer();
      expect(await IdentifiantsSecurises.instance.migrer(), isTrue);
      await aucuneTraceEnClair([mdp]);
      expect(journal.any((l) => l.contains('stockage sécurisé indisponible')), isTrue);
      pasDeSecretDansLeJournal();
    });

    test('relecture différente : repli en clair (connexion automatique conservée)', () async {
      final coffre = CoffreEnPanne(relectureFausse: true);
      IdentifiantsSecurises.instance = IdentifiantsSecurises.creer(coffre: coffre);
      await IdentifiantsSecurises.instance.ecrire(mdp);
      expect(await IdentifiantsSecurises.instance.lire(), mdp);
      pasDeSecretDansLeJournal();
    });

    test('cookie : stockage sûr en panne, la session reste utilisable', () async {
      CookieSecurise.instance = CookieSecurise.creer(coffre: CoffreEnPanne());
      await ApiService().setSessionCookie('$cookie; Path=/prestige');
      await ApiService().loadSessionCookie();
      expect(await CookieSecurise.instance.lire(), cookie);
      pasDeSecretDansLeJournal();
    });

    test('effacement : ancienne clé en clair supprimée même si le Keystore est en panne', () async {
      SharedPreferences.setMockInitialValues({'saved_password': mdp});
      IdentifiantsSecurises.instance = IdentifiantsSecurises.creer(coffre: CoffreEnPanne());
      await IdentifiantsSecurises.instance.effacer();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('saved_password'), isFalse);
    });
  });

  group('Connexion', () {
    Widget appli(IpConfigProvider ip, AuthProvider auth) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: ip),
            ChangeNotifierProvider.value(value: auth),
          ],
          child: const MaterialApp(home: LoginScreen()),
        );

    testWidgets('« Rester connecté » : mot de passe dans le stockage sûr, pré-rempli, cookie protégé', (tester) async {
      SharedPreferences.setMockInitialValues({'local_ip': '10.0.0.5', 'is_app_configured': true});
      final requetes = <http.Request>[];
      ApiService.client = serveur(requetes: requetes);
      final ip = IpConfigProvider();
      final auth = AuthProvider();
      await tester.pumpWidget(appli(ip, auth));
      await tester.pump(const Duration(seconds: 3));

      await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), 'admin');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), mdp);
      await tester.tap(find.text('Rester connecté'));
      await tester.tap(find.text('Connexion'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      expect(auth.isLoggedIn, isTrue);
      // Le cookie est renvoyé au serveur ensuite.
      expect(requetes.last.headers['Cookie'], cookie);

      await tester.runAsync(() async {
        expect(await _sur.read(key: IdentifiantsSecurises.cleSure), mdp);
        expect(await _sur.read(key: CookieSecurise.cleSure), cookie);
        await aucuneTraceEnClair([mdp.trim(), 'abc123secret']);
      });

      // Nouvel écran de connexion (après déconnexion) : identifiant et mot de passe pré-remplis.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(appli(ip, AuthProvider()));
      await tester.pump(const Duration(seconds: 3));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      final champs = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      expect(champs[0].controller!.text, 'admin');
      expect(champs[1].controller!.text, mdp);
      pasDeSecretDansLeJournal();
    });

    testWidgets('sans « Rester connecté » : mot de passe effacé partout', (tester) async {
      SharedPreferences.setMockInitialValues({'local_ip': '10.0.0.5', 'is_app_configured': true, 'saved_password': mdp, 'remember_me': true});
      ApiService.client = serveur();
      final auth = AuthProvider();
      await tester.pumpWidget(appli(IpConfigProvider(), auth));
      await tester.pump(const Duration(seconds: 3));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), 'admin');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), mdp);
      await tester.tap(find.text('Rester connecté')); // décoche
      await tester.tap(find.text('Connexion'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      expect(auth.isLoggedIn, isTrue);
      await tester.runAsync(() async {
        expect(await _sur.read(key: IdentifiantsSecurises.cleSure), isNull);
        await aucuneTraceEnClair([mdp.trim()]);
      });
    });
  });

  group('Sauvegardes Android', () {
    test('le stockage sécurisé est exclu des sauvegardes et transferts', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:fullBackupContent="@xml/regles_sauvegarde"'));
      expect(manifest, contains('android:dataExtractionRules="@xml/regles_extraction"'));
      final sauvegarde = File('android/app/src/main/res/xml/regles_sauvegarde.xml').readAsStringSync();
      expect(sauvegarde, contains('<exclude domain="sharedpref" path="FlutterSecureStorage.xml" />'));
      final extraction = File('android/app/src/main/res/xml/regles_extraction.xml').readAsStringSync();
      expect(RegExp('FlutterSecureStorage.xml').allMatches(extraction).length, 2);
    });
  });
}
