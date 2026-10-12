// Étape 1b : journaux minimaux. Jamais d'URL avec paramètres, de réponse complète du serveur ni de secret
// (mot de passe, cookie, clé de licence) ; rien du tout dans une version release.
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/services/journal_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/contexte_api.dart';

void main() {
  late List<String> journal;

  setUp(() {
    SharedPreferences.setMockInitialValues({'local_ip': '10.0.0.5', 'is_app_configured': true});
    FlutterSecureStorage.setMockInitialValues({});
    journal = [];
    JournalApp.actif = true;
    JournalApp.sortie = journal.add;
  });

  tearDown(() => ApiService.client = http.Client());

  group('Masquage', () {
    test('paramètres d\'URL retirés', () {
      final t = JournalApp.masquer('GET http://10.0.0.5:8080/prestige/api/v1/fichearticle/comparaison?query=doliprane&limit=15');
      expect(t, isNot(contains('doliprane')));
      expect(t, contains('/fichearticle/comparaison?…'));
    });

    test('cookie, mot de passe, clé de licence et PIN masqués', () {
      expect(JournalApp.masquer('Cookie: JSESSIONID=abc123; Path=/'), isNot(contains('abc123')));
      expect(JournalApp.masquer('{"login":"admin","password":"Secret!42"}'), isNot(contains('Secret!42')));
      expect(JournalApp.masquer('GET /api/v1/licence/save/AAAA-BBBB-CCCC'), isNot(contains('AAAA-BBBB')));
      expect(JournalApp.masquer('pin=4826'), isNot(contains('4826')));
    });

    test('requête décrite par sa méthode et son chemin seulement', () {
      final uri = Uri.parse('http://10.0.0.5:8080/prestige/api/v1/ventestats?query=123&dtStart=2026-01-01');
      expect(JournalApp.requete('GET', uri), 'GET /api/v1/ventestats');
    });
  });

  test('version release : rien n\'est écrit', () {
    JournalApp.actif = false;
    JournalApp.debug('GET /api/v1/officine');
    expect(journal, isEmpty);
  });

  testWidgets('ApiService : URL sans paramètres, ni réponse brute, ni cookie dans le journal', (tester) async {
    ApiService.client = MockClient((req) async {
      if (req.url.path.endsWith('/user/auth')) {
        return http.Response('{"success":true,"str_LOGIN":"admin"}', 200, headers: {'set-cookie': 'JSESSIONID=abc123secret; Path=/prestige'});
      }
      return http.Response('<html>Stacktrace interne doliprane SECRET-SERVEUR</html>', 500);
    });
    final ctx = await monterAvecProviders(tester);
    await tester.runAsync(() async {
      await ApiService().post(ctx, '/user/auth', {'login': 'admin', 'password': 'Secret!42'});
      try {
        await ApiService().get(ctx, '/fichearticle/comparaison', queryParams: {'query': 'doliprane', 'limit': '15'});
      } catch (_) {}
    });
    expect(journal, isNotEmpty);
    expect(journal.any((l) => l.contains('GET /api/v1/fichearticle/comparaison')), isTrue);
    for (final l in journal) {
      expect(l, isNot(contains('doliprane')));
      expect(l, isNot(contains('SECRET-SERVEUR')));
      expect(l, isNot(contains('abc123secret')));
      expect(l, isNot(contains('Secret!42')));
    }
  });

  test('aucun debugPrint / print direct dans lib/ (tout passe par JournalApp)', () {
    final fautifs = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      if (f.path.endsWith('journal_app.dart')) continue;
      final lignes = f.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        if (RegExp(r'(^|[^\w.])(debugPrint|print)\(').hasMatch(lignes[i])) fautifs.add('${f.path}:${i + 1}');
      }
    }
    expect(fautifs, isEmpty);
  });
}
